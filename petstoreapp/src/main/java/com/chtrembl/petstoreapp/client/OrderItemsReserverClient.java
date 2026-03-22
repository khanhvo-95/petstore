package com.chtrembl.petstoreapp.client;

import com.chtrembl.petstoreapp.config.FeignConfig;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

@FeignClient(
        name = "orderitemsreserver-service",
        url = "${petstore.service.orderitemsreserver.url}",
        configuration = FeignConfig.class
)
public interface OrderItemsReserverClient {

    @PostMapping("/api/order/reserve")
    String reserveOrderItems(@RequestBody String orderJson);

    @GetMapping("/api/health")
    String getHealth();

    @GetMapping("/api/info")
    String getInfo();
}

