
output "container_app_url" {
  value = azurerm_container_app.feedcord.ingress[0].fqdn
}

output "container_app_principal_id" {
  description = "Principal ID of the Container App's system-assigned managed identity"
  value       = azurerm_container_app.feedcord.identity[0].principal_id
}
