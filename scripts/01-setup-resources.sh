#!/bin/bash
###############################################################################
# Step 1 & 2: Set Up Azure Resources (Resource Group + ACR) and
#             Build & Push Docker Images to ACR
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
echo "Current Azure CLI account:"
az account show --output table
echo ""
echo "Subscription ID: $(az account show --query id --output tsv)"
echo "Subscription:    $(az account show --query name --output tsv)"
echo "Tenant ID:       $(az account show --query tenantId --output tsv)"
echo "User:            $(az account show --query user.name --output tsv)"
echo ""
echo "Target Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location:       $LOCATION"
echo "  ACR Name:       $ACR_NAME"
echo "  Image Tag:      $IMAGE_TAG"
echo ""
read -p "Proceed with the above subscription and settings? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted. Use 'az account set --subscription <id>' to switch subscription."
  exit 1
fi
echo ""
# =============================================================================

echo "============================================"
echo "  Step 1: Create Azure Resources"
echo "============================================"

# Create Resource Group
echo "[1/3] Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
echo "  ✅ Resource Group created."

# Create Azure Container Registry
echo "[2/3] Creating Azure Container Registry: $ACR_NAME..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true \
  --output none
echo "  ✅ ACR created."

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
echo "  ACR Login Server: $ACR_LOGIN_SERVER"

echo ""
echo "============================================"
echo "  Step 2: Build & Push Docker Images to ACR"
echo "============================================"

# Log in to ACR
echo "[3/3] Logging in to ACR..."
az acr login --name "$ACR_NAME"

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build and push each service using `az acr build` (cloud-side build, no local Docker needed)
SERVICES=("petstoreapp" "petstorepetservice" "petstoreproductservice" "petstoreorderservice")

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "--- Building and pushing $SERVICE:$IMAGE_TAG ---"
  az acr build \
    --registry "$ACR_NAME" \
    --image "$SERVICE:$IMAGE_TAG" \
    --file "$PROJECT_ROOT/$SERVICE/Dockerfile" \
    "$PROJECT_ROOT/$SERVICE"
  echo "  ✅ $SERVICE:$IMAGE_TAG pushed to $ACR_LOGIN_SERVER"
done

echo ""
echo "============================================"
echo "  ✅ Steps 1 & 2 Complete!"
echo "============================================"
echo ""
echo "Resources created:"
echo "  - Resource Group: $RESOURCE_GROUP"
echo "  - ACR:            $ACR_LOGIN_SERVER"
echo "  - Images pushed:  ${SERVICES[*]} (tag: $IMAGE_TAG)"
echo ""
echo "Next: Run 02-deploy-container-apps.sh"
