import http from 'k6/http';
import { check, group } from 'k6';
import { Trend, Counter, Gauge } from 'k6/metrics';

/**
 * Shared helper functions for k6 load tests.
 */

// ============================================================================
// CUSTOM METRICS – Autoscaling Monitoring
// ============================================================================

// Per-service response time trends (helps correlate latency vs replica count)
export const appLatency     = new Trend('app_latency', true);
export const petLatency     = new Trend('pet_service_latency', true);
export const orderLatency   = new Trend('order_service_latency', true);
export const productLatency = new Trend('product_service_latency', true);

// Per-service error counters
export const appErrors     = new Counter('app_errors');
export const petErrors     = new Counter('pet_service_errors');
export const orderErrors   = new Counter('order_service_errors');
export const productErrors = new Counter('product_service_errors');

// Unique container/replica tracker per service (detects scale-out)
export const appReplicas     = new Gauge('app_unique_replicas');
export const petReplicas     = new Gauge('pet_unique_replicas');
export const orderReplicas   = new Gauge('order_unique_replicas');
export const productReplicas = new Gauge('product_unique_replicas');

// Sets that accumulate unique container hostnames observed during the test
const _seenContainers = {
  app: new Set(),
  pet: new Set(),
  order: new Set(),
  product: new Set(),
};

/**
 * Record a response into the per-service custom metrics.
 * Also detects unique replicas from the health-check JSON body
 * ("container" field) or from response headers that Azure Container Apps
 * may inject.
 *
 * @param {object}  res         – k6 HTTP response
 * @param {string}  serviceKey  – one of 'app' | 'pet' | 'order' | 'product'
 */
export function trackServiceMetrics(res, serviceKey) {
  const latencyMap = { app: appLatency, pet: petLatency, order: orderLatency, product: productLatency };
  const errorMap   = { app: appErrors,  pet: petErrors,  order: orderErrors,  product: productErrors };
  const replicaMap = { app: appReplicas, pet: petReplicas, order: orderReplicas, product: productReplicas };

  // 1) Record latency
  if (latencyMap[serviceKey]) {
    latencyMap[serviceKey].add(res.timings.duration);
  }

  // 2) Record errors
  if (res.status >= 400 && errorMap[serviceKey]) {
    errorMap[serviceKey].add(1);
  }

  // 3) Detect unique replicas/containers
  let containerId = null;

  // Try JSON body (health endpoints return { "container": "hostname" })
  try {
    const body = JSON.parse(res.body);
    if (body.container) containerId = body.container;
  } catch { /* not JSON – that's fine */ }

  if (containerId && _seenContainers[serviceKey]) {
    _seenContainers[serviceKey].add(containerId);
    replicaMap[serviceKey].add(_seenContainers[serviceKey].size);
  }
}

/**
 * Validates a standard HTTP response.
 * @param {object} response - The k6 HTTP response object
 * @param {string} name - Name for the check
 * @param {number} expectedStatus - Expected HTTP status code (default: 200)
 */
export function validateResponse(response, name, expectedStatus = 200) {
  check(response, {
    [`${name} - status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
    [`${name} - response time < 3s`]: (r) => r.timings.duration < 3000,
  });
}

/**
 * Validates a JSON response.
 * @param {object} response - The k6 HTTP response object
 * @param {string} name - Name for the check
 */
export function validateJsonResponse(response, name) {
  check(response, {
    [`${name} - status is 200`]: (r) => r.status === 200,
    [`${name} - response time < 3s`]: (r) => r.timings.duration < 3000,
    [`${name} - content-type is JSON`]: (r) =>
      r.headers['Content-Type'] && r.headers['Content-Type'].includes('application/json'),
  });
}

/**
 * Validates health check response.
 * @param {object} response - The k6 HTTP response object
 * @param {string} serviceName - Name of the service
 */
export function validateHealthCheck(response, serviceName) {
  check(response, {
    [`${serviceName} health - status is 200`]: (r) => r.status === 200,
    [`${serviceName} health - status is UP`]: (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.status === 'UP';
      } catch {
        return false;
      }
    },
  });
}

/**
 * Standard JSON headers for POST requests.
 */
export const JSON_HEADERS = {
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
};

/**
 * Standard GET request headers.
 */
export const GET_HEADERS = {
  headers: {
    'Accept': 'application/json',
  },
};

/**
 * Generate a random integer between min and max (inclusive).
 */
export function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Generate a random session ID (32-character hex string, uppercase).
 */
export function randomSessionId() {
  const chars = '0123456789ABCDEF';
  let result = '';
  for (let i = 0; i < 32; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
