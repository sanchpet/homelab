# sweb-vps — one SpaceWeb VPS, managed declaratively.
#
# The provider block lives in the module (one instance == one account), configured from the
# connection inputs. Null creds → the provider reads them from the environment.

provider "sweb" {
  endpoint = var.endpoint
  token    = var.token
  login    = var.login
  password = var.password
}

resource "sweb_vps" "this" {
  alias        = var.alias
  distributive = var.distributive
  datacenter   = var.datacenter

  # Exactly one of these two modes is set (provider enforces it).
  plan     = var.plan
  cpu      = var.cpu
  ram      = var.ram
  disk     = var.disk
  category = var.category

  ssh_key  = var.ssh_key
  ip_count = var.ip_count

  timeouts {
    create = var.create_timeout
  }
}
