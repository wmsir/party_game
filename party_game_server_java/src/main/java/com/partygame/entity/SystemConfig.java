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
@Table(name = "system_configs", indexes = {
    @Index(name = "idx_cfg_key", columnList = "configKey", unique = true)
})
public class SystemConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 64)
    private String configKey;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String configValue;

    @Column(length = 256)
    private String description;

    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    public void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
