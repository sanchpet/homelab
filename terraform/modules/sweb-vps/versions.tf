# Provider + engine pinning for the sweb-vps module.
#
# `use_lockfile` (S3-native state locking, set in live/root.hcl) needs Terraform >= 1.11;
# the repo-root mise.toml pins the toolchain at 1.15.x, so require >= 1.11 here.
#
# sanchpet/sweb is our own provider (github.com/sanchpet/terraform-provider-sweb). Until it
# is published to the Terraform Registry, init it via a CLI dev_override pointing at a local
# build — see live/sweb/infra-hub/README.md.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    sweb = {
      source  = "sanchpet/sweb"
      version = "~> 0.1"
    }
  }
}
