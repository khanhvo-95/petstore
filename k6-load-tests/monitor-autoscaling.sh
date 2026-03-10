#!/bin/bash
# =============================================================================
# monitor-autoscaling.sh
#
# Run this script in a SEPARATE terminal ALONGSIDE k6 to monitor
# Azure Container Apps replica counts in real-time.
#
# Usage:
#   chmod +x monitor-autoscaling.sh
#   ./monitor-autoscaling.sh
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - jq installed (for JSON parsing)
# =============================================================================

# ── Configuration ────────────────────────────────────────────────────────────
# Update these to match your Azure Container Apps environment
RESOURCE_GROUP="<YOUR_RESOURCE_GROUP>"          # e.g. "petstore-rg"
SUBSCRIPTION="<YOUR_SUBSCRIPTION_ID>"           # optional, if not default

# Container App names (as shown in Azure Portal)
APP_NAMES=(
  "demo-app-southeast"
  "demo-petservice-southeast"
  "demo-orederservice-southeast"
  "demo-productservice-southeast"
)

# Polling interval in seconds
INTERVAL=10

# Output log file
LOG_FILE="autoscaling-monitor-$(date +%Y%m%d-%H%M%S).csv"

# ── Colour codes ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Functions ────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║    Azure Container Apps – Autoscaling Monitor               ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "Resource Group: ${YELLOW}${RESOURCE_GROUP}${NC}"
  echo -e "Polling every:  ${YELLOW}${INTERVAL}s${NC}"
  echo -e "Log file:       ${YELLOW}${LOG_FILE}${NC}"
  echo ""
}

get_replica_count() {
  local app_name=$1
  # Get the current running replica count from the Container App
  az containerapp replica list \
    --name "$app_name" \
    --resource-group "$RESOURCE_GROUP" \
    --query "length(@)" \
    --output tsv 2>/dev/null || echo "N/A"
}

get_revision_replicas() {
  local app_name=$1
  # Get replica info from the active revision
  az containerapp show \
    --name "$app_name" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{running: properties.runningStatus.replicas, min: properties.template.scale.minReplicas, max: properties.template.scale.maxReplicas}" \
    --output json 2>/dev/null || echo "{}"
}

# ── Main Loop ────────────────────────────────────────────────────────────────
print_header

# Write CSV header
echo "timestamp,service,running_replicas,min_replicas,max_replicas" > "$LOG_FILE"

echo -e "${GREEN}Starting monitoring... Press Ctrl+C to stop.${NC}"
echo ""
printf "%-25s %-35s %-10s %-8s %-8s\n" "TIMESTAMP" "SERVICE" "RUNNING" "MIN" "MAX"
printf "%-25s %-35s %-10s %-8s %-8s\n" "─────────────────────────" "───────────────────────────────────" "──────────" "────────" "────────"

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  for app in "${APP_NAMES[@]}"; do
    # Get replica info
    INFO=$(get_revision_replicas "$app")

    RUNNING=$(echo "$INFO" | jq -r '.running // "?"')
    MIN_REP=$(echo "$INFO" | jq -r '.min // "?"')
    MAX_REP=$(echo "$INFO" | jq -r '.max // "?"')

    # Colour code: green if running=min, yellow if scaling, red if at max
    if [ "$RUNNING" = "$MAX_REP" ] && [ "$MAX_REP" != "?" ]; then
      COLOR=$RED
    elif [ "$RUNNING" = "$MIN_REP" ] && [ "$MIN_REP" != "?" ]; then
      COLOR=$GREEN
    else
      COLOR=$YELLOW
    fi

    printf "%-25s %-35s ${COLOR}%-10s${NC} %-8s %-8s\n" "$TIMESTAMP" "$app" "$RUNNING" "$MIN_REP" "$MAX_REP"

    # Log to CSV
    echo "$TIMESTAMP,$app,$RUNNING,$MIN_REP,$MAX_REP" >> "$LOG_FILE"
  done

  echo ""
  sleep "$INTERVAL"
done

