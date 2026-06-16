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
`terraform/live/threexui/<panel>/`. The interface is VLESS-Reality-focused (the homelab's
actual workload); extend `variables.tf` + `main.tf` for more protocols when needed. Usage:
see [`terragrunt.example.hcl`](terragrunt.example.hcl).

## Secrets warning

The Reality private key, client UUIDs, and the panel password land in the **state**. The
state lives in Yandex S3 (see `terraform/live/root.hcl`) with access restricted to the
owner; the panel password is sourced from SOPS, never hard-coded. Do not commit state or
`*.tfvars`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_threexui"></a> [threexui](#requirement\_threexui) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_threexui"></a> [threexui](#provider\_threexui) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [threexui_inbound.this](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/inbound) | resource |
| [threexui_inbound_client.this](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/inbound_client) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_base_path"></a> [base\_path](#input\_base\_path) | Panel webBasePath (the obscured panel path). Secret-in-disguise — sourced from SOPS, not hard-coded. | `string` | `"/"` | no |
| <a name="input_clients"></a> [clients](#input\_clients) | Clients to declare, keyed by a stable local name. | <pre>map(object({<br/>    inbound_key = string # key into var.inbounds<br/>    email       = string # unique per panel<br/>    flow        = optional(string, "xtls-rprx-vision")<br/>    enable      = optional(bool, true)<br/>    total_gb    = optional(number, 0) # 0 = unlimited<br/>    expiry_time = optional(number, 0) # unix ms, 0 = no expiry<br/>    limit_ip    = optional(number, 0) # 0 = no limit<br/>    comment     = optional(string)<br/>    tg_id       = optional(number)<br/>    sub_id      = optional(string) # null => auto-generate<br/>  }))</pre> | `{}` | no |
| <a name="input_endpoint"></a> [endpoint](#input\_endpoint) | Base URL of the 3x-ui panel, e.g. http://localhost:2053. The panel is ClusterIP-only, so this is reached through an SSH tunnel (VPN off) or kubectl port-forward (VPN on). | `string` | n/a | yes |
| <a name="input_inbounds"></a> [inbounds](#input\_inbounds) | VLESS-Reality inbounds to declare, keyed by a stable local name. | <pre>map(object({<br/>    port                 = number<br/>    remark               = string<br/>    enable               = optional(bool, true)<br/>    reality_target       = string                 # SNI dest, e.g. \"www.amazon.com:443\"<br/>    reality_server_names = list(string)           # e.g. [\"www.amazon.com\"]<br/>    reality_private_key  = optional(string)       # null => panel auto-generates<br/>    reality_short_ids    = optional(list(string)) # null => panel auto-generates<br/>  }))</pre> | `{}` | no |
| <a name="input_insecure_skip_verify"></a> [insecure\_skip\_verify](#input\_insecure\_skip\_verify) | Skip TLS verification (true when the panel uses a self-signed cert; over a localhost tunnel the endpoint is plain HTTP, so usually false). | `bool` | `false` | no |
| <a name="input_password"></a> [password](#input\_password) | Panel admin password. | `string` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Panel admin username. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_sub_ids"></a> [client\_sub\_ids](#output\_client\_sub\_ids) | Map of client local-name => subscription ID (build sub URLs from these). |
| <a name="output_client_uuids"></a> [client\_uuids](#output\_client\_uuids) | Map of client local-name => UUID (client\_id). |
| <a name="output_inbound_ids"></a> [inbound\_ids](#output\_inbound\_ids) | Map of inbound local-name => numeric panel ID. |
| <a name="output_inbound_tags"></a> [inbound\_tags](#output\_inbound\_tags) | Map of inbound local-name => auto-generated xray tag. |
<!-- END_TF_DOCS -->
