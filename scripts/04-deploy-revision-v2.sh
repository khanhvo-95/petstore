#!/bin/bash
###############################################################################
# Step 5: Deploy Multiple Revisions (Canary / Blue-Green Deployment)
#   - Enable multi-revision mode for PetStoreApp
#   - Build and push v2 image to ACR
#   - Deploy v2 as a new revision
#   - Split traffic between v1 and v2 (canary)
#   - Optionally switch all traffic to v2 (blue/green)
###############################################################################
set -euo pipefail

# ===================== LOAD SHARED CONFIGURATION =============================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
# =============================================================================

# ===================== PRE-FLIGHT CHECKS =====================================
echo "============================================"
echo "  Pre-flight: Azure Account Info"
echo "============================================"
echo ""
echo "Subscription:    $(az account show --query name --output tsv)"
echo "Subscription ID: $(az account show --query id --output tsv)"
echo "User:            $(az account show --query user.name --output tsv)"
echo ""
echo "Target Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  ACR Name:        $ACR_NAME"
echo "  App:             $APP_NAME"
echo "  Old Tag:         $OLD_TAG"
echo "  New Tag:         $NEW_TAG"
echo "  Canary Traffic:  $CANARY_TRAFFIC_PERCENT%"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 1
fi
echo ""
# =============================================================================

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================"
echo "  Step 5: Deploy Multiple Revisions"
echo "============================================"

# --- 5.1 Enable multi-revision mode ---
echo ""
echo "[1/5] Enabling multi-revision mode for $APP_NAME..."
az containerapp revision set-mode \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --mode multiple \
  -o none
echo "  ✅ Multi-revision mode enabled."

# --- 5.2 Build and push v2 image ---
echo ""
echo "[2/5] Building and pushing petstoreapp:$NEW_TAG to ACR..."
az acr build \
  --registry "$ACR_NAME" \
  --image "petstoreapp:$NEW_TAG" \
  --file "$PROJECT_ROOT/petstoreapp/Dockerfile" \
  "$PROJECT_ROOT/petstoreapp"
echo "  ✅ petstoreapp:$NEW_TAG pushed to $ACR_LOGIN_SERVER"

# --- 5.3 Deploy v2 as a new revision ---
echo ""
echo "[3/5] Creating new revision ($NEW_TAG) for $APP_NAME..."

# Get the current container name
CONTAINER_NAME=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.template.containers[0].name" -o tsv)

az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --container-name "$CONTAINER_NAME" \
  --image "$ACR_LOGIN_SERVER/petstoreapp:$NEW_TAG" \
  --revision-suffix "$NEW_TAG" \
  -o none
echo "  ✅ Revision $NEW_TAG created."

# --- 5.4 Split traffic (canary deployment) ---
echo ""
echo "[4/5] Configuring canary traffic split..."

OLD_REVISION_NAME="${APP_NAME}--${OLD_TAG}"
NEW_REVISION_NAME="${APP_NAME}--${NEW_TAG}"
OLD_TRAFFIC_PERCENT=$((100 - CANARY_TRAFFIC_PERCENT))

az containerapp ingress traffic set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision-weight \
    "${OLD_REVISION_NAME}=${OLD_TRAFFIC_PERCENT}" \
    "${NEW_REVISION_NAME}=${CANARY_TRAFFIC_PERCENT}" \
  -o none
echo "  ✅ Traffic split: $OLD_TAG=$OLD_TRAFFIC_PERCENT%, $NEW_TAG=$CANARY_TRAFFIC_PERCENT%"

# --- 5.5 Show revision URLs for testing ---
echo ""
echo "[5/5] Retrieving revision URLs..."

APP_FQDN=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

# Revision-specific URLs follow the pattern: <app-name>--<suffix>.<env>.<region>.azurecontainerapps.io
OLD_REVISION_FQDN=$(az containerapp revision show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$OLD_REVISION_NAME" \
  --query "properties.fqdn" -o tsv 2>/dev/null || echo "N/A")
NEW_REVISION_FQDN=$(az containerapp revision show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$NEW_REVISION_NAME" \
  --query "properties.fqdn" -o tsv 2>/dev/null || echo "N/A")

echo ""
echo "============================================"
echo "  ✅ Step 5 (Canary) Complete!"
echo "============================================"
echo ""
echo "Application URL (load-balanced): https://$APP_FQDN"
echo "Revision URLs for direct testing:"
echo "  v1: https://$OLD_REVISION_FQDN"
echo "  v2: https://$NEW_REVISION_FQDN"
echo ""
echo "Current traffic split:"
echo "  $OLD_TAG: ${OLD_TRAFFIC_PERCENT}%"
echo "  $NEW_TAG: ${CANARY_TRAFFIC_PERCENT}%"
echo ""
echo "============================================"
echo "  To complete Blue/Green (switch all traffic to $NEW_TAG):"
echo "  Run: ./05-switch-traffic.sh"
echo "============================================"
