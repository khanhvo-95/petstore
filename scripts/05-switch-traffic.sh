#!/bin/bash
###############################################################################
# Step 5 (continued): Switch All Traffic to New Revision (Blue/Green)
#   - Route 100% traffic to v2
#   - Deactivate old v1 revision
###############################################################################
set -euo pipefail

# ===================== CONFIGURATION - EDIT THESE VALUES =====================
RESOURCE_GROUP="auto-demo-rg"
APP_NAME="petstore-app"
OLD_TAG="v1"
NEW_TAG="v2"
# =============================================================================

OLD_REVISION_NAME="${APP_NAME}--${OLD_TAG}"
NEW_REVISION_NAME="${APP_NAME}--${NEW_TAG}"

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
echo "  App:             $APP_NAME"
echo "  Switch traffic:  $OLD_TAG -> $NEW_TAG (100%)"
echo "  Deactivate:      $OLD_REVISION_NAME"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 1
fi
echo ""
# =============================================================================

echo "============================================"
echo "  Blue/Green: Switch All Traffic to $NEW_TAG"
echo "============================================"

# --- Route 100% traffic to new revision ---
echo ""
echo "[1/2] Routing 100% traffic to $NEW_TAG..."
az containerapp ingress traffic set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision-weight \
    "${NEW_REVISION_NAME}=100" \
  -o none
echo "  ✅ All traffic now goes to $NEW_TAG."

# --- Deactivate old revision ---
echo ""
echo "[2/2] Deactivating old revision ($OLD_TAG)..."
az containerapp revision deactivate \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --revision "$OLD_REVISION_NAME" \
  -o none
echo "  ✅ Revision $OLD_TAG deactivated."

APP_FQDN=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo ""
echo "============================================"
echo "  ✅ Blue/Green Deployment Complete!"
echo "============================================"
echo ""
echo "  🌐 PetStoreApp: https://$APP_FQDN"
echo "  Active revision: $NEW_TAG (100%)"
echo "  Old revision $OLD_TAG: deactivated"
echo ""
echo "  To rollback, reactivate $OLD_TAG and switch traffic back:"
echo "    az containerapp revision activate --name $APP_NAME -g $RESOURCE_GROUP --revision $OLD_REVISION_NAME"
echo "    az containerapp ingress traffic set --name $APP_NAME -g $RESOURCE_GROUP --revision-weight ${OLD_REVISION_NAME}=100"

