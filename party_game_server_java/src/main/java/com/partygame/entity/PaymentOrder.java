package com.partygame.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "payment_orders", indexes = {
    @Index(name = "idx_order_user_id", columnList = "userId"),
    @Index(name = "idx_order_status", columnList = "status"),
    @Index(name = "idx_order_created_at", columnList = "createdAt")
})
public class PaymentOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false, length = 64)
    private String orderId;

    @Column(nullable = false, length = 64)
    private String userId;

    @Column(length = 64)
    private String tierId;

    @Column(length = 24)
    private String payChannel; // WXPAY, ALIPAY, FIRST_RECHARGE

    private Integer amountRmb;

    private Integer diamondsAward;

    private Integer coinsAward;

    private Integer vipExpAward;

    @Column(length = 24)
    @Builder.Default
    private String status = "PENDING"; // PENDING, PAID, FAILED, REFUNDED

    @Column(length = 128)
    private String tradeNo;

    @Builder.Default
    private Boolean sandboxMode = false;

    private LocalDateTime createdAt;

    private LocalDateTime paidAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (status == null || status.isBlank()) {
            status = "PENDING";
        }
    }
}
