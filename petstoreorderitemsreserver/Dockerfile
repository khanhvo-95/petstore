# =============================================================================
# Dockerfile for OrderItemsReserver Azure Function (Java 21, Container Deploy)
# =============================================================================

# --- Stage 1: Build ---
FROM maven:3.9.9-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# --- Stage 2: Runtime (Azure Functions custom container) ---
FROM mcr.microsoft.com/azure-functions/java:4-java21
WORKDIR /home/site/wwwroot

# Copy the function app output (compiled classes + dependencies)
COPY --from=build /app/target/azure-functions/petstore-orderitemsreserver/ /home/site/wwwroot

# Copy Application Insights config
COPY --from=build /app/src/main/resources/applicationinsights.json /home/site/wwwroot/applicationinsights.json

# Azure Functions environment variables
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

EXPOSE 80

