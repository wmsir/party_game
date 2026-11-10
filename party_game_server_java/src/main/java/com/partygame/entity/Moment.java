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
@Table(name = "moments", indexes = {
    @Index(name = "idx_moment_created", columnList = "createdAt")
})
public class Moment {

    @Id
    @Column(length = 64)
    private String id;

    @Column(length = 64)
    private String authorId;

    @Column(length = 64)
    private String authorName;

    @Column(length = 32)
    private String authorAvatar;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(length = 64)
    private String gameTag;

    @Column(length = 128)
    private String recordHighlight;

    @Builder.Default
    private Integer likeCount = 0;

    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
