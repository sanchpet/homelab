# live/sweb/infra-hub — the RU infra-hub node on SpaceWeb (sweb.ru).
#
# Created imperatively via the sweb CLI (WP-009); brought under IaC here by IMPORT rather
# than recreate (a fresh apply would bill a new node and the old one is 24h-delete-locked).
# Trace: WP-058 (provider) feeds WP-057 (hub-spoke topology), node petrovpet2_vps_10.
#
# Credentials come from the ENVIRONMENT (kept out of HCL/state):
#   export SWEB_LOGIN=... SWEB_PASSWORD=...      # or: export SWEB_TOKEN=...
# Plus the Yandex S3 state creds from live/root.hcl (AWS_ACCESS_KEY_ID / _SECRET / bucket).
#
# Until sanchpet/sweb is on the Terraform Registry, point Terraform at a local provider
# build with a dev_override — see README.md (the import runbook).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sweb-vps"
}

inputs = {
  alias = "infra-hub"

  # Plan-mode (matches what `terraform import` reconstructs). 379 = Облако-2/6/15 — the
  # configurator 2cpu/6GB/15GB (nvme) this node was created with, resolved to a plan id.
  plan = 379

  # ⚠️ CONFIRM AFTER IMPORT: these are best-guesses so `import` passes schema validation.
  # Import reads the real values from the API; after it, run
  #   `terragrunt state show sweb_vps.this`
  # and correct these two lines (os_distr_id / datacenter_id) so `terragrunt plan` is clean.
  distributive = 164 # os_distr_id   — guess: debian-13
  datacenter   = 1   # datacenter_id — guess: 1=spb (2=msk, 3=ams)
}
