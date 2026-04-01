#!/bin/bash
# =======================================================
# Azure CLI Script: Create Azure Database for PostgreSQL
# and configure it for PetStore Pet & Product Services
# =======================================================
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Bash shell
#
# Usage:
#   chmod +x scripts/06-setup-postgresql.sh
#   ./scripts/06-setup-postgresql.sh
# =======================================================

set -euo pipefail

# -------------------------------------------------------
# Configuration - override via environment variables
# -------------------------------------------------------
RESOURCE_GROUP="${RESOURCE_GROUP:-petstore-rg}"
LOCATION="${LOCATION:-eastus}"
PG_SERVER_NAME="${PG_SERVER_NAME:-petstore-pgserver}"
PG_ADMIN_USER="${PG_ADMIN_USER:-petstoreAdmin}"
PG_ADMIN_PASSWORD="${PG_ADMIN_PASSWORD:-}"    # must be set externally
PG_DATABASE_NAME="${PG_DATABASE_NAME:-petstore}"
PG_SKU="${PG_SKU:-Standard_B1ms}"
PG_TIER="${PG_TIER:-Burstable}"
PG_VERSION="${PG_VERSION:-16}"
PG_STORAGE_SIZE="${PG_STORAGE_SIZE:-32}"       # GiB

# -------------------------------------------------------
# Validate required inputs
# -------------------------------------------------------
if [ -z "$PG_ADMIN_PASSWORD" ]; then
  echo "ERROR: PG_ADMIN_PASSWORD must be set."
  echo "  export PG_ADMIN_PASSWORD='YourStr0ngP@ssword!'"
  exit 1
fi

echo "============================================="
echo " Creating Azure Database for PostgreSQL"
echo "============================================="
echo " Resource Group : $RESOURCE_GROUP"
echo " Location       : $LOCATION"
echo " Server Name    : $PG_SERVER_NAME"
echo " Database       : $PG_DATABASE_NAME"
echo " SKU            : $PG_SKU ($PG_TIER)"
echo " PG Version     : $PG_VERSION"
echo "============================================="

# -------------------------------------------------------
# 1. Create Resource Group (idempotent)
# -------------------------------------------------------
echo "[1/6] Creating resource group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# -------------------------------------------------------
# 2. Create PostgreSQL Flexible Server
# -------------------------------------------------------
echo "[2/6] Creating PostgreSQL Flexible Server..."
az postgres flexible-server create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PG_SERVER_NAME" \
  --location "$LOCATION" \
  --admin-user "$PG_ADMIN_USER" \
  --admin-password "$PG_ADMIN_PASSWORD" \
  --sku-name "$PG_SKU" \
  --tier "$PG_TIER" \
  --version "$PG_VERSION" \
  --storage-size "$PG_STORAGE_SIZE" \
  --public-access 0.0.0.0 \
  --yes \
  --output none

echo "  PostgreSQL server '$PG_SERVER_NAME' created."

# -------------------------------------------------------
# 3. Create the petstore database
# -------------------------------------------------------
echo "[3/6] Creating database '$PG_DATABASE_NAME'..."
az postgres flexible-server db create \
  --resource-group "$RESOURCE_GROUP" \
  --server-name "$PG_SERVER_NAME" \
  --database-name "$PG_DATABASE_NAME" \
  --output none

echo "  Database '$PG_DATABASE_NAME' created."

# -------------------------------------------------------
# 4. Add firewall rule for current client IP
# -------------------------------------------------------
echo "[4/6] Adding firewall rule for current client IP..."
MY_IP=$(curl -s https://api.ipify.org)
az postgres flexible-server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PG_SERVER_NAME" \
  --rule-name "AllowMyIP" \
  --start-ip-address "$MY_IP" \
  --end-ip-address "$MY_IP" \
  --output none

echo "  Firewall rule added for IP: $MY_IP"

# -------------------------------------------------------
# 5. Run DDL and DML scripts
# -------------------------------------------------------
PG_HOST="${PG_SERVER_NAME}.postgres.database.azure.com"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[5/6] Running DDL and DML scripts..."

for sql_file in \
  "$SCRIPT_DIR/sql/01-ddl-petservice.sql" \
  "$SCRIPT_DIR/sql/02-ddl-productservice.sql" \
  "$SCRIPT_DIR/sql/03-dml-petservice.sql" \
  "$SCRIPT_DIR/sql/04-dml-productservice.sql"; do

  echo "  Executing: $(basename "$sql_file")"
  PGPASSWORD="$PG_ADMIN_PASSWORD" psql \
    -h "$PG_HOST" \
    -U "$PG_ADMIN_USER" \
    -d "$PG_DATABASE_NAME" \
    -f "$sql_file" \
    --set=sslmode=require \
    -q
done

echo "  All SQL scripts executed."

# -------------------------------------------------------
# 6. Print connection info
# -------------------------------------------------------
JDBC_URL="jdbc:postgresql://${PG_HOST}:5432/${PG_DATABASE_NAME}?sslmode=require"

echo ""
echo "============================================="
echo " PostgreSQL Setup Complete!"
echo "============================================="
echo ""
echo "Connection details:"
echo "  Host     : $PG_HOST"
echo "  Port     : 5432"
echo "  Database : $PG_DATABASE_NAME"
echo "  Username : $PG_ADMIN_USER"
echo "  JDBC URL : $JDBC_URL"
echo ""
echo "Set these environment variables in Azure App Service"
echo "or .env file for local Docker Compose:"
echo ""
echo "  PETSTOREPETSERVICE_DB_URL=$JDBC_URL"
echo "  PETSTOREPETSERVICE_DB_USERNAME=$PG_ADMIN_USER"
echo "  PETSTOREPETSERVICE_DB_PASSWORD=<your-password>"
echo ""
echo "  PETSTOREPRODUCTSERVICE_DB_URL=$JDBC_URL"
echo "  PETSTOREPRODUCTSERVICE_DB_USERNAME=$PG_ADMIN_USER"
echo "  PETSTOREPRODUCTSERVICE_DB_PASSWORD=<your-password>"
echo ""
echo "============================================="
