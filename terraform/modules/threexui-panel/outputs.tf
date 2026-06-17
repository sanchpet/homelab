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

output "subscription_base_url" {
  description = "Public subscription base URL (append a client sub_id). Contains the random path → sensitive. null when subscription is unset."
  value       = var.subscription != null ? "${var.subscription.public_url}/${random_string.sub_path[0].result}/" : null
  sensitive   = true
}

output "client_subscription_urls" {
  description = "Full subscription URL per client (random path + sub_id) → sensitive."
  value = var.subscription == null ? {} : {
    for k, v in threexui_inbound_client.this : k => "${var.subscription.public_url}/${random_string.sub_path[0].result}/${v.sub_id}"
  }
  sensitive = true
}
