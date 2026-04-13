###############################################################################
# Outputs
###############################################################################

output "resource_group_name" {
  value = data.azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "storage_account_name" {
  value = azurerm_storage_account.orders.name
}

output "appinsights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

# ─── Key Vault outputs ──────────────────────────────────────────────────────

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "secret_uri_pgsql_url" {
  value = azurerm_key_vault_secret.pgsql_url.versionless_id
}

output "secret_uri_pgsql_username" {
  value = azurerm_key_vault_secret.pgsql_username.versionless_id
}

output "secret_uri_pgsql_password" {
  value     = azurerm_key_vault_secret.pgsql_password.versionless_id
  sensitive = true
}

output "secret_uri_cosmos_endpoint" {
  value = azurerm_key_vault_secret.cosmos_endpoint.versionless_id
}

output "secret_uri_cosmos_key" {
  value     = azurerm_key_vault_secret.cosmos_key.versionless_id
  sensitive = true
}

# ─── Managed identity principal IDs ─────────────────────────────────────────

output "user_assigned_identity_id" {
  description = "Resource ID of the shared User-Assigned Managed Identity (used for Key Vault access)"
  value       = azurerm_user_assigned_identity.container_apps.id
}

output "user_assigned_identity_principal_id" {
  description = "Principal ID of the shared User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_apps.principal_id
}

output "petservice_identity_principal_id" {
  value = azurerm_container_app.petservice.identity[0].principal_id
}

output "productservice_identity_principal_id" {
  value = azurerm_container_app.productservice.identity[0].principal_id
}

output "orderservice_identity_principal_id" {
  value = azurerm_container_app.orderservice.identity[0].principal_id
}

# ─── App URLs ───────────────────────────────────────────────────────────────

output "petstoreapp_url" {
  value = "https://${azurerm_container_app.petstoreapp.ingress[0].fqdn}"
}

output "petservice_url" {
  value = "https://${azurerm_container_app.petservice.ingress[0].fqdn}"
}

output "productservice_url" {
  value = "https://${azurerm_container_app.productservice.ingress[0].fqdn}"
}

output "orderservice_url" {
  value = "https://${azurerm_container_app.orderservice.ingress[0].fqdn}"
}

output "orderitemsreserver_url" {
  value = "https://${azurerm_container_app.orderitemsreserver.ingress[0].fqdn}"
}

# ─── Entra ID ───────────────────────────────────────────────────────────────

output "entra_app_client_id" {
  description = "Entra ID app registration client ID (managed by Terraform)"
  value       = azuread_application.petstoreapp.client_id
}

output "entra_app_display_name" {
  value = azuread_application.petstoreapp.display_name
}

# ─── Service Bus ────────────────────────────────────────────────────────────

output "servicebus_namespace" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.main.name
}

output "servicebus_queue_name" {
  description = "Service Bus queue name for order messages"
  value       = azurerm_servicebus_queue.order_items.name
}

output "servicebus_send_connection_string" {
  description = "Service Bus connection string with Send-only permission (for PetStoreApp)"
  value       = azurerm_servicebus_queue_authorization_rule.send.primary_connection_string
  sensitive   = true
}

output "servicebus_listen_connection_string" {
  description = "Service Bus connection string with Listen-only permission (for OrderItemsReserver)"
  value       = azurerm_servicebus_queue_authorization_rule.listen.primary_connection_string
  sensitive   = true
}

# ─── Logic App (DLQ Monitor) ───────────────────────────────────────────────

output "logic_app_name" {
  description = "Logic App name for DLQ monitoring"
  value       = azurerm_logic_app_workflow.dlq_monitor.name
}

