# live/sweb/infra — the RU infra node group on SpaceWeb (sweb.ru).
#
# Group of identical nodes named infra-01, infra-02, … (slug "infra"). Today only the first
# node exists — created imperatively via the sweb CLI (WP-009) as "infra-hub" — so it is
# brought under IaC by IMPORT, not recreate (a fresh apply would bill a new node and the old
# one is 24h-delete-locked). Grow the cluster by bumping node_count and `terragrunt apply`.
# Trace: WP-058 (provider) feeds WP-057 (hub-spoke topology), node petrovpet2_vps_10.
#
# Credentials come from the ENVIRONMENT (kept out of HCL/state):
#   export SWEB_LOGIN=... SWEB_PASSWORD=...      # or: export SWEB_TOKEN=...
# Plus the Yandex S3 state creds from live/root.hcl (AWS_ACCESS_KEY_ID / _SECRET / bucket).
#
# sanchpet/sweb is on the Terraform Registry — `terragrunt init` resolves it directly.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sweb-vps"
}

inputs = {
  slug        = "infra"
  node_count  = 1 # only the first node exists today; bump to grow the cluster
  index_width = 2 # infra-01, infra-02, …

  # Plan-mode (matches what `terraform import` reconstructs). 379 = Облако-2/6/15 — the
  # configurator 2cpu/6GB/15GB (nvme) this node was created with, resolved to a plan id.
  plan = 379

  # ⚠️ CONFIRM AFTER IMPORT: these are best-guesses so `import` passes schema validation.
  # Import reads the real values from the API; after it, run
  #   terragrunt state show 'sweb_vps.this["infra-01"]'
  # and correct these two lines (os_distr_id / datacenter_id) so `terragrunt plan` is clean.
  distributive = 164 # os_distr_id   — guess: debian-13
  datacenter   = 1   # datacenter_id — guess: 1=spb (2=msk, 3=ams)
}
