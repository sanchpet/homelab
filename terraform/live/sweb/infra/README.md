# infra — the RU infra node group, imported into IaC

The `infra` group on SpaceWeb is named `infra-01`, `infra-02`, … (slug `infra`, managed by
the `sweb-vps` module). Today only the first node exists: `petrovpet2_vps_10`
(`168.222.202.148`), created imperatively via the sweb CLI (WP-009). We bring it under
Terragrunt by **import**, not recreate — a fresh apply would bill a second node, and the
original is delete-locked for 24h.

Uses the `sanchpet/sweb` provider (github.com/sanchpet/terraform-provider-sweb) **>= 0.2**,
published to the Terraform Registry. That version renames a node **in place** (an `alias`
change is an update, not a replacement), so the node's current SpaceWeb name (`infra-hub`)
does not need to match the scheme before import — `terragrunt apply` renames it to `infra-01`.

## Prerequisites

**SpaceWeb auth** is injected automatically by the scoped `../mise.toml`: run `sweb
configure` once on the machine, and entering this dir mints a fresh `SWEB_TOKEN` (via
`sweb token`) — no login/password in the environment. (Manual fallback:
`export SWEB_LOGIN=... SWEB_PASSWORD=...`, or `export SWEB_TOKEN=...`.)

**Yandex S3 state backend** (see `../../root.hcl`) still comes from the environment:

```sh
export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...  TF_STATE_BUCKET=sanchpet-homelab-tfstate
```

## Import

```sh
cd terraform/live/sweb/infra
terragrunt init
terragrunt import 'sweb_vps.this["infra-01"]' petrovpet2_vps_10
```

Import reads the node's current API name (`infra-hub`) into state.

## Reconcile to a clean plan

Import reconstructs the node in **plan-mode** from the API. Read the real ids it wrote and
correct `terragrunt.hcl` so the desired state matches:

```sh
terragrunt state show 'sweb_vps.this["infra-01"]'   # note os_distr_id, datacenter_id, plan_id
# -> edit terragrunt.hcl: set distributive / datacenter (and confirm plan = 379)
terragrunt plan     # expect ONE in-place update: alias "infra-hub" -> "infra-01"
terragrunt apply    # renames the node in place (no replacement)
terragrunt plan     # now must report: No changes
```

The rename is the only expected change (the module's for_each key is `infra-01`, the node is
still named `infra-hub`). `ssh_key` is create-only and not recoverable from the API; if the
node was created with one, re-declare it in HCL (it won't force replacement on an
already-imported resource unless changed). A clean `terragrunt plan` after the rename apply is
the proof that the node is now managed as code.

## Grow the cluster

Bump `node_count` in `terragrunt.hcl` (e.g. to `3`) and `terragrunt apply` — the new indices
(`infra-02`, `infra-03`) are created; the imported node is untouched.
