###############################################################################
# Variables
###############################################################################

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "petstore-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southeastasia"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "petstore"
}

variable "acr_name" {
  description = "Azure Container Registry name (globally unique, alphanumeric)"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name (globally unique, lowercase, 3-24 chars)"
  type        = string
}

variable "blob_container_name" {
  description = "Blob container name for order reservations"
  type        = string
  default     = "orderitemsreserver"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "v1"
}

variable "min_replicas" {
  description = "Minimum replicas per Container App"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum replicas per Container App"
  type        = number
  default     = 5
}

variable "concurrent_requests" {
  description = "Concurrent HTTP requests to trigger autoscaling"
  type        = string
  default     = "10"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "petstore"
    environment = "dev"
    managed_by  = "terraform"
  }
}

