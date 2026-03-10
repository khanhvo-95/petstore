# =============================================================================
# monitor-autoscaling.ps1
#
# PowerShell version of the autoscaling monitor for Windows.
# Run this in a SEPARATE terminal ALONGSIDE k6 to monitor
# Azure Container Apps replica counts in real-time.
#
# Usage:
#   .\monitor-autoscaling.ps1
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
# =============================================================================

# ── Configuration ────────────────────────────────────────────────────────────
# Update these to match your Azure Container Apps environment
$RESOURCE_GROUP = "<YOUR_RESOURCE_GROUP>"          # e.g. "petstore-rg"
# $SUBSCRIPTION  = "<YOUR_SUBSCRIPTION_ID>"        # uncomment if needed

# Container App names (as shown in Azure Portal)
$APP_NAMES = @(
  "demo-app-southeast",
  "demo-petservice-southeast",
  "demo-orederservice-southeast",
  "demo-productservice-southeast"
)

# Polling interval in seconds
$INTERVAL = 10

# Output log file
$LOG_FILE = "autoscaling-monitor-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# ── Functions ────────────────────────────────────────────────────────────────

function Get-RevisionReplicas {
  param([string]$AppName)

  try {
    $json = az containerapp show `
      --name $AppName `
      --resource-group $RESOURCE_GROUP `
      --query "{running: properties.runningStatus.replicas, min: properties.template.scale.minReplicas, max: properties.template.scale.maxReplicas}" `
      --output json 2>$null

    if ($json) {
      return $json | ConvertFrom-Json
    }
  }
  catch { }

  return [PSCustomObject]@{ running = "?"; min = "?"; max = "?" }
}

function Write-ColorLine {
  param(
    [string]$Timestamp,
    [string]$Service,
    [string]$Running,
    [string]$Min,
    [string]$Max
  )

  # Determine color: Green=at min, Yellow=scaling, Red=at max
  $color = "Yellow"
  if ($Running -eq $Max -and $Max -ne "?") {
    $color = "Red"
  }
  elseif ($Running -eq $Min -and $Min -ne "?") {
    $color = "Green"
  }

  $line = "{0,-25} {1,-35} " -f $Timestamp, $Service
  Write-Host $line -NoNewline
  Write-Host ("{0,-10}" -f $Running) -ForegroundColor $color -NoNewline
  Write-Host (" {0,-8} {1,-8}" -f $Min, $Max)
}

# ── Main ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    Azure Container Apps - Autoscaling Monitor               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: " -NoNewline; Write-Host $RESOURCE_GROUP -ForegroundColor Yellow
Write-Host "Polling every:  " -NoNewline; Write-Host "${INTERVAL}s" -ForegroundColor Yellow
Write-Host "Log file:       " -NoNewline; Write-Host $LOG_FILE -ForegroundColor Yellow
Write-Host ""

# Write CSV header
"timestamp,service,running_replicas,min_replicas,max_replicas" | Out-File -FilePath $LOG_FILE -Encoding utf8

Write-Host "Starting monitoring... Press Ctrl+C to stop." -ForegroundColor Green
Write-Host ""

# Table header
$headerFmt = "{0,-25} {1,-35} {2,-10} {3,-8} {4,-8}"
Write-Host ($headerFmt -f "TIMESTAMP", "SERVICE", "RUNNING", "MIN", "MAX")
Write-Host ($headerFmt -f ("-" * 25), ("-" * 35), ("-" * 10), ("-" * 8), ("-" * 8))

while ($true) {
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  foreach ($app in $APP_NAMES) {
    $info = Get-RevisionReplicas -AppName $app

    $running = if ($info.running) { $info.running } else { "?" }
    $min     = if ($info.min)     { $info.min }     else { "?" }
    $max     = if ($info.max)     { $info.max }     else { "?" }

    Write-ColorLine -Timestamp $timestamp -Service $app -Running $running -Min $min -Max $max

    # Append to CSV
    "$timestamp,$app,$running,$min,$max" | Out-File -FilePath $LOG_FILE -Append -Encoding utf8
  }

  Write-Host ""
  Start-Sleep -Seconds $INTERVAL
}

