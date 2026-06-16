# Module: yc-folder

Creates a single Yandex Cloud folder.

**Own thin module** — community-first ladder (`terraform/CLAUDE.md`), tier 3: there is no
folder module in `terraform-yacloud-modules` (the `terraform-yandex-iam` module manages
service accounts/roles, not folder lifecycle), and a folder is one
`yandex_resourcemanager_folder` resource.

Auth via env: `export YC_TOKEN=$(yc iam create-token)` + the `cloud_id` input. Usage:
see [`terragrunt.example.hcl`](terragrunt.example.hcl).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | ~> 0.206 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | ~> 0.206 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [yandex_resourcemanager_folder.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_folder) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloud_id"></a> [cloud\_id](#input\_cloud\_id) | Yandex Cloud ID the folder belongs to. | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Folder description. | `string` | `""` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels (key-value). | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Folder name. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_folder_id"></a> [folder\_id](#output\_folder\_id) | Created folder ID. |
| <a name="output_folder_name"></a> [folder\_name](#output\_folder\_name) | Created folder name. |
<!-- END_TF_DOCS -->
