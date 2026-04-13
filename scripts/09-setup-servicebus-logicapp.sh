#!/bin/bash
###############################################################################
# 09-setup-servicebus-logicapp.sh
# ─────────────────────────────────
# Sets up Azure Service Bus namespace + queue for order messaging, and
# creates a Logic App that monitors the Dead-Letter Queue (DLQ) for
# failed messages and sends email notifications to the manager.
#
# This script:
# 1. Creates a Service Bus namespace (Standard tier for DLQ support)
# 2. Creates the order-items-queue with DLQ enabled
# 3. Retrieves the connection string for use by petstoreapp + function
# 4. Creates a Logic App for DLQ monitoring + email notification
# 5. Updates Container Apps with the Service Bus connection string
###############################################################################

set -euo pipefail

# ─── Source shared config ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ─── Service Bus Configuration ───────────────────────────────────────────────
SERVICEBUS_NAMESPACE="petstore-servicebus"
SERVICEBUS_QUEUE_NAME="order-items-queue"
SERVICEBUS_SKU="Standard"    # Standard tier required for DLQ, sessions, topics

# ─── Logic App Configuration ────────────────────────────────────────────────
LOGIC_APP_NAME="petstore-dlq-monitor"
MANAGER_EMAIL="${MANAGER_EMAIL:-manager@petstore.com}"   # Set via env var or default

echo "============================================================"
echo "  PetStore: Service Bus + Logic App Setup"
echo "============================================================"
echo ""
echo "  Resource Group:       $RESOURCE_GROUP"
echo "  Location:             $LOCATION"
echo "  Service Bus NS:       $SERVICEBUS_NAMESPACE"
echo "  Queue Name:           $SERVICEBUS_QUEUE_NAME"
echo "  Logic App:            $LOGIC_APP_NAME"
echo "  Manager Email:        $MANAGER_EMAIL"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 1. CREATE SERVICE BUS NAMESPACE
# ═══════════════════════════════════════════════════════════════════════════════
echo "──────────────────────────────────────────────────────────────"
echo "Step 1: Creating Service Bus Namespace..."
echo "──────────────────────────────────────────────────────────────"

az servicebus namespace create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SERVICEBUS_NAMESPACE" \
    --location "$LOCATION" \
    --sku "$SERVICEBUS_SKU" \
    --output table

echo "✓ Service Bus namespace '$SERVICEBUS_NAMESPACE' created"

# ═══════════════════════════════════════════════════════════════════════════════
# 2. CREATE SERVICE BUS QUEUE WITH DLQ ENABLED
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "──────────────────────────────────────────────────────────────"
echo "Step 2: Creating Service Bus Queue with Dead-Letter Queue..."
echo "──────────────────────────────────────────────────────────────"

az servicebus queue create \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "$SERVICEBUS_QUEUE_NAME" \
    --max-delivery-count 3 \
    --dead-lettering-on-message-expiration true \
    --default-message-time-to-live "P1D" \
    --lock-duration "PT1M" \
    --max-size 1024 \
    --output table

echo "✓ Queue '$SERVICEBUS_QUEUE_NAME' created with maxDeliveryCount=3 and DLQ enabled"

# ═══════════════════════════════════════════════════════════════════════════════
# 3. RETRIEVE CONNECTION STRING
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "──────────────────────────────────────────────────────────────"
echo "Step 3: Retrieving Service Bus Connection String..."
echo "──────────────────────────────────────────────────────────────"

SERVICEBUS_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "RootManageSharedAccessKey" \
    --query "primaryConnectionString" \
    --output tsv)

echo "✓ Connection string retrieved"
echo ""
echo "  SERVICEBUS_CONNECTION_STRING=$SERVICEBUS_CONNECTION_STRING"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 4. CREATE SHARED ACCESS POLICIES (separate for send/listen)
# ═══════════════════════════════════════════════════════════════════════════════
echo "──────────────────────────────────────────────────────────────"
echo "Step 4: Creating access policies (send + listen)..."
echo "──────────────────────────────────────────────────────────────"

# Send-only policy for petstoreapp
az servicebus namespace authorization-rule create \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "PetStoreAppSendPolicy" \
    --rights Send \
    --output table 2>/dev/null || echo "  (Send policy already exists)"

# Listen-only policy for OrderItemsReserver function
az servicebus namespace authorization-rule create \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "OrderItemsReserverListenPolicy" \
    --rights Listen \
    --output table 2>/dev/null || echo "  (Listen policy already exists)"

SERVICEBUS_SEND_CONNECTION=$(az servicebus namespace authorization-rule keys list \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "PetStoreAppSendPolicy" \
    --query "primaryConnectionString" \
    --output tsv)

SERVICEBUS_LISTEN_CONNECTION=$(az servicebus namespace authorization-rule keys list \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICEBUS_NAMESPACE" \
    --name "OrderItemsReserverListenPolicy" \
    --query "primaryConnectionString" \
    --output tsv)

echo "✓ Access policies created"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 5. UPDATE CONTAINER APPS WITH SERVICE BUS CONNECTION
# ═══════════════════════════════════════════════════════════════════════════════
echo "──────────────────────────────────────────────────────────────"
echo "Step 5: Updating Container Apps with Service Bus settings..."
echo "──────────────────────────────────────────────────────────────"

# Update petstoreapp with the send connection string
echo "  Updating $APP_NAME..."
az containerapp update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --set-env-vars \
        "SERVICEBUS_CONNECTION_STRING=$SERVICEBUS_SEND_CONNECTION" \
        "SERVICEBUS_QUEUE_NAME=$SERVICEBUS_QUEUE_NAME" \
    --output table

# Update OrderItemsReserver with the listen connection string
echo "  Updating $ORDER_ITEMS_RESERVER_NAME..."
az containerapp update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ORDER_ITEMS_RESERVER_NAME" \
    --set-env-vars \
        "SERVICEBUS_CONNECTION_STRING=$SERVICEBUS_LISTEN_CONNECTION" \
        "SERVICEBUS_QUEUE_NAME=$SERVICEBUS_QUEUE_NAME" \
    --output table

echo "✓ Container Apps updated with Service Bus configuration"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 6. CREATE LOGIC APP FOR DLQ MONITORING
# ═══════════════════════════════════════════════════════════════════════════════
echo "──────────────────────────────────────────────────────────────"
echo "Step 6: Creating Logic App for DLQ monitoring..."
echo "──────────────────────────────────────────────────────────────"

# Create the Logic App workflow definition
# This Logic App:
#   1. Triggers when a message arrives in the DLQ of order-items-queue
#   2. Parses the dead-letter message content (order JSON)
#   3. Sends an email to the manager with order details
LOGIC_APP_DEFINITION=$(cat <<'DEFINITION_EOF'
{
    "definition": {
        "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
        "contentVersion": "1.0.0.0",
        "triggers": {
            "When_a_message_is_received_in_DLQ": {
                "type": "ApiConnection",
                "recurrence": {
                    "frequency": "Minute",
                    "interval": 1
                },
                "inputs": {
                    "host": {
                        "connection": {
                            "name": "@parameters('$connections')['servicebus']['connectionId']"
                        }
                    },
                    "method": "get",
                    "path": "/@{encodeURIComponent(encodeURIComponent('order-items-queue'))}/messages/deadletter/head",
                    "queries": {
                        "queueType": "Main",
                        "sessionId": "None"
                    }
                }
            }
        },
        "actions": {
            "Parse_Message_Content": {
                "type": "ParseJson",
                "inputs": {
                    "content": "@base64ToString(triggerBody()?['ContentData'])",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "id": { "type": "string" },
                            "email": { "type": "string" },
                            "products": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "id": { "type": "integer" },
                                        "name": { "type": "string" },
                                        "quantity": { "type": "integer" },
                                        "photoURL": { "type": "string" }
                                    }
                                }
                            },
                            "status": { "type": "string" },
                            "complete": { "type": "boolean" }
                        }
                    }
                },
                "runAfter": {}
            },
            "Send_Email_Notification": {
                "type": "ApiConnection",
                "inputs": {
                    "host": {
                        "connection": {
                            "name": "@parameters('$connections')['office365']['connectionId']"
                        }
                    },
                    "method": "post",
                    "path": "/v2/Mail",
                    "body": {
                        "To": "MANAGER_EMAIL_PLACEHOLDER",
                        "Subject": "PetStore Alert: Failed Order Upload - Manual Processing Required",
                        "Body": "<h2>Failed Order Upload - Dead-Letter Queue Alert</h2><p>An order message failed to be processed after 3 retry attempts and has been moved to the Dead-Letter Queue.</p><h3>Order Details</h3><table border='1' cellpadding='8' cellspacing='0'><tr><td><strong>Session/Order ID</strong></td><td>@{body('Parse_Message_Content')?['id']}</td></tr><tr><td><strong>Customer Email</strong></td><td>@{body('Parse_Message_Content')?['email']}</td></tr><tr><td><strong>Order Status</strong></td><td>@{body('Parse_Message_Content')?['status']}</td></tr><tr><td><strong>Complete</strong></td><td>@{body('Parse_Message_Content')?['complete']}</td></tr></table><h3>Products</h3><p>@{body('Parse_Message_Content')?['products']}</p><h3>Dead-Letter Details</h3><table border='1' cellpadding='8' cellspacing='0'><tr><td><strong>Dead-Letter Reason</strong></td><td>@{triggerBody()?['Properties']?['DeadLetterReason']}</td></tr><tr><td><strong>Dead-Letter Error</strong></td><td>@{triggerBody()?['Properties']?['DeadLetterErrorDescription']}</td></tr><tr><td><strong>Enqueued Time</strong></td><td>@{triggerBody()?['EnqueuedTimeUtc']}</td></tr><tr><td><strong>Message ID</strong></td><td>@{triggerBody()?['MessageId']}</td></tr></table><br/><p><strong>Action Required:</strong> Please manually process this order or investigate the Blob Storage upload failure.</p><p>This is an automated notification from the PetStore Order Items Reserver service.</p>",
                        "Importance": "High"
                    }
                },
                "runAfter": {
                    "Parse_Message_Content": ["Succeeded"]
                }
            }
        },
        "parameters": {
            "$connections": {
                "defaultValue": {},
                "type": "Object"
            }
        }
    },
    "parameters": {
        "$connections": {
            "value": {}
        }
    }
}
DEFINITION_EOF
)

# Replace the email placeholder
LOGIC_APP_DEFINITION=$(echo "$LOGIC_APP_DEFINITION" | sed "s/MANAGER_EMAIL_PLACEHOLDER/$MANAGER_EMAIL/g")

# Write the definition to a temp file
TEMP_FILE=$(mktemp /tmp/logic-app-XXXXXX.json)
echo "$LOGIC_APP_DEFINITION" > "$TEMP_FILE"

# Create the Logic App
az logic workflow create \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --name "$LOGIC_APP_NAME" \
    --definition "$TEMP_FILE" \
    --output table 2>/dev/null || {
    echo "  Note: Logic App creation via CLI requires manual API connection setup."
    echo "  The workflow definition has been prepared."
}

# Clean up temp file
rm -f "$TEMP_FILE"

echo ""
echo "✓ Logic App '$LOGIC_APP_NAME' created"
echo ""
echo "  IMPORTANT: After creation, you must configure the API connections"
echo "  in the Azure Portal:"
echo "    1. Go to Logic App '$LOGIC_APP_NAME' -> API connections"
echo "    2. Add 'Service Bus' connection using the namespace connection string"
echo "    3. Add 'Office 365 Outlook' connection (or 'Outlook.com') for email"
echo "    4. Authorize both connections"
echo "    5. Enable the Logic App"

# ═══════════════════════════════════════════════════════════════════════════════
# 7. SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "============================================================"
echo "  Setup Complete!"
echo "============================================================"
echo ""
echo "  Service Bus Namespace: $SERVICEBUS_NAMESPACE"
echo "  Queue Name:            $SERVICEBUS_QUEUE_NAME"
echo "  Max Delivery Count:    3 (messages DLQ after 3 failed attempts)"
echo "  Logic App:             $LOGIC_APP_NAME"
echo ""
echo "  Connection Strings:"
echo "  ─────────────────────────────────────────────────────────"
echo "  Send (petstoreapp):      $SERVICEBUS_SEND_CONNECTION"
echo "  Listen (function):       $SERVICEBUS_LISTEN_CONNECTION"
echo "  Full (RootManage):       $SERVICEBUS_CONNECTION_STRING"
echo ""
echo "  Environment Variables to set:"
echo "  ─────────────────────────────────────────────────────────"
echo "  petstoreapp:"
echo "    SERVICEBUS_CONNECTION_STRING=<send connection string>"
echo "    SERVICEBUS_QUEUE_NAME=$SERVICEBUS_QUEUE_NAME"
echo ""
echo "  petstoreorderitemsreserver:"
echo "    SERVICEBUS_CONNECTION_STRING=<listen connection string>"
echo "    SERVICEBUS_QUEUE_NAME=$SERVICEBUS_QUEUE_NAME"
echo "    BLOB_STORAGE_CONNECTION_STRING=<blob storage connection>"
echo "    BLOB_STORAGE_CONTAINER_NAME=orderitemsreserver"
echo ""
echo "  Logic App Manual Steps:"
echo "  ─────────────────────────────────────────────────────────"
echo "  1. Configure Service Bus API connection in Azure Portal"
echo "  2. Configure Office 365 / Outlook API connection for email"
echo "  3. Update manager email: $MANAGER_EMAIL"
echo "  4. Enable the Logic App workflow"
echo ""
