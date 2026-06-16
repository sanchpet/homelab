# Dedicated "homelab" folder in Yandex Cloud.
#
# State: S3 via `include "root"`, like every other unit. Chicken-and-egg caveat — when
# bootstrapping FROM ZERO (the bucket doesn't exist yet), comment out the `include` below for
# the very first `terragrunt apply` so it runs on local state; then restore it and
# `terragrunt init -migrate-state`. See docs/2_yandex_cloud_bootstrap.md. Auth via env:
#   export YC_TOKEN=$(yc iam create-token)
#   export YC_CLOUD_ID=<cloud id>   # or rely on the default below

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../modules/yc-folder"
}

inputs = {
  cloud_id    = include.root.locals.cloud_id
  name        = "homelab"
  description = "Homelab infrastructure — k3s VPN stand + Terraform state"
  labels      = include.root.locals.labels
}
