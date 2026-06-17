variable "resource_group_name" {
  description = "Name of the Azure resource group to create/use"
  type        = string
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. whartons/FeedCord-AzContainerApp) for OIDC federation"
  type        = string
}


variable "container_app_name" {
  description = "Name of the Azure Container App to create"
  type        = string
}

variable "environment_name" {
  description = "Name of the Container Apps environment"
  type        = string
}

variable "appsettings_json" {
  description = "JSON blob used for appsettings (will be stored as a Container App secret)"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Image tag to deploy (e.g. latest or a commit SHA)"
  type        = string
  default     = "latest"
}

variable "min_replicas" {
  description = "Minimum number of container replicas (FeedCord requires >= 1 to continuously poll RSS feeds)"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 1
}

variable "concurrent_requests" {
  description = "Concurrent requests threshold for HTTP scale rule"
  type        = number
  default     = 50
}

variable "github_token" {
  description = "GitHub Personal Access Token for Gist persistence"
  type        = string
  sensitive   = true
}

variable "github_gist_id" {
  description = "GitHub Gist ID for storing feed_dump.csv"
  type        = string
}
