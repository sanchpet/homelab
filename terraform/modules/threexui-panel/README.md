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
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_threexui"></a> [threexui](#requirement\_threexui) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_threexui"></a> [threexui](#provider\_threexui) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [random_string.sub_path](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [threexui_inbound.this](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/inbound) | resource |
| [threexui_inbound_client.this](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/inbound_client) | resource |
| [threexui_panel_subscription.settings](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/panel_subscription) | resource |
| [threexui_panel_user.admin](https://registry.terraform.io/providers/batonogov/threexui/latest/docs/resources/panel_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_base_path"></a> [base\_path](#input\_base\_path) | Panel webBasePath (the obscured panel path). Secret-in-disguise — sourced from SOPS, not hard-coded. | `string` | `"/"` | no |
| <a name="input_bootstrap_password"></a> [bootstrap\_password](#input\_bootstrap\_password) | Initial/old panel password for first-run rotation (e.g. "admin"). Set together with bootstrap\_username. | `string` | `null` | no |
| <a name="input_bootstrap_username"></a> [bootstrap\_username](#input\_bootstrap\_username) | Initial/old panel username for first-run rotation (e.g. "admin"). Set together with bootstrap\_password. On 3x-ui v3 it is tried only if the steady-state username/password is rejected — so it can stay set harmlessly after rotation. | `string` | `null` | no |
| <a name="input_clients"></a> [clients](#input\_clients) | Clients to declare, keyed by a stable local name. | <pre>map(object({<br/>    inbound_key = string # key into var.inbounds<br/>    email       = string # unique per panel<br/>    flow        = optional(string, "xtls-rprx-vision")<br/>    enable      = optional(bool, true)<br/>    total_gb    = optional(number, 0) # 0 = unlimited<br/>    expiry_time = optional(number, 0) # unix ms, 0 = no expiry<br/>    limit_ip    = optional(number, 0) # 0 = no limit<br/>    comment     = optional(string)<br/>    tg_id       = optional(number)<br/>    sub_id      = optional(string) # null => auto-generate<br/>  }))</pre> | `{}` | no |
| <a name="input_endpoint"></a> [endpoint](#input\_endpoint) | Base URL of the 3x-ui panel, e.g. http://localhost:2053. The panel is ClusterIP-only, so this is reached through an SSH tunnel (VPN off) or kubectl port-forward (VPN on). | `string` | n/a | yes |
| <a name="input_inbounds"></a> [inbounds](#input\_inbounds) | VLESS-Reality inbounds to declare, keyed by a stable local name. | <pre>map(object({<br/>    port                 = number<br/>    remark               = string<br/>    enable               = optional(bool, true)<br/>    reality_target       = string                 # SNI dest, e.g. \"www.amazon.com:443\"<br/>    reality_server_names = list(string)           # e.g. [\"www.amazon.com\"]<br/>    reality_private_key  = optional(string)       # null => panel auto-generates<br/>    reality_short_ids    = optional(list(string)) # null => panel auto-generates<br/>  }))</pre> | `{}` | no |
| <a name="input_insecure_skip_verify"></a> [insecure\_skip\_verify](#input\_insecure\_skip\_verify) | Skip TLS verification (true when the panel uses a self-signed cert; over a localhost tunnel the endpoint is plain HTTP, so usually false). | `bool` | `false` | no |
| <a name="input_manage_panel_user"></a> [manage\_panel\_user](#input\_manage\_panel\_user) | Manage the panel admin user via threexui\_panel\_user — rotate it to username/password. The new password is applied write-only (not persisted in state). | `bool` | `true` | no |
| <a name="input_panel_password_version"></a> [panel\_password\_version](#input\_panel\_password\_version) | Bump this to force re-sending the panel password (write-only passwords need a version to re-apply). Increment when you change the password. | `number` | `1` | no |
| <a name="input_password"></a> [password](#input\_password) | Panel admin password (steady-state / desired). When manage\_panel\_user is true, the panel is rotated to this; it's applied write-only, so it is NOT stored in state. | `string` | n/a | yes |
| <a name="input_subscription"></a> [subscription](#input\_subscription) | Subscription server settings (null = untouched). | <pre>object({<br/>    public_url  = string # e.g. https://sub.vps.ger.ips.sanch.pet:8443<br/>    enabled     = optional(bool, true)<br/>    port        = optional(number, 2096)<br/>    json_enable = optional(bool, true)<br/>    path_length = optional(number, 16) # random URI path length<br/>    title       = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_username"></a> [username](#input\_username) | Panel admin username (steady-state / desired). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_sub_ids"></a> [client\_sub\_ids](#output\_client\_sub\_ids) | Map of client local-name => subscription ID (build sub URLs from these). |
| <a name="output_client_subscription_urls"></a> [client\_subscription\_urls](#output\_client\_subscription\_urls) | Full subscription URL per client (random path + sub\_id) → sensitive. |
| <a name="output_client_uuids"></a> [client\_uuids](#output\_client\_uuids) | Map of client local-name => UUID (client\_id). |
| <a name="output_inbound_ids"></a> [inbound\_ids](#output\_inbound\_ids) | Map of inbound local-name => numeric panel ID. |
| <a name="output_inbound_tags"></a> [inbound\_tags](#output\_inbound\_tags) | Map of inbound local-name => auto-generated xray tag. |
| <a name="output_subscription_base_url"></a> [subscription\_base\_url](#output\_subscription\_base\_url) | Public subscription base URL (append a client sub\_id). Contains the random path → sensitive. null when subscription is unset. |
<!-- END_TF_DOCS -->
