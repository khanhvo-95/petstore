#!/bin/bash
###############################################################################
# Shared Configuration for all PetStore deployment scripts
# ──────────────────────────────────────────────────────────
# Edit the values below ONCE. Every script sources this file so changes
# propagate automatically to 01-setup, 02-deploy, 03-autoscale, 04-v2, 05-traffic.
###############################################################################

# ===================== AZURE RESOURCE NAMES ==================================
RESOURCE_GROUP="auto-demo-rg"
LOCATION="southeastasia"
ACR_NAME="voautodemopetstoreappcontainer"          # Must be globally unique, lowercase, alphanumeric only

# ===================== CONTAINER APPS ========================================
ENVIRONMENT_NAME="petstore-container-env"
APP_NAME="petstore-app"
PET_SERVICE_NAME="petstore-petservice"
PRODUCT_SERVICE_NAME="petstore-productservice"
ORDER_SERVICE_NAME="petstore-orderservice"

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
AI_CONNECTION_STRING="InstrumentationKey=60515101-cf69-427c-9fb6-a77a4b48a935;IngestionEndpoint=https://southeastasia-1.in.applicationinsights.azure.com/;LiveEndpoint=https://southeastasia.livediagnostics.monitor.azure.com/;ApplicationId=df3a0678-ee4f-47a5-899e-6876cecdcf08"

# ===================== REVISION / CANARY =====================================
OLD_TAG="v1"
NEW_TAG="v2"
CANARY_TRAFFIC_PERCENT=20   # New revision gets this %, old gets the rest

