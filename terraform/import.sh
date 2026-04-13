#!/bin/bash
###############################################################################
# terraform/import.sh — Safely import existing Azure resources into Terraform
#
# Run this ONCE after a fresh "terraform init" when no state file exists but
# resources may already exist in Azure.
#
# Each import is attempted individually — if a resource doesn't exist yet,
# the error is caught and skipped. Resources that don't exist will be
# created normally by "terraform apply".
#
# Usage:
#   cd terraform
#   bash import.sh
#   terraform plan
#   terraform apply
###############################################################################

set -euo pipefail

# ─── Read values from the current Azure CLI session ─────────────────────────
SUB=$(az account show --query id -o tsv)
echo "Using subscription: $SUB"

# ─── Configuration (must match terraform.tfvars) ────────────────────────────
RG="demo-rg"
PROJECT="petstore"
ACR_NAME="vodemopetstoreappcontainer"
STORAGE_NAME="vopetstore2storage"
BLOB_CONTAINER="orderitemsreserver"

# ─── Helper: attempt import, skip if resource doesn't exist ─────────────────
try_import() {
  local resource="$1"
  local id="$2"
  echo ""
  echo "─── Importing: $resource"
  if terraform import "$resource" "$id" 2>&1; then
    echo "    ✓ Imported successfully"
  else
    echo "    ✗ Skipped (resource does not exist yet — will be created by terraform apply)"
  fi
}

# ─── Ensure terraform is initialized ────────────────────────────────────────
if [ ! -d ".terraform" ]; then
  echo "Running terraform init..."
  terraform init
fi

# ═════════════════════════════════════════════════════════════════════════════
#  Import each resource
# ═════════════════════════════════════════════════════════════════════════════

# Container Registry
try_import "azurerm_container_registry.acr" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"

# Storage Account
try_import "azurerm_storage_account.orders" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${STORAGE_NAME}"

# Storage Container (uses blob URL format)
try_import "azurerm_storage_container.orderitemsreserver" \
  "https://${STORAGE_NAME}.blob.core.windows.net/${BLOB_CONTAINER}"

# Log Analytics Workspace
try_import "azurerm_log_analytics_workspace.main" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.OperationalInsights/workspaces/${PROJECT}-logs"

# Application Insights
try_import "azurerm_application_insights.main" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.Insights/components/${PROJECT}-appinsights"

# Key Vault
try_import "azurerm_key_vault.main" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.KeyVault/vaults/${PROJECT}-kv"

# Key Vault Secrets
try_import "azurerm_key_vault_secret.pgsql_url" \
  "https://${PROJECT}-kv.vault.azure.net/secrets/pgsql-url"

try_import "azurerm_key_vault_secret.pgsql_username" \
  "https://${PROJECT}-kv.vault.azure.net/secrets/pgsql-username"

try_import "azurerm_key_vault_secret.pgsql_password" \
  "https://${PROJECT}-kv.vault.azure.net/secrets/pgsql-password"

try_import "azurerm_key_vault_secret.cosmos_endpoint" \
  "https://${PROJECT}-kv.vault.azure.net/secrets/cosmos-endpoint"

try_import "azurerm_key_vault_secret.cosmos_key" \
  "https://${PROJECT}-kv.vault.azure.net/secrets/cosmos-key"

# Container Apps Environment
try_import "azurerm_container_app_environment.main" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/managedEnvironments/${PROJECT}-env"

# Container Apps
try_import "azurerm_container_app.petservice" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps/${PROJECT}-petservice"

try_import "azurerm_container_app.productservice" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps/${PROJECT}-productservice"

try_import "azurerm_container_app.orderservice" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps/${PROJECT}-orderservice"

try_import "azurerm_container_app.orderitemsreserver" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps/${PROJECT}-orderitemsreserver"

try_import "azurerm_container_app.petstoreapp" \
  "/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/containerApps/${PROJECT}-app"

# Key Vault Access Policies (require principal IDs from container apps)
echo ""
echo "─── Importing Key Vault access policies (require managed identity principal IDs)..."

PET_OID=$(az containerapp show -n "${PROJECT}-petservice" -g "${RG}" --query identity.principalId -o tsv 2>/dev/null || echo "")
PROD_OID=$(az containerapp show -n "${PROJECT}-productservice" -g "${RG}" --query identity.principalId -o tsv 2>/dev/null || echo "")
ORDER_OID=$(az containerapp show -n "${PROJECT}-orderservice" -g "${RG}" --query identity.principalId -o tsv 2>/dev/null || echo "")

KV_ID="/subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.KeyVault/vaults/${PROJECT}-kv"

if [ -n "$PET_OID" ]; then
  try_import "azurerm_key_vault_access_policy.petservice" "${KV_ID}/objectId/${PET_OID}"
else
  echo "    ✗ Skipped petservice access policy (container app not found)"
fi

if [ -n "$PROD_OID" ]; then
  try_import "azurerm_key_vault_access_policy.productservice" "${KV_ID}/objectId/${PROD_OID}"
else
  echo "    ✗ Skipped productservice access policy (container app not found)"
fi

if [ -n "$ORDER_OID" ]; then
  try_import "azurerm_key_vault_access_policy.orderservice" "${KV_ID}/objectId/${ORDER_OID}"
else
  echo "    ✗ Skipped orderservice access policy (container app not found)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "  Import complete. Now run:"
echo "    terraform plan"
echo "    terraform apply"
echo "═══════════════════════════════════════════════════════════════════════"
