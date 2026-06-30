# sweb-vps — a group of identical SpaceWeb VPS nodes, managed declaratively.
#
# The provider block lives in the module (one instance == one account), configured from the
# connection inputs. Null creds → the provider reads them from the environment.

provider "sweb" {
  endpoint = var.endpoint
  token    = var.token
  login    = var.login
  password = var.password
}

locals {
  # <slug>-<zero-padded index>, e.g. infra-01, infra-02. Keyed for for_each so adding or
  # removing a node never reindexes (and so never destroys) its siblings.
  node_names = toset([
    for i in range(var.node_count) :
    format("%s-%0${var.index_width}d", var.slug, var.index_start + i)
  ])
}

resource "sweb_vps" "this" {
  for_each = local.node_names

  alias        = each.key
  distributive = var.distributive
  datacenter   = var.datacenter

  # Exactly one of these two modes is set (provider enforces it). All nodes are identical.
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
