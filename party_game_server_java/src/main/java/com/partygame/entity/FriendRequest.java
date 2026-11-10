package com.partygame.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "friend_requests", indexes = {
    @Index(name = "idx_freq_to_user", columnList = "toUserId,status"),
    @Index(name = "idx_freq_from_user", columnList = "fromUserId")
})
public class FriendRequest {

    @Id
    @Column(length = 64)
    private String id;

    @Column(nullable = false, length = 64)
    private String fromUserId;

    @Column(nullable = false, length = 64)
    private String toUserId;

    @Column(length = 32)
    @Builder.Default
    private String status = "PENDING"; // PENDING, ACCEPTED, REJECTED

    @Column(length = 500)
    private String message;

    private LocalDateTime createdAt;
    private LocalDateTime respondedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
