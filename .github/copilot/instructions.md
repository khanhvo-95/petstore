# Copilot Instructions for PetStore Project

## Project Overview
A microservices-based PetStore application deployed on **Azure Container Apps** in Southeast Asia region.

## Architecture
| Service | Type | Port | Description |
|---------|------|------|-------------|
| `petstoreapp` | Spring Boot Web UI | 8080 | Main frontend + B2C auth |
| `petstorepetservice` | Spring Boot REST API | 8080 | Pet CRUD operations |
| `petstoreproductservice` | Spring Boot REST API | 8080 | Product catalog |
| `petstoreorderservice` | Spring Boot REST API | 8080 | Order management |
| `petstoreorderitemsreserver` | Azure Function (Java) | 80 | Order reservation → Blob Storage |

## Tech Stack
- **Language:** Java 17, Spring Boot 3.x
- **Build:** Maven (`mvn clean package -DskipTests`)
- **Containers:** Docker/Podman → Azure Container Registry
- **Cloud:** Azure Container Apps, ACR, Blob Storage, Application Insights
- **IaC:** Terraform (`/terraform`), Bash scripts (`/scripts`)
- **Auth:** Azure AD B2C (OAuth2)
- **Monitoring:** Application Insights (Java agent auto-attach)
- **Load Testing:** k6 (`/k6-load-tests`)

## Azure Resources
- **Subscription:** `06fea321-1582-4bd7-bf0c-53376f2660a6` (Subscription 1)
- **Region:** Southeast Asia
- **Resource Group:** `demo-rg`
- **Container Registry:** `vodemopetstoreappcontainer.azurecr.io`
- **Container Apps Environment:** `demo-container-app-env`

## Key Environment Variables
| Variable | Used By | Description |
|----------|---------|-------------|
| `PETSTOREPETSERVICE_URL` | petstoreapp | URL of Pet Service |
| `PETSTOREPRODUCTSERVICE_URL` | petstoreapp | URL of Product Service |
| `PETSTOREORDERSERVICE_URL` | petstoreapp | URL of Order Service |
| `PETSTOREORDERITEMSRESERVER_URL` | petstoreorderservice | URL of Order Items Reserver |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | all services | App Insights connection |

## Coding Conventions
- Use `application.yml` (not `.properties`) for Spring Boot config
- Each service has its own `Dockerfile` in its root directory
- Docker images tagged as `v1`, `v2`, `latest`
- Telemetry tracked via `PetStoreTelemetryClient` class using custom events/properties
- Session tracking uses `sessionId` in customDimensions for App Insights queries
- REST APIs documented with Swagger/OpenAPI

## When Generating Code
- Always use Java 17+ features (records, text blocks, pattern matching)
- Use Spring Boot 3.x conventions (Jakarta namespace, not javax)
- Include proper error handling with logging (SLF4J)
- Track custom events via Application Insights for observability
- Use environment variables for all external URLs and secrets (never hardcode)

## When Working with Azure
- Always target `southeastasia` region
- Use resource group `demo-rg`
- ACR: `vodemopetstoreappcontainer.azurecr.io`
- Use Terraform for infrastructure changes when possible
- Container Apps use HTTP ingress with port 8080 (except Azure Function on 80)
