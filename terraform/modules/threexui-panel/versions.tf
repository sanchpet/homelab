# Provider + engine pinning for the threexui-panel module.
#
# `use_lockfile` (S3-native state locking, set in live/root.hcl) needs OpenTofu >= 1.10;
# we pin the toolchain at 1.12.x in the repo-root mise.toml, so require >= 1.10 here.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    threexui = {
      # Fully qualified ON PURPOSE: batonogov/threexui is published to the Terraform
      # registry but NOT the OpenTofu one (registry.opentofu.org 404s). OpenTofu honors
      # an explicit hostname, so this pulls it from registry.terraform.io. Do not shorten
      # to "batonogov/threexui" — `tofu init` would then fail to find the provider.
      source  = "registry.terraform.io/batonogov/threexui"
      version = "~> 3.0"
    }
  }
}
