# Dedicated "homelab" folder in Yandex Cloud.
#
# Bootstrap unit: created before the S3 state bucket exists, so it runs on LOCAL state
# (transient, in .terragrunt-cache/). Once yc-s3-tf-state has created the bucket, migrate
# this unit onto S3 — add `include "root"` + `terragrunt init -migrate-state` (see
# docs/2_yandex_cloud_bootstrap.md). Until you migrate, don't clear .terragrunt-cache or the
# local state is lost (then re-import). Auth via env:
#   export YC_TOKEN=$(yc iam create-token)
#   export YC_CLOUD_ID=<cloud id>   # or rely on the default below

terraform {
  source = "../../../modules/yc-folder"
}

inputs = {
  cloud_id    = get_env("YC_CLOUD_ID", "b1gr5nrg10c4rnr8gehu")
  name        = "homelab"
  description = "Homelab infrastructure — k3s VPN stand + Terraform state"
  labels = {
    project    = "homelab"
    managed_by = "terraform"
  }
}
