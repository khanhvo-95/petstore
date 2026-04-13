package com.chtrembl.petstoreapp.service;

import com.azure.messaging.servicebus.ServiceBusClientBuilder;
import com.azure.messaging.servicebus.ServiceBusMessage;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Service for sending order messages to Azure Service Bus.
 * Messages are consumed by the OrderItemsReserver Azure Function
 * (Service Bus Trigger) which uploads order JSON to Blob Storage.
 */
@Service
@Slf4j
public class ServiceBusSenderService {

    @Value("${petstore.servicebus.connection-string:}")
    private String connectionString;

    @Value("${petstore.servicebus.queue-name:order-items-queue}")
    private String queueName;

    private ServiceBusSenderClient senderClient;
    private boolean configured = false;

    @PostConstruct
    public void init() {
        if (connectionString == null || connectionString.isBlank()) {
            log.warn("Service Bus connection string is not configured. "
                    + "Set SERVICEBUS_CONNECTION_STRING environment variable. "
                    + "Order messages will NOT be sent to Service Bus.");
            return;
        }

        try {
            this.senderClient = new ServiceBusClientBuilder()
                    .connectionString(connectionString)
                    .sender()
                    .queueName(queueName)
                    .buildClient();
            this.configured = true;
            log.info("ServiceBusSenderService initialized successfully for queue: {}", queueName);
        } catch (Exception e) {
            log.error("Failed to initialize Service Bus sender client: {}", e.getMessage(), e);
        }
    }

    @PreDestroy
    public void cleanup() {
        if (senderClient != null) {
            try {
                senderClient.close();
                log.info("ServiceBusSenderService closed successfully");
            } catch (Exception e) {
                log.warn("Error closing Service Bus sender client: {}", e.getMessage());
            }
        }
    }

    /**
     * Sends an order message to the Service Bus queue.
     * The message body is the order JSON and the session ID is set as a message property
     * so the consumer can use it as the blob filename.
     *
     * @param sessionId  the customer's session ID (used as blob filename)
     * @param orderJson  the serialized order JSON
     */
    public void sendOrderMessage(String sessionId, String orderJson) {
        if (!configured) {
            log.warn("Service Bus is not configured. Skipping message for session: {}", sessionId);
            return;
        }

        try {
            ServiceBusMessage message = new ServiceBusMessage(orderJson);
            message.getApplicationProperties().put("sessionId", sessionId);
            message.setContentType("application/json");

            senderClient.sendMessage(message);
            log.info("Order message sent to Service Bus queue '{}' for session: {}", queueName, sessionId);

        } catch (Exception e) {
            log.error("Failed to send order message to Service Bus for session {}: {}",
                    sessionId, e.getMessage(), e);
        }
    }

    public boolean isConfigured() {
        return configured;
    }
}
