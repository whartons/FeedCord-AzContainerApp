resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_container_app_environment" "env" {
  name                = var.environment_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_container_app" "feedcord" {
  name                         = var.container_app_name
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template {
    container {
      name   = "feedcord"
      # Use a reliable Microsoft placeholder image (Port 80) to ensure fast provisioning.
      # The actual app image will be deployed by GitHub Actions.
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "APPCONFIG_JSON"
        secret_name = "appsettings-json"
      }

      # Force the .NET app (FeedCord) to listen on port 80 to match the Ingress configuration.
      # This ensures alignment between the placeholder (listening on 80) and the final app.
      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:80"
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "appsettings-json"
    value = var.appsettings_json
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      registry
    ]
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.feedcord.identity[0].principal_id
  depends_on           = [azurerm_container_app.feedcord]
}
