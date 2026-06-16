# Example: a bootstrap unit that creates a dedicated Yandex Cloud folder.
# Bootstrap unit → no `include "root"` (LOCAL state until the S3 state bucket exists).
# Auth: export YC_TOKEN=$(yc iam create-token); export YC_CLOUD_ID=<cloud id>

terraform {
  source = "../../../modules/yc-folder"
}

inputs = {
  cloud_id    = get_env("YC_CLOUD_ID")
  name        = "homelab"
  description = "Homelab infrastructure"
  labels = {
    project    = "homelab"
    managed_by = "opentofu"
  }
}
