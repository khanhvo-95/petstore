# PetStore — Terraform Deployment Guide (Azure Container Apps)

> **This project uses Azure Container Apps (serverless).** AKS is not used.
> A Helm chart is included in `helm/` for reference only — skip it unless you migrate to AKS.

---

## Project Structure

```
petstore/
├── terraform/                     # ✅ Azure infra provisioning (USE THIS)
│   ├── main.tf                    # All Azure resources + 5 Container Apps
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output URLs
│   └── terraform.tfvars           # ← Edit this with YOUR values
│
├── helm/petstore/                 # ⚠️ Optional: only for AKS (NOT used here)
│   └── ...
```

---

## What Terraform Provisions

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all resources |
| Azure Container Registry (ACR) | Docker image store |
| Storage Account + Blob Container | OrderItemsReserver JSON uploads |
| Log Analytics Workspace | Container logs |
| Application Insights | APM / telemetry |
| Container Apps Environment | Serverless hosting environment |
| `petstore-petservice` | Pet API service (port 8080) |
| `petstore-productservice` | Product API service (port 8080) |
| `petstore-orderservice` | Order API service (port 8080) |
| `petstore-orderitemsreserver` | Azure Function — reserves items + uploads to Blob (port 80) |
| `petstore-app` | PetStore web frontend (port 8080) |

All inter-service URLs, App Insights connection strings, Blob Storage credentials, and
autoscaling rules are **wired automatically** by Terraform.

---

## Step-by-Step Deployment

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed (`terraform -v`)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed (`az -v`)
- Logged in: `az login`

### Step 1 — Set Subscription

```bash
az login
az account set --subscription "06fea321-1582-4bd7-bf0c-53376f2620a6"
az account show --output table   # verify correct subscription
```

### Step 2 — Edit `terraform.tfvars`

Open `petstore/terraform/terraform.tfvars` and set your values:

```hcl
subscription_id      = "06fea321-1582-4bd7-bf0c-53376f2660a6"
resource_group_name  = "petstore-rg"
location             = "southeastasia"
project_name         = "petstore"
acr_name             = "vodemopetstoreacr"       # ← must be globally unique
storage_account_name = "vopetorderstorage"        # ← must be globally unique
blob_container_name  = "orderitemsreserver"
image_tag            = "v1"
min_replicas         = 1
max_replicas         = 5
concurrent_requests  = "10"
```

> ⚠️ `acr_name` and `storage_account_name` **must be globally unique** across all of Azure.
> If you get a "name already taken" error, change them.

### Step 3 — Build & Push Docker Images to ACR

Terraform deploys Container Apps that **reference images in ACR**, so images must exist first.

```bash
cd petstore

# Create ACR first (Terraform will adopt it, or you can let Terraform create it and
# build images after — but this chicken-and-egg is easiest solved by creating ACR first)
ACR_NAME="vodemopetstoreacr"    # must match terraform.tfvars

az group create --name petstore-rg --location southeastasia
az acr create --name $ACR_NAME --resource-group petstore-rg \
  --sku Basic --admin-enabled true --location southeastasia

# Build all 5 images in the cloud (no local Docker needed)
for svc in petstoreapp petstorepetservice petstoreproductservice petstoreorderservice petstoreorderitemsreserver; do
  echo "=== Building $svc ==="
  az acr build --registry $ACR_NAME --image "$svc:v1" --file "$svc/Dockerfile" "$svc"
done
```

Verify images exist:
```bash
az acr repository list --name $ACR_NAME --output table
```

Expected output:
```
Result
--------------------------
petstoreapp
petstoreorderitemsreserver
petstoreorderservice
petstorepetservice
petstoreproductservice
```

### Step 4 — Terraform Init + Plan

```bash
cd terraform
terraform init       # downloads Azure provider
terraform plan       # preview what will be created (no changes yet)
```

Review the plan — you should see ~12 resources to create.

### Step 5 — Terraform Apply

```bash
terraform apply
```

Type `yes` when prompted. This takes **3-5 minutes** and creates everything.

### Step 6 — Get Output URLs

```bash
terraform output
```

Output:
```
acr_login_server            = "vodemopetstoreacr.azurecr.io"
orderitemsreserver_url      = "https://petstore-orderitemsreserver.xxx.southeastasia.azurecontainerapps.io"
orderservice_url            = "https://petstore-orderservice.xxx.southeastasia.azurecontainerapps.io"
petservice_url              = "https://petstore-petservice.xxx.southeastasia.azurecontainerapps.io"
petstoreapp_url             = "https://petstore-app.xxx.southeastasia.azurecontainerapps.io"
productservice_url          = "https://petstore-productservice.xxx.southeastasia.azurecontainerapps.io"
resource_group_name         = "petstore-rg"
storage_account_name        = "vopetorderstorage"
```

### Step 7 — Verify

```bash
# PetStoreApp — open in browser
echo "Open: $(terraform output -raw petstoreapp_url)"

# OrderItemsReserver health check
curl $(terraform output -raw orderitemsreserver_url)/api/health

# Test reservation + blob upload
curl -X POST "$(terraform output -raw orderitemsreserver_url)/api/order/reserve" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "TEST1234567890ABCDEF1234567890AB",
    "products": [{"id": 1, "name": "Ball", "quantity": 2}]
  }'

# Check blob was uploaded
BLOB_CONN=$(az storage account show-connection-string \
  --name vopetorderstorage --resource-group petstore-rg -o tsv)
az storage blob list --container-name orderitemsreserver \
  --connection-string "$BLOB_CONN" --output table
```

---

## Common Operations

### Update an image (e.g., new code for petstoreapp)
```bash
# Rebuild image with new tag
az acr build --registry vodemopetstoreacr --image petstoreapp:v2 \
  --file petstoreapp/Dockerfile petstoreapp

# Update Terraform variable and re-apply
# Edit terraform.tfvars: image_tag = "v2"
terraform apply
```

### Scale a specific service
Edit `terraform.tfvars`:
```hcl
min_replicas = 2
max_replicas = 10
```
Then `terraform apply`.

### Tear down everything
```bash
terraform destroy    # type "yes" — removes ALL resources
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `terraform apply` fails with "name already taken" | Change `acr_name` or `storage_account_name` in `terraform.tfvars` — they must be globally unique |
| Container App shows "Provisioning Failed" | Images must exist in ACR before Terraform deploys. Run Step 3 first |
| `az acr build` fails with auth error | Run `az login` first, then `az account set --subscription ...` |
| OrderItemsReserver returns 404 | The base path is `/api/order/reserve` (not `/order/reserve`) |
| Blob upload not happening | Check env vars: `az containerapp show --name petstore-orderitemsreserver --resource-group petstore-rg --query "properties.template.containers[0].env"` |
| App Insights not showing data | Wait 2-3 minutes after first request. Check `APPLICATIONINSIGHTS_CONNECTION_STRING` env var |

---

## Architecture

```
                        ┌─────────────────────────────────────────────────┐
                        │      Azure Container Apps Environment           │
                        │                                                 │
 Browser ──────────────►│  petstore-app (Web)                             │
                        │    ├── → petstore-petservice                    │
                        │    ├── → petstore-productservice                │
                        │    ├── → petstore-orderservice                  │
                        │    │       └── → petstore-productservice        │
                        │    └── → petstore-orderitemsreserver            │
                        │              │                                  │
                        └──────────────┼──────────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  Azure Blob      │
                              │  Storage         │
                              │  /orders/{id}/   │
                              │   *.json         │
                              └─────────────────┘

 All provisioned by Terraform:
   • Resource Group         • Log Analytics
   • Container Registry     • Application Insights
   • Storage Account        • Container Apps Environment + 5 Apps
```

---

## Note on Helm Chart (AKS)

The `helm/petstore/` directory contains a Helm chart for deploying to Azure Kubernetes
Service (AKS). **This project does NOT use AKS** — it uses Azure Container Apps.

The Helm chart is provided as reference only, in case you ever want to migrate to AKS.
To use it you would need: an AKS cluster, kubectl, Helm 3, and an NGINX Ingress Controller.
See the `helm/petstore/values.yaml` for configuration details.
