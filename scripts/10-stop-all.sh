#!/bin/bash
###############################################################################
# 10-stop-all.sh — Stop all billable services in demo-rg to save costs
# ──────────────────────────────────────────────────────────
# Stops:
#   - All 5 Container Apps (via REST API since az containerapp stop is unavailable)
#   - PostgreSQL Flexible Server
#
# Resources NOT stopped (minimal/zero cost when idle):
#   - Cosmos DB (cannot be stopped; serverless/autoscale keeps cost low at 0 RU/s)
#   - Service Bus Standard (fixed ~$10/mo — cannot be stopped)
#   - Storage Account, Key Vault, ACR (minimal cost, no stop capability)
#   - Logic App (pay-per-run, no cost when idle)
#
# Usage:
#   chmod +x scripts/10-stop-all.sh
#   bash scripts/10-stop-all.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

API_VERSION="2024-03-01"

echo "============================================================"
echo " Stopping all PetStore services in '$RESOURCE_GROUP'"
echo " $(date)"
echo "============================================================"

# ─── Get subscription ID ────────────────────────────────────────────────────
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo ""
echo "Subscription: $SUBSCRIPTION_ID"

# ─── Stop Container Apps ────────────────────────────────────────────────────
CONTAINER_APPS=(
  "$APP_NAME"
  "$PET_SERVICE_NAME"
  "$PRODUCT_SERVICE_NAME"
  "$ORDER_SERVICE_NAME"
  "$ORDER_ITEMS_RESERVER_NAME"
)

echo ""
echo "── Stopping Container Apps ──────────────────────────────────"
for APP in "${CONTAINER_APPS[@]}"; do
  echo -n "  Stopping $APP ... "
  ERROR=$(az rest --method post \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/containerApps/${APP}/stop?api-version=${API_VERSION}" \
    -o none 2>&1) && echo "OK" || echo "FAILED: $ERROR"
done

# ─── Stop PostgreSQL Flexible Server ────────────────────────────────────────
PGSQL_SERVER="voautodemopetstoreappcontainer-pgserver"

echo ""
echo "── Stopping PostgreSQL Flexible Server ──────────────────────"
echo -n "  Stopping $PGSQL_SERVER ... "
ERROR=$(az postgres flexible-server stop \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PGSQL_SERVER" \
  -o none 2>&1) && echo "OK" || echo "FAILED: $ERROR"

# ─── Verify ─────────────────────────────────────────────────────────────────
echo ""
echo "── Verifying Container App status ───────────────────────────"
for APP in "${CONTAINER_APPS[@]}"; do
  STATUS=$(az containerapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP" \
    --query "properties.runningStatus" -o tsv 2>/dev/null || echo "Unknown")
  echo "  $APP: $STATUS"
done

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " All services stopped."
echo " To start them again, run: bash scripts/11-start-all.sh"
echo "============================================================"
echo ""
echo "NOTE: PostgreSQL auto-starts after 7 days if not manually"
echo "      started. Re-run this script if that happens."
