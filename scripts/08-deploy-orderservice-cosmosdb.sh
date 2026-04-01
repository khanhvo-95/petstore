#!/bin/bash
###############################################################################
# 08-deploy-orderservice-cosmosdb.sh
# ──────────────────────────────────────────────────────────
# Rebuilds the Order Service image with Cosmos DB support,
# pushes to ACR (cloud build), and updates the Container App.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

PETSTORE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Use a unique tag per deployment to force Container Apps to pull the new image.
# Falls back to a timestamp if git is not available.
DEPLOY_TAG="${IMAGE_TAG}-$(git -C "$PETSTORE_ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"

echo "============================================================"
echo " Deploy Order Service with Cosmos DB"
echo "============================================================"
echo " Resource Group:    $RESOURCE_GROUP"
echo " ACR:               $ACR_NAME"
echo " Order Service:     $ORDER_SERVICE_NAME"
echo " Cosmos Account:    $COSMOS_ACCOUNT_NAME"
echo " Cosmos Database:   $COSMOS_DATABASE_NAME"
echo " Image Tag:         $DEPLOY_TAG"
echo "============================================================"
echo ""

# 1. Get ACR login server
echo ">>> [1/5] Getting ACR info..."
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
echo "    ACR: $ACR_LOGIN_SERVER"

# 2. Build image in the cloud using ACR Tasks (no local Docker needed)
echo ""
echo ">>> [2/5] Building petstoreorderservice image in ACR..."
az acr build \
  --registry "$ACR_NAME" \
  --image "petstoreorderservice:$DEPLOY_TAG" \
  "$PETSTORE_ROOT/petstoreorderservice"
echo "    Image built: $ACR_LOGIN_SERVER/petstoreorderservice:$DEPLOY_TAG"

# 3. Get Cosmos DB connection details
echo ""
echo ">>> [3/5] Retrieving Cosmos DB connection details..."
COSMOS_ENDPOINT=$(az cosmosdb show \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "documentEndpoint" -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "primaryMasterKey" -o tsv)

echo "    Cosmos Endpoint: $COSMOS_ENDPOINT"

# 4. Get Product Service URL
echo ""
echo ">>> [4/5] Retrieving Product Service URL..."
PRODUCT_FQDN=$(az containerapp show \
  --name "$PRODUCT_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
PRODUCT_URL="https://$PRODUCT_FQDN"
echo "    Product Service URL: $PRODUCT_URL"

# 5. Update the Order Service Container App
echo ""
echo ">>> [5/5] Updating Order Service Container App..."
az containerapp update \
  --name "$ORDER_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_LOGIN_SERVER/petstoreorderservice:$IMAGE_TAG" \
  --set-env-vars \
    "PETSTOREPRODUCTSERVICE_URL=$PRODUCT_URL" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
    "AZURE_COSMOS_ENDPOINT=$COSMOS_ENDPOINT" \
    "AZURE_COSMOS_KEY=$COSMOS_KEY" \
    "AZURE_COSMOS_DATABASE=$COSMOS_DATABASE_NAME" \
  -o none

echo ""
echo "============================================================"
echo " Order Service deployed with Cosmos DB!"
echo "============================================================"
ORDER_FQDN=$(az containerapp show \
  --name "$ORDER_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)
echo " Order Service URL: https://$ORDER_FQDN"
echo "============================================================"
