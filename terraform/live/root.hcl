# Terragrunt root — shared remote state for every live/<unit>/ unit.
#
# Included by each child via:  include "root" { path = find_in_parent_folders("root.hcl") }
#
# State backend: Yandex Object Storage (S3-compatible). One state object per unit (key
# derived from the path). Locking is S3-native (`use_lockfile`, Terraform >= 1.11) — a lock
# object beside the state, no DynamoDB. (Yandex backend flags follow itruslan/homelab-infra,
# which runs this in production.)
#
# Credentials: a Yandex static access key (storage-admin SA), supplied via the environment:
#   export AWS_ACCESS_KEY_ID=...        # static key id
#   export AWS_SECRET_ACCESS_KEY=...    # static key secret
#   export TF_STATE_BUCKET=...          # state bucket name
#
# Bootstrap (chicken-and-egg): the bucket holds the state, so it can't be created by this
# state. The live/yandex-cloud/{yc-folder,yc-s3-tf-state} units create it on LOCAL state
# first, then migrate into S3 (`terragrunt init -migrate-state`). See terraform/README.md.

# Fleet-wide values shared by units. Read them with `include.root.locals.<name>` after
# `include "root" { ... expose = true }`.
locals {
  cloud_id = get_env("YC_CLOUD_ID", "b1gr5nrg10c4rnr8gehu")
  labels = {
    project    = "homelab"
    managed_by = "terraform"
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = get_env("TF_STATE_BUCKET", "sanchpet-homelab-tfstate")
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1" # canonical placeholder; Yandex ignores region (validation skipped)

    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }

    # S3-native state locking (Terraform >= 1.11): a *.tflock object beside the state.
    use_lockfile = true

    # Yandex Object Storage is S3-compatible but not AWS — skip the AWS-only preflight,
    # disable the new SDK checksum (Yandex rejects it), and don't try to manage the bucket.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    disable_bucket_update       = true
  }
}
