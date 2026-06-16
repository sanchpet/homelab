# Dedicated "homelab" folder in Yandex Cloud.
#
# Bootstrap unit: standalone (no `include "root"`) → LOCAL state, because the S3 state
# bucket doesn't exist yet (chicken-and-egg). After yc-s3-tf-state creates the bucket, this
# unit's state is migrated into S3 (see terraform/README.md § bootstrap). Auth via env:
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
    managed_by = "opentofu"
  }
}
