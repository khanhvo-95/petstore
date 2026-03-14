FROM maven:3.9.9-eclipse-temurin-21-alpine AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Download Application Insights Java agent (using wget for reliability in cloud builds)
RUN wget -q -O applicationinsights-agent.jar \
    "https://github.com/microsoft/ApplicationInsights-Java/releases/download/3.7.1/applicationinsights-agent-3.7.1.jar" \
    && ls -la applicationinsights-agent.jar

COPY --from=build /app/target/*.jar app.jar
COPY --from=build /app/src/main/resources/applicationinsights.json applicationinsights.json

EXPOSE 8080
CMD ["java", "-javaagent:applicationinsights-agent.jar", "-jar", "app.jar"]
