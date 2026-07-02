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

  # The plan id to provision. Either a literal `plan`, or the configurator spec
  # (cpu/ram/disk[/category]) resolved to an id via the sweb_plan data source.
  plan_id = var.plan != null ? var.plan : data.sweb_plan.spec[0].id
}

# Resolve the readable spec to a plan id at plan-time. Present only in spec-mode
# (var.plan == null). Keeping the resource in plan-mode (below) is deliberate: an
# imported plan-mode node re-derives the same id and keeps a clean plan, instead of
# being pushed through changePlan/resize just to describe it by cpu/ram/disk.
data "sweb_plan" "spec" {
  count = var.plan == null ? 1 : 0

  cpu      = var.cpu
  ram      = var.ram
  disk     = var.disk
  category = var.category
}

resource "sweb_vps" "this" {
  for_each = local.node_names

  alias        = each.key
  distributive = var.distributive
  datacenter   = var.datacenter

  # Always plan-mode: the spec (if any) is resolved to an id above. This is what
  # keeps an imported node's plan clean while HCL still reads by resources.
  plan = local.plan_id

  ssh_key  = var.ssh_key
  ip_count = var.ip_count

  timeouts {
    create = var.create_timeout
  }

  lifecycle {
    precondition {
      condition     = var.plan != null || (var.cpu != null && var.ram != null && var.disk != null)
      error_message = "Set either `plan` (a literal id) or the configurator spec (cpu + ram + disk)."
    }
  }
}
