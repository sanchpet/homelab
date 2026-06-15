# Terragrunt root — shared remote state for every live/<panel>/ unit.
#
# Included by each child via:  include "root" { path = find_in_parent_folders("root.hcl") }
#
# State backend: Yandex Object Storage (S3-compatible). One state object per unit
# (key derived from the path). Locking is S3-native (`use_lockfile`, OpenTofu >= 1.10) —
# a lock object next to the state, no DynamoDB table needed.
#
# Credentials: a Yandex static access key, supplied via the environment, never in Git:
#   export AWS_ACCESS_KEY_ID=...        # static key id
#   export AWS_SECRET_ACCESS_KEY=...    # static key secret
#
# Bootstrap note (chicken-and-egg): this bucket holds the state, so it cannot be created
# by this state. Create it once out-of-band (yc / AWS CLI against the Yandex endpoint)
# before the first `terragrunt apply`. See terraform/README.md.

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "homelab-tofu-state"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "ru-central1"

    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }

    # S3-native state locking (OpenTofu >= 1.10): a *.tflock object beside the state.
    use_lockfile = true

    # Yandex Object Storage is S3-compatible but not AWS — skip the AWS-only preflight.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
