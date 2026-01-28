variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "container_app_name" { type = string }
variable "environment_name" { type = string }
variable "appsettings_json" {
	type      = string
	sensitive = true
}
variable "image_tag" { type = string }

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