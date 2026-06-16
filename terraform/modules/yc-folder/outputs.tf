output "folder_id" {
  description = "Created folder ID."
  value       = yandex_resourcemanager_folder.this.id
}

output "folder_name" {
  description = "Created folder name."
  value       = yandex_resourcemanager_folder.this.name
}
