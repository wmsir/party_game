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
@Table(name = "user_intimacies", indexes = {
    @Index(name = "idx_ui_user1", columnList = "user1Id"),
    @Index(name = "idx_ui_user2", columnList = "user2Id")
}, uniqueConstraints = {
    @UniqueConstraint(name = "uk_user_pair", columnNames = {"user1Id", "user2Id"})
})
public class UserIntimacy {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String user1Id;

    @Column(nullable = false, length = 64)
    private String user2Id;

    @Builder.Default
    private Integer intimacyScore = 0;

    @Column(length = 32)
    private String relationship;

    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    public void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
