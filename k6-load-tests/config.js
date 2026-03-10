/**
 * Centralized configuration for k6 load tests.
 * Update the base URLs below to match your Azure Container Apps deployment.
 */

// ============================================================================
// SERVICE BASE URLs - Azure Container Apps
// ============================================================================
export const SERVICES = {
  PETSTORE_APP: 'https://demo-app-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io',
  PET_SERVICE: 'https://demo-petservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io',
  ORDER_SERVICE: 'https://demo-orederservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io',
  PRODUCT_SERVICE: 'https://demo-productservice-southeast.icymoss-140a1618.southeastasia.azurecontainerapps.io',
};

// ============================================================================
// API ENDPOINTS per service  (discovered via Swagger / source code)
//
// Each backend service exposes:
//   Swagger UI :  /swagger-ui.html   (redirected from /)
//   OpenAPI doc:  /api-docs
//   Actuator   :  /actuator/health, /actuator/info
//   Custom     :  /v2/health  (returns container hostname for replica tracking)
// ============================================================================
export const ENDPOINTS = {
  // PetStore App (Frontend – Spring MVC, no Swagger)
  APP: {
    HOME: '/',
    LOGIN: '/login',
    API_CONTACTUS: '/api/contactus',
    API_SESSIONID: '/api/sessionid',
    DOG_BREEDS: '/dogbreeds?category=Dog',
    CAT_BREEDS: '/catbreeds?category=Cat',
    FISH_BREEDS: '/fishbreeds?category=Fish',
  },

  // Pet Service  (Swagger tag: "Pet", "Info")
  //   GET /petstorepetservice/v2/pet/findByStatus?status=  → find by status
  //   GET /petstorepetservice/v2/pet/{petId}                → find by ID
  //   GET /petstorepetservice/v2/pet/all                    → list all
  //   GET /petstorepetservice/v2/health                     → health (container ID)
  //   GET /swagger-ui.html                                  → Swagger UI
  //   GET /api-docs                                         → OpenAPI JSON
  //   GET /actuator/health                                  → Spring Actuator health
  //   GET /actuator/info                                    → Spring Actuator info
  PET: {
    SWAGGER_UI: '/swagger-ui.html',
    API_DOCS: '/api-docs',
    ACTUATOR_HEALTH: '/actuator/health',
    ACTUATOR_INFO: '/actuator/info',
    HEALTH: '/petstorepetservice/v2/health',
    FIND_BY_STATUS_AVAILABLE: '/petstorepetservice/v2/pet/findByStatus?status=available',
    FIND_BY_STATUS_PENDING: '/petstorepetservice/v2/pet/findByStatus?status=pending',
    FIND_BY_STATUS_SOLD: '/petstorepetservice/v2/pet/findByStatus?status=sold',
    GET_ALL: '/petstorepetservice/v2/pet/all',
    GET_BY_ID: (id) => `/petstorepetservice/v2/pet/${id}`,
  },

  // Order Service  (Swagger tag: "Store", "Info")
  //   POST /petstoreorderservice/v2/store/order             → place order
  //   GET  /petstoreorderservice/v2/store/order/{orderId}   → get order
  //   GET  /petstoreorderservice/v2/store/info               → service info (container ID)
  //   GET  /petstoreorderservice/v2/health                   → health (container ID)
  //   GET  /swagger-ui.html                                  → Swagger UI
  //   GET  /api-docs                                         → OpenAPI JSON
  //   GET  /actuator/health                                  → Spring Actuator health
  //   GET  /actuator/info                                    → Spring Actuator info
  ORDER: {
    SWAGGER_UI: '/swagger-ui.html',
    API_DOCS: '/api-docs',
    ACTUATOR_HEALTH: '/actuator/health',
    ACTUATOR_INFO: '/actuator/info',
    HEALTH: '/petstoreorderservice/v2/health',
    STORE_INFO: '/petstoreorderservice/v2/store/info',
    PLACE_ORDER: '/petstoreorderservice/v2/store/order',
    GET_BY_ID: (orderId) => `/petstoreorderservice/v2/store/order/${orderId}`,
  },

  // Product Service  (Swagger tag: "Product", "Info")
  //   GET /petstoreproductservice/v2/product/findByStatus?status= → find by status
  //   GET /petstoreproductservice/v2/product/{productId}          → find by ID
  //   GET /petstoreproductservice/v2/product/all                  → list all
  //   GET /petstoreproductservice/v2/health                       → health (container ID)
  //   GET /swagger-ui.html                                        → Swagger UI
  //   GET /api-docs                                               → OpenAPI JSON
  //   GET /actuator/health                                        → Spring Actuator health
  //   GET /actuator/info                                          → Spring Actuator info
  PRODUCT: {
    SWAGGER_UI: '/swagger-ui.html',
    API_DOCS: '/api-docs',
    ACTUATOR_HEALTH: '/actuator/health',
    ACTUATOR_INFO: '/actuator/info',
    HEALTH: '/petstoreproductservice/v2/health',
    FIND_BY_STATUS_AVAILABLE: '/petstoreproductservice/v2/product/findByStatus?status=available',
    FIND_BY_STATUS_PENDING: '/petstoreproductservice/v2/product/findByStatus?status=pending',
    FIND_BY_STATUS_SOLD: '/petstoreproductservice/v2/product/findByStatus?status=sold',
    GET_ALL: '/petstoreproductservice/v2/product/all',
    GET_BY_ID: (id) => `/petstoreproductservice/v2/product/${id}`,
  },
};

// ============================================================================
// LOAD TEST THRESHOLDS (shared across all tests)
// ============================================================================
export const THRESHOLDS = {
  http_req_duration: ['p(95)<5000'],   // 95% of requests should complete within 5s
  http_req_failed: ['rate<0.15'],      // Less than 15% failure rate
  http_reqs: ['rate>10'],              // At least 10 requests per second
};

// ============================================================================
// CONCURRENT USERS CONFIGURATION
//
// TARGET_VUS       = default level (moderate load)
// HIGH_VUS         = aggressive level (force autoscaling)
// SLEEP_DURATION   = pause between iterations (lower = more pressure)
//
// Azure Container Apps default HTTP scaling rule triggers at
// ~10-20 concurrent requests per replica. To force scale-out:
//   - Use HIGH_VUS (200) with SLEEP_DURATION (0.1s)
//   - Each VU sends ~25 requests/iteration → 200 VUs = ~5000 req/s peak
// ============================================================================
export const TARGET_VUS = 50;
export const HIGH_VUS = 90;
export const SLEEP_DURATION = 0.5;     // seconds between iterations (was 1s)

