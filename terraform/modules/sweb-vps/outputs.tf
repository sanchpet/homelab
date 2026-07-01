# Outputs: identifiers + reachability per node, keyed by node name (e.g. "infra-01"), for
# wiring into ansible / Flux / DNS.

output "billing_ids" {
  description = "Map node name -> SpaceWeb service id (login_vps_N), the resource id and delete/import key."
  value       = { for k, v in sweb_vps.this : k => v.billing_id }
}

output "uids" {
  description = "Map node name -> stable unique id of the VPS."
  value       = { for k, v in sweb_vps.this : k => v.uid }
}

output "names" {
  description = "Map node name -> effective name reported by the API."
  value       = { for k, v in sweb_vps.this : k => v.name }
}

output "ips" {
  description = "Map node name -> primary IP address."
  value       = { for k, v in sweb_vps.this : k => v.ip }
}

output "running" {
  description = "Map node name -> whether the VPS is running."
  value       = { for k, v in sweb_vps.this : k => v.running }
}
