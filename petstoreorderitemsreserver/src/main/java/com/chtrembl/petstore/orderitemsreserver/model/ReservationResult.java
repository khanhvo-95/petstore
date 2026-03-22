package com.chtrembl.petstore.orderitemsreserver.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Represents a reservation confirmation for order items.
 * Returned by the OrderItemsReserver function after successfully reserving items.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class ReservationResult {

    @JsonProperty("reservationId")
    private String reservationId;

    @JsonProperty("orderId")
    private String orderId;

    @JsonProperty("status")
    private ReservationStatus status;

    @JsonProperty("reservedItems")
    @Builder.Default
    private List<ReservedItem> reservedItems = new ArrayList<>();

    @JsonProperty("failedItems")
    @Builder.Default
    private List<FailedItem> failedItems = new ArrayList<>();

    @JsonProperty("timestamp")
    private String timestamp;

    @JsonProperty("message")
    private String message;

    public boolean isFullyReserved() {
        return failedItems == null || failedItems.isEmpty();
    }

    public enum ReservationStatus {
        @JsonProperty("confirmed") CONFIRMED,
        @JsonProperty("partially_confirmed") PARTIALLY_CONFIRMED,
        @JsonProperty("failed") FAILED
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ReservedItem {
        @JsonProperty("productId")
        private Long productId;

        @JsonProperty("productName")
        private String productName;

        @JsonProperty("quantity")
        private Integer quantity;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class FailedItem {
        @JsonProperty("productId")
        private Long productId;

        @JsonProperty("productName")
        private String productName;

        @JsonProperty("requestedQuantity")
        private Integer requestedQuantity;

        @JsonProperty("reason")
        private String reason;
    }
}

