package com.tus.orderservice.dto;

import java.time.LocalDate;

/**
 * Represents the response returned by customer-service GET /customer/{id}.
 * Used only for deserialising the HTTP response in CustomerClient.
 */
public class CustomerDTO {

    private Long id;
    private String name;
    private String email;
    private LocalDate createdAt;

    public CustomerDTO() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public LocalDate getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDate createdAt) { this.createdAt = createdAt; }
}
