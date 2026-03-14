#!/bin/bash
###############################################################################
# Step 4: Configure Autoscaling for all Container Apps
#   - Set HTTP concurrent request scaling rules
#   - Configure min/max replicas
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
echo "  Resource Group:       $RESOURCE_GROUP"
echo "  Min/Max Replicas:     $MIN_REPLICAS / $MAX_REPLICAS"
echo "  Concurrent Requests:  $CONCURRENT_REQUESTS"
echo "  Apps:                 $APP_NAME, $PET_SERVICE_NAME, $PRODUCT_SERVICE_NAME, $ORDER_SERVICE_NAME"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 1
fi
echo ""
# =============================================================================

echo "============================================"
echo "  Step 4: Configure Autoscaling"
echo "============================================"

SERVICES=("$APP_NAME" "$PET_SERVICE_NAME" "$PRODUCT_SERVICE_NAME" "$ORDER_SERVICE_NAME")

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "--- Configuring autoscaling for: $SERVICE ---"

  # Update the container app with scale rules
  az containerapp update \
    --name "$SERVICE" \
    --resource-group "$RESOURCE_GROUP" \
    --min-replicas "$MIN_REPLICAS" \
    --max-replicas "$MAX_REPLICAS" \
    --scale-rule-name "$SCALE_RULE_NAME" \
    --scale-rule-type http \
    --scale-rule-http-concurrency "$CONCURRENT_REQUESTS" \
    -o none

  echo "  ✅ $SERVICE: autoscaling configured (min=$MIN_REPLICAS, max=$MAX_REPLICAS, concurrent=$CONCURRENT_REQUESTS)"
done

echo ""
echo "============================================"
echo "  ✅ Step 4 Complete!"
echo "============================================"
echo ""
echo "Autoscaling configured for all services:"
echo "  Min replicas:         $MIN_REPLICAS"
echo "  Max replicas:         $MAX_REPLICAS"
echo "  Concurrent requests:  $CONCURRENT_REQUESTS"
echo ""
echo "To test autoscaling, use the k6 load tests in k6-load-tests/"
echo "Example:"
echo "  k6 run k6-load-tests/gradual-rampup.js"
echo ""
echo "Next: Run 04-deploy-revision-v2.sh"
