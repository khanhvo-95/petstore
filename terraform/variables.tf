###############################################################################
# Variables
###############################################################################

variable "subscription_id" {
  description = "Azure subscription ID (used for import blocks)"
  type        = string
  default     = ""
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

# ─── Key Vault / Database credentials ───────────────────────────────────────

variable "pgsql_server_name" {
  description = "PostgreSQL Flexible Server name (without .postgres.database.azure.com)"
  type        = string
}

variable "pgsql_admin_user" {
  description = "PostgreSQL admin username"
  type        = string
}

variable "pgsql_password_rotation_days" {
  description = "Number of days before the PostgreSQL password is auto-rotated"
  type        = number
  default     = 90
}

variable "pgsql_database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "petstore"
}

variable "cosmos_account_name" {
  description = "Azure Cosmos DB account name (Terraform reads endpoint + key from Azure automatically)"
  type        = string
}

variable "cosmos_database_name" {
  description = "Azure Cosmos DB database name"
  type        = string
  default     = "petstore"
}

# ─── Entra ID (OAuth2 authentication for PetStore App) ──────────────────────


variable "entra_security_enabled" {
  description = "Enable OAuth2 sign-in via Microsoft Entra ID"
  type        = bool
  default     = true
}

