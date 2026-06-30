# sweb-vps

Manages a group of **identical** SpaceWeb (sweb.ru) VPS nodes via the `sanchpet/sweb`
provider. Nodes share one `slug` and are named `<slug>-<index>` (e.g. `infra-01`,
`infra-02`, …), keyed by name with `for_each` so adding or removing a node never
reindexes — and so never destroys — its siblings.

One module instance == one SpaceWeb account: the provider is configured inside the module
from the connection inputs, which default to `null` so the provider falls back to the
environment (`SWEB_LOGIN`/`SWEB_PASSWORD` or `SWEB_TOKEN`) — keep credentials out of HCL and
state. All nodes are provisioned identically: set **either** `plan` **or** the configurator
(`cpu`/`ram`/`disk`/`category`) — the provider enforces exactly-one-of and recreates a node
on any change to a create-only input.

Grow the cluster by bumping `node_count` and `terragrunt apply` (new indices are created;
existing nodes are untouched). To bring an already-existing node under management, **import**
it at its keyed address — e.g. `terragrunt import 'sweb_vps.this["infra-01"]' <billing_id>`;
its SpaceWeb name must already equal the templated name (rename in the panel first, since the
provider cannot rename — an `alias` change forces replacement).

Usage example: [`terragrunt.example.hcl`](./terragrunt.example.hcl).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_sweb"></a> [sweb](#requirement\_sweb) | ~> 0.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_sweb"></a> [sweb](#provider\_sweb) | ~> 0.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [sweb_vps.this](https://registry.terraform.io/providers/sanchpet/sweb/latest/docs/resources/vps) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_category"></a> [category](#input\_category) | Configurator: catalog category id (1=nvme, 2=hdd, 3=turbo). Defaults to 1 in the provider. | `number` | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Configurator: CPU cores. Mutually exclusive with plan. | `number` | `null` | no |
| <a name="input_create_timeout"></a> [create\_timeout](#input\_create\_timeout) | Max time to wait for the VPS to become ready. | `string` | `"15m"` | no |
| <a name="input_datacenter"></a> [datacenter](#input\_datacenter) | Datacenter id (1=spb, 2=msk, 3=ams). | `number` | n/a | yes |
| <a name="input_disk"></a> [disk](#input\_disk) | Configurator: disk in GB. | `number` | `null` | no |
| <a name="input_distributive"></a> [distributive](#input\_distributive) | OS distributive id (e.g. 164=debian-13, 122=ubuntu-24.04). | `number` | n/a | yes |
| <a name="input_endpoint"></a> [endpoint](#input\_endpoint) | API root override. Null → provider uses $SWEB\_ENDPOINT, then the production API. | `string` | `null` | no |
| <a name="input_index_start"></a> [index\_start](#input\_index\_start) | First index value (1 -> infra-01, infra-02, ...). | `number` | `1` | no |
| <a name="input_index_width"></a> [index\_width](#input\_index\_width) | Zero-pad width of the node index (2 -> infra-01; 1 -> infra-1). | `number` | `2` | no |
| <a name="input_ip_count"></a> [ip\_count](#input\_ip\_count) | Number of IPs to order. Create-only. | `number` | `null` | no |
| <a name="input_login"></a> [login](#input\_login) | Login for transparent token refresh. Null → provider uses $SWEB\_LOGIN. | `string` | `null` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of identical nodes to manage in the group. | `number` | `1` | no |
| <a name="input_password"></a> [password](#input\_password) | Password for transparent token refresh. Null → provider uses $SWEB\_PASSWORD. | `string` | `null` | no |
| <a name="input_plan"></a> [plan](#input\_plan) | Ready-made plan id. Mutually exclusive with the configurator. | `number` | `null` | no |
| <a name="input_ram"></a> [ram](#input\_ram) | Configurator: RAM in GB. | `number` | `null` | no |
| <a name="input_slug"></a> [slug](#input\_slug) | Group slug shared by every node; node names are <slug>-<index> (e.g. "infra" -> infra-01). | `string` | n/a | yes |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | SSH public key id to inject at create. Create-only; not recoverable on import. | `string` | `null` | no |
| <a name="input_token"></a> [token](#input\_token) | API token. Null → provider uses $SWEB\_TOKEN. One-off (no refresh). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_billing_ids"></a> [billing\_ids](#output\_billing\_ids) | Map node name -> SpaceWeb service id (login\_vps\_N), the resource id and delete/import key. |
| <a name="output_ips"></a> [ips](#output\_ips) | Map node name -> primary IP address. |
| <a name="output_names"></a> [names](#output\_names) | Map node name -> effective name reported by the API. |
| <a name="output_running"></a> [running](#output\_running) | Map node name -> whether the VPS is running. |
| <a name="output_uids"></a> [uids](#output\_uids) | Map node name -> stable unique id of the VPS. |
<!-- END_TF_DOCS -->
