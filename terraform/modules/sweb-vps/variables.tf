# Inputs for the sweb-vps module: one SpaceWeb VPS, plus how to authenticate.
#
# The module configures its own provider from the connection inputs (one module instance ==
# one SpaceWeb account). Credentials default to null so the provider falls back to the
# environment (SWEB_LOGIN/SWEB_PASSWORD or SWEB_TOKEN) — keep them out of HCL and state.

# --- Connection / auth ---

variable "endpoint" {
  description = "API root override. Null → provider uses $SWEB_ENDPOINT, then the production API."
  type        = string
  default     = null
}

variable "token" {
  description = "API token. Null → provider uses $SWEB_TOKEN. One-off (no refresh)."
  type        = string
  default     = null
  sensitive   = true
}

variable "login" {
  description = "Login for transparent token refresh. Null → provider uses $SWEB_LOGIN."
  type        = string
  default     = null
}

variable "password" {
  description = "Password for transparent token refresh. Null → provider uses $SWEB_PASSWORD."
  type        = string
  default     = null
  sensitive   = true
}

# --- Node group definition ---
#
# The module manages a group of identical nodes sharing one slug, named <slug>-<index>
# (e.g. infra-01, infra-02). Nodes are keyed by name via for_each, so adding or removing one
# never reindexes — and so never destroys — its siblings (which `count` would).

variable "slug" {
  description = "Group slug shared by every node; node names are <slug>-<index> (e.g. \"infra\" -> infra-01)."
  type        = string
}

variable "node_count" {
  description = "Number of identical nodes to manage in the group."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "index_width" {
  description = "Zero-pad width of the node index (2 -> infra-01; 1 -> infra-1)."
  type        = number
  default     = 2
}

variable "index_start" {
  description = "First index value (1 -> infra-01, infra-02, ...)."
  type        = number
  default     = 1
}

variable "distributive" {
  description = "OS distributive id (e.g. 164=debian-13, 122=ubuntu-24.04)."
  type        = number
}

variable "datacenter" {
  description = "Datacenter id (1=spb, 2=msk, 3=ams)."
  type        = number
}

# Provisioning: set EITHER a literal `plan` id OR the readable spec (cpu/ram/disk
# [/category]). The spec is resolved to a plan id via the sweb_plan data source and
# the node is provisioned in PLAN-MODE either way — so an imported plan-mode node
# stays clean (no changePlan/resize) while HCL still reads by resources.

variable "plan" {
  description = "Ready-made plan id. Mutually exclusive with the spec (cpu/ram/disk)."
  type        = number
  default     = null
}

variable "cpu" {
  description = "Spec: CPU cores. Resolved to a plan id via sweb_plan. Mutually exclusive with plan."
  type        = number
  default     = null
}

variable "ram" {
  description = "Spec: RAM in GB."
  type        = number
  default     = null
}

variable "disk" {
  description = "Spec: disk in GB."
  type        = number
  default     = null
}

variable "category" {
  description = "Spec: catalog category id (1=nvme, 2=hdd, 3=turbo). Null → sweb_plan defaults to 1 (nvme)."
  type        = number
  default     = null
}

variable "ssh_key" {
  description = "SSH public key id to inject at create. Create-only; not recoverable on import."
  type        = string
  default     = null
}

variable "ip_count" {
  description = "Number of IPs to order. Create-only."
  type        = number
  default     = null
}

variable "create_timeout" {
  description = "Max time to wait for the VPS to become ready."
  type        = string
  default     = "15m"
}
