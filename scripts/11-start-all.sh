#!/bin/bash
###############################################################################
# 11-start-all.sh — Start all PetStore services in demo-rg
# ──────────────────────────────────────────────────────────
# Starts:
#   - PostgreSQL Flexible Server (started FIRST — services depend on it)
#   - All 5 Container Apps (via REST API)
#
# Usage:
#   chmod +x scripts/11-start-all.sh
#   bash scripts/11-start-all.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

API_VERSION="2024-03-01"

echo "============================================================"
echo " Starting all PetStore services in '$RESOURCE_GROUP'"
echo " $(date)"
echo "============================================================"

# ─── Get subscription ID ────────────────────────────────────────────────────
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo ""
echo "Subscription: $SUBSCRIPTION_ID"

# ─── Start PostgreSQL Flexible Server FIRST (services depend on it) ─────────
PGSQL_SERVER="voautodemopetstoreappcontainer-pgserver"

echo ""
echo "── Starting PostgreSQL Flexible Server ──────────────────────"
echo -n "  Starting $PGSQL_SERVER ... "
ERROR=$(az postgres flexible-server start \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PGSQL_SERVER" \
  -o none 2>&1) && echo "OK" || echo "FAILED: $ERROR"

echo "  Waiting 30s for PostgreSQL to become ready..."
sleep 30

# ─── Start Container Apps ───────────────────────────────────────────────────
CONTAINER_APPS=(
  "$PET_SERVICE_NAME"
  "$PRODUCT_SERVICE_NAME"
  "$ORDER_SERVICE_NAME"
  "$ORDER_ITEMS_RESERVER_NAME"
  "$APP_NAME"
)

echo ""
echo "── Starting Container Apps ──────────────────────────────────"
for APP in "${CONTAINER_APPS[@]}"; do
  echo -n "  Starting $APP ... "
  ERROR=$(az rest --method post \
    --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/containerApps/${APP}/start?api-version=${API_VERSION}" \
    -o none 2>&1) && echo "OK" || echo "FAILED: $ERROR"
done

# ─── Wait and verify ────────────────────────────────────────────────────────
echo ""
echo "── Verifying Container App status ───────────────────────────"
echo "  Waiting 30s for services to start..."
sleep 30

ALL_APPS=("$APP_NAME" "$PET_SERVICE_NAME" "$PRODUCT_SERVICE_NAME" "$ORDER_SERVICE_NAME" "$ORDER_ITEMS_RESERVER_NAME")
for APP in "${ALL_APPS[@]}"; do
  STATUS=$(az containerapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP" \
    --query "properties.runningStatus" -o tsv 2>/dev/null || echo "Unknown")
  echo "  $APP: $STATUS"
done

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " All services started."
echo ""
echo " PetStore App: https://${APP_NAME}.nicebush-3fecf9b5.southeastasia.azurecontainerapps.io"
echo "============================================================"
