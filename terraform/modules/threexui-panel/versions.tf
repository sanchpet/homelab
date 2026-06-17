# Provider + engine pinning for the threexui-panel module.
#
# `use_lockfile` (S3-native state locking, set in live/root.hcl) needs Terraform >= 1.11;
# we pin the toolchain at 1.15.x in the repo-root mise.toml, so require >= 1.11 here.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    threexui = {
      source  = "batonogov/threexui"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
