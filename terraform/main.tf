###############################################################################
# PetStore - Azure Infrastructure (Terraform)
# Provisions: ACR, Storage Account, Log Analytics,
#             Application Insights, Container Apps Environment, 5 Container Apps
# Note: Resource Group must already exist (managed outside Terraform)
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ─── Resource Group (already exists — read-only reference) ───────────────────
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
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
  blob_conn_string = azurerm_storage_account.orders.primary_connection_string
  image_tag        = var.image_tag
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

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
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

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
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

  depends_on = [azurerm_container_app.productservice]

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
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
    name  = "blob-connection-string"
    value = local.blob_conn_string
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
  ]

  registry {
    server               = local.acr_login_server
    username             = local.acr_admin_user
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = local.acr_admin_pass
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

