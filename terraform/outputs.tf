output "acr_login_server" {
  description = "The ACR login server (e.g. myregistry.azurecr.io)"
  value       = module.feedcord.acr_login_server
}

output "container_app_url" {
  description = "FQDN of the deployed Container App"
  value       = module.feedcord.container_app_url
}

output "container_app_principal_id" {
  description = "Principal ID of the Container App's system-assigned managed identity"
  value       = module.feedcord.container_app_principal_id
}

output "azure_credentials_json" {
  description = "JSON credentials for GitHub Actions (add to AZURE_CREDENTIALS secret)"
  sensitive   = true
  value = jsonencode({
    clientId       = azuread_service_principal.github_actions.client_id
    subscriptionId = data.azurerm_subscription.current.subscription_id
    tenantId       = data.azurerm_subscription.current.tenant_id
  })
}
