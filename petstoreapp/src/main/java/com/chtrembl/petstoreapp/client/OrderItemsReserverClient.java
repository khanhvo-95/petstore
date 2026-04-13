package com.chtrembl.petstoreapp.client;

import com.chtrembl.petstoreapp.config.FeignConfig;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Feign client for the OrderItemsReserver Azure Function.
 * Note: Order reservation messages are now sent via Azure Service Bus
 * instead of direct HTTP calls. This client is retained for health checks only.
 */
@FeignClient(
        name = "orderitemsreserver-service",
        url = "${petstore.service.orderitemsreserver.url}",
        configuration = FeignConfig.class
)
public interface OrderItemsReserverClient {

    @GetMapping("/api/health")
    String getHealth();

    @GetMapping("/api/info")
    String getInfo();
}
