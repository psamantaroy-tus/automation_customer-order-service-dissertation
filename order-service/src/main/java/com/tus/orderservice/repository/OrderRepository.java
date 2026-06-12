package com.tus.orderservice.repository;

import com.tus.orderservice.entity.Order;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;

public interface OrderRepository extends JpaRepository<Order, Long> {

    List<Order> findByCustomerId(Long customerId);

    List<Order> findByOrderDateBetween(LocalDate startDate, LocalDate endDate);

    Page<Order> findAll(Pageable pageable);
}
