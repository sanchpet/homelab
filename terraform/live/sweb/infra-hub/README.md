# infra-hub — import the RU hub node into IaC

The `infra-hub` SpaceWeb node (`petrovpet2_vps_10`, `168.222.202.148`) was created
imperatively (sweb CLI, WP-009). We bring it under Terragrunt by **import**, not recreate:
a fresh apply would bill a second node, and the original is delete-locked for 24h.

Uses the `sanchpet/sweb` provider (github.com/sanchpet/terraform-provider-sweb).

## Prerequisites

```sh
# SpaceWeb auth (kept out of HCL/state):
export SWEB_LOGIN=...  SWEB_PASSWORD=...        # or: export SWEB_TOKEN=...
# Yandex S3 state backend (see ../../root.hcl):
export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...  TF_STATE_BUCKET=sanchpet-homelab-tfstate
```

## Option A — provider on the Terraform Registry (preferred)

Once `sanchpet/sweb` is published to registry.terraform.io, no overrides are needed:

```sh
cd terraform/live/sweb/infra-hub
terragrunt init
terragrunt import sweb_vps.this petrovpet2_vps_10
```

## Option B — local dev_override (before the registry publish)

Build the provider and point Terraform at the binary via a CLI config:

```sh
# 1. Build the provider into a dir (the dev_override target is a DIRECTORY)
mkdir -p ~/.terraform.d/plugins-dev
( cd /path/to/terraform-provider-sweb && go build -o ~/.terraform.d/plugins-dev/terraform-provider-sweb . )

# 2. dev_override config
cat > /tmp/sweb-dev.tfrc <<'EOF'
provider_installation {
  dev_overrides { "registry.terraform.io/sanchpet/sweb" = "/Users/sanchpet/.terraform.d/plugins-dev" }
  direct {}
}
EOF
export TF_CLI_CONFIG_FILE=/tmp/sweb-dev.tfrc

# 3. With dev_overrides, skip provider init (a warning is expected); import directly
cd terraform/live/sweb/infra-hub
terragrunt import sweb_vps.this petrovpet2_vps_10
```

## Reconcile to a clean plan

Import reconstructs the node in **plan-mode** from the API. Read the real ids it wrote and
correct `terragrunt.hcl` so the desired state matches:

```sh
terragrunt state show sweb_vps.this        # note os_distr_id, datacenter_id, plan_id
# -> edit terragrunt.hcl: set distributive / datacenter (and confirm plan = 379)
terragrunt plan                            # must report: No changes
```

`ssh_key` is create-only and not recoverable from the API; if the node was created with one,
re-declare it in HCL (it won't force replacement on an already-imported resource unless
changed). A clean `terragrunt plan` is the proof that `infra-hub` is now managed as code.
