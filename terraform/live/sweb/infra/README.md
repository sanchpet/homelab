# infra — the RU infra node group, imported into IaC

The `infra` group on SpaceWeb is named `infra-01`, `infra-02`, … (slug `infra`, managed by
the `sweb-vps` module). Today only the first node exists: `petrovpet2_vps_10`
(`168.222.202.148`), created imperatively via the sweb CLI (WP-009). We bring it under
Terragrunt by **import**, not recreate — a fresh apply would bill a second node, and the
original is delete-locked for 24h.

Uses the `sanchpet/sweb` provider (github.com/sanchpet/terraform-provider-sweb), published
to the Terraform Registry.

## Step 0 — rename the existing node to match the scheme (BLOCKING)

The provider cannot rename a node (no SDK `Rename`; an `alias` change forces replacement),
and `import` reads the node's real name from the API. So the node's SpaceWeb name must
**already** equal the templated name before import, or `terragrunt plan` will want to replace
it.

In the **SpaceWeb panel**, rename the node `infra-hub` → **`infra-01`**. (This is a label
change; it does not touch the VM.) If the panel does not support renaming a VPS, switch the
scheme to keep the existing name (see WP-058 — option "keep infra-hub").

## Prerequisites

```sh
# SpaceWeb auth (kept out of HCL/state):
export SWEB_LOGIN=...  SWEB_PASSWORD=...        # or: export SWEB_TOKEN=...
# Yandex S3 state backend (see ../../root.hcl):
export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...  TF_STATE_BUCKET=sanchpet-homelab-tfstate
```

## Import

```sh
cd terraform/live/sweb/infra
terragrunt init
terragrunt import 'sweb_vps.this["infra-01"]' petrovpet2_vps_10
```

## Reconcile to a clean plan

Import reconstructs the node in **plan-mode** from the API. Read the real ids it wrote and
correct `terragrunt.hcl` so the desired state matches:

```sh
terragrunt state show 'sweb_vps.this["infra-01"]'   # note os_distr_id, datacenter_id, plan_id
# -> edit terragrunt.hcl: set distributive / datacenter (and confirm plan = 379)
terragrunt plan                                      # must report: No changes
```

`ssh_key` is create-only and not recoverable from the API; if the node was created with one,
re-declare it in HCL (it won't force replacement on an already-imported resource unless
changed). A clean `terragrunt plan` is the proof that the node is now managed as code.

## Grow the cluster

Bump `node_count` in `terragrunt.hcl` (e.g. to `3`) and `terragrunt apply` — the new indices
(`infra-02`, `infra-03`) are created; the imported node is untouched.
