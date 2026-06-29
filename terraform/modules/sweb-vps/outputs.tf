# Outputs: identifiers + reachability for wiring into ansible / Flux / DNS.

output "billing_id" {
  description = "SpaceWeb service id (login_vps_N) — the resource id and delete/import key."
  value       = sweb_vps.this.billing_id
}

output "uid" {
  description = "Stable unique id of the VPS."
  value       = sweb_vps.this.uid
}

output "name" {
  description = "Effective name reported by the API."
  value       = sweb_vps.this.name
}

output "ip" {
  description = "Primary IP address."
  value       = sweb_vps.this.ip
}

output "running" {
  description = "Whether the VPS is running."
  value       = sweb_vps.this.running
}
