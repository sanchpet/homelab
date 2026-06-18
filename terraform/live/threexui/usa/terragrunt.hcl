# live/threexui/usa — the 3x-ui panel on the ips-usa-vps-2 cluster.
#
# The panel is ClusterIP-only (svc/xui-panel:2053, not public). Before apply/import, open a
# tunnel so http://localhost:2053 reaches it:
#   VPN off:  ssh -L 2053:<xui-panel-clusterIP>:2053 <usa-node>
#   VPN on:   kubectl port-forward -n vpn svc/xui-panel 2053:2053
# Then: cd terraform/live/threexui/usa && terragrunt apply
#
# This panel PRE-EXISTS (live clients). Its resources must be IMPORTED into state before the
# first apply, otherwise apply would recreate them and rotate keys (breaking live clients).
# Full onboarding/import + parity runbook: see README.md in this dir.
#
# Two SOPS-encrypted files in this dir (need the age key locally — SOPS_AGE_KEY_FILE or
# ~/.config/sops/age/keys.txt):
#   secrets.sops.yaml  — panel admin user/pass + webBasePath (see *.example)
#   clients.sops.yaml  — the VPN client list (identities are PII) (see *.example)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/threexui-panel"
}

locals {
  panel = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.sops.yaml"))
  # clients.sops.yaml stores the whole client map as a single encrypted block-scalar string
  # (so SOPS hides the handles too, not just values) — decode the file, then the inner YAML.
  clients = yamldecode(yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/clients.sops.yaml")).clients)
}

inputs = {
  endpoint  = "http://localhost:2053"
  base_path = local.panel.base_path
  username  = local.panel.username
  password  = local.panel.password

  # First-run rotation from admin/admin → steady-state (remove from secrets.sops.yaml once
  # the panel is rotated; optional after that).
  bootstrap_username = try(local.panel.bootstrap_username, null)
  bootstrap_password = try(local.panel.bootstrap_password, null)

  # IMPORTANT — these MUST match the LIVE USA inbound before import, or the first plan/apply
  # will rotate the Reality keys and break existing clients. Enumerate the live panel first
  # (README §Enumerate), then replace the placeholders below with the real values, and set
  # reality_private_key / reality_short_ids explicitly (null => panel regenerates).
  inbounds = {
    reality = {
      port                 = 443                  # VERIFY against live USA inbound
      remark               = "vless-reality-usa"  # VERIFY (panel remark)
      reality_target       = "www.amazon.com:443" # VERIFY
      reality_server_names = ["www.amazon.com"]   # VERIFY
      # reality_private_key  = "<from live panel>" # REQUIRED for a no-op import
      # reality_short_ids    = ["<from live panel>"]
    }
  }

  clients = local.clients

  # Subscription server, fronted by the cluster Gateway (sub-https:8443 → xui-sub:2096).
  subscription = {
    public_url = "https://sub.vps-2.usa.ips.sanch.pet:8443"
  }
}
