package com.tus.customerservice.controller;

import java.time.LocalDate;
import java.util.UUID;

import org.junit.jupiter.api.AfterEach;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.tus.customerservice.entity.Customer;
import com.tus.customerservice.repository.CustomerRepository;

@SpringBootTest
@ActiveProfiles("test")
class CustomerControllerIntegrationTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    @Autowired
    private CustomerRepository customerRepository;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @AfterEach
    void cleanUp() {
        customerRepository.deleteAll();
    }

    @Test
    void createCustomer_shouldPersistAndReturnCustomer() throws Exception {
        String email = "priyanka-" + UUID.randomUUID() + "@example.com";

        String requestBody = """
            {
              "name": "Priyanka",
              "email": "%s"
            }
            """.formatted(email);

        // New controller returns 201 CREATED
        mockMvc.perform(post("/customer/createcustomer")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isCreated())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.name").value("Priyanka"))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.createdAt").exists());

        assertTrue(
            customerRepository.findAll().stream()
                .anyMatch(savedCustomer -> "Priyanka".equals(savedCustomer.getName()))
        );
    }

    @Test
    void getCustomer_shouldReturnExistingCustomer() throws Exception {
        Customer customer = new Customer();
        customer.setName("Alice");
        customer.setEmail("alice-" + UUID.randomUUID() + "@example.com");
        customer.setCreatedAt(LocalDate.now());
        Customer saved = customerRepository.save(customer);

        mockMvc.perform(get("/customer/" + saved.getId()))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(saved.getId()))
                .andExpect(jsonPath("$.name").value("Alice"))
                .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void deleteCustomer_shouldRemoveCustomer() throws Exception {
        Customer customer = new Customer();
        customer.setName("Bob");
        customer.setEmail("bob-" + UUID.randomUUID() + "@example.com");
        customer.setCreatedAt(LocalDate.now());
        Customer saved = customerRepository.save(customer);

        mockMvc.perform(delete("/customer/delete/" + saved.getId()))
                .andExpect(status().isOk())
                .andExpect(content().string("Customer deleted successfully"));

        assertFalse(customerRepository.existsById(saved.getId()));
    }

    @Test
    void getAllCustomers_shouldReturnAllCustomers() throws Exception {
        Customer customer1 = new Customer();
        customer1.setName("John");
        customer1.setEmail("john-" + UUID.randomUUID() + "@example.com");
        customer1.setCreatedAt(LocalDate.now());
        customerRepository.save(customer1);

        Customer customer2 = new Customer();
        customer2.setName("Jane");
        customer2.setEmail("jane-" + UUID.randomUUID() + "@example.com");
        customer2.setCreatedAt(LocalDate.now());
        customerRepository.save(customer2);

        mockMvc.perform(get("/customer/customers"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2));

        long customerCount = customerRepository.count();
        assertEquals(2, customerCount);
    }
}
