# terraform/ — instructions for Claude Code

> Nested under the repo-root `CLAUDE.md` (which still applies: English-only artifacts, PR
> workflow, no self-merge). This file adds the Terraform conventions. Loaded automatically
> when working under `terraform/`.

Engine: **Terraform**, orchestrated by **Terragrunt**. Toolchain pinned in the repo-root
`mise.toml`. Layout: `modules/` (own reusable modules) + `live/` (terragrunt units,
grouped by domain: `live/yandex-cloud/…`, `live/threexui/…`).

## Community-first for modules (BLOCKING) — the ladder

Before writing a module, walk this ladder top-down and stop at the first that fits:

1. **A community module fully covers the need → use it.** Reference it by pinned
   `source` + `version` (exact tag for git sources). Do **not** write your own.
   Example: the state bucket uses `terraform-yacloud-modules/terraform-yandex-storage-bucket`
   (`?ref=v2.0.0`).
2. **A community module covers it partially → write a thin wrapper around it**, not a
   rewrite. The wrapper adds only the missing inputs/resources on top; the community
   module stays the base (pinned).
3. **Nothing adequate exists, or the requirements are too specific, or it's a trivial
   single resource → write your own thin module.** Justify it in the module (a comment +
   the README) by naming what you checked.
   Example: `yc-folder` is own — there is **no** community folder module in
   `terraform-yacloud-modules` (the `terraform-yandex-iam` module manages service
   accounts/roles, not folder lifecycle), and a folder is a single
   `yandex_resourcemanager_folder` resource.

Always check before hand-rolling, and confirm the community module is **maintained**
(recent commits/releases), not abandoned.

## Module conventions (BLOCKING)

Every module under `modules/<name>/` has:

- `versions.tf` — `required_version` + pinned `required_providers`.
- `variables.tf`, `main.tf`, `outputs.tf`.
- `README.md` — a short human intro **plus** an auto-generated docs block between
  `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers (Inputs/Outputs/Providers).
  **Do not hand-write the Inputs/Outputs tables** — they're generated.
- `terragrunt.example.hcl` — a copy-pasteable usage example (how a `live/` unit calls it).

The READMEs, formatting, lint and security scan are enforced by
[antonbabenko/pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
hooks (`.pre-commit-config.yaml`): `terragrunt_fmt`, `terraform_fmt`, `terraform_docs`
(rewrites the README between the markers — re-stage if it changes), `terraform_tflint`,
`terraform_trivy`. To run them by hand: `pre-commit run terraform_docs --all-files`.

> The hooks run from the repo root and shell out to `terraform`/`terraform-docs`/`tflint`/
> `trivy`, so those are pinned in the **repo-root `mise.toml`** (not a `terraform/`-scoped
> one) — they must be on PATH where pre-commit runs.

## Why Terraform, not OpenTofu

Providers resolve from `registry.terraform.io` (bare `source = "<ns>/<name>"`). This is
the deciding reason we run Terraform here, not OpenTofu: the Yandex ecosystem targets the
Terraform registry, and OpenTofu's mirror lags badly (`yandex-cloud/yandex` was 0.127 on
`registry.opentofu.org` vs 0.206 on `registry.terraform.io` — old enough to miss resources
the community `terraform-yandex-storage-bucket` module needs). `batonogov/threexui` isn't
on the OpenTofu registry at all. On Terraform both just work without qualifying the source.

## State + bootstrap

Remote state is Yandex Object Storage (S3), config in `live/root.hcl`. Units that create
the state backend itself (`live/yandex-cloud/yc-folder`, `yc-s3-tf-state`) are **bootstrap
units**: standalone (no `include "root"`) → LOCAL state on first apply, then migrated into
S3 (`terragrunt init -migrate-state`). Every other unit `include`s root → S3 from the
start. Full runbook in `terraform/README.md`.
