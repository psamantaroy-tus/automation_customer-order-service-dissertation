package com.tus.customerservice.service;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.tus.customerservice.dto.CustomerCreateDTO;
import com.tus.customerservice.dto.CustomerDTO;
import com.tus.customerservice.entity.Customer;
import com.tus.customerservice.repository.CustomerRepository;

@ExtendWith(MockitoExtension.class)
public class CustomerService_UnitTest {

    @Mock
    private CustomerRepository customerRepository;

    private CustomerService customerService;

    @BeforeEach
    public void setUp() {
        customerService = new CustomerService(customerRepository);
    }

    @Test //TEST1
    public void testCreateCustomer_savesAndReturnsDTO() {
        CustomerCreateDTO dto = new CustomerCreateDTO();
        dto.setName("Alice");
        dto.setEmail("alice@example.com");

        Customer saved = new Customer();
        saved.setId(1L);
        saved.setName("Alice");
        saved.setEmail("alice@example.com");
        saved.setCreatedAt(LocalDate.now());

        when(customerRepository.save(any(Customer.class))).thenReturn(saved);

        CustomerDTO result = customerService.createCustomer(dto);

        assertNotNull(result);
        assertEquals(1L, result.getId());
        assertEquals("Alice", result.getName());
        assertNotNull(result.getCreatedAt());
        verify(customerRepository, times(1)).save(any(Customer.class));
    }

    @Test //TEST2
    public void testGetCustomer_found_returnsDTO() {
        Customer customer = new Customer();
        customer.setId(2L);
        customer.setName("Bob");
        customer.setEmail("bob@example.com");
        customer.setCreatedAt(LocalDate.of(2024, 1, 1));
        when(customerRepository.findById(2L)).thenReturn(Optional.of(customer));

        CustomerDTO dto = customerService.getCustomer(2L);

        assertNotNull(dto);
        assertEquals(2L, dto.getId());
        assertEquals("Bob", dto.getName());
        assertEquals(LocalDate.of(2024, 1, 1), dto.getCreatedAt());
        verify(customerRepository, times(1)).findById(2L);
    }

    @Test //TEST3 NEGATIVE TEST
    public void testGetCustomer_notFound_throws() {
        when(customerRepository.findById(99L)).thenReturn(Optional.empty());
        assertThrows(RuntimeException.class, () -> customerService.getCustomer(99L));
        verify(customerRepository, times(1)).findById(99L);
    }

    @Test //TEST4
    public void testGetAllCustomers_returnsList() {
        Customer c1 = new Customer();
        c1.setId(10L);
        c1.setName("C1");
        c1.setEmail("c1@example.com");
        c1.setCreatedAt(LocalDate.now());

        Customer c2 = new Customer();
        c2.setId(11L);
        c2.setName("C2");
        c2.setEmail("c2@example.com");
        c2.setCreatedAt(LocalDate.now());

        when(customerRepository.findAll()).thenReturn(Arrays.asList(c1, c2));

        List<CustomerDTO> list = customerService.getAllCustomers();

        assertEquals(2, list.size());
        assertEquals(10L, list.get(0).getId());
        assertEquals("C1", list.get(0).getName());
        assertEquals(11L, list.get(1).getId());
        verify(customerRepository, times(1)).findAll();
    }

    @Test //TEST5
    public void testDeleteCustomer_exists_deletes() {
        when(customerRepository.existsById(5L)).thenReturn(true);

        customerService.deleteCustomer(5L);

        verify(customerRepository, times(1)).existsById(5L);
        verify(customerRepository, times(1)).deleteById(5L);
    }

    @Test //TEST6 NEGATIVE TEST
    public void testDeleteCustomer_notFound_throws() {
        when(customerRepository.existsById(6L)).thenReturn(false);

        assertThrows(RuntimeException.class, () -> customerService.deleteCustomer(6L));

        verify(customerRepository, times(1)).existsById(6L);
        verify(customerRepository, never()).deleteById(anyLong());
    }

    @Test //TEST7 NEGATIVE TEST
    public void testCreateCustomer_nullName_throws() {
        // save returns null → convertToDTO(null) throws NullPointerException (RuntimeException)
        when(customerRepository.save(any(Customer.class))).thenReturn(null);

        CustomerCreateDTO dto = new CustomerCreateDTO();
        dto.setName(null);
        dto.setEmail("test@example.com");

        assertThrows(RuntimeException.class, () -> customerService.createCustomer(dto));
    }
}
