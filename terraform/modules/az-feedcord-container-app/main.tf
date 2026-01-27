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

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:80"
      }

      volume_mounts {
        name = "appsettings-vol"
        path = "/app/config"
      }
    }

    # Debugger Sidecar: Provides curl and a shell for testing egress/ingress
    # before the first GitHub Action deployment.
    container {
      name    = "debugger"
      image   = "alpine:latest"
      cpu     = 0.25
      memory  = "0.5Gi"
      command = ["sh", "-c", "apk add --no-cache curl && sleep infinity"]
    }

    init_container {
      name   = "config-setup"
      image  = "alpine:latest"
      command = ["sh", "-c", "cp /mnt/secrets/appsettings-json /app/config/appsettings.json"]

      volume_mounts {
        name = "secret-vol"
        path = "/mnt/secrets"
      }

      volume_mounts {
        name = "appsettings-vol"
        path = "/app/config"
      }
    }

    volume {
      name = "appsettings-vol"
      storage_type = "EmptyDir"
    }

    volume {
      name = "secret-vol"
      storage_type = "Secret"
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

  # Map the secret to a specific file inside the volume
  # Note: The 'azure-native' term for this is secretRef, but in azurerm it's handled via the template volume object.
  # However, the azurerm provider (v4.0) handles secret volumes by mapping the secret name to a file with the same name.
  # We might need to adjust the path or use a different approach if the filename needs to be exactly appsettings.json.

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      registry,
      secret
    ]
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.feedcord.identity[0].principal_id
  depends_on           = [azurerm_container_app.feedcord]
}
