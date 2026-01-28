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

      # Ghost Gist Trick: Symlink everything for maximum compatibility
      # We cd into /app and symlink BOTH the state file and the config file
      command = ["/bin/sh"]
      args    = ["-c", "cd /app && ln -sf /mnt/state/feed_dump.csv feed_dump.csv && ln -sf /mnt/config/appsettings-json appsettings.json && dotnet FeedCord.dll"]

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://+:80"
      }

      volume_mounts {
        name = "secret-vol"
        path = "/mnt/config"
      }

      volume_mounts {
        name = "shared-data"
        path = "/mnt/state"
      }
    }

    container {
      name    = "wake-up-server"
      image   = "alpine:3.18"
      command = ["/bin/sh", "-c"]
      args    = [<<-EOT
        apk add --no-cache curl jq;
        echo "Syncing down state from Gist $GITHUB_GIST_ID...";
        curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/gists/$GITHUB_GIST_ID | jq -r '.files["feed_dump.csv"].content' > /shared/feed_dump.csv;
        if [ ! -f /shared/feed_dump.csv ] || [ "$(cat /shared/feed_dump.csv)" = "null" ]; then echo "url,isYoutube,lastRunDate" > /shared/feed_dump.csv; fi;
        echo 'HTTP/1.1 200 OK\n\nOK' > index.html;
        httpd -p 80 -h . &
        HTTPD_PID=$!;
        trap "
          echo 'SIGTERM received. Waiting for FeedCord to persist...';
          sleep 15;
          echo 'Syncing up state to Gist...';
          CONTENT=\$(cat /shared/feed_dump.csv | jq -Rsa .);
          PAYLOAD=\"{\\\"files\\\": {\\\"feed_dump.csv\\\": {\\\"content\\\": \$CONTENT}}}\";
          curl -s -X PATCH -H \"Authorization: token \$GITHUB_TOKEN\" -d \"\$PAYLOAD\" https://api.github.com/gists/\$GITHUB_GIST_ID;
          echo 'Sync complete. Shutting down.';
          kill \$HTTPD_PID;
          exit 0;
        " SIGTERM;
        wait $HTTPD_PID
      EOT
      ]
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name      = "GITHUB_TOKEN"
        secret_name = "github-token"
      }
      env {
        name      = "GITHUB_GIST_ID"
        secret_name = "github-gist-id"
      }

      volume_mounts {
        name = "shared-data"
        path = "/shared"
      }
    }

    volume {
      name         = "secret-vol"
      storage_type = "Secret"
    }

    volume {
      name         = "shared-data"
      storage_type = "EmptyDir"
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

  secret {
    name  = "github-token"
    value = var.github_token
  }

  secret {
    name  = "github-gist-id"
    value = var.github_gist_id
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
