# ──────────────────────────────────────────────────────────────
# terraform.tfvars — fill in YOUR values
# ──────────────────────────────────────────────────────────────

subscription_id      = ""   # Run: az account show --query id -o tsv
resource_group_name  = "demo-rg"
location             = "southeastasia"
project_name         = "petstore"
acr_name             = "vodemopetstoreappcontainer"          # must be globally unique
storage_account_name = "vopetorderstorage"           # must be globally unique
blob_container_name  = "orderitemsreserver"
image_tag            = "latest"
min_replicas         = 1
max_replicas         = 5
concurrent_requests  = "10"

