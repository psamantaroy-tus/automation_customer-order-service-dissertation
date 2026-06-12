package com.tus.orderservice.config;

import com.tus.orderservice.entity.Order;
import com.tus.orderservice.repository.OrderRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/**
 * Loads seed data into order_db on application startup.
 * Idempotent: only inserts if the table is empty.
 *
 * Customer IDs 1-5 correspond to seed data in customer-service.
 */
@Component
@Profile("!test")  // Do not run seed data during tests
public class DataLoader implements ApplicationRunner {

    private final OrderRepository orderRepository;

    public DataLoader(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (orderRepository.count() == 0) {
            // Alice (customerId=1) - 2 orders
            orderRepository.save(new Order(null, LocalDate.of(2025, 1, 15),  149.99, 1L));
            orderRepository.save(new Order(null, LocalDate.of(2025, 3, 10),   59.00, 1L));

            // Bob (customerId=2) - 2 orders
            orderRepository.save(new Order(null, LocalDate.of(2025, 2, 20),  299.50, 2L));
            orderRepository.save(new Order(null, LocalDate.of(2025, 6, 1),    19.99, 2L));

            // Carol (customerId=3) - 1 order
            orderRepository.save(new Order(null, LocalDate.of(2025, 4, 5),   500.00, 3L));

            // David (customerId=4) - 2 orders
            orderRepository.save(new Order(null, LocalDate.of(2025, 11, 11), 120.00, 4L));
            orderRepository.save(new Order(null, LocalDate.of(2026, 1, 22),   75.25, 4L));

            // Eva (customerId=5) - 1 order
            orderRepository.save(new Order(null, LocalDate.of(2026, 5, 30),  999.00, 5L));

            System.out.println("[order-service] Seed data loaded: 8 orders.");
        } else {
            System.out.println("[order-service] Seed data already present, skipping.");
        }
    }
}
