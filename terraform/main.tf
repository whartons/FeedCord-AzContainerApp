terraform {
	required_version = ">= 1.0.0"
	required_providers {
		azurerm = {
			source  = "hashicorp/azurerm"
			version = "~> 4.0"
		}
		azuread = {
			source  = "hashicorp/azuread"
			version = "~> 2.0"
		}
	}
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

data "azurerm_subscription" "current" {}

resource "azuread_application" "github_actions" {
  display_name = "github-feedcord-sp"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-federated"
  description    = "Deployments for ${var.github_repo}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  # Subject allows the 'master' branch of the specific repo to request tokens
  subject        = "repo:${var.github_repo}:ref:refs/heads/master"
}

resource "azurerm_role_assignment" "github_actions" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

data "azurerm_client_config" "current" {}

module "feedcord" {
	source = "./modules/az-feedcord-container-app"

	resource_group_name = var.resource_group_name
	location            = var.location
	acr_name            = var.acr_name
	container_app_name  = var.container_app_name
	environment_name    = var.environment_name
	appsettings_json    = var.appsettings_json
	image_tag           = var.image_tag
}
