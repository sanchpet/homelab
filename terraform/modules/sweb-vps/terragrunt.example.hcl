# Example: how a live/ unit calls the sweb-vps module to manage a node group.
#
# Credentials come from the environment (kept out of HCL/state):
#   export SWEB_LOGIN=... SWEB_PASSWORD=...      # or: export SWEB_TOKEN=...
# plus the Yandex S3 state creds from live/root.hcl (AWS_ACCESS_KEY_ID / _SECRET / bucket).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sweb-vps"
}

inputs = {
  # Group of identical nodes: infra-01, infra-02, infra-03.
  slug        = "infra"
  node_count  = 3
  index_width = 2 # zero-pad -> infra-01 (sorts lexicographically past 9 nodes)

  # Plan-mode (or use the configurator: cpu/ram/disk[/category]).
  plan         = 379 # 2cpu / 6GB / 15GB nvme
  distributive = 164 # debian-13
  datacenter   = 1   # spb
}
