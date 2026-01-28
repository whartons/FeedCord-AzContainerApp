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
- **Container App Environment**: The serverless host environment for the app.
- **Container App**: Running the FeedCord application (pulling directly from `qolors/feedcord:latest`).
- **Federated Identity**: Enables passwordless GitHub Actions login via OIDC.

### Scaling & $0 Cost Strategy
- **Scale-to-Zero**: Defaults to `min_replicas = 0`. The application will shut down completely when idle to ensure it stays within the **Azure Always Free** grant.
- **Periodic Triggers**: Since FeedCord is a background poller, it is "woken up" every 15 minutes by a GitHub Action (`feedcord-keep-alive.yml`). This trigger pings the app's URL, causing it to scale up, poll for new feeds, and then scale back down.
- **Resources**: Default allocation is 0.25 vCPU and 0.5Gi RAM.

## Outputs
After a successful `terraform apply`, you will need these values for your GitHub Repository configuration:

| Output | Command to View | Usage |
| :--- | :--- | :--- |
| `container_app_url` | `terraform output -raw container_app_url` | Add as `CONTAINER_APP_URL` variable in GitHub. |
| `azure_credentials_json` | `terraform output -raw azure_credentials_json` | Add as `AZURE_CREDENTIALS` secret in GitHub. |

## Verify the Deployment

### Logs
To watch the real-time application logs (useful during the 15-minute "wake up" cycles):
```bash
az containerapp logs show \
  --name feedcord-app \
  --resource-group feedcord-rg \
  --follow
```

### Manual Trigger
You can manually wake the app at any time by simply visiting the `container_app_url` in your browser or running:
```bash
curl -I $(terraform output -raw container_app_url)
```