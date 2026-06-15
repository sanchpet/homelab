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
