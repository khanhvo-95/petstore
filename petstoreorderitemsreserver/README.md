# PetStore OrderItemsReserver - Azure Function

An Azure Functions service that handles order item reservation for the PetStore application. Built with Java 21 and deployed as a Docker container to Azure Container Apps (or Azure Functions with container deployment).

## Overview

The **OrderItemsReserver** function receives an order and reserves the items, validating product availability and quantities. It returns a detailed reservation result.

## Endpoints

| Method | Route                | Auth Level | Description                    |
|--------|----------------------|------------|--------------------------------|
| POST   | `/api/order/reserve` | Function   | Reserve items from an order    |
| GET    | `/api/health`        | Anonymous  | Health check                   |
| GET    | `/api/info`          | Anonymous  | Service information            |

## Request/Response

### POST `/api/order/reserve`

**Request Body:**
```json
{
  "id": "68FAE9B1D86B794F0AE0ADD35A437428",
  "email": "customer@example.com",
  "products": [
    { "id": 1, "name": "Ball", "quantity": 2 },
    { "id": 5, "name": "Leash", "quantity": 1 }
  ]
}
```

**Response (200 OK):**
```json
{
  "reservationId": "550e8400-e29b-41d4-a716-446655440000",
  "orderId": "68FAE9B1D86B794F0AE0ADD35A437428",
  "status": "confirmed",
  "reservedItems": [
    { "productId": 1, "productName": "Ball", "quantity": 2 },
    { "productId": 5, "productName": "Leash", "quantity": 1 }
  ],
  "failedItems": [],
  "timestamp": "2026-03-22T10:30:00+08:00",
  "message": "All items reserved successfully"
}
```

## Build & Run Locally

### Prerequisites
- Java 21
- Maven 3.9+
- Azure Functions Core Tools v4

### Build
```bash
cd petstoreorderitemsreserver
mvn clean package
```

### Run locally with Azure Functions Core Tools
```bash
mvn azure-functions:run
```

### Build Docker image
```bash
docker build -t petstoreorderitemsreserver:v1 .
```

### Run Docker container
```bash
docker run -p 8085:80 \
  -e APPLICATIONINSIGHTS_CONNECTION_STRING="<your-connection-string>" \
  petstoreorderitemsreserver:v1
```

## Deploy to Azure

### 1. Create a Storage Account (for Blob uploads)
```bash
az storage account create \
  --name <your-storage-name> \
  --resource-group <your-rg> \
  --location southeastasia \
  --sku Standard_LRS

# Get connection string
az storage account show-connection-string \
  --name <your-storage-name> \
  --resource-group <your-rg> \
  --query connectionString -o tsv

# Create blob container
az storage container create \
  --name orderitemsreserver \
  --connection-string "<connection-string>"
```

### 2. Build and push Docker image to ACR
```bash
# Login to ACR
az acr login -n <your-acr-name>

# Build & push
docker build -t <your-acr>.azurecr.io/petstoreorderitemsreserver:v1 .
docker push <your-acr>.azurecr.io/petstoreorderitemsreserver:v1

# OR use ACR build:
az acr build --registry <your-acr> --image petstoreorderitemsreserver:v1 .
```

### 3. Deploy as Azure Container App
```bash
az containerapp create \
  --name petstore-orderitemsreserver \
  --resource-group <your-rg> \
  --environment <your-env> \
  --image <your-acr>.azurecr.io/petstoreorderitemsreserver:v1 \
  --registry-server <your-acr>.azurecr.io \
  --registry-username <acr-username> \
  --registry-password <acr-password> \
  --target-port 80 \
  --ingress external \
  --env-vars \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=<your-ai-connection-string>" \
    "BLOB_STORAGE_CONNECTION_STRING=<your-storage-connection-string>" \
    "BLOB_STORAGE_CONTAINER_NAME=orderitemsreserver"
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | No | App Insights connection string |
| `BLOB_STORAGE_CONNECTION_STRING` | Yes* | Azure Storage account connection string |
| `BLOB_STORAGE_ENDPOINT` | Yes* | Storage account endpoint (alternative to connection string, uses Managed Identity) |
| `BLOB_STORAGE_CONTAINER_NAME` | No | Blob container name (default: `orderitemsreserver`) |

*One of `BLOB_STORAGE_CONNECTION_STRING` or `BLOB_STORAGE_ENDPOINT` is required for blob uploads.

## Blob Storage Output

When an order is reserved, the function uploads a JSON file to Blob Storage:

**Path pattern:** `orders/{orderId}/{timestamp}-reservation.json`

**Example blob content:**
```json
{
  "order": {
    "id": "68FAE9B1D86B794F0AE0ADD35A437428",
    "products": [
      { "id": 1, "name": "Ball", "quantity": 2 }
    ]
  },
  "reservation": {
    "reservationId": "550e8400-e29b-41d4-a716-446655440000",
    "orderId": "68FAE9B1D86B794F0AE0ADD35A437428",
    "status": "confirmed",
    "reservedItems": [
      { "productId": 1, "productName": "Ball", "quantity": 2 }
    ],
    "failedItems": [],
    "timestamp": "2026-03-22T10:30:00+08:00",
    "message": "All items reserved successfully"
  }
}
```

## Project Structure

```
petstoreorderitemsreserver/
├── Dockerfile
├── pom.xml
├── README.md
└── src/
    └── main/
        ├── java/com/chtrembl/petstore/orderitemsreserver/
        │   ├── OrderItemsReserverFunction.java    # Azure Function handlers
        │   ├── model/
        │   │   ├── Order.java                     # Order model
        │   │   ├── Product.java                   # Product model
        │   │   └── ReservationResult.java         # Reservation response model
        │   └── service/
        │       └── BlobStorageService.java        # Azure Blob Storage upload
        └── resources/
            ├── applicationinsights.json
            ├── host.json
            ├── local.settings.json
            └── version.json
```

