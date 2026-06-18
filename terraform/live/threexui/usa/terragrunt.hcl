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

  # manage_panel_user defaults to true (like ger): the module owns the admin user and keeps it
  # rotated to username/password (applied write-only). secrets.sops.yaml holds the current
  # creds, so this is a no-op rotation until the password is intentionally changed.

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

  # Subscription server (fronted by the cluster Gateway). The existing 3x-ui-generated path is
  # adopted by importing random_string.sub_path + threexui_panel_subscription; the path_* knobs
  # are set to match what `terraform import` records for random_string (all char classes true),
  # so the import is a no-op and existing subscription URLs are preserved. See README §Subscription.
  subscription = {
    public_url   = "https://sub.vps-2.usa.ips.sanch.pet:8443"
    json_enable  = false # live panel: subJsonEnable = false
    path_length  = 20    # len("vTA72nw8jcJ3jkHB6anK")
    path_special = true  # import sets random_string char-class flags to provider defaults
    path_upper   = true  # (all true) — match them so the import is a no-op
  }
}
