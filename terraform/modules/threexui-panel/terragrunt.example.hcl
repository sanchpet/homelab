# Example: configure one 3x-ui panel. Real units live under live/threexui/<panel>/.
# The panel is ClusterIP-only → reach the endpoint over an SSH tunnel / kubectl
# port-forward. Panel creds come from a SOPS-encrypted secrets.sops.yaml next to the unit.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/threexui-panel"
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
      remark               = "vless-reality"
      reality_target       = "www.amazon.com:443"
      reality_server_names = ["www.amazon.com"]
    }
  }

  clients = {
    owner = {
      inbound_key = "reality"
      email       = "owner@example"
    }
  }
}
