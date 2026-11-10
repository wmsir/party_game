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
@Table(name = "direct_messages", indexes = {
    @Index(name = "idx_dm_to_user", columnList = "toUserId"),
    @Index(name = "idx_dm_from_user", columnList = "fromUserId")
})
public class DirectMessageRecord {

    @Id
    @Column(length = 64)
    private String id;

    @Column(nullable = false, length = 64)
    private String fromUserId;

    @Column(length = 64)
    private String fromNickname;

    @Column(length = 32)
    private String fromAvatar;

    @Column(nullable = false, length = 64)
    private String toUserId;

    @Column(length = 1000)
    private String content;

    @Column(length = 32)
    private String inviteRoomCode;

    private Long timestamp;

    @Builder.Default
    private Boolean delivered = false;

    @Builder.Default
    private Boolean isRead = false;

    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (timestamp == null) timestamp = System.currentTimeMillis();
        if (delivered == null) delivered = false;
        if (isRead == null) isRead = false;
    }
}
