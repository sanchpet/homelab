# threexui-panel — declares VLESS-Reality inbounds + clients on a single 3x-ui panel.
#
# The provider block lives in the module (one module instance == one panel). This is the
# upstream multi-server pattern; here each panel is a terragrunt unit under live/ rather
# than a for_each in a parent module.

provider "threexui" {
  endpoint             = var.endpoint
  base_path            = var.base_path
  username             = var.username
  password             = var.password
  insecure_skip_verify = var.insecure_skip_verify

  # First-run rotation: authenticate with the old creds if the steady-state ones are
  # rejected (3x-ui v3), so threexui_panel_user can rotate the panel in the same apply.
  bootstrap_username = var.bootstrap_username
  bootstrap_password = var.bootstrap_password
}

# Manage the panel admin user — rotate it to username/password. password_wo is write-only
# (Terraform >= 1.11): the new password is sent to the panel but never stored in state.
resource "threexui_panel_user" "admin" {
  count = var.manage_panel_user ? 1 : 0

  username            = var.username
  password_wo         = var.password
  password_wo_version = var.panel_password_version
}

resource "threexui_inbound" "this" {
  for_each = var.inbounds

  port     = each.value.port
  protocol = "vless"
  enable   = each.value.enable
  remark   = each.value.remark

  vless_settings {
    decryption = "none"
  }

  stream_settings {
    network  = "tcp"
    security = "reality"

    reality_settings {
      target       = each.value.reality_target
      server_names = each.value.reality_server_names
      private_key  = each.value.reality_private_key # null => panel auto-generates
      short_ids    = each.value.reality_short_ids   # null => panel auto-generates
    }

    tcp_settings {
      accept_proxy_protocol = false
      header_type           = "none"
    }
  }

  sniffing {
    enabled       = true
    dest_override = ["http", "tls", "quic", "fakedns"]
  }
}

resource "threexui_inbound_client" "this" {
  for_each = var.clients

  inbound_id  = threexui_inbound.this[each.value.inbound_key].id
  email       = each.value.email
  flow        = each.value.flow
  enable      = each.value.enable
  total_gb    = each.value.total_gb
  expiry_time = each.value.expiry_time
  limit_ip    = each.value.limit_ip
  comment     = each.value.comment
  tg_id       = each.value.tg_id
  sub_id      = each.value.sub_id # null => panel auto-generates
}
