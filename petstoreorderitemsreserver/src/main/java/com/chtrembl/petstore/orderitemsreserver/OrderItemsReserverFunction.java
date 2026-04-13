package com.chtrembl.petstore.orderitemsreserver;

import com.chtrembl.petstore.orderitemsreserver.model.Order;
import com.chtrembl.petstore.orderitemsreserver.service.BlobStorageService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Azure Function: OrderItemsReserver
 *
 * Receives order messages from Azure Service Bus queue and uploads them
 * as JSON files to Azure Blob Storage. Uses the customer's session ID
 * as the blob filename so each session's file is overwritten on every
 * cart update within the same session.
 *
 * Retry policy: up to 3 attempts for Blob Storage upload.
 * If all retries fail, the function throws an exception which causes
 * the Service Bus message to be moved to the Dead-Letter Queue (DLQ).
 * A Logic App monitors the DLQ and sends email notifications to the manager.
 *
 * Deployed as a containerized Azure Function with Java runtime.
 */
public class OrderItemsReserverFunction {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final int MAX_RETRY_ATTEMPTS = 3;
    private static final long RETRY_DELAY_MS = 1000; // 1 second between retries

    /**
     * Service Bus triggered function to process order messages.
     *
     * Listens to the "order-items-queue" queue. When a message arrives:
     * 1. Parses the order JSON from the message body
     * 2. Uses the session ID as the blob filename
     * 3. Uploads the order JSON to Blob Storage with retry policy (3 attempts)
     * 4. If all retries fail, throws exception -> message goes to DLQ
     *
     * The Service Bus queue is configured with:
     * - maxDeliveryCount = 3 (matching our retry policy)
     * - Dead-letter queue enabled for failed messages
     */
    @FunctionName("ProcessOrderMessage")
    public void processOrderMessage(
            @ServiceBusQueueTrigger(
                    name = "message",
                    queueName = "%SERVICEBUS_QUEUE_NAME%",
                    connection = "SERVICEBUS_CONNECTION_STRING",
                    isSessionsEnabled = false
            ) String message,
            final ExecutionContext context) {

        Logger logger = context.getLogger();
        logger.info("OrderItemsReserver: Received Service Bus message");

        // Parse order from message
        Order order;
        try {
            order = OBJECT_MAPPER.readValue(message, Order.class);
        } catch (Exception e) {
            logger.log(Level.SEVERE, "OrderItemsReserver: Failed to parse order JSON from Service Bus message", e);
            // Invalid JSON should not be retried - throw to send to DLQ immediately
            throw new RuntimeException("Failed to parse order JSON: " + e.getMessage(), e);
        }

        // Validate order
        if (order.getId() == null || order.getId().isBlank()) {
            logger.severe("OrderItemsReserver: Order ID is missing in Service Bus message");
            throw new RuntimeException("Order ID is required in the message");
        }

        if (order.getProducts() == null || order.getProducts().isEmpty()) {
            logger.warning("OrderItemsReserver: Order has no products, skipping blob upload for order: " + order.getId());
            return; // No products to process - complete successfully (don't retry)
        }

        // Extract session ID from order ID (session ID is used as the order ID)
        String sessionId = order.getId();

        logger.info("OrderItemsReserver: Processing order for session: " + sessionId
                + " with " + order.getProducts().size() + " products");

        // Upload to Blob Storage with retry policy (3 attempts)
        uploadWithRetry(order, sessionId, logger);

        logger.info("OrderItemsReserver: Successfully processed order for session: " + sessionId);
    }

    /**
     * Uploads order JSON to Blob Storage with a retry policy.
     * Makes up to 3 attempts. If all fail, throws RuntimeException
     * which causes the Service Bus message to be moved to the DLQ.
     *
     * @param order     the order to upload
     * @param sessionId the session ID used as the blob filename
     * @param logger    the function logger
     */
    private void uploadWithRetry(Order order, String sessionId, Logger logger) {
        Exception lastException = null;

        for (int attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
            try {
                logger.warning("OrderItemsReserver: ===== Blob upload attempt " + attempt + "/" + MAX_RETRY_ATTEMPTS
                        + " for session: " + sessionId + " =====");

                uploadOrderToBlob(order, sessionId, logger);

                logger.warning("OrderItemsReserver: Blob upload SUCCEEDED on attempt " + attempt
                        + " for session: " + sessionId);
                return; // Success - exit retry loop

            } catch (Exception e) {
                lastException = e;
                logger.severe("OrderItemsReserver: Blob upload attempt " + attempt + "/" + MAX_RETRY_ATTEMPTS
                        + " FAILED for session " + sessionId + ": " + e.getMessage());

                if (attempt < MAX_RETRY_ATTEMPTS) {
                    try {
                        long delay = RETRY_DELAY_MS * attempt; // Linear backoff: 1s, 2s
                        logger.warning("OrderItemsReserver: Waiting " + delay + "ms before retry attempt " + (attempt + 1) + "...");
                        Thread.sleep(delay);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException("Blob upload interrupted during retry for session: " + sessionId, ie);
                    }
                }
            }
        }

        // All retry attempts exhausted - throw to trigger DLQ
        String errorMsg = String.format(
                "OrderItemsReserver: ===== ALL %d BLOB UPLOAD ATTEMPTS FAILED for session %s. "
                        + "Message will be moved to Dead-Letter Queue for manual processing. =====",
                MAX_RETRY_ATTEMPTS, sessionId);
        logger.severe(errorMsg);
        throw new RuntimeException(errorMsg, lastException);
    }

    /**
     * Uploads the order as a JSON file to Azure Blob Storage.
     * Uses the session ID as the blob filename so the file is overwritten
     * for each user session whenever a cart update is made.
     *
     * Blob name pattern: {sessionId}.json
     */
    private void uploadOrderToBlob(Order order, String sessionId, Logger logger) {
        // Check if Blob Storage is configured
        String connectionString = System.getenv("BLOB_STORAGE_CONNECTION_STRING");
        String endpoint = System.getenv("BLOB_STORAGE_ENDPOINT");

        if ((connectionString == null || connectionString.isBlank())
                && (endpoint == null || endpoint.isBlank())) {
            throw new RuntimeException(
                    "Blob Storage not configured (BLOB_STORAGE_CONNECTION_STRING / BLOB_STORAGE_ENDPOINT not set)");
        }

        BlobStorageService blobService = new BlobStorageService(logger);

        try {
            // Build the JSON payload with order details and product list
            var payload = new java.util.LinkedHashMap<String, Object>();
            payload.put("sessionId", sessionId);
            payload.put("order", order);

            String jsonContent = OBJECT_MAPPER.writerWithDefaultPrettyPrinter().writeValueAsString(payload);

            // Use session ID as the blob filename - overwrites on every update
            String blobName = sessionId + ".json";

            blobService.uploadOrderJson(blobName, jsonContent);

            logger.info("Order JSON uploaded to Blob Storage: " + blobName);

        } catch (Exception e) {
            throw new RuntimeException("Failed to upload order JSON to Blob Storage for session "
                    + sessionId + ": " + e.getMessage(), e);
        }
    }

    /**
     * HTTP-triggered function for health checks.
     * Retained for monitoring and Container Apps health probes.
     *
     * GET /api/health
     */
    @FunctionName("HealthCheck")
    public HttpResponseMessage healthCheck(
            @HttpTrigger(
                    name = "req",
                    methods = {HttpMethod.GET},
                    authLevel = AuthorizationLevel.ANONYMOUS,
                    route = "health"
            ) HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        context.getLogger().info("OrderItemsReserver: Health check requested");

        return request.createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .body("{\"status\": \"UP\", \"service\": \"OrderItemsReserver\", \"version\": \"0.0.1-SNAPSHOT\", \"trigger\": \"ServiceBus\"}")
                .build();
    }

    /**
     * HTTP-triggered function to get service info.
     *
     * GET /api/info
     */
    @FunctionName("Info")
    public HttpResponseMessage info(
            @HttpTrigger(
                    name = "req",
                    methods = {HttpMethod.GET},
                    authLevel = AuthorizationLevel.ANONYMOUS,
                    route = "info"
            ) HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        context.getLogger().info("OrderItemsReserver: Info requested");

        String info = """
                {
                  "service": "OrderItemsReserver",
                  "description": "Azure Function that processes order messages from Service Bus and uploads to Blob Storage",
                  "version": "0.0.1-SNAPSHOT",
                  "runtime": "Java 21",
                  "trigger": "Azure Service Bus Queue",
                  "retryPolicy": {
                    "maxAttempts": 3,
                    "retryDelayMs": 1000,
                    "fallback": "Dead-Letter Queue -> Logic App email notification"
                  },
                  "endpoints": {
                    "ServiceBus Trigger": "Processes order messages from queue",
                    "GET /api/health": "Health check",
                    "GET /api/info": "Service information"
                  }
                }
                """;

        return request.createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .body(info)
                .build();
    }
}
