package com.chtrembl.petstore.orderitemsreserver.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class Order {

    @JsonProperty("id")
    private String id;

    @JsonProperty("email")
    private String email;

    @JsonProperty("products")
    @Builder.Default
    private List<Product> products = new ArrayList<>();

    @JsonProperty("status")
    private Status status;

    @JsonProperty("complete")
    @Builder.Default
    private Boolean complete = false;

    public List<Product> getProducts() {
        return products != null ? products : new ArrayList<>();
    }

    public Boolean getComplete() {
        return complete != null ? complete : false;
    }

    public enum Status {
        PLACED("placed"),
        APPROVED("approved"),
        DELIVERED("delivered");

        private final String value;

        Status(String value) {
            this.value = value;
        }

        @Override
        @JsonValue
        public String toString() {
            return String.valueOf(value);
        }

        @JsonCreator
        public static Status fromValue(String text) {
            if (text == null) return null;
            for (Status s : Status.values()) {
                if (s.value.equalsIgnoreCase(text.trim())) return s;
            }
            return null;
        }
    }
}

