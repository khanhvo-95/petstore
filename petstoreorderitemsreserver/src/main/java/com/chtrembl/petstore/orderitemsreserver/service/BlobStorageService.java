package com.chtrembl.petstore.orderitemsreserver.service;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import com.azure.storage.blob.models.BlobHttpHeaders;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Service for uploading order reservation JSON files to Azure Blob Storage.
 *
 * Configuration via environment variables:
 *   - BLOB_STORAGE_CONNECTION_STRING : full connection string (preferred for simplicity)
 *   - BLOB_STORAGE_ENDPOINT          : storage account endpoint (used with Managed Identity)
 *   - BLOB_STORAGE_CONTAINER_NAME    : container name (default: "orderitemsreserver")
 */
public class BlobStorageService {

    private static final String DEFAULT_CONTAINER_NAME = "orderitemsreserver";

    private final BlobContainerClient containerClient;
    private final Logger logger;

    public BlobStorageService(Logger logger) {
        this.logger = logger;

        String connectionString = System.getenv("BLOB_STORAGE_CONNECTION_STRING");
        String endpoint = System.getenv("BLOB_STORAGE_ENDPOINT");
        String containerName = System.getenv("BLOB_STORAGE_CONTAINER_NAME");

        if (containerName == null || containerName.isBlank()) {
            containerName = DEFAULT_CONTAINER_NAME;
        }

        BlobServiceClient serviceClient;

        if (connectionString != null && !connectionString.isBlank()) {
            // Option 1: Connection string (simplest, works everywhere)
            logger.info("BlobStorageService: Using connection string authentication");
            serviceClient = new BlobServiceClientBuilder()
                    .connectionString(connectionString)
                    .buildClient();
        } else if (endpoint != null && !endpoint.isBlank()) {
            // Option 2: Managed Identity / DefaultAzureCredential
            logger.info("BlobStorageService: Using DefaultAzureCredential with endpoint: " + endpoint);
            serviceClient = new BlobServiceClientBuilder()
                    .endpoint(endpoint)
                    .credential(new DefaultAzureCredentialBuilder().build())
                    .buildClient();
        } else {
            throw new IllegalStateException(
                    "Azure Blob Storage is not configured. " +
                    "Set either BLOB_STORAGE_CONNECTION_STRING or BLOB_STORAGE_ENDPOINT environment variable.");
        }

        this.containerClient = serviceClient.getBlobContainerClient(containerName);

        // Create container if it doesn't exist
        if (!containerClient.exists()) {
            containerClient.create();
            logger.info("BlobStorageService: Created container '" + containerName + "'");
        } else {
            logger.info("BlobStorageService: Using existing container '" + containerName + "'");
        }
    }

    /**
     * Uploads a JSON string as a blob to Azure Blob Storage.
     *
     * @param blobName the name of the blob (e.g., "orders/order-ABC123-2026-03-22T10-30-00.json")
     * @param jsonContent the JSON content to upload
     */
    public void uploadOrderJson(String blobName, String jsonContent) {
        try {
            BlobClient blobClient = containerClient.getBlobClient(blobName);

            byte[] bytes = jsonContent.getBytes(StandardCharsets.UTF_8);
            ByteArrayInputStream inputStream = new ByteArrayInputStream(bytes);

            blobClient.upload(inputStream, bytes.length, true);

            // Set content type to application/json
            blobClient.setHttpHeaders(new BlobHttpHeaders().setContentType("application/json"));

            logger.info("BlobStorageService: Successfully uploaded blob '" + blobName
                    + "' (" + bytes.length + " bytes)");

        } catch (Exception e) {
            logger.log(Level.SEVERE, "BlobStorageService: Failed to upload blob '" + blobName + "'", e);
            throw new RuntimeException("Failed to upload order JSON to Blob Storage: " + e.getMessage(), e);
        }
    }
}

