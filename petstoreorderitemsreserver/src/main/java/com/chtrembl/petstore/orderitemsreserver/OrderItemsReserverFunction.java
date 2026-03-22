package com.chtrembl.petstore.orderitemsreserver;

import com.chtrembl.petstore.orderitemsreserver.model.Order;
import com.chtrembl.petstore.orderitemsreserver.model.Product;
import com.chtrembl.petstore.orderitemsreserver.model.ReservationResult;
import com.chtrembl.petstore.orderitemsreserver.model.ReservationResult.FailedItem;
import com.chtrembl.petstore.orderitemsreserver.model.ReservationResult.ReservedItem;
import com.chtrembl.petstore.orderitemsreserver.model.ReservationResult.ReservationStatus;
import com.chtrembl.petstore.orderitemsreserver.service.BlobStorageService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Azure Function: OrderItemsReserver
 *
 * Receives an order (via HTTP POST) and reserves the items in the order.
 * Validates each product's availability and quantity, then returns a
 * reservation confirmation with details about reserved and failed items.
 *
 * Deployed as a containerized Azure Function with Java runtime.
 */
public class OrderItemsReserverFunction {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    // Simulated max stock per product (in a real scenario, this would come from a database)
    private static final int MAX_STOCK_PER_PRODUCT = 10;

    /**
     * HTTP-triggered function to reserve order items.
     *
     * POST /api/order/reserve
     * Body: JSON Order object
     * Returns: JSON ReservationResult
     */
    @FunctionName("ReserveOrderItems")
    public HttpResponseMessage reserveOrderItems(
            @HttpTrigger(
                    name = "req",
                    methods = {HttpMethod.POST},
                    authLevel = AuthorizationLevel.ANONYMOUS,
                    route = "order/reserve"
            ) HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        Logger logger = context.getLogger();
        logger.info("OrderItemsReserver: Processing reservation request");

        // Parse request body
        String requestBody = request.getBody().orElse(null);
        if (requestBody == null || requestBody.isBlank()) {
            logger.warning("OrderItemsReserver: Empty request body");
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                    .header("Content-Type", "application/json")
                    .body("{\"error\": \"Request body is required. Send an Order JSON object.\"}")
                    .build();
        }

        Order order;
        try {
            order = OBJECT_MAPPER.readValue(requestBody, Order.class);
        } catch (Exception e) {
            logger.log(Level.WARNING, "OrderItemsReserver: Failed to parse order JSON", e);
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                    .header("Content-Type", "application/json")
                    .body("{\"error\": \"Invalid JSON format: " + e.getMessage() + "\"}")
                    .build();
        }

        // Validate order
        if (order.getId() == null || order.getId().isBlank()) {
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                    .header("Content-Type", "application/json")
                    .body("{\"error\": \"Order ID is required\"}")
                    .build();
        }

        if (order.getProducts() == null || order.getProducts().isEmpty()) {
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                    .header("Content-Type", "application/json")
                    .body("{\"error\": \"Order must contain at least one product\"}")
                    .build();
        }

        // Process reservation
        ReservationResult result = processReservation(order, logger);

        // Upload order JSON to Blob Storage
        uploadOrderToBlob(order, result, logger);

        try {
            String responseJson = OBJECT_MAPPER.writeValueAsString(result);
            HttpStatus status = result.getStatus() == ReservationStatus.FAILED
                    ? HttpStatus.CONFLICT
                    : HttpStatus.OK;

            logger.info("OrderItemsReserver: Reservation completed for order " + order.getId()
                    + " - Status: " + result.getStatus()
                    + " - Reserved: " + result.getReservedItems().size()
                    + " - Failed: " + result.getFailedItems().size());

            return request.createResponseBuilder(status)
                    .header("Content-Type", "application/json")
                    .body(responseJson)
                    .build();

        } catch (Exception e) {
            logger.log(Level.SEVERE, "OrderItemsReserver: Error serializing response", e);
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .header("Content-Type", "application/json")
                    .body("{\"error\": \"Internal server error\"}")
                    .build();
        }
    }

    /**
     * HTTP-triggered function for health checks.
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
                .body("{\"status\": \"UP\", \"service\": \"OrderItemsReserver\", \"version\": \"0.0.1-SNAPSHOT\"}")
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
                  "description": "Azure Function that reserves items for pet store orders",
                  "version": "0.0.1-SNAPSHOT",
                  "runtime": "Java 21",
                  "endpoints": {
                    "POST /api/order/reserve": "Reserve items in an order",
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

    /**
     * Processes the reservation for an order.
     * Validates each product and reserves available items.
     */
    private ReservationResult processReservation(Order order, Logger logger) {
        String reservationId = UUID.randomUUID().toString();
        List<ReservedItem> reservedItems = new ArrayList<>();
        List<FailedItem> failedItems = new ArrayList<>();

        for (Product product : order.getProducts()) {
            if (product.getId() == null) {
                failedItems.add(FailedItem.builder()
                        .productId(null)
                        .productName(product.getName())
                        .requestedQuantity(product.getQuantity())
                        .reason("Product ID is required")
                        .build());
                continue;
            }

            int requestedQty = product.getQuantity();

            if (requestedQty <= 0) {
                failedItems.add(FailedItem.builder()
                        .productId(product.getId())
                        .productName(product.getName())
                        .requestedQuantity(requestedQty)
                        .reason("Quantity must be greater than 0")
                        .build());
                continue;
            }

            if (requestedQty > MAX_STOCK_PER_PRODUCT) {
                failedItems.add(FailedItem.builder()
                        .productId(product.getId())
                        .productName(product.getName())
                        .requestedQuantity(requestedQty)
                        .reason("Requested quantity (" + requestedQty
                                + ") exceeds maximum stock (" + MAX_STOCK_PER_PRODUCT + ")")
                        .build());
                continue;
            }

            // Simulate stock check — in production this would query a real inventory DB
            boolean inStock = simulateStockCheck(product.getId(), requestedQty, logger);

            if (inStock) {
                reservedItems.add(ReservedItem.builder()
                        .productId(product.getId())
                        .productName(product.getName())
                        .quantity(requestedQty)
                        .build());
                logger.info("Reserved product " + product.getId()
                        + " (" + product.getName() + ") x" + requestedQty);
            } else {
                failedItems.add(FailedItem.builder()
                        .productId(product.getId())
                        .productName(product.getName())
                        .requestedQuantity(requestedQty)
                        .reason("Insufficient stock")
                        .build());
                logger.warning("Failed to reserve product " + product.getId()
                        + " (" + product.getName() + ") - insufficient stock");
            }
        }

        ReservationStatus status;
        String message;
        if (failedItems.isEmpty()) {
            status = ReservationStatus.CONFIRMED;
            message = "All items reserved successfully";
        } else if (reservedItems.isEmpty()) {
            status = ReservationStatus.FAILED;
            message = "No items could be reserved";
        } else {
            status = ReservationStatus.PARTIALLY_CONFIRMED;
            message = reservedItems.size() + " of " + (reservedItems.size() + failedItems.size())
                    + " items reserved";
        }

        return ReservationResult.builder()
                .reservationId(reservationId)
                .orderId(order.getId())
                .status(status)
                .reservedItems(reservedItems)
                .failedItems(failedItems)
                .timestamp(OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME))
                .message(message)
                .build();
    }

    /**
     * Simulates a stock check. In a real-world scenario, this would query an
     * inventory database or external inventory service.
     *
     * Current simulation: all products with ID > 0 and quantity <= MAX_STOCK are in stock.
     */
    private boolean simulateStockCheck(Long productId, int requestedQuantity, Logger logger) {
        logger.info("Checking stock for product " + productId + ", quantity: " + requestedQuantity);
        // Simulate: product IDs 1-99 are in stock, others are out of stock
        return productId > 0 && productId < 100 && requestedQuantity <= MAX_STOCK_PER_PRODUCT;
    }

    /**
     * Uploads the order and reservation result as a JSON file to Azure Blob Storage.
     * The blob name follows the pattern: orders/{orderId}/{timestamp}-reservation.json
     *
     * This is a best-effort operation — failures are logged but do not block the HTTP response.
     */
    private void uploadOrderToBlob(Order order, ReservationResult result, Logger logger) {
        try {
            // Check if Blob Storage is configured
            String connectionString = System.getenv("BLOB_STORAGE_CONNECTION_STRING");
            String endpoint = System.getenv("BLOB_STORAGE_ENDPOINT");

            if ((connectionString == null || connectionString.isBlank())
                    && (endpoint == null || endpoint.isBlank())) {
                logger.info("Blob Storage not configured (BLOB_STORAGE_CONNECTION_STRING / BLOB_STORAGE_ENDPOINT not set). "
                        + "Skipping upload for order: " + order.getId());
                return;
            }

            BlobStorageService blobService = new BlobStorageService(logger);

            // Build a combined payload with order + reservation result
            var payload = new java.util.LinkedHashMap<String, Object>();
            payload.put("order", order);
            payload.put("reservation", result);

            String jsonContent = OBJECT_MAPPER.writerWithDefaultPrettyPrinter().writeValueAsString(payload);

            // Blob name: orders/<orderId>/<timestamp>-reservation.json
            String timestamp = OffsetDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
            String blobName = String.format("orders/%s/%s-reservation.json", order.getId(), timestamp);

            blobService.uploadOrderJson(blobName, jsonContent);

            logger.info("Order JSON uploaded to Blob Storage: " + blobName);

        } catch (Exception e) {
            // Best-effort: log the error but don't fail the reservation
            logger.log(Level.WARNING,
                    "Failed to upload order JSON to Blob Storage for order " + order.getId()
                            + ": " + e.getMessage(), e);
        }
    }
}
