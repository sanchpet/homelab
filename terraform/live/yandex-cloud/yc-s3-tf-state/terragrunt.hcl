# The S3 bucket that holds Terraform state for the whole homelab + its storage-admin
# service account (static access key). Community module, pinned to the latest tag.
#
# State: S3 via `include "root"`, like every other unit. Chicken-and-egg caveat — this unit
# CREATES that bucket, so when bootstrapping FROM ZERO comment out the `include` below for the
# first `terragrunt apply` (local state); then restore it and `terragrunt init -migrate-state`
# (see docs/2_yandex_cloud_bootstrap.md). Until you migrate, don't clear .terragrunt-cache.
# Auth via env:
#   export YC_TOKEN=$(yc iam create-token)   # IAM token creates the bucket (not S3 keys)
#   export TF_STATE_BUCKET=sanchpet-homelab-tfstate

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "git::https://github.com/terraform-yacloud-modules/terraform-yandex-storage-bucket.git?ref=v2.0.0"
}

# The module configures the yandex provider implicitly from env (YC_TOKEN/YC_CLOUD_ID) and
# needs an aws provider only for an aws_iam_policy_document *data source* (no AWS calls) —
# a mock is enough.
generate "providers" {
  path      = "providers_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "yandex" {
  cloud_id = "${include.root.locals.cloud_id}"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
EOF
}

dependency "yc_folder" {
  config_path = "../yc-folder"

  mock_outputs = {
    folder_id = "mock-folder-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  bucket_name = get_env("TF_STATE_BUCKET", "sanchpet-homelab-tfstate")
}

inputs = {
  folder_id   = dependency.yc_folder.outputs.folder_id
  bucket_name = local.bucket_name

  # Versioned state: recover from a bad apply by rolling back an object version.
  versioning = {
    enabled = true
  }

  # Generate a dedicated storage-admin SA + static access key for state access.
  storage_admin_service_account = {
    name = "sa-${local.bucket_name}"
  }

  labels = include.root.locals.labels
}
