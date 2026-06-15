# live/ger — the 3x-ui panel on the ips-ger-vps cluster.
#
# The panel is ClusterIP-only (svc/xui-panel:2053, not public). Before apply, open a
# tunnel so http://localhost:2053 reaches it:
#   VPN off:  ssh -L 2053:<xui-panel-clusterIP>:2053 <ger-node>
#   VPN on:   kubectl port-forward -n vpn svc/xui-panel 2053:2053
# Then: cd terraform/live/ger && terragrunt apply
#
# Panel credentials (admin user/pass + webBasePath) come from the SOPS-encrypted
# secrets.sops.yaml in this dir — see secrets.sops.yaml.example. The age private key must
# be available locally for sops to decrypt (SOPS_AGE_KEY_FILE or ~/.config/sops/age/keys.txt).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/threexui-panel"
}

locals {
  panel = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.sops.yaml"))
}

inputs = {
  endpoint  = "http://localhost:2053"
  base_path = local.panel.base_path
  username  = local.panel.username
  password  = local.panel.password

  inbounds = {
    reality = {
      port                 = 443
      remark               = "vless-reality-ger"
      reality_target       = "www.amazon.com:443"
      reality_server_names = ["www.amazon.com"]
    }
  }

  clients = {
    owner = {
      inbound_key = "reality"
      email       = "owner@ger"
      comment     = "owner"
    }
  }
}
