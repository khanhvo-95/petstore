#!/bin/bash
###############################################################################
# 07-setup-cosmosdb.sh
# ──────────────────────────────────────────────────────────
# Creates Azure Cosmos DB account, database, and container for Order Service.
# Sources shared config from config.sh.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ===================== COSMOS DB SETTINGS ====================================
COSMOS_ACCOUNT_NAME="${COSMOS_ACCOUNT_NAME:-petstore-cosmos-${RESOURCE_GROUP}}"
COSMOS_DATABASE_NAME="${COSMOS_DATABASE_NAME:-petstore}"
COSMOS_CONTAINER_NAME="${COSMOS_CONTAINER_NAME:-orders}"
COSMOS_PARTITION_KEY="/id"

echo "============================================================"
echo " Setting up Azure Cosmos DB for Order Service"
echo "============================================================"
echo " Resource Group:    $RESOURCE_GROUP"
echo " Location:          $LOCATION"
echo " Cosmos Account:    $COSMOS_ACCOUNT_NAME"
echo " Database:          $COSMOS_DATABASE_NAME"
echo " Container:         $COSMOS_CONTAINER_NAME"
echo " Partition Key:     $COSMOS_PARTITION_KEY"
echo "============================================================"

# 1. Create Cosmos DB Account (NoSQL API)
echo ""
echo ">>> [1/3] Creating Cosmos DB account (NoSQL API)..."
az cosmosdb create \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --kind GlobalDocumentDB \
  --default-consistency-level Session \
  --enable-free-tier false \
  --capabilities EnableServerless

echo "    Cosmos DB account '$COSMOS_ACCOUNT_NAME' created."

# 2. Create Database
echo ""
echo ">>> [2/3] Creating database '$COSMOS_DATABASE_NAME'..."
az cosmosdb sql database create \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$COSMOS_DATABASE_NAME"

echo "    Database '$COSMOS_DATABASE_NAME' created."

# 3. Create Container
echo ""
echo ">>> [3/3] Creating container '$COSMOS_CONTAINER_NAME'..."
az cosmosdb sql container create \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name "$COSMOS_DATABASE_NAME" \
  --name "$COSMOS_CONTAINER_NAME" \
  --partition-key-path "$COSMOS_PARTITION_KEY"

echo "    Container '$COSMOS_CONTAINER_NAME' created."

# 4. Retrieve connection info
echo ""
echo "============================================================"
echo " Retrieving connection details..."
echo "============================================================"

COSMOS_ENDPOINT=$(az cosmosdb show \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "documentEndpoint" -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "primaryMasterKey" -o tsv)

echo ""
echo "============================================================"
echo " Cosmos DB setup complete!"
echo "============================================================"
echo ""
echo " Set these environment variables for the Order Service:"
echo ""
echo "   AZURE_COSMOS_ENDPOINT=$COSMOS_ENDPOINT"
echo "   AZURE_COSMOS_KEY=$COSMOS_KEY"
echo "   AZURE_COSMOS_DATABASE=$COSMOS_DATABASE_NAME"
echo ""
echo " For Azure Container Apps, run:"
echo "   az containerapp update \\"
echo "     --name $ORDER_SERVICE_NAME \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --set-env-vars \\"
echo "       AZURE_COSMOS_ENDPOINT=$COSMOS_ENDPOINT \\"
echo "       AZURE_COSMOS_KEY=$COSMOS_KEY \\"
echo "       AZURE_COSMOS_DATABASE=$COSMOS_DATABASE_NAME"
echo "============================================================"
