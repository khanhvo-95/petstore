/**
 * ALL SERVICES - Scenario 1: Constant Load (HIGH PRESSURE for autoscaling)
 *
 * Simulates a constant load of 200 concurrent users hitting ALL 4 services
 * (PetStore App, Pet Service, Order Service, Product Service) simultaneously
 * with minimal sleep between iterations to force Azure Container Apps
 * to scale out replicas.
 *
 * Run:  k6 run constant-load.js
 *
 * WHY 200 VUs?
 *   Azure Container Apps HTTP scaling default = 10 concurrent requests/replica.
 *   With sleep(1), 50 VUs only produce ~50 concurrent requests across 4 services
 *   = ~12 per service = 1-2 replicas at most.
 *   With 200 VUs and sleep(0.1), each service sees ~50+ concurrent requests
 *   = should trigger 3-5+ replicas.
 */
import http from 'k6/http';
import { sleep, group } from 'k6';
import { SERVICES, ENDPOINTS, THRESHOLDS, HIGH_VUS, SLEEP_DURATION } from './config.js';
import {
  validateResponse,
  validateJsonResponse,
  validateHealthCheck,
  trackServiceMetrics,
  randomInt,
  randomSessionId,
  JSON_HEADERS,
  GET_HEADERS,
} from './helpers.js';

export const options = {
  vus: HIGH_VUS,          // 200 concurrent virtual users (was 50)
  duration: '5m',         // Steady for 5 minutes
  thresholds: {
    ...THRESHOLDS,
    app_latency:             ['p(95)<5000'],
    pet_service_latency:     ['p(95)<5000'],
    order_service_latency:   ['p(95)<5000'],
    product_service_latency: ['p(95)<5000'],
    app_errors:              ['count<200'],
    pet_service_errors:      ['count<200'],
    order_service_errors:    ['count<200'],
    product_service_errors:  ['count<200'],
  },
  tags: { scenario: 'constant-load' },
};

// ── helper: random order payload ────────────────────────────────────────────
function createOrderPayload() {
  return JSON.stringify({
    id: randomSessionId(),
    email: `loadtest-${randomInt(1, 10000)}@test.com`,
    products: [{ id: randomInt(1, 10), quantity: randomInt(1, 5) }],
    complete: false,
  });
}

// ── main VU function ────────────────────────────────────────────────────────
export default function () {

  // ====== 1. PetStore App (Frontend) ======
  group('PetStoreApp - Home Page', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.HOME}`);
    validateResponse(res, 'App-Home');
    trackServiceMetrics(res, 'app');
  });

  group('PetStoreApp - Login Page', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.LOGIN}`);
    validateResponse(res, 'App-Login');
    trackServiceMetrics(res, 'app');
  });

  group('PetStoreApp - Contact Us API', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.API_CONTACTUS}`, GET_HEADERS);
    validateResponse(res, 'App-ContactUs');
    trackServiceMetrics(res, 'app');
  });

  group('PetStoreApp - Dog Breeds', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.DOG_BREEDS}`);
    validateResponse(res, 'App-DogBreeds');
    trackServiceMetrics(res, 'app');
  });

  group('PetStoreApp - Cat Breeds', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.CAT_BREEDS}`);
    validateResponse(res, 'App-CatBreeds');
    trackServiceMetrics(res, 'app');
  });

  group('PetStoreApp - Fish Breeds', () => {
    const res = http.get(`${SERVICES.PETSTORE_APP}${ENDPOINTS.APP.FISH_BREEDS}`);
    validateResponse(res, 'App-FishBreeds');
    trackServiceMetrics(res, 'app');
  });

  // ====== 2. Pet Service (endpoints from Swagger: /swagger-ui.html) ======
  group('PetService - Swagger UI', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.SWAGGER_UI}`);
    validateResponse(res, 'Pet-SwaggerUI');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - OpenAPI Docs', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.API_DOCS}`, GET_HEADERS);
    validateJsonResponse(res, 'Pet-APIDocs');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - Actuator Health', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.ACTUATOR_HEALTH}`, GET_HEADERS);
    validateJsonResponse(res, 'Pet-ActuatorHealth');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - Actuator Info', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.ACTUATOR_INFO}`, GET_HEADERS);
    validateResponse(res, 'Pet-ActuatorInfo');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - Health (container ID)', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.HEALTH}`, GET_HEADERS);
    validateHealthCheck(res, 'PetService');
    trackServiceMetrics(res, 'pet');       // ← tracks unique container hostnames
  });

  group('PetService - Pets by Status (available)', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.FIND_BY_STATUS_AVAILABLE}`, GET_HEADERS);
    validateJsonResponse(res, 'Pet-FindAvailable');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - All Pets', () => {
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.GET_ALL}`, GET_HEADERS);
    validateJsonResponse(res, 'Pet-GetAll');
    trackServiceMetrics(res, 'pet');
  });

  group('PetService - Pet by ID', () => {
    const id = randomInt(1, 12);
    const res = http.get(`${SERVICES.PET_SERVICE}${ENDPOINTS.PET.GET_BY_ID(id)}`, GET_HEADERS);
    validateJsonResponse(res, `Pet-ById-${id}`);
    trackServiceMetrics(res, 'pet');
  });

  // ====== 3. Order Service (endpoints from Swagger: /swagger-ui.html) ======
  group('OrderService - Swagger UI', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.SWAGGER_UI}`);
    validateResponse(res, 'Order-SwaggerUI');
    trackServiceMetrics(res, 'order');
  });

  group('OrderService - OpenAPI Docs', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.API_DOCS}`, GET_HEADERS);
    validateJsonResponse(res, 'Order-APIDocs');
    trackServiceMetrics(res, 'order');
  });

  group('OrderService - Actuator Health', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.ACTUATOR_HEALTH}`, GET_HEADERS);
    validateJsonResponse(res, 'Order-ActuatorHealth');
    trackServiceMetrics(res, 'order');
  });

  group('OrderService - Actuator Info', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.ACTUATOR_INFO}`, GET_HEADERS);
    validateResponse(res, 'Order-ActuatorInfo');
    trackServiceMetrics(res, 'order');
  });

  group('OrderService - Health (container ID)', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.HEALTH}`, GET_HEADERS);
    validateHealthCheck(res, 'OrderService');
    trackServiceMetrics(res, 'order');     // ← tracks unique container hostnames
  });

  group('OrderService - Store Info (container ID)', () => {
    const res = http.get(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.STORE_INFO}`, GET_HEADERS);
    validateJsonResponse(res, 'Order-StoreInfo');
    trackServiceMetrics(res, 'order');     // ← also returns container hostname
  });

  group('OrderService - Place Order', () => {
    const payload = createOrderPayload();
    const res = http.post(`${SERVICES.ORDER_SERVICE}${ENDPOINTS.ORDER.PLACE_ORDER}`, payload, JSON_HEADERS);
    validateJsonResponse(res, 'Order-Place');
    trackServiceMetrics(res, 'order');
  });

  // ====== 4. Product Service (endpoints from Swagger: /swagger-ui.html) ======
  group('ProductService - Swagger UI', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.SWAGGER_UI}`);
    validateResponse(res, 'Product-SwaggerUI');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - OpenAPI Docs', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.API_DOCS}`, GET_HEADERS);
    validateJsonResponse(res, 'Product-APIDocs');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - Actuator Health', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.ACTUATOR_HEALTH}`, GET_HEADERS);
    validateJsonResponse(res, 'Product-ActuatorHealth');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - Actuator Info', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.ACTUATOR_INFO}`, GET_HEADERS);
    validateResponse(res, 'Product-ActuatorInfo');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - Health (container ID)', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.HEALTH}`, GET_HEADERS);
    validateHealthCheck(res, 'ProductService');
    trackServiceMetrics(res, 'product');   // ← tracks unique container hostnames
  });

  group('ProductService - Products by Status (available)', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.FIND_BY_STATUS_AVAILABLE}`, GET_HEADERS);
    validateJsonResponse(res, 'Product-FindAvailable');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - All Products', () => {
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.GET_ALL}`, GET_HEADERS);
    validateJsonResponse(res, 'Product-GetAll');
    trackServiceMetrics(res, 'product');
  });

  group('ProductService - Product by ID', () => {
    const id = randomInt(1, 10);
    const res = http.get(`${SERVICES.PRODUCT_SERVICE}${ENDPOINTS.PRODUCT.GET_BY_ID(id)}`, GET_HEADERS);
    validateJsonResponse(res, `Product-ById-${id}`);
    trackServiceMetrics(res, 'product');
  });

  sleep(SLEEP_DURATION);  // 0.1s — fast iterations to push high concurrency
}

