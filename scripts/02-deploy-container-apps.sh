#!/bin/bash
###############################################################################
# Step 3: Deploy Services to Azure Container Apps
#   - Create Container Apps Environment
#   - Deploy PetService, ProductService, OrderService, PetStoreApp
#   - Configure environment variables for inter-service communication
###############################################################################
set -euo pipefail

# ===================== CONFIGURATION - EDIT THESE VALUES =====================
RESOURCE_GROUP="auto-demo-rg"
LOCATION="southeastasia"
ACR_NAME="voautodemopetstoreappcontainer"
IMAGE_TAG="v1"
APP_NAME="petstore-app"
PET_SERVICE_NAME="petstore-petservice"
PRODUCT_SERVICE_NAME="petstore-productservice"
ORDER_SERVICE_NAME="petstore-orderservice"
ENVIRONMENT_NAME="petstore-container-env"
MIN_REPLICAS=1
MAX_REPLICAS=5
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
echo "  Location:        $LOCATION"
echo "  ACR Name:        $ACR_NAME"
echo "  Environment:     $ENVIRONMENT_NAME"
echo "  Apps:            $APP_NAME, $PET_SERVICE_NAME, $PRODUCT_SERVICE_NAME, $ORDER_SERVICE_NAME"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted."
  exit 1
fi
echo ""
# =============================================================================

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

echo "============================================"
echo "  Step 3: Deploy Services to Container Apps"
echo "============================================"

# --- 3.1 Create Container Apps Environment ---
echo ""
echo "[1/6] Creating Container Apps Environment: $ENVIRONMENT_NAME..."
az containerapp env create \
  --name "$ENVIRONMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  -o none
echo "  ✅ Environment created."

# --- 3.2 Deploy PetService ---
echo ""
echo "[2/6] Deploying PetService: $PET_SERVICE_NAME..."
az containerapp create \
  --name "$PET_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/petstorepetservice:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 8080 \
  --ingress external \
  --transport auto \
  --allow-insecure \
  --min-replicas "$MIN_REPLICAS" \
  --max-replicas "$MAX_REPLICAS" \
  --revision-suffix "$IMAGE_TAG" \
  -o none
echo "  ✅ PetService deployed."

# --- 3.3 Deploy ProductService ---
echo ""
echo "[3/6] Deploying ProductService: $PRODUCT_SERVICE_NAME..."
az containerapp create \
  --name "$PRODUCT_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/petstoreproductservice:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 8080 \
  --ingress external \
  --transport auto \
  --allow-insecure \
  --min-replicas "$MIN_REPLICAS" \
  --max-replicas "$MAX_REPLICAS" \
  --revision-suffix "$IMAGE_TAG" \
  -o none
echo "  ✅ ProductService deployed."

# --- 3.4 Deploy OrderService (depends on ProductService URL) ---
echo ""
echo "[4/6] Deploying OrderService: $ORDER_SERVICE_NAME..."
PRODUCT_FQDN=$(az containerapp show \
  --name "$PRODUCT_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
PRODUCT_URL="https://$PRODUCT_FQDN"

az containerapp create \
  --name "$ORDER_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/petstoreorderservice:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 8080 \
  --ingress external \
  --transport auto \
  --allow-insecure \
  --min-replicas "$MIN_REPLICAS" \
  --max-replicas "$MAX_REPLICAS" \
  --revision-suffix "$IMAGE_TAG" \
  --env-vars "PETSTOREPRODUCTSERVICE_URL=$PRODUCT_URL" \
  -o none
echo "  ✅ OrderService deployed."

# --- 3.5 Retrieve all service URLs ---
echo ""
echo "[5/6] Retrieving service URLs..."
PET_FQDN=$(az containerapp show \
  --name "$PET_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
ORDER_FQDN=$(az containerapp show \
  --name "$ORDER_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

PET_URL="https://$PET_FQDN"
ORDER_URL="https://$ORDER_FQDN"

echo "  PetService URL:     $PET_URL"
echo "  ProductService URL: $PRODUCT_URL"
echo "  OrderService URL:   $ORDER_URL"

# --- 3.6 Deploy PetStoreApp (Web) with env vars pointing to API services ---
echo ""
echo "[6/6] Deploying PetStoreApp: $APP_NAME..."
az containerapp create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/petstoreapp:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 8080 \
  --ingress external \
  --transport auto \
  --allow-insecure \
  --min-replicas "$MIN_REPLICAS" \
  --max-replicas "$MAX_REPLICAS" \
  --revision-suffix "$IMAGE_TAG" \
  --env-vars \
    "PETSTOREPETSERVICE_URL=$PET_URL" \
    "PETSTOREPRODUCTSERVICE_URL=$PRODUCT_URL" \
    "PETSTOREORDERSERVICE_URL=$ORDER_URL" \
  -o none
echo "  ✅ PetStoreApp deployed."

# --- Print summary ---
APP_FQDN=$(az containerapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo ""
echo "============================================"
echo "  ✅ Step 3 Complete!"
echo "============================================"
echo ""
echo "Service URLs:"
echo "  🌐 PetStoreApp:      https://$APP_FQDN"
echo "  🐾 PetService:       $PET_URL"
echo "  📦 ProductService:   $PRODUCT_URL"
echo "  🛒 OrderService:     $ORDER_URL"
echo ""
echo "Next: Run 03-configure-autoscaling.sh"

