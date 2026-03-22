#!/bin/bash
###############################################################################
# Shared Configuration for all PetStore deployment scripts
# ──────────────────────────────────────────────────────────
# Edit the values below ONCE. Every script sources this file so changes
# propagate automatically to 01-setup, 02-deploy, 03-autoscale, 04-v2, 05-traffic.
###############################################################################

# ===================== AZURE RESOURCE NAMES ==================================
RESOURCE_GROUP="demo-rg"
LOCATION="southeastasia"
ACR_NAME="voautodemopetstoreappcontainer"          # Must be globally unique, lowercase, alphanumeric only

# ===================== CONTAINER APPS ========================================
ENVIRONMENT_NAME="petstore-container-env"
APP_NAME="petstore-app"
PET_SERVICE_NAME="petstore-petservice"
PRODUCT_SERVICE_NAME="petstore-productservice"
ORDER_SERVICE_NAME="petstore-orderservice"
ORDER_ITEMS_RESERVER_NAME="petstore-orderitemsreserver"

# ===================== IMAGE TAGS ============================================
IMAGE_TAG="v1"

# ===================== AUTOSCALING ===========================================
MIN_REPLICAS=1
MAX_REPLICAS=5
CONCURRENT_REQUESTS=10    # HTTP concurrent requests to trigger scaling
SCALE_RULE_NAME="http-autoscaler"

# ===================== APPLICATION INSIGHTS ==================================
# Paste your Application Insights connection string here (from Azure Portal →
# Application Insights → Settings → Properties → Connection String).
# This is passed as an environment variable to every Container App.
AI_CONNECTION_STRING="InstrumentationKey=aa74e670-d8b5-4722-affb-40bab90974f2;IngestionEndpoint=https://southeastasia-1.in.applicationinsights.azure.com/;LiveEndpoint=https://southeastasia.livediagnostics.monitor.azure.com/;ApplicationId=fd7bc746-922e-441b-9ab0-5d0d06bb0579"

# ===================== BLOB STORAGE (OrderItemsReserver) =====================
# Storage account name for the OrderItemsReserver to upload order JSON files.
# The script will create the storage account and retrieve its connection string.
STORAGE_ACCOUNT_NAME="vopetorderstorage"       # Must be globally unique, lowercase, 3-24 chars
BLOB_CONTAINER_NAME="orderitemsreserver"

# ===================== ENTRA ID (Authentication) =============================
# Enable login/logout via Microsoft Entra ID OAuth2
PETSTORE_SECURITY_ENABLED="true"
AZURE_TENANT_ID="${AZURE_TENANT_ID:-}"            # Set via: export AZURE_TENANT_ID="your-tenant-id"
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"            # Set via: export AZURE_CLIENT_ID="your-client-id"
AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"    # Set via: export AZURE_CLIENT_SECRET="your-client-secret"

# ===================== REVISION / CANARY =====================================
OLD_TAG="v1"
NEW_TAG="v2"
CANARY_TRAFFIC_PERCENT=20   # New revision gets this %, old gets the rest

