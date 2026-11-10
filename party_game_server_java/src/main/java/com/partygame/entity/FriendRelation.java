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
@Table(name = "friend_relations", indexes = {
    @Index(name = "idx_fr_user_id", columnList = "userId"),
    @Index(name = "idx_fr_friend_id", columnList = "friendId")
}, uniqueConstraints = {
    @UniqueConstraint(name = "uk_user_friend", columnNames = {"userId", "friendId"})
})
public class FriendRelation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String userId;

    @Column(nullable = false, length = 64)
    private String friendId;

    @Column(length = 64)
    private String remark;

    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
