package com.chtrembl.petstore.order.service;

import com.chtrembl.petstore.order.exception.OrderNotFoundException;
import com.chtrembl.petstore.order.model.Order;
import com.chtrembl.petstore.order.model.Product;
import com.chtrembl.petstore.order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@Slf4j
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ProductService productService;

    public Order createOrder(String orderId) {
        log.info("Creating new order with id: {} and saving to Cosmos DB", orderId);
        Order order = Order.builder()
                .id(orderId)
                .products(new ArrayList<>())
                .status(Order.Status.PLACED)
                .complete(false)
                .build();
        return orderRepository.save(order);
    }

    public Order getOrderById(String orderId) {
        log.info("Retrieving order from Cosmos DB: {}", orderId);

        if (orderId == null || orderId.trim().isEmpty()) {
            throw new IllegalArgumentException("Order ID cannot be null or empty");
        }

        return orderRepository.findById(orderId)
                .orElseThrow(() -> {
                    log.warn("Order not found: {}", orderId);
                    return new OrderNotFoundException("Order with ID " + orderId + " not found");
                });
    }

    public Order getOrCreateOrder(String orderId) {
        log.info("Getting or creating order: {}", orderId);
        Optional<Order> existing = orderRepository.findById(orderId);
        if (existing.isPresent()) {
            log.info("Found existing order: {}", orderId);
            return existing.get();
        }
        log.info("Creating new order: {}", orderId);
        return createOrder(orderId);
    }

    public Order updateOrder(Order order) {
        log.info("Updating order: {}", order.getId());

        if (order.getProducts() != null && !order.getProducts().isEmpty()) {
            List<Product> availableProducts = productService.getAvailableProducts();
            validateProductsExist(order.getProducts(), availableProducts);
        }

        Order existingOrder = getOrCreateOrder(order.getId());

        existingOrder.setEmail(order.getEmail());

        if (order.getStatus() != null) {
            existingOrder.setStatus(order.getStatus());
        }

        Boolean isComplete = order.getComplete();
        if (isComplete != null && isComplete) {
            log.info("Completing order {} - clearing products", order.getId());
            existingOrder.setProducts(new ArrayList<>());
            existingOrder.setComplete(true);
        } else {
            existingOrder.setComplete(isComplete != null ? isComplete : false);
            updateOrderProducts(existingOrder, order.getProducts());
        }

        return orderRepository.save(existingOrder);
    }

    private void validateProductsExist(List<Product> orderProducts, List<Product> availableProducts) {
        if (orderProducts == null || orderProducts.isEmpty()) {
            return;
        }

        List<Long> requestedProductIds = orderProducts.stream()
                .map(Product::getId)
                .filter(id -> id != null)
                .collect(Collectors.toList());

        List<Long> availableProductIds = availableProducts.stream()
                .map(Product::getId)
                .filter(id -> id != null)
                .collect(Collectors.toList());

        List<Long> missingProductIds = requestedProductIds.stream()
                .filter(id -> !availableProductIds.contains(id))
                .collect(Collectors.toList());

        if (!missingProductIds.isEmpty()) {
            String errorMessage = String.format("Products with IDs %s are not available or do not exist",
                    missingProductIds);
            log.warn("Product validation failed for order: {}", errorMessage);
            throw new IllegalArgumentException(errorMessage);
        }
    }

    private void updateOrderProducts(Order existingOrder, List<Product> incomingProducts) {
        if (incomingProducts == null || incomingProducts.isEmpty()) {
            return;
        }

        if (incomingProducts.size() == 1) {
            handleSingleProductUpdate(existingOrder, incomingProducts.getFirst());
        } else {
            existingOrder.setProducts(new ArrayList<>(incomingProducts));
        }
    }

    private void handleSingleProductUpdate(Order existingOrder, Product incomingProduct) {
        List<Product> existingProducts = existingOrder.getProducts();
        if (existingProducts == null) {
            existingProducts = new ArrayList<>();
            existingOrder.setProducts(existingProducts);
        }

        Integer quantity = incomingProduct.getQuantity();

        Optional<Product> existingProductOpt = existingProducts.stream()
                .filter(p -> p.getId().equals(incomingProduct.getId()))
                .findFirst();

        if (existingProductOpt.isPresent()) {
            Product existingProduct = existingProductOpt.get();
            int currentQuantity = existingProduct.getQuantity();
            int newQuantity = currentQuantity + quantity;

            if (newQuantity <= 0) {
                existingProducts.removeIf(p -> p.getId().equals(incomingProduct.getId()));
            } else if (newQuantity <= 10) {
                existingProduct.setQuantity(newQuantity);
            } else {
                existingProduct.setQuantity(10);
            }
        } else {
            if (quantity > 0) {
                int finalQuantity = Math.min(quantity, 10);
                existingProducts.add(Product.builder()
                        .id(incomingProduct.getId())
                        .quantity(finalQuantity)
                        .name(incomingProduct.getName())
                        .photoURL(incomingProduct.getPhotoURL())
                        .build());
            }
        }
    }

    public void enrichOrderWithProductDetails(Order order, List<Product> availableProducts) {
        if (order.getProducts() == null || availableProducts == null) {
            return;
        }

        for (Product orderProduct : order.getProducts()) {
            Optional<Product> foundProduct = availableProducts.stream()
                    .filter(p -> p.getId().equals(orderProduct.getId()))
                    .findFirst();

            if (foundProduct.isPresent()) {
                Product availableProduct = foundProduct.get();
                orderProduct.setName(availableProduct.getName());
                orderProduct.setPhotoURL(availableProduct.getPhotoURL());
            }
        }
    }
}
