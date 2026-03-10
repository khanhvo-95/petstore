# PetStore k6 Load Tests — Autoscaling Monitoring Guide

Load tests for all 4 Azure Container Apps services using [k6](https://k6.io/),
with built-in **autoscaling monitoring and evaluation**.

---

## Services Under Test

| Service | URL |
|---------|-----|
| PetStore App (Frontend) | `https://demo-app-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io` |
| Pet Service | `https://demo-petservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io` |
| Order Service | `https://demo-orederservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io` |
| Product Service | `https://demo-productservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io` |

---

## File Structure

```
k6-load-tests/
├── config.js                  # URLs, endpoints, thresholds, VU=50
├── helpers.js                 # Validation + autoscaling custom metrics
├── constant-load.js           # Scenario 1 – 50 VUs steady for 5 min
├── gradual-rampup.js          # Scenario 2 – 0→10→25→50, hold, ramp-down
├── spike.js                   # Scenario 3 – 10→50 spike, hold, cool-down
├── monitor-autoscaling.sh     # Azure CLI replica count monitor
└── README.md
```

---

## Quick Start

```bash
cd petstore/k6-load-tests

# Run any scenario
k6 run constant-load.js
k6 run gradual-rampup.js
k6 run spike.js
```

---

## How Autoscaling Monitoring Works

The tests track autoscaling from **two sides** simultaneously:

### Side 1 — k6 Custom Metrics (Client-side)

Every request records per-service metrics via `trackServiceMetrics()` in `helpers.js`:

| Custom Metric | Type | What It Measures |
|---|---|---|
| `app_latency` | Trend | PetStore App response time distribution |
| `pet_service_latency` | Trend | Pet Service response time distribution |
| `order_service_latency` | Trend | Order Service response time distribution |
| `product_service_latency` | Trend | Product Service response time distribution |
| `app_errors` | Counter | Total errors for PetStore App |
| `pet_service_errors` | Counter | Total errors for Pet Service |
| `order_service_errors` | Counter | Total errors for Order Service |
| `product_service_errors` | Counter | Total errors for Product Service |
| `app_unique_replicas` | Gauge | Unique container IDs seen (PetStore App) |
| `pet_unique_replicas` | Gauge | Unique container IDs seen (Pet Service) |
| `order_unique_replicas` | Gauge | Unique container IDs seen (Order Service) |
| `product_unique_replicas` | Gauge | Unique container IDs seen (Product Service) |

**Replica detection**: The health endpoints (`/v2/health`) return a `"container"` field
with the hostname. Each time a new unique hostname appears, the gauge increments —
proving that new replicas have been spun up by Azure autoscaling.

### Side 2 — Azure CLI Monitor (Server-side)

Run `monitor-autoscaling.sh` in a **second terminal** during the test:

```bash
# Edit the script first to set your RESOURCE_GROUP
bash monitor-autoscaling.sh
```

This polls `az containerapp show` every 10 seconds and logs:
- **Running replicas** (current)
- **Min replicas** (scale rule minimum)
- **Max replicas** (scale rule maximum)
- Colour-coded output (🟢 at min, 🟡 scaling, 🔴 at max)
- CSV log file for post-test analysis

---

## Step-by-Step: Run a Full Autoscaling Test

### 1. Open Terminal 1 — Start the Azure CLI monitor

```bash
cd petstore/k6-load-tests
# Edit RESOURCE_GROUP in the script first!
bash monitor-autoscaling.sh
```

### 2. Open Terminal 2 — Run k6 spike test

```bash
cd petstore/k6-load-tests
k6 run spike.js
```

### 3. Watch both terminals side-by-side

| Time | k6 (Terminal 2) | Azure Monitor (Terminal 1) |
|---|---|---|
| 0:00–1:00 | Warm-up: 10 VUs | Replicas: 1 (min) |
| 1:00–2:00 | ⚡ Spike to 50 VUs | Replicas: 1 → 2 → 3 (scaling up) |
| 2:00–7:00 | Hold at 50 VUs | Replicas: 3–5 (stabilised) |
| 7:00–8:00 | Cool-down to 10 | Replicas: 3 → 2 (scaling down) |
| 8:00–9:00 | Ramp to 0 | Replicas: 2 → 1 (back to min) |

### 4. Check k6 results

After the test finishes, look for these in the k6 summary output:

```
  ✓ pet_service_latency............: avg=120ms  p(95)=450ms
  ✓ pet_unique_replicas............: 3          ← 3 different containers seen!
  ✓ order_service_latency..........: avg=200ms  p(95)=800ms
  ✓ order_unique_replicas..........: 2          ← 2 containers seen
  ✓ pet_service_errors.............: 0
```

### 5. Export results for detailed analysis

```bash
# Export to JSON for post-processing
k6 run --out json=results/spike-results.json spike.js

# Export to CSV
k6 run --out csv=results/spike-results.csv spike.js
```

---

## Evaluating Autoscaling — What to Look For

### ✅ Autoscaling is working well if:

| Signal | How to Check |
|---|---|
| **Replica count increased** | `*_unique_replicas` gauge > 1 in k6 output |
| **Latency stayed stable** | `*_service_latency` p(95) < 3000ms even at 50 VUs |
| **Error rate stayed low** | `*_service_errors` count < 50 |
| **Scale-up was fast** | Azure monitor shows replica increase within 1–2 min of spike |
| **Scale-down happened** | Replicas decrease during cool-down phase |

### ⚠️ Autoscaling needs tuning if:

| Signal | Likely Cause | Fix |
|---|---|---|
| Latency spikes during ramp-up | Scale-up too slow | Lower `cooldownPeriod`, lower concurrency threshold |
| Replicas never increase | Scaling rule not triggered | Check HTTP concurrency rule (should be < 50) |
| Replicas stay at max after load drops | Scale-down too slow | Reduce `cooldownPeriod` for scale-in |
| Errors during spike | Not enough replicas | Increase `maxReplicas` |
| `*_unique_replicas` = 1 throughout | No autoscaling happening | Verify scale rules exist in Container App config |

---

## Azure CLI Commands for Manual Inspection

```bash
# Check current replica count
az containerapp show \
  --name demo-petservice-southeast \
  --resource-group <RG> \
  --query "{replicas: properties.runningStatus.replicas, min: properties.template.scale.minReplicas, max: properties.template.scale.maxReplicas}"

# Check scaling rules configured
az containerapp show \
  --name demo-petservice-southeast \
  --resource-group <RG> \
  --query "properties.template.scale"

# View revision-level replica info
az containerapp revision list \
  --name demo-petservice-southeast \
  --resource-group <RG> \
  --query "[].{name:name, replicas:properties.replicas, active:properties.active}"

# Stream real-time logs (see which container handles each request)
az containerapp logs show \
  --name demo-petservice-southeast \
  --resource-group <RG> \
  --follow

# View system logs (autoscaler decisions)
az containerapp logs show \
  --name demo-petservice-southeast \
  --resource-group <RG> \
  --type system \
  --follow
```

---

## Azure Portal Monitoring

While running k6, open the **Azure Portal** to visually monitor:

1. **Container Apps → your app → Metrics**
   - `Replica Count` — shows scale-out/scale-in over time
   - `Requests` — correlate with k6 request rate
   - `Response Time` — correlate with k6 latency metrics

2. **Container Apps → your app → Log stream**
   - Real-time logs from all replicas
   - See request distribution across containers

3. **Container Apps → your app → Revisions and replicas**
   - Shows active revision and current replica count
   - Health status of each replica

---

## Thresholds

| Metric | Threshold | Purpose |
|--------|-----------|---------|
| `http_req_duration` p(95) | < 3 seconds | Overall latency |
| `http_req_failed` rate | < 10% | Overall error rate |
| `http_reqs` rate | > 10 req/s | Minimum throughput |
| `*_service_latency` p(95) | < 3 seconds | Per-service latency |
| `*_service_errors` count | < 50 | Per-service error budget |

---

## Customisation

Edit `config.js` to change:
- Service URLs, Target VUs (default: 50), Thresholds, API endpoint paths

Edit `monitor-autoscaling.sh` to change:
- `RESOURCE_GROUP` — your Azure resource group
- `APP_NAMES` — your Container App names
- `INTERVAL` — polling frequency (default: 10s)
