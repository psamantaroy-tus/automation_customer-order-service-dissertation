package com.tus.orderservice.service;

import com.tus.orderservice.client.CustomerClient;
import com.tus.orderservice.dto.OrderCreateDTO;
import com.tus.orderservice.dto.OrderDTO;
import com.tus.orderservice.entity.Order;
import com.tus.orderservice.exception.ResourceNotFoundException;
import com.tus.orderservice.repository.OrderRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final CustomerClient customerClient;

    public OrderService(OrderRepository orderRepository, CustomerClient customerClient) {
        this.orderRepository = orderRepository;
        this.customerClient = customerClient;
    }

    // 1) Create order — verifies customer exists via REST call to customer-service
    public OrderDTO createOrder(Long customerId, OrderCreateDTO dto) {
        customerClient.getCustomerById(customerId); // throws ResourceNotFoundException if not found

        Order order = new Order();
        order.setCustomerId(customerId);
        order.setOrderDate(dto.getOrderDate());
        order.setAmount(dto.getAmount());

        return convertToDTO(orderRepository.save(order));
    }

    // 2) Get all orders for a customer
    public List<OrderDTO> getOrdersByCustomer(Long customerId) {
        customerClient.getCustomerById(customerId); // validate customer exists
        return orderRepository.findByCustomerId(customerId)
                .stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    // 3) Update existing order
    public OrderDTO updateOrder(Long orderId, OrderCreateDTO dto) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found with id: " + orderId));
        order.setOrderDate(dto.getOrderDate());
        order.setAmount(dto.getAmount());
        return convertToDTO(orderRepository.save(order));
    }

    // 4) Delete order
    public void deleteOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("Order not found with id: " + orderId));
        orderRepository.delete(order);
    }

    // 5) Filter orders by date range
    public List<OrderDTO> getOrdersByDateRange(LocalDate start, LocalDate end) {
        return orderRepository.findByOrderDateBetween(start, end)
                .stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    // 6) Paginated orders
    public Page<OrderDTO> getPaginatedOrders(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        return orderRepository.findAll(pageable).map(this::convertToDTO);
    }

    private OrderDTO convertToDTO(Order order) {
        return new OrderDTO(
                order.getId(),
                order.getOrderDate(),
                order.getAmount(),
                order.getCustomerId()
        );
    }
}
