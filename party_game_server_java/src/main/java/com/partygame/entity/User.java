package com.partygame.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;
import com.fasterxml.jackson.annotation.JsonSetter;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_user_phone", columnList = "phone"),
    @Index(name = "idx_user_username", columnList = "username"),
    @Index(name = "idx_user_rank_score", columnList = "rankScore")
})
public class User {

    @Id
    @Column(length = 64)
    private String id;

    @Column(length = 64)
    private String username;

    @Column(length = 64)
    private String nickname;

    @Column(length = 32)
    private String phone;

    @Column(length = 128)
    private String password;

    @Column(length = 32)
    private String avatar;

    @Column(length = 64)
    private String levelTitle;

    @Builder.Default
    private Long coins = 2000L;

    @Builder.Default
    private Long diamonds = 50L;

    @Builder.Default
    private Integer vipLevel = 0;

    @Builder.Default
    private Integer vipExp = 0;

    @Builder.Default
    private Integer rankScore = 1200;

    @Column(length = 32)
    @Builder.Default
    private String rankTier = "黄金II";

    @Builder.Default
    private Integer stamina = 100;

    @Builder.Default
    private Integer winCount = 0;

    @Builder.Default
    private Integer totalGames = 0;

    @Builder.Default
    private Boolean isGuest = false;

    @Column(length = 64)
    @Builder.Default
    private String avatarFrame = "FRAME_DEFAULT";

    @Column(length = 64)
    @Builder.Default
    private String entranceBanner = "BANNER_DEFAULT";

    @Column(length = 64)
    @Builder.Default
    private String diceCupSkin = "CLASSIC_GOLD";

    @Column(length = 64)
    @Builder.Default
    private String chatTextColor = "COLOR_DEFAULT";

    @Column(columnDefinition = "TEXT")
    private String inventory; // JSON array string e.g. ["CLASSIC_GOLD","FRAME_DEFAULT"]

    @JsonSetter("inventory")
    public void setInventoryFromJson(JsonNode node) {
        if (node == null || node.isNull()) {
            this.inventory = null;
        } else if (node.isTextual()) {
            this.inventory = node.asText();
        } else {
            this.inventory = node.toString();
        }
    }

    @Column(length = 32)
    private String lastSignDate;

    @Builder.Default
    private Integer signInStreak = 0;

    @Column(length = 256)
    private String token;

    @Builder.Default
    private Integer totalRechargeRmb = 0;

    private LocalDateTime lastLoginAt;

    @Version
    private Long version;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (lastLoginAt == null) lastLoginAt = LocalDateTime.now();
        if (inventory == null) {
            inventory = "[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]";
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
