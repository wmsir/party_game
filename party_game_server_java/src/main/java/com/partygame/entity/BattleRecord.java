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
@Table(name = "battle_records", indexes = {
    @Index(name = "idx_br_user_id", columnList = "userId,playedAt")
})
public class BattleRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String userId;

    @Column(length = 64)
    private String gameType; // liars_dice, six_nimmt, roulette, undercover

    @Column(length = 64)
    private String gameMode; // 最强王者局, 排位天梯赛, 欢乐休闲局

    @Column(length = 32)
    private String roomCode;

    private Boolean isWin;

    private Integer scoreDelta;

    private Integer coinsReward;

    private LocalDateTime playedAt;

    @PrePersist
    public void prePersist() {
        if (playedAt == null) playedAt = LocalDateTime.now();
    }
}
