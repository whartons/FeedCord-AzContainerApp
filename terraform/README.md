# Deploying FeedCord with Terraform

This folder contains the Terraform configuration to provision the Azure infrastructure for FeedCord. It uses the `az-feedcord-container-app` module found in `./modules/az-feedcord-container-app`.

## Prerequisites
- **Terraform 1.0+**
- **Azure CLI**
- **Azure Subscription** (You'll need your Subscription ID and Tenant ID)

## Quickstart

1. **Authenticate with Azure**:
   ```bash
   az login
   ```

2. **Configure Variables**:
   Copy the example variables file and fill in your details:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `terraform.tfvars` and set your `subscription_id`, `tenant_id`, and `github_repo` (e.g., `username/FeedCord-AzContainerApp`).

3. **Initialize and Apply**:
   ```bash
   terraform init
   ```
   ```bash
   terraform plan
   ```
   ```bash
   terraform apply
   ```

4. **GitHub Actions OIDC Setup**:
   Terraform automatically creates a Federated Identity for GitHub Actions. After the apply completes, run this to get the JSON for your GitHub `AZURE_CREDENTIALS` secret:
   ```bash
   terraform output -raw azure_credentials_json
   ```

## Infrastructure Details

### Resources Created
- **Resource Group**: Organizes all FeedCord resources.
- **Azure Container Registry (ACR)**: Stores the FeedCord Docker image.
- **Container App Environment**: The host environment for the app.
- **Container App**: Running the FeedCord application.
- **System-Assigned Managed Identity**: Used by the app to securely pull images from ACR.
- **Federated Identity**: Enables passwordless GitHub Actions login via OIDC.

### Scaling & Performance
- **Replicas**: Defaults to `min_replicas = 1` and `max_replicas = 1`. This is required because FeedCord is a background worker that needs to be constantly running to poll feeds.
- **Resources**: Default allocation is 0.25 vCPU and 0.5Gi RAM, which is sufficient for typical RSS polling.

### Permissions
The account running Terraform must have permission to create **Role Assignments** (like User Access Administrator or Owner) to grant the Container App `AcrPull` permissions on the registry.

## Verify the Deployment
To check the deployment status or logs:
```bash
# Get the URL of your app
terraform output container_app_url

# Check the principal ID of the app identity
terraform output container_app_principal_id
```

## Testing & Troubleshooting

### Ingress (Inbound)
To verify the app is reachable from the internet:
1. Get the URL: `terraform output container_app_url`.
2. Visit the URL or use `curl -I <URL>`.
   - *Note*: FeedCord is a background service and may not serve a web page, but the URL should be reachable if ingress is enabled.

### Egress (Outbound)
To test if the container can reach external services:
1. **Interactive Console** (Targeting the `debugger` container which has `curl` pre-installed):
   ```bash
   # Add --container debugger to specify the sidecar
   az containerapp exec \
     --name feedcord-app \
     --resource-group feedcord-rg \
     --container debugger \
     --command "/bin/sh"
   ```
2. **Test Connectivity**:
   Inside the container, try to reach an external site:
   ```sh
   curl -I https://discord.com
   ```

### Logs
To watch the real-time application logs:
```bash
az containerapp logs show \
  --name feedcord-app \
  --resource-group feedcord-rg \
  --follow
```