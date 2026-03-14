package com.chtrembl.petstore.order;

import com.microsoft.applicationinsights.attach.ApplicationInsights;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class OrderServiceApplication {

    private static final Logger logger = LoggerFactory.getLogger(OrderServiceApplication.class);

    public static void main(String[] args) {
        configureApplicationInsights();
        SpringApplication.run(OrderServiceApplication.class, args);
    }

    private static void configureApplicationInsights() {
        String connectionString = System.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING");
        if (connectionString != null && !connectionString.isEmpty()) {
            try {
                ApplicationInsights.attach();
                logger.info("Application Insights enabled successfully for petstoreorderservice");
            } catch (Exception e) {
                logger.warn("Failed to attach Application Insights: {}", e.getMessage());
            }
        } else {
            logger.info("Application Insights not configured (no connection string). Set APPLICATIONINSIGHTS_CONNECTION_STRING to enable.");
        }
    }
}