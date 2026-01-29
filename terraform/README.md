# Deploying FeedCord with Terraform

This folder contains the Terraform configuration to provision the Azure infrastructure for FeedCord. It utilizes a **Scale-to-Zero** architecture with **Ghost Gist Persistence** to achieve a truly $0 monthly cost.

## Prerequisites
- **Terraform 1.0+**
- **Azure CLI**
- **Azure Subscription**
- **GitHub Personal Access Token (PAT)**: Requires the `gist` scope. Generate one at [GitHub Token Settings](https://github.com/settings/tokens).
- **GitHub Gist**: Create a **Secret Gist** at [gist.github.com](https://gist.github.com/):
  - **Filename**: `feed_dump.csv`
  - **Content**: `url,isYoutube,lastRunDate` (copy this exact line)
  - **Visibility**: Secret
  - **Gist ID**: After creating, copy the long alphanumeric string from the end of the URL (e.g., `https://gist.github.com/user/a1b2c3d4...` -> the ID is `a1b2c3d4...`).

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
   Edit `terraform.tfvars` and set your `subscription_id`, `tenant_id`, and `github_token`.

3. **Initialize and Apply**:
   ```bash
   terraform init
   terraform plan
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
- **Container App**: Running the FeedCord application (pulling from your private `ghcr.io` registry).
- **Federated Identity**: Enables passwordless GitHub Actions login via OIDC.

### The "Ghost Gist" Persistence ($0)
Instead of paying for Azure Storage, this deployment uses a **Private GitHub Gist** to store the RSS poll state (`feed_dump.csv`).
- **Manual Setup**: You must create a private Gist once manually and provide its ID to Terraform.
- **Lifecycle Sync**: 
  - **Sync-Down**: When the container wakes up, a sidecar container downloads the latest state from your Gist.
  - **Sync-Up**: When the container prepares to shut down, the sidecar uploads the updated state back to GitHub.

### Scaling & $0 Cost Strategy
- **Scale-to-Zero**: Defaults to `min_replicas = 0`. The application will shut down completely when idle to ensure it stays within the **Azure Always Free** grant.
- **Periodic Triggers**: Since FeedCord is a background poller, it is "woken up" every 15 minutes by a GitHub Action (`feedcord-keep-alive.yml`). This trigger pings the app's URL, causing it to scale up, poll for new feeds, and then scale back down.
- **Resources**: Default allocation is 0.25 vCPU and 0.5Gi RAM.

## Outputs
Run these commands to get the values needed for your GitHub Actions secrets:

| Output | Command | Usage |
| :--- | :--- | :--- |
| `container_app_url` | `terraform output -raw container_app_url` | `CONTAINER_APP_URL` variable |
| `azure_credentials_json` | `terraform output -raw azure_credentials_json` | `AZURE_CREDENTIALS` secret |

## Logging
To watch the real-time activity (only works when the app is "awake"):
```bash
az containerapp logs show -n feedcord-app -g feedcord-rg --follow
```