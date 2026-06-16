# Own thin module — community-first ladder (terraform/CLAUDE.md), tier 3: checked
# terraform-yacloud-modules (42 modules) → no folder module exists (terraform-yandex-iam
# manages service accounts/roles, not folder lifecycle), and a folder is a single
# yandex_resourcemanager_folder resource. yandex provider pinned to the current
# OpenTofu-registry version.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.127.0"
    }
  }
}
