resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
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
      # Pointing directly to upstream Docker Hub image to save ACR costs
      image  = "qolors/feedcord:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "APPCONFIG_JSON"
        secret_name = "appsettings-json"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:80"
      }

      volume_mounts {
        name     = "secret-vol"
        path     = "/app/config/appsettings.json"
        sub_path = "appsettings-json"
      }
    }

    volume {
      name         = "secret-vol"
      storage_type = "Secret"
    }

    min_replicas = 0
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

  # Map the secret to a specific file inside the volume
  # Note: The 'azure-native' term for this is secretRef, but in azurerm it's handled via the template volume object.
  # However, the azurerm provider (v4.0) handles secret volumes by mapping the secret name to a file with the same name.
  # We might need to adjust the path or use a different approach if the filename needs to be exactly appsettings.json.

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      secret
    ]
  }
}
