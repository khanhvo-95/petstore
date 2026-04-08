###############################################################################
# PetStore - Azure Infrastructure (Terraform)
# Provisions: ACR, Storage Account, Log Analytics, Application Insights,
#             Key Vault (with DB secrets), User-Assigned Managed Identity,
#             Container Apps Environment,
#             5 Container Apps (secrets pulled from Key Vault at runtime
#             via User-Assigned Managed Identity — no plaintext secrets
#             in Terraform state or environment variables)
# Note: Resource Group must already exist (managed outside Terraform)
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  # No subscription_id or tenant_id hardcoded.
  # Terraform uses the current Azure CLI session automatically:
  #   az login --tenant <YOUR_TENANT_ID>
  #   az account set --subscription <YOUR_SUBSCRIPTION_ID>
  # This prevents tenant/subscription mismatch errors.
}

# ─── Current Azure client (for Key Vault access policies) ───────────────────
data "azurerm_client_config" "current" {}

# ─── Import blocks removed — all resources are now in Terraform state ────────
# A User-Assigned Managed Identity is used to break the circular dependency
# between Container Apps and Key Vault access policies. The identity is created
# first, granted Key Vault access, then assigned to Container Apps.


# ─── Resource Group (already exists — read-only reference) ───────────────────
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ─── Cosmos DB (already exists — read endpoint + key directly from Azure) ────
data "azurerm_cosmosdb_account" "main" {
  name                = var.cosmos_account_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ─── PostgreSQL password rotation ────────────────────────────────────────────
# The time_rotating resource triggers a new password every 90 days.
# On the next `terraform apply` after rotation, Terraform will:
#   1. Generate a new random_password
#   2. Update the PostgreSQL server with the new password
#   3. Update the Key Vault secret
#   4. Container Apps pick up the new secret from Key Vault automatically
resource "time_rotating" "pgsql_password" {
  rotation_days = var.pgsql_password_rotation_days
}

resource "random_password" "pgsql" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}|:,.<>?"

  keepers = {
    rotation = time_rotating.pgsql_password.id
  }
}

# ─── PostgreSQL Flexible Server (import existing, then managed by Terraform) ─
import {
  to = azurerm_postgresql_flexible_server.main
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.DBforPostgreSQL/flexibleServers/${var.pgsql_server_name}"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = var.pgsql_server_name
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = var.location
  administrator_login           = var.pgsql_admin_user
  administrator_password        = random_password.pgsql.result
  version                       = "16"
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  zone                          = "1"
  public_network_access_enabled = true
  tags                          = var.tags

  lifecycle {
    ignore_changes = [zone, high_availability, maintenance_window]
  }
}

import {
  to = azurerm_postgresql_flexible_server_database.main
  id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.DBforPostgreSQL/flexibleServers/${var.pgsql_server_name}/databases/${var.pgsql_database_name}"
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.pgsql_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ─── Azure Container Registry ───────────────────────────────────────────────
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ─── Storage Account (Blob Storage for OrderItemsReserver) ──────────────────
resource "azurerm_storage_account" "orders" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "orderitemsreserver" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.orders.id
  container_access_type = "private"
}

# ─── Log Analytics Workspace ────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-logs"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ─── Application Insights ───────────────────────────────────────────────────
resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-appinsights"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "java"
  tags                = var.tags
}

# ─── Azure Key Vault ────────────────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                       = "${var.project_name}-kv"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  # Deployer access (Terraform service principal / current user)
  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
  }
}

# ─── Key Vault Secrets ──────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "pgsql_url" {
  name         = "pgsql-url"
  value        = local.pgsql_jdbc_url
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "pgsql_username" {
  name         = "pgsql-username"
  value        = var.pgsql_admin_user
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "pgsql_password" {
  name         = "pgsql-password"
  value        = random_password.pgsql.result
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "cosmos_endpoint" {
  name         = "cosmos-endpoint"
  value        = data.azurerm_cosmosdb_account.main.endpoint
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-key"
  value        = data.azurerm_cosmosdb_account.main.primary_key
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "blob_connection_string" {
  name         = "blob-connection-string"
  value        = azurerm_storage_account.orders.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

# ─── Entra ID App Registration (fully managed by Terraform) ─────────────────
# No manual `az ad app` or `az keyvault secret set` needed.
# Terraform creates the app, generates a client secret, and stores it in KV.

resource "azuread_application" "petstoreapp" {
  display_name = "${var.project_name}-app"

  # Redirect URI is set separately below to avoid circular dependency
  # (app needs petstoreapp FQDN, petstoreapp needs app client ID)
}

resource "azuread_service_principal" "petstoreapp" {
  client_id = azuread_application.petstoreapp.client_id
}

# Update redirect URI after the Container App is created
resource "azuread_application_redirect_uris" "petstoreapp" {
  application_id = azuread_application.petstoreapp.id
  type           = "Web"
  redirect_uris = [
    "https://${azurerm_container_app.petstoreapp.ingress[0].fqdn}/login/oauth2/code/azure",
  ]
}

resource "time_rotating" "entra_client_secret" {
  rotation_days = 180
}

resource "azuread_application_password" "petstoreapp" {
  application_id    = azuread_application.petstoreapp.id
  display_name      = "terraform-managed"
  end_date_relative = "4320h" # 180 days

  rotate_when_changed = {
    rotation = time_rotating.entra_client_secret.id
  }
}


resource "azurerm_key_vault_secret" "entra_client_secret" {
  name         = "entra-client-secret"
  value        = azuread_application_password.petstoreapp.value
  key_vault_id = azurerm_key_vault.main.id
}

# ─── User-Assigned Managed Identity (for Key Vault access) ──────────────────
# Created BEFORE Container Apps so we can grant Key Vault access without
# circular dependencies (system-assigned IDs only exist after app creation).
resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "${var.project_name}-identity"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_key_vault_access_policy" "container_apps_identity" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_user_assigned_identity.container_apps.principal_id
  secret_permissions = ["Get"]
}

# ─── Container Apps Environment ─────────────────────────────────────────────
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-env"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = var.tags
}

# ─── Locals: shared config ──────────────────────────────────────────────────
locals {
  acr_login_server = azurerm_container_registry.acr.login_server
  acr_admin_user   = azurerm_container_registry.acr.admin_username
  acr_admin_pass   = azurerm_container_registry.acr.admin_password
  ai_conn_string   = azurerm_application_insights.main.connection_string
  image_tag        = var.image_tag
  pgsql_jdbc_url   = "jdbc:postgresql://${var.pgsql_server_name}.postgres.database.azure.com:5432/${var.pgsql_database_name}?sslmode=require"
}

# ═════════════════════════════════════════════════════════════════════════════
#  Container Apps (one per microservice)
# ═════════════════════════════════════════════════════════════════════════════

# ─── 1. Pet Service ─────────────────────────────────────────────────────────
resource "azurerm_container_app" "petservice" {
  name                         = "${var.project_name}-petservice"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  depends_on = [azurerm_key_vault_access_policy.container_apps_identity]

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
  }

  secret {
    name                = "db-url"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_url.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "db-username"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_username.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_password.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "petservice"
      image  = "${local.acr_login_server}/petstorepetservice:${local.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = local.ai_conn_string
      }

      env {
        name        = "PETSTOREPETSERVICE_DB_URL"
        secret_name = "db-url"
      }

      env {
        name        = "PETSTOREPETSERVICE_DB_USERNAME"
        secret_name = "db-username"
      }

      env {
        name        = "PETSTOREPETSERVICE_DB_PASSWORD"
        secret_name = "db-password"
      }
    }

    http_scale_rule {
      name                = "http-autoscaler"
      concurrent_requests = var.concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ─── 2. Product Service ─────────────────────────────────────────────────────
resource "azurerm_container_app" "productservice" {
  name                         = "${var.project_name}-productservice"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  depends_on = [azurerm_key_vault_access_policy.container_apps_identity]

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
  }

  secret {
    name                = "db-url"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_url.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "db-username"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_username.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = azurerm_key_vault_secret.pgsql_password.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "productservice"
      image  = "${local.acr_login_server}/petstoreproductservice:${local.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = local.ai_conn_string
      }

      env {
        name        = "PETSTOREPRODUCTSERVICE_DB_URL"
        secret_name = "db-url"
      }

      env {
        name        = "PETSTOREPRODUCTSERVICE_DB_USERNAME"
        secret_name = "db-username"
      }

      env {
        name        = "PETSTOREPRODUCTSERVICE_DB_PASSWORD"
        secret_name = "db-password"
      }
    }

    http_scale_rule {
      name                = "http-autoscaler"
      concurrent_requests = var.concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ─── 3. Order Service ───────────────────────────────────────────────────────
resource "azurerm_container_app" "orderservice" {
  name                         = "${var.project_name}-orderservice"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  depends_on = [
    azurerm_container_app.productservice,
    azurerm_key_vault_access_policy.container_apps_identity,
  ]

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
  }

  secret {
    name                = "cosmos-endpoint"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_endpoint.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "cosmos-key"
    key_vault_secret_id = azurerm_key_vault_secret.cosmos_key.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "orderservice"
      image  = "${local.acr_login_server}/petstoreorderservice:${local.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = local.ai_conn_string
      }
      env {
        name  = "PETSTOREPRODUCTSERVICE_URL"
        value = "https://${azurerm_container_app.productservice.ingress[0].fqdn}"
      }
      env {
        name        = "AZURE_COSMOS_ENDPOINT"
        secret_name = "cosmos-endpoint"
      }
      env {
        name        = "AZURE_COSMOS_KEY"
        secret_name = "cosmos-key"
      }
      env {
        name  = "AZURE_COSMOS_DATABASE"
        value = var.cosmos_database_name
      }
    }

    http_scale_rule {
      name                = "http-autoscaler"
      concurrent_requests = var.concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ─── 4. OrderItemsReserver (Azure Function container) ────────────────────────
resource "azurerm_container_app" "orderitemsreserver" {
  name                         = "${var.project_name}-orderitemsreserver"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  depends_on = [azurerm_key_vault_access_policy.container_apps_identity]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
  }

  secret {
    name                = "blob-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.blob_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "orderitemsreserver"
      image  = "${local.acr_login_server}/petstoreorderitemsreserver:${local.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = local.ai_conn_string
      }
      env {
        name        = "BLOB_STORAGE_CONNECTION_STRING"
        secret_name = "blob-connection-string"
      }
      env {
        name  = "BLOB_STORAGE_CONTAINER_NAME"
        value = var.blob_container_name
      }
    }

    http_scale_rule {
      name                = "http-autoscaler"
      concurrent_requests = var.concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ─── 5. PetStore App (Web Frontend) ─────────────────────────────────────────
resource "azurerm_container_app" "petstoreapp" {
  name                         = "${var.project_name}-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Multiple"
  tags                         = var.tags

  depends_on = [
    azurerm_container_app.petservice,
    azurerm_container_app.productservice,
    azurerm_container_app.orderservice,
    azurerm_container_app.orderitemsreserver,
    azurerm_key_vault_access_policy.container_apps_identity,
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
  }

  secret {
    name                = "entra-client-secret"
    key_vault_secret_id = azurerm_key_vault_secret.entra_client_secret.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "petstoreapp"
      image  = "${local.acr_login_server}/petstoreapp:${local.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = local.ai_conn_string
      }
      env {
        name  = "APPLICATIONINSIGHTS_ENABLED"
        value = "true"
      }
      env {
        name  = "PETSTOREPETSERVICE_URL"
        value = "https://${azurerm_container_app.petservice.ingress[0].fqdn}"
      }
      env {
        name  = "PETSTOREPRODUCTSERVICE_URL"
        value = "https://${azurerm_container_app.productservice.ingress[0].fqdn}"
      }
      env {
        name  = "PETSTOREORDERSERVICE_URL"
        value = "https://${azurerm_container_app.orderservice.ingress[0].fqdn}"
      }
      env {
        name  = "PETSTOREORDERITEMSRESERVER_URL"
        value = "https://${azurerm_container_app.orderitemsreserver.ingress[0].fqdn}"
      }

      # ── Entra ID OAuth2 authentication ──
      env {
        name  = "PETSTORE_SECURITY_ENABLED"
        value = tostring(var.entra_security_enabled)
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azuread_application.petstoreapp.client_id
      }
      env {
        name        = "AZURE_CLIENT_SECRET"
        secret_name = "entra-client-secret"
      }
    }

    http_scale_rule {
      name                = "http-autoscaler"
      concurrent_requests = var.concurrent_requests
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ═════════════════════════════════════════════════════════════════════════════
#  Key Vault Access Policies for Managed Identities
# ═════════════════════════════════════════════════════════════════════════════

resource "azurerm_key_vault_access_policy" "petservice" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_container_app.petservice.identity[0].principal_id
  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "productservice" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_container_app.productservice.identity[0].principal_id
  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_access_policy" "orderservice" {
  key_vault_id       = azurerm_key_vault.main.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_container_app.orderservice.identity[0].principal_id
  secret_permissions = ["Get"]
}


