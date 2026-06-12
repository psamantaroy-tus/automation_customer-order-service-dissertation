package com.tus.customerservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.tus.customerservice.entity.Customer;

public interface CustomerRepository extends JpaRepository<Customer, Long> {
}
