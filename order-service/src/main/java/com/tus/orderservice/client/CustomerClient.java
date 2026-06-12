package com.tus.orderservice.client;

import com.tus.orderservice.dto.CustomerDTO;
import com.tus.orderservice.exception.ResourceNotFoundException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

/**
 * HTTP client that calls customer-service to validate a customer exists.
 * The base URL is configured via 'customer.service.url' and can be
 * overridden by the CUSTOMER_SERVICE_URL environment variable in Docker/K8s.
 */
@Component
public class CustomerClient {

    private final RestTemplate restTemplate;

    @Value("${customer.service.url}")
    private String customerServiceUrl;

    public CustomerClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /**
     * Fetches a customer from customer-service.
     *
     * @throws ResourceNotFoundException if the customer does not exist (404)
     */
    public CustomerDTO getCustomerById(Long customerId) {
        try {
            return restTemplate.getForObject(
                    customerServiceUrl + "/customer/" + customerId,
                    CustomerDTO.class
            );
        } catch (HttpClientErrorException.NotFound e) {
            throw new ResourceNotFoundException("Customer not found with id: " + customerId);
        }
    }
}
