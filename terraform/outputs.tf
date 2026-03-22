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

