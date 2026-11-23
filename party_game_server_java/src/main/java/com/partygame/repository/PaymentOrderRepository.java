package com.partygame.repository;

import com.partygame.entity.PaymentOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, Long> {

    Optional<PaymentOrder> findByOrderId(String orderId);

    Page<PaymentOrder> findAllByOrderByCreatedAtDesc(Pageable pageable);

    Page<PaymentOrder> findByStatusOrderByCreatedAtDesc(String status, Pageable pageable);

    long countByStatus(String status);

    @Query("SELECT COALESCE(SUM(o.amountRmb), 0) FROM PaymentOrder o WHERE o.status = 'PAID'")
    Long sumPaidRevenueRmb();

    @Query("SELECT COALESCE(SUM(o.amountRmb), 0) FROM PaymentOrder o WHERE o.status = 'PAID' AND o.paidAt >= :since")
    Long sumPaidRevenueRmbSince(@Param("since") LocalDateTime since);
}
