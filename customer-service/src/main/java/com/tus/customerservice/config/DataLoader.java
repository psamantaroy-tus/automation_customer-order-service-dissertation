package com.tus.customerservice.config;

import java.time.LocalDate;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import com.tus.customerservice.entity.Customer;
import com.tus.customerservice.repository.CustomerRepository;

/**
 * Loads seed data into customer_db on application startup.
 * Idempotent: only inserts if the table is empty.
 */
@Component
@Profile("!test")  // Do not run seed data during tests
public class DataLoader implements ApplicationRunner {

    private final CustomerRepository customerRepository;

    public DataLoader(CustomerRepository customerRepository) {
        this.customerRepository = customerRepository;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (customerRepository.count() == 0) {
            customerRepository.save(new Customer(null, "Alice Johnson",  "alice@example.com",  LocalDate.of(2024, 1, 10)));
            customerRepository.save(new Customer(null, "Bob Smith",      "bob@example.com",    LocalDate.of(2024, 3, 22)));
            customerRepository.save(new Customer(null, "Carol White",    "carol@example.com",  LocalDate.of(2024, 6, 5)));
            customerRepository.save(new Customer(null, "David Brown",    "david@example.com",  LocalDate.of(2025, 2, 14)));
            customerRepository.save(new Customer(null, "Eva Martinez",   "eva@example.com",    LocalDate.of(2025, 9, 30)));
            System.out.println("[customer-service] Seed data loaded: 5 customers.");
        } else {
            System.out.println("[customer-service] Seed data already present, skipping.");
        }
    }
}
