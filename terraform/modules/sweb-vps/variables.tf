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

# --- Node definition ---

variable "alias" {
  description = "Human-facing name for the VPS."
  type        = string
}

variable "distributive" {
  description = "OS distributive id (e.g. 164=debian-13, 122=ubuntu-24.04)."
  type        = number
}

variable "datacenter" {
  description = "Datacenter id (1=spb, 2=msk, 3=ams)."
  type        = number
}

# Provisioning mode — set EITHER plan OR the configurator (cpu/ram/disk[/category]).
# The provider enforces exactly-one-of (plan, cpu) and recreates the node on any change.

variable "plan" {
  description = "Ready-made plan id. Mutually exclusive with the configurator."
  type        = number
  default     = null
}

variable "cpu" {
  description = "Configurator: CPU cores. Mutually exclusive with plan."
  type        = number
  default     = null
}

variable "ram" {
  description = "Configurator: RAM in GB."
  type        = number
  default     = null
}

variable "disk" {
  description = "Configurator: disk in GB."
  type        = number
  default     = null
}

variable "category" {
  description = "Configurator: catalog category id (1=nvme, 2=hdd, 3=turbo). Defaults to 1 in the provider."
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
