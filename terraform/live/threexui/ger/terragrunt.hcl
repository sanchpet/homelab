# live/threexui/ger — the 3x-ui panel on the ips-ger-vps cluster.
#
# The panel is ClusterIP-only (svc/xui-panel:2053, not public). Before apply, open a
# tunnel so http://localhost:2053 reaches it:
#   VPN off:  ssh -L 2053:<xui-panel-clusterIP>:2053 <ger-node>
#   VPN on:   kubectl port-forward -n vpn svc/xui-panel 2053:2053
# Then: cd terraform/live/threexui/ger && terragrunt apply
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
  panel   = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.sops.yaml"))
  clients = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/clients.sops.yaml")).clients
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

  inbounds = {
    reality = {
      port                 = 443
      remark               = "vless-reality-ger"
      reality_target       = "www.amazon.com:443"
      reality_server_names = ["www.amazon.com"]
    }
  }

  clients = local.clients
}
