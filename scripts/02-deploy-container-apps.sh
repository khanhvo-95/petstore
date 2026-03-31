#!/bin/bash
###############################################################################
# Step 3: Deploy Services to Azure Container Apps
#   - Create Container Apps Environment
#   - Deploy PetService, ProductService, OrderService, PetStoreApp
#   - Configure environment variables for inter-service communication
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
echo "  Location:        $LOCATION"
echo "  ACR Name:        $ACR_NAME"
echo "  Environment:     $ENVIRONMENT_NAME"
echo "  PostgreSQL:      $PG_SERVER_NAME ($PG_DATABASE_NAME)"
echo "  Apps:            $APP_NAME, $PET_SERVICE_NAME, $PRODUCT_SERVICE_NAME, $ORDER_SERVICE_NAME, $ORDER_ITEMS_RESERVER_NAME"
echo ""

# Validate PostgreSQL password is set (needed for Pet & Product service env vars)
if [ -z "$PG_ADMIN_PASSWORD" ]; then
  echo "ERROR: PG_ADMIN_PASSWORD must be set for Pet & Product service database access."
  echo "  export PG_ADMIN_PASSWORD='YourStr0ngP@ssword!'"
  exit 1
fi

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
echo "[1/7] Creating Container Apps Environment: $ENVIRONMENT_NAME..."
az containerapp env create \
  --name "$ENVIRONMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  -o none
echo "  ✅ Environment created."

# --- 3.2 Deploy PetService ---
echo ""
echo "[2/7] Deploying PetService: $PET_SERVICE_NAME..."
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
  --env-vars \
    "PETSTOREPETSERVICE_DB_URL=$PG_JDBC_URL" \
    "PETSTOREPETSERVICE_DB_USERNAME=$PG_ADMIN_USER" \
    "PETSTOREPETSERVICE_DB_PASSWORD=$PG_ADMIN_PASSWORD" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
  -o none
echo "  ✅ PetService deployed."

# --- 3.3 Deploy ProductService ---
echo ""
echo "[3/7] Deploying ProductService: $PRODUCT_SERVICE_NAME..."
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
  --env-vars \
    "PETSTOREPRODUCTSERVICE_DB_URL=$PG_JDBC_URL" \
    "PETSTOREPRODUCTSERVICE_DB_USERNAME=$PG_ADMIN_USER" \
    "PETSTOREPRODUCTSERVICE_DB_PASSWORD=$PG_ADMIN_PASSWORD" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
  -o none
echo "  ✅ ProductService deployed."

# --- 3.4 Deploy OrderService (depends on ProductService URL) ---
echo ""
echo "[4/7] Deploying OrderService: $ORDER_SERVICE_NAME..."
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
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
  -o none
echo "  ✅ OrderService deployed."

# --- 3.5 Deploy OrderItemsReserver (Azure Function as Container App) ---
echo ""
echo "[5/7] Deploying OrderItemsReserver: $ORDER_ITEMS_RESERVER_NAME..."

# Retrieve Storage Account connection string for Blob uploads
BLOB_CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query connectionString -o tsv)

az containerapp create \
  --name "$ORDER_ITEMS_RESERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/petstoreorderitemsreserver:$IMAGE_TAG" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --target-port 80 \
  --ingress external \
  --transport auto \
  --allow-insecure \
  --min-replicas "$MIN_REPLICAS" \
  --max-replicas "$MAX_REPLICAS" \
  --revision-suffix "$IMAGE_TAG" \
  --env-vars \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
    "BLOB_STORAGE_CONNECTION_STRING=$BLOB_CONNECTION_STRING" \
    "BLOB_STORAGE_CONTAINER_NAME=$BLOB_CONTAINER_NAME" \
  -o none
echo "  ✅ OrderItemsReserver deployed."

# --- 3.6 Retrieve all service URLs ---
echo ""
echo "[6/7] Retrieving service URLs..."
PET_FQDN=$(az containerapp show \
  --name "$PET_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
ORDER_FQDN=$(az containerapp show \
  --name "$ORDER_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
ORDER_ITEMS_RESERVER_FQDN=$(az containerapp show \
  --name "$ORDER_ITEMS_RESERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

PET_URL="https://$PET_FQDN"
ORDER_URL="https://$ORDER_FQDN"
ORDER_ITEMS_RESERVER_URL="https://$ORDER_ITEMS_RESERVER_FQDN"

echo "  PetService URL:             $PET_URL"
echo "  ProductService URL:         $PRODUCT_URL"
echo "  OrderService URL:           $ORDER_URL"
echo "  OrderItemsReserver URL:     $ORDER_ITEMS_RESERVER_URL"

# --- 3.7 Deploy PetStoreApp (Web) with env vars pointing to API services ---
echo ""
echo "[7/7] Deploying PetStoreApp: $APP_NAME..."
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
    "PETSTOREORDERITEMSRESERVER_URL=$ORDER_ITEMS_RESERVER_URL" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
    "APPLICATIONINSIGHTS_ENABLED=true" \
    "PETSTORE_SECURITY_ENABLED=$PETSTORE_SECURITY_ENABLED" \
    "AZURE_TENANT_ID=$AZURE_TENANT_ID" \
    "AZURE_CLIENT_ID=$AZURE_CLIENT_ID" \
    "AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET" \
    "OAUTH_REDIRECT_URI=https://$APP_NAME.$ENVIRONMENT_NAME.$LOCATION.azurecontainerapps.io/login/oauth2/code/azure" \
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
echo "  🌐 PetStoreApp:            https://$APP_FQDN"
echo "  🐾 PetService:             $PET_URL"
echo "  📦 ProductService:         $PRODUCT_URL"
echo "  🛒 OrderService:           $ORDER_URL"
echo "  📋 OrderItemsReserver:     $ORDER_ITEMS_RESERVER_URL"
echo ""
echo "Next: Run 03-configure-autoscaling.sh"
