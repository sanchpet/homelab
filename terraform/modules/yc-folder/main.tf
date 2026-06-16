# Creates a Yandex Cloud folder. Auth via env: YC_TOKEN (IAM token, `yc iam create-token`)
# + the cloud_id input. The folder is created at cloud level.

provider "yandex" {
  cloud_id = var.cloud_id
}

resource "yandex_resourcemanager_folder" "this" {
  cloud_id    = var.cloud_id
  name        = var.name
  description = var.description
  labels      = var.labels
}
