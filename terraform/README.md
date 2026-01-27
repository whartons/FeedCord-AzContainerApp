# Deploying the az-feedcord-container-app module

This folder contains a root Terraform configuration that instantiates the
`az-feedcord-container-app` module (found in `./modules/az-feedcord-container-app`).

Prerequisites
- Terraform 1.0+
- Azure CLI (for authentication) and an Azure subscription

Quickstart
1. Authenticate with Azure (one of):

   - az login
   - or use a service principal and set the environment variables used by Terraform

2. Copy the example variables and edit them:

   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars and set values appropriate for your subscription

3. Initialize and plan:

   terraform init
   terraform plan

4. Apply:

   terraform apply

Notes
- The module will create the resource group and the ACR, and deploy a default hello world image to the container.
- If you prefer a remote backend (recommended for team usage), configure a backend block in a `backend.tf` file.

Scaling and cost control

- The module configures the container with minimal resources by default (0.25 vCPU, 0.5Gi memory).
- Autoscaling is configured via the `azurerm_container_app_autoscale_setting` resource.
- By default, `min_replicas = 1` and `max_replicas = 1`, which ensures one replica is always running (required for FeedCord to continuously poll RSS feeds).
- You can override these in your `terraform.tfvars` to adjust scaling behavior:

   ```hcl
   min_replicas = 1
   max_replicas = 1
   ```

Permissions & verification

- Required permission to create role assignments: The principal/account that runs Terraform must have the permission to create role assignments in the scope of the ACR (for example, Owner or User Access Administrator). If the principal lacks the required permissions, the `azurerm_role_assignment` resource that grants `AcrPull` to the Container App identity will fail.

- Verify the role assignment after apply:
  1. Get the Container App principal id from Terraform outputs:

     ```bash
     cd terraform
     terraform output -raw container_app_principal_id
     ```
  2. Get the ACR resource id using the Azure CLI (replace names as appropriate):

     ```bash
     az acr show -n <acr_name> -g <resource_group_name> --query id -o tsv
     ```
  3. List role assignments for the principal scoped to the ACR:
     ```bash
     az role assignment list --assignee <principal_id> --scope <acr_id> -o table
     ```
- Create the role assignment manually if needed (requires a user with permission to create role assignments):
  ```bash
  az role assignment create --assignee <principal_id> --role AcrPull --scope <acr_id>
  ```

- Alternative for quick dev testing: enabling the ACR admin user (`admin_enabled = true`) allows using admin credentials for pulls, but this is less secure and not recommended for production.