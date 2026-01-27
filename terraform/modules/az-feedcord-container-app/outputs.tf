output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "container_app_url" {
  value = azurerm_container_app.feedcord.latest_revision_fqdn
}

output "container_app_principal_id" {
  description = "Principal ID of the Container App's system-assigned managed identity"
  value       = azurerm_container_app.feedcord.identity[0].principal_id
}
