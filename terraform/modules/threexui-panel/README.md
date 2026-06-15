# Module: threexui-panel

Declares VLESS-Reality **inbounds** and **clients** on a single [3x-ui](https://github.com/MHSanaei/3x-ui)
panel, via the community provider
[`batonogov/threexui`](https://github.com/batonogov/terraform-provider-threexui)
(community-first: we consume the maintained provider, we don't hand-roll the API client).

This closes the caveat in `kubernetes/apps/base/3x-ui/README.md` — inbounds/clients/Reality
keys lived only in the panel's SQLite DB, not in Git. With this module the panel config is
code: reviewed in PRs, versioned, and re-appliable.

## Scope

One module instance == **one panel** (the provider is configured inside the module;
Terraform cannot `for_each` a provider). Each panel is a terragrunt unit under
`terraform/live/<panel>/`. The interface is VLESS-Reality-focused (the homelab's actual
workload); extend `variables.tf` + `main.tf` for more protocols when needed.

## Inputs

| Variable | Description |
|----------|-------------|
| `endpoint` | Panel base URL (e.g. `http://localhost:2053` over a tunnel — the panel is ClusterIP-only). |
| `base_path` | Panel `webBasePath` (obscured path; secret-in-disguise → from SOPS). |
| `username` / `password` | Panel admin credentials (from SOPS). |
| `insecure_skip_verify` | Skip TLS verify (self-signed panel cert). Default `false`. |
| `inbounds` | `map(object)` of VLESS-Reality inbounds (port, remark, reality target/SNI; Reality key + short_ids auto-generate when null). |
| `clients` | `map(object)` of clients, each referencing an inbound by key. UUID + sub_id auto-generate when null. |

## Outputs

`inbound_ids`, `inbound_tags`, and (sensitive) `client_uuids`, `client_sub_ids`.

## Secrets warning

The Reality private key, client UUIDs, and the panel password land in the **state**. The
state lives in Yandex S3 (see `terraform/live/root.hcl`) with access restricted to the
owner; the panel password is sourced from SOPS, never hard-coded. Do not commit state or
`*.tfvars`.
