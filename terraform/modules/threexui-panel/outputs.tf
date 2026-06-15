# Outputs: ids/tags for wiring, and client identifiers for building subscription links.
# Client UUIDs and sub_ids are secrets → marked sensitive.

output "inbound_ids" {
  description = "Map of inbound local-name => numeric panel ID."
  value       = { for k, v in threexui_inbound.this : k => v.id }
}

output "inbound_tags" {
  description = "Map of inbound local-name => auto-generated xray tag."
  value       = { for k, v in threexui_inbound.this : k => v.tag }
}

output "client_uuids" {
  description = "Map of client local-name => UUID (client_id)."
  value       = { for k, v in threexui_inbound_client.this : k => v.client_id }
  sensitive   = true
}

output "client_sub_ids" {
  description = "Map of client local-name => subscription ID (build sub URLs from these)."
  value       = { for k, v in threexui_inbound_client.this : k => v.sub_id }
  sensitive   = true
}
