package com.partygame.service;

import com.partygame.entity.BattleRecord;
import com.partygame.entity.User;
import com.partygame.repository.BattleRecordRepository;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class GameService {

    private final UserRepository userRepository;
    private final BattleRecordRepository battleRecordRepository;

    public static String calculateRankTier(int score) {
        if (score <= 0) return "暂无段位";
        if (score >= 3000) return "最强王者";
        if (score >= 2600) return "星耀I";
        if (score >= 2300) return "星耀II";
        if (score >= 1900) return "钻石I";
        if (score >= 1600) return "钻石II";
        if (score >= 1300) return "铂金I";
        if (score >= 1000) return "铂金II";
        if (score >= 700) return "黄金I";
        if (score >= 400) return "黄金II";
        if (score >= 200) return "白银";
        return "青铜";
    }

    @Transactional
    public Map<String, Object> settleRank(String userId, boolean isWin, String gameType) {
        User user = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        user.setTotalGames((user.getTotalGames() != null ? user.getTotalGames() : 0) + 1);
        int currentScore = user.getRankScore() != null ? user.getRankScore() : 0;
        int delta = isWin ? 25 : -15;
        int newScore = Math.max(0, currentScore + delta);
        user.setRankScore(newScore);

        String oldTier = user.getRankTier() != null ? user.getRankTier() : "暂无段位";
        user.setRankTier(calculateRankTier(newScore));

        int coinsReward = isWin ? 100 : 20;
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + coinsReward);
        if (isWin) {
            user.setWinCount((user.getWinCount() != null ? user.getWinCount() : 0) + 1);
        }

        userRepository.save(user);

        // 真实战绩存入数据库 battle_records 表
        String mode = newScore >= 2600 ? "最强王者局" : "排位天梯赛";
        BattleRecord record = BattleRecord.builder()
                .userId(userId)
                .gameType(gameType != null ? gameType : "liars_dice")
                .gameMode(mode)
                .isWin(isWin)
                .scoreDelta(delta)
                .coinsReward(coinsReward)
                .playedAt(LocalDateTime.now())
                .build();
        battleRecordRepository.save(record);

        Map<String, Object> res = new HashMap<>();
        res.put("user", user);
        res.put("isWin", isWin);
        res.put("scoreDelta", delta);
        res.put("currentScore", newScore);
        res.put("rankTier", user.getRankTier());
        res.put("coinsReward", coinsReward);
        return res;
    }

    public List<BattleRecord> getRecentBattleRecords(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return Collections.emptyList();
        }
        return battleRecordRepository.findRecentByUserIdClean(userId.trim());
    }

    public Page<BattleRecord> getRecentBattleRecordsPaged(String userId, int page, int size) {
        if (userId == null || userId.trim().isEmpty()) {
            return Page.empty();
        }
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.max(1, size), Sort.by(Sort.Direction.DESC, "playedAt"));
        return battleRecordRepository.findRecentByUserIdCleanPaged(userId.trim(), pageable);
    }

    @org.springframework.transaction.annotation.Transactional
    public void clearBattleRecords(String userId) {
        battleRecordRepository.deleteByUserId(userId);
    }

    @org.springframework.transaction.annotation.Transactional
    public void clearAllBattleRecords() {
        battleRecordRepository.deleteAll();
    }

    public List<User> getRankLeaderboard() {
        return userRepository.findTop10ByOrderByRankScoreDesc();
    }

    public List<User> getWealthLeaderboard() {
        return userRepository.findTop10ByOrderByCoinsDesc();
    }
}
