# Copy to terraform.tfvars or pass values via -var on the CLI

resource_group_name = "feedcord-rg"
subscription_id     = "a74ef4fa-1be6-424d-ad49-7ed3931f2b4c"
tenant_id           = "148fdc2b-27f0-4526-9578-2237362e67a7"
github_repo         = "whartons/FeedCord-AzContainerApp"
location            = "eastus"
acr_name            = "feedcordacr"
container_app_name  = "feedcord-app"
environment_name    = "feedcord-env"
# Provide your appsettings.json inline or via a file
appsettings_json    = "{\"Logging\":{\"LogLevel\":{\"Default\":\"Information\"}}}"
image_tag           = "latest"