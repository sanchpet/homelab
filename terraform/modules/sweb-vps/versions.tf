# Provider + engine pinning for the sweb-vps module.
#
# `use_lockfile` (S3-native state locking, set in live/root.hcl) needs Terraform >= 1.11;
# the repo-root mise.toml pins the toolchain at 1.15.x, so require >= 1.11 here.
#
# sanchpet/sweb is our own provider (github.com/sanchpet/terraform-provider-sweb), published
# to the Terraform Registry — `terragrunt init` resolves it directly, no dev_override needed.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    sweb = {
      source  = "sanchpet/sweb"
      version = "~> 0.3.0" # >= 0.3.0: tolerates the API's number-or-string fields (plan_price float) + in-place resize; < 0.4.0
    }
  }
}
