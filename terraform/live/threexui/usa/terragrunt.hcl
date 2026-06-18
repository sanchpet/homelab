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

  # Onboarding an EXISTING, already-rotated panel via import — do NOT manage/rotate the admin
  # user (no bootstrap creds needed; secrets.sops.yaml holds the panel's current creds).
  manage_panel_user = false

  # Mirrors the ger inbound (same port/protocol); only the Reality camouflage differs:
  # USA fronts www.microsoft.com (ger fronts www.amazon.com). reality_private_key /
  # reality_short_ids are panel-managed (Optional+Computed) — omitted here like ger and
  # reconciled into state on import, so the secret private key never lands in this public repo.
  inbounds = {
    reality = {
      port                 = 443
      remark               = "vless-reality-usa" # VERIFY exact remark on the panel Basics tab
      reality_target       = "www.microsoft.com:443"
      reality_server_names = ["www.microsoft.com"]
    }
  }

  clients = local.clients

  # Subscription management DEFERRED during onboarding. The live USA panel already has a
  # sub_path; if the module created its own random_string.sub_path it would rotate the path
  # and break every existing subscription URL. Enable this only after importing the existing
  # sub settings + sub_path (follow-up). Until then the panel's current subscription is
  # untouched. Target public_url for later: https://sub.vps-2.usa.ips.sanch.pet:8443
  subscription = null
}
