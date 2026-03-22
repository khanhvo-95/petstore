package com.chtrembl.petstore.orderitemsreserver.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties(ignoreUnknown = true)
public class Product {

    @JsonProperty("id")
    private Long id;

    @JsonProperty("name")
    private String name;

    @JsonProperty("quantity")
    @Builder.Default
    private Integer quantity = 0;

    @JsonProperty("photoURL")
    private String photoURL;

    public Integer getQuantity() {
        return quantity != null ? quantity : 0;
    }
}

