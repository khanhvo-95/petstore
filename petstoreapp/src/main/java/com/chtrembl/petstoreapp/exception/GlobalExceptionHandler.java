package com.chtrembl.petstoreapp.exception;

import com.chtrembl.petstoreapp.model.User;
import com.chtrembl.petstoreapp.telemetry.PetStoreTelemetryClient;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.servlet.ModelAndView;

import java.util.HashMap;
import java.util.Map;

/**
 * Global exception handler that catches all unhandled exceptions,
 * tracks them in Application Insights, and returns the error page.
 * <p>
 * Without this, Spring Boot's default error handling (BasicErrorController)
 * swallows exceptions silently — they render the error page but never call
 * trackException(), so exceptions don't appear in App Insights Failures tab.
 */
@ControllerAdvice
@RequiredArgsConstructor
@Slf4j
public class GlobalExceptionHandler {

    private final User sessionUser;

    @ExceptionHandler(Exception.class)
    public ModelAndView handleAllExceptions(Exception ex, HttpServletRequest request) {
        log.error("Unhandled exception on [{}] {}: {}",
                request.getMethod(), request.getRequestURI(), ex.getMessage(), ex);

        // Explicitly track the exception in Application Insights
        try {
            PetStoreTelemetryClient telemetryClient = sessionUser.getTelemetryClient();
            if (telemetryClient != null) {
                Map<String, String> properties = new HashMap<>();
                properties.put("requestUri", request.getRequestURI());
                properties.put("requestMethod", request.getMethod());
                properties.put("queryString", request.getQueryString() != null ? request.getQueryString() : "");
                properties.put("session_Id", sessionUser.getSessionId() != null ? sessionUser.getSessionId() : "unknown");
                properties.put("username", sessionUser.getName() != null ? sessionUser.getName() : "unknown");

                telemetryClient.trackException(ex, properties, null);
                telemetryClient.flush();

                log.info("Exception tracked in Application Insights: {}", ex.getMessage());
            }
        } catch (Exception trackingEx) {
            log.warn("Failed to track exception in Application Insights: {}", trackingEx.getMessage());
        }

        // Return the error page with HTTP 500 status
        ModelAndView mav = new ModelAndView("error");
        mav.setStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        mav.addObject("status", 500);
        mav.addObject("error", "Internal Server Error");
        mav.addObject("message", ex.getMessage());
        return mav;
    }
}

