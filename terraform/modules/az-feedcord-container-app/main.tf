resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.container_app_name}-logs"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"

  # 30 days sits inside the 31 days of retention included at no charge.
  retention_in_days = 30

  # Hard cost ceiling. 0.1 GB/day caps ingestion at ~3 GB/month, comfortably
  # inside Azure Monitor's 5 GB/month free ingestion grant, so this workspace
  # cannot produce a bill even if something starts log-spamming.
  daily_quota_gb = 0.1
}

resource "azurerm_container_app_environment" "env" {
  name                       = var.environment_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_container_app" "feedcord" {
  name                         = var.container_app_name
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template {
    container {
      name   = "feedcord"
      # Pointing to GHCR to avoid Docker Hub rate limits
      image  = "ghcr.io/whartons/feedcord:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      # Ghost Gist Trick: Symlink everything for maximum compatibility
      # The app expects config at /app/config/appsettings.json
      command = ["/bin/sh"]
      args    = ["-c", "echo 'Waiting for sidecar...' && while [ ! -f /mnt/state/ready ]; do sleep 1; done && echo 'Sidecar ready!' && cd /app && mkdir -p config && ln -sf /mnt/state/feed_dump.csv feed_dump.csv && ln -sf /mnt/config/appsettings-json config/appsettings.json && exec dotnet FeedCord.dll"]

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
      image   = "ghcr.io/whartons/alpine:3.18"
      command = ["/bin/sh", "-c"]
      args    = [replace(<<-EOT
        apk add --no-cache curl jq busybox-extras

        # Health endpoint for the keep-alive ping. Alpine ships httpd in
        # busybox-extras, not base busybox, so plain `busybox httpd` is a no-op.
        # Served from a dedicated dir so the container filesystem is not
        # exposed through the public ingress.
        mkdir -p /healthz
        echo 'OK' > /healthz/index.html
        busybox-extras httpd -p 80 -h /healthz &
        sleep 1
        if wget -qO- http://127.0.0.1/ >/dev/null 2>&1; then
          echo 'healthz: listening on :80'
        else
          echo 'healthz: FAILED to start'
        fi

        sync_to_gist() {
          echo "=== Syncing to Gist at $(date) ==="
          if [ -s /shared/feed_dump.csv ]; then
            # Deduplicate CSV: Filter out header, keep last entry per URL, then prepend header
            awk -F, '$1!="url"{lines[$1]=$0} END {print "url,isYoutube,lastRunDate"; for (l in lines) print lines[l]}' /shared/feed_dump.csv > /shared/feed_dump_clean.csv
            mv /shared/feed_dump_clean.csv /shared/feed_dump.csv
            
            CONTENT=$(jq -Rsa . /shared/feed_dump.csv)
            echo '{"files":{"feed_dump.csv":{"content":'$CONTENT'}}}' > /shared/payload.json
            curl -s -X PATCH -H "Authorization: token $GITHUB_TOKEN" -d @/shared/payload.json -o /dev/null -w "%%{http_code}" https://api.github.com/gists/$GITHUB_GIST_ID > /shared/up_code.txt
            UP_CODE=$(cat /shared/up_code.txt)
            echo "Sync result: HTTP $UP_CODE"
          else
            echo 'No CSV file found'
          fi
        }

        trap "sleep 10; sync_to_gist" SIGTERM

        echo "Syncing down from Gist..."
        curl -s -H "Authorization: token $GITHUB_TOKEN" -w "%%{http_code}" -o /shared/gist_body.json https://api.github.com/gists/$GITHUB_GIST_ID > /shared/gist_code.txt
        HTTP_CODE=$(cat /shared/gist_code.txt)
        if [ "$HTTP_CODE" = "200" ]; then
          jq -r '.files["feed_dump.csv"].content' /shared/gist_body.json > /shared/feed_dump.csv
          echo "Download OK"
        else
          echo "Download failed: $HTTP_CODE"
        fi
        if [ ! -s /shared/feed_dump.csv ]; then
          echo "url,isYoutube,lastRunDate" > /shared/feed_dump.csv
        fi
        
        # Signal that Gist download is complete and file is ready
        touch /shared/ready
        echo 'Sidecar ready - starting periodic sync loop'
        
        while true; do
          sync_to_gist
          sleep 60 &
          wait $!
        done
      EOT
      , "\r\n", "\n")]
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
