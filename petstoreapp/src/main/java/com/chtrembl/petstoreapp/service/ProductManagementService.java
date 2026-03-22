package com.chtrembl.petstoreapp.service;

import com.chtrembl.petstoreapp.client.ProductServiceClient;
import com.chtrembl.petstoreapp.exception.ProductServiceException;
import com.chtrembl.petstoreapp.model.ContainerEnvironment;
import com.chtrembl.petstoreapp.model.Product;
import com.chtrembl.petstoreapp.model.Tag;
import com.chtrembl.petstoreapp.model.User;
import feign.FeignException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.chtrembl.petstoreapp.config.Constants.CATEGORY;
import static com.chtrembl.petstoreapp.config.Constants.OPERATION;
import static com.chtrembl.petstoreapp.config.Constants.REQUEST_ID;
import static com.chtrembl.petstoreapp.config.Constants.TRACE_ID;
import static com.chtrembl.petstoreapp.model.Status.AVAILABLE;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProductManagementService {

    private final User sessionUser;
    private final ContainerEnvironment containerEnvironment;
    private final ProductServiceClient productServiceClient;

    public Collection<Product> getProductsByCategory(String category, List<Tag> tags) {
        List<Product> products;

        MDC.put(OPERATION, "getProducts");
        MDC.put(CATEGORY, category);

        String requestId = MDC.get(REQUEST_ID);
        String traceId = MDC.get(TRACE_ID);

        log.info("Starting product retrieval operation [RequestID: {}, TraceID: {}, Category: {}]",
                requestId, traceId, category);

        try {
            Map<String, String> requestProperties = new HashMap<>(this.sessionUser.getCustomEventProperties());
            requestProperties.put("username", this.sessionUser.getName());
            requestProperties.put("session_Id", this.sessionUser.getSessionId());
            requestProperties.put("category", category);

            this.sessionUser.getTelemetryClient().trackEvent(
                    String.format("PetStoreApp user %s is requesting to retrieve products from the ProductService",
                            this.sessionUser.getName()),
                    requestProperties, null);

            log.info("User '{}' with session '{}' is requesting products for category '{}' [RequestID: {}, TraceID: {}]",
                    this.sessionUser.getName(), this.sessionUser.getSessionId(), category, requestId, traceId);

            products = productServiceClient.getProductsByStatus(AVAILABLE.getValue());
            this.sessionUser.setProducts(products);

            if (tags.stream().anyMatch(t -> t.getName().equals("large"))) {
                products = products.stream()
                        .filter(product -> category.equals(product.getCategory().getName())
                                && product.getTags().toString().contains("large"))
                        .toList();
            } else {
                products = products.stream()
                        .filter(product -> category.equals(product.getCategory().getName())
                                && product.getTags().toString().contains("small"))
                        .toList();
            }

            int productCount = products.size();
            this.sessionUser.getTelemetryClient().trackMetric("ProductsReturned", productCount);
            log.info("Returned {} products to user '{}' for category '{}' with tags {} [RequestID: {}, TraceID: {}]",
                    productCount, this.sessionUser.getName(), category, tags, requestId, traceId);

            Map<String, String> resultProperties = new HashMap<>(this.sessionUser.getCustomEventProperties());
            resultProperties.put("username", this.sessionUser.getName());
            resultProperties.put("session_Id", this.sessionUser.getSessionId());
            resultProperties.put("category", category);
            Map<String, Double> resultMetrics = new HashMap<>();
            resultMetrics.put("productsReturnedCount", (double) productCount);

            this.sessionUser.getTelemetryClient().trackEvent(
                    String.format("PetStoreApp user %s retrieved %d products for category %s",
                            this.sessionUser.getName(), productCount, category),
                    resultProperties, resultMetrics);

            return products;
        } catch (FeignException fe) {
            log.error("Feign error retrieving products [RequestID: {}, TraceID: {}, Category: {}, HTTP: {}, Message: {}]",
                    requestId, traceId, category, fe.status(), fe.getMessage(), fe);

            this.sessionUser.getTelemetryClient().trackException(fe);
            this.sessionUser.getTelemetryClient().trackEvent(
                    String.format("PetStoreApp %s received Feign error %s (HTTP %d), container host: %s",
                            this.sessionUser.getName(),
                            fe.getMessage(),
                            fe.status(),
                            this.containerEnvironment.getContainerHostName())
            );
            log.error("Failed to retrieve products from ProductService via Feign client", fe);
            throw new ProductServiceException("Unable to retrieve products from product service", fe);
        } finally {
            MDC.remove(OPERATION);
            MDC.remove(CATEGORY);
        }
    }
}
