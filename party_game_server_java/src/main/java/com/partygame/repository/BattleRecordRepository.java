package com.partygame.repository;

import com.partygame.entity.BattleRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BattleRecordRepository extends JpaRepository<BattleRecord, Long> {

    List<BattleRecord> findTop20ByUserIdOrderByPlayedAtDesc(String userId);

    @Query("SELECT r FROM BattleRecord r WHERE REPLACE(LOWER(r.userId), '-', '') = REPLACE(LOWER(:userId), '-', '') ORDER BY r.playedAt DESC")
    List<BattleRecord> findRecentByUserIdClean(@Param("userId") String userId);

    @Query(value = "SELECT r FROM BattleRecord r WHERE REPLACE(LOWER(r.userId), '-', '') = REPLACE(LOWER(:userId), '-', '') ORDER BY r.playedAt DESC",
           countQuery = "SELECT count(r) FROM BattleRecord r WHERE REPLACE(LOWER(r.userId), '-', '') = REPLACE(LOWER(:userId), '-', '')")
    Page<BattleRecord> findRecentByUserIdCleanPaged(@Param("userId") String userId, Pageable pageable);

    long countByUserId(String userId);

    long countByUserIdAndIsWinTrue(String userId);

    void deleteByUserId(String userId);

    long countByPlayedAtAfter(java.time.LocalDateTime time);

    @Query("SELECT HOUR(b.playedAt) as hr, COUNT(b) as cnt FROM BattleRecord b GROUP BY HOUR(b.playedAt) ORDER BY HOUR(b.playedAt)")
    List<Object[]> countBattlesByHour();

    @Query("SELECT b.gameType as gt, COUNT(b) as cnt FROM BattleRecord b GROUP BY b.gameType")
    List<Object[]> countBattlesByGameType();
}
