###############################################################################
# PetStore - Azure Infrastructure (Terraform)
# Provisions: ACR, Storage Account, Log Analytics, Application Insights,
#             Key Vault (with DB secrets), User-Assigned Managed Identity,
#             Container Apps Environment,
#             5 Container Apps (secrets pulled from Key Vault at runtime
#             via User-Assigned Managed Identity — no plaintext secrets
#             in Terraform state or environment variables),
#             Service Bus (namespace + queue with DLQ for order messaging),
#             Logic App (DLQ monitor with email notifications),
#             API Connections (Service Bus + Office 365 for Logic App)
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

# ─── Azure Service Bus (Order Messaging) ────────────────────────────────────
# Standard tier is required for DLQ (Dead-Letter Queue) support.
# PetStoreApp sends order messages → queue → OrderItemsReserver consumes them.
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.project_name}-servicebus"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "order_items" {
  name                                 = var.servicebus_queue_name
  namespace_id                         = azurerm_servicebus_namespace.main.id
  max_delivery_count                   = 3
  lock_duration                        = "PT1M"
  default_message_ttl                  = "P1D"
  dead_lettering_on_message_expiration = true
  requires_duplicate_detection         = false
  requires_session                     = false
  max_size_in_megabytes                = 1024
}

# Separate authorization rules for least-privilege access:
# - PetStoreApp only needs Send
# - OrderItemsReserver only needs Listen
resource "azurerm_servicebus_queue_authorization_rule" "send" {
  name     = "PetStoreAppSendPolicy"
  queue_id = azurerm_servicebus_queue.order_items.id
  send     = true
  listen   = false
  manage   = false
}

resource "azurerm_servicebus_queue_authorization_rule" "listen" {
  name     = "OrderItemsReserverListenPolicy"
  queue_id = azurerm_servicebus_queue.order_items.id
  send     = false
  listen   = true
  manage   = false
}

# Store Service Bus connection strings in Key Vault
resource "azurerm_key_vault_secret" "servicebus_send_connection_string" {
  name         = "servicebus-send-connection-string"
  value        = azurerm_servicebus_queue_authorization_rule.send.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "servicebus_listen_connection_string" {
  name         = "servicebus-listen-connection-string"
  value        = azurerm_servicebus_queue_authorization_rule.listen.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

# ─── Logic App (DLQ Monitoring — sends email on failed order processing) ────
# Monitors the Service Bus Dead-Letter Queue and sends an email notification
# to the manager when messages land in the DLQ (all 3 retries exhausted).
#
# NOTE: After `terraform apply`, you must manually authorize the API connections
# (Service Bus + Outlook.com) in the Azure Portal:
#   Portal → Logic App → API Connections → Authorize → Save
# API Connection: Service Bus (for Logic App to read from DLQ)
resource "azurerm_api_connection" "servicebus" {
  name                = "${var.project_name}-servicebus-connection"
  resource_group_name = data.azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/servicebus"
  display_name        = "PetStore Service Bus"

  parameter_values = {
    connectionString = azurerm_servicebus_namespace.main.default_primary_connection_string
  }

  tags = var.tags

  lifecycle {
    # Connection authorization state is managed in Azure Portal
    ignore_changes = [parameter_values]
  }
}

# API Connection: Outlook.com (for Logic App to send email)
# Uses the Outlook.com connector which supports personal @outlook.com/@hotmail.com accounts.
# The Office 365 Outlook connector (office365) requires a licensed M365/Exchange Online mailbox.
resource "azurerm_api_connection" "outlook" {
  name                = "${var.project_name}-outlook-connection"
  resource_group_name = data.azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/outlook"
  display_name        = "PetStore Outlook.com"

  tags = var.tags

  lifecycle {
    # OAuth authorization is completed manually in Azure Portal
    ignore_changes = [parameter_values]
  }
}

# Logic App Workflow: DLQ monitor with full workflow definition.
# Polls the Service Bus Dead-Letter Queue every 3 minutes. When a message
# is found, it parses the order JSON and sends an email notification to
# the manager with the order details for manual processing.
resource "azurerm_logic_app_workflow" "dlq_monitor" {
  name                = "${var.project_name}-dlq-monitor"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  tags                = var.tags

  workflow_parameters = {
    "$connections" = jsonencode({
      defaultValue = {}
      type         = "Object"
    })
  }

  parameters = {
    "$connections" = jsonencode({
      servicebus = {
        connectionId   = azurerm_api_connection.servicebus.id
        connectionName = azurerm_api_connection.servicebus.name
        id             = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/servicebus"
      }
      outlook = {
        connectionId   = azurerm_api_connection.outlook.id
        connectionName = azurerm_api_connection.outlook.name
        id             = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/outlook"
      }
    })
  }

  depends_on = [
    azurerm_api_connection.servicebus,
    azurerm_api_connection.outlook,
  ]
}

# Trigger: Poll the Service Bus DLQ for dead-lettered messages every 3 minutes
# Uses peek-lock mode so we can explicitly complete the message after processing.
# Operation ID: GetNewMessageFromQueueWithPeekLock (queueType=DeadLetter)
resource "azurerm_logic_app_trigger_custom" "dlq_trigger" {
  name         = "When_a_message_is_received_in_DLQ_(peek-lock)"
  logic_app_id = azurerm_logic_app_workflow.dlq_monitor.id

  body = jsonencode({
    type = "ApiConnection"
    recurrence = {
      frequency = "Minute"
      interval  = 3
    }
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['servicebus']['connectionId']"
        }
      }
      method = "get"
      path   = "/@{encodeURIComponent(encodeURIComponent('${var.servicebus_queue_name}'))}/messages/head/peek"
      queries = {
        queueType = "DeadLetter"
      }
    }
  })
}

# Action: Parse the Service Bus message body as JSON (the order payload)
resource "azurerm_logic_app_action_custom" "parse_order" {
  name         = "Parse_Order_JSON"
  logic_app_id = azurerm_logic_app_workflow.dlq_monitor.id

  body = jsonencode({
    type     = "ParseJson"
    runAfter = {}
    inputs = {
      content = "@base64ToString(triggerBody()?['ContentData'])"
      schema = {
        type = "object"
        properties = {
          id = {
            type = "string"
          }
          email = {
            type = "string"
          }
          status = {
            type = "string"
          }
          complete = {
            type = "boolean"
          }
          products = {
            type = "array"
            items = {
              type = "object"
              properties = {
                id       = { type = "integer" }
                name     = { type = "string" }
                quantity = { type = "integer" }
                photoURL = { type = "string" }
              }
            }
          }
        }
      }
    }
  })
}

# Action: Send email notification to the manager with the failed order details
resource "azurerm_logic_app_action_custom" "send_email" {
  name         = "Send_Manager_Email"
  logic_app_id = azurerm_logic_app_workflow.dlq_monitor.id

  depends_on = [azurerm_logic_app_action_custom.parse_order]

  body = jsonencode({
    type = "ApiConnection"
    runAfter = {
      Parse_Order_JSON = ["Succeeded"]
    }
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['outlook']['connectionId']"
        }
      }
      method = "post"
      path   = "/v2/Mail"
      body = {
        To         = var.manager_email
        Subject    = "PetStore Alert: Failed Order Upload - Order @{body('Parse_Order_JSON')?['id']}"
        Body       = "<h2>Failed Order Upload Notification</h2><p>An order failed to upload to Blob Storage after <strong>3 retry attempts</strong> and has been moved to the Service Bus Dead-Letter Queue.</p><hr/><h3>Order Details</h3><table border='1' cellpadding='8' cellspacing='0' style='border-collapse:collapse;'><tr><th>Field</th><th>Value</th></tr><tr><td><strong>Order ID (Session)</strong></td><td>@{body('Parse_Order_JSON')?['id']}</td></tr><tr><td><strong>Customer Email</strong></td><td>@{coalesce(body('Parse_Order_JSON')?['email'], 'N/A')}</td></tr><tr><td><strong>Status</strong></td><td>@{coalesce(body('Parse_Order_JSON')?['status'], 'N/A')}</td></tr><tr><td><strong>Dead-Letter Reason</strong></td><td>@{triggerBody()?['Properties']?['DeadLetterReason']}</td></tr><tr><td><strong>Dead-Letter Description</strong></td><td>@{triggerBody()?['Properties']?['DeadLetterErrorDescription']}</td></tr><tr><td><strong>Enqueue Time (UTC)</strong></td><td>@{triggerBody()?['Properties']?['EnqueuedTimeUtc']}</td></tr></table><h3>Products in Order</h3><p>@{body('Parse_Order_JSON')?['products']}</p><hr/><p><strong>Action Required:</strong> Please process this order manually. The order data is available in the Service Bus Dead-Letter Queue for replay or manual investigation.</p><p><em>Queue: ${var.servicebus_queue_name} | Service Bus: ${var.project_name}-servicebus</em></p>"
        Importance = "High"
      }
    }
  })
}

# Action: Complete (remove) the dead-letter message after sending the email
# Operation ID: CompleteMessageInQueue (queueType=DeadLetter)
resource "azurerm_logic_app_action_custom" "complete_dlq_message" {
  name         = "Complete_DLQ_Message"
  logic_app_id = azurerm_logic_app_workflow.dlq_monitor.id

  depends_on = [azurerm_logic_app_action_custom.send_email]

  body = jsonencode({
    type = "ApiConnection"
    runAfter = {
      Send_Manager_Email = ["Succeeded"]
    }
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['servicebus']['connectionId']"
        }
      }
      method = "delete"
      path   = "/@{encodeURIComponent(encodeURIComponent('${var.servicebus_queue_name}'))}/messages/complete"
      queries = {
        lockToken = "@triggerBody()?['LockToken']"
        queueType = "DeadLetter"
        sessionId = ""
      }
    }
  })
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

  depends_on = [
    azurerm_key_vault_access_policy.container_apps_identity,
    azurerm_servicebus_queue.order_items,
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
    name                = "blob-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.blob_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name                = "servicebus-listen-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.servicebus_listen_connection_string.versionless_id
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
      env {
        name        = "SERVICEBUS_CONNECTION_STRING"
        secret_name = "servicebus-listen-connection-string"
      }
      env {
        name  = "SERVICEBUS_QUEUE_NAME"
        value = var.servicebus_queue_name
      }
      env {
        name        = "AzureWebJobsStorage"
        secret_name = "blob-connection-string"
      }
      env {
        name  = "FUNCTIONS_WORKER_RUNTIME"
        value = "java"
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
    azurerm_servicebus_queue.order_items,
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

  secret {
    name                = "servicebus-send-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.servicebus_send_connection_string.versionless_id
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

      # ── Azure Service Bus (order messaging) ──
      env {
        name        = "SERVICEBUS_CONNECTION_STRING"
        secret_name = "servicebus-send-connection-string"
      }
      env {
        name  = "SERVICEBUS_QUEUE_NAME"
        value = var.servicebus_queue_name
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


