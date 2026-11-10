package com.partygame.controller;

import com.partygame.entity.BattleRecord;
import com.partygame.entity.User;
import com.partygame.service.GameService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class RankController {

    private final GameService gameService;

    /**
     * 排位天梯榜与财富榜 (由真实数据库数据计算输出)
     */
    @GetMapping({"/api/rank/leaderboard", "/party-game/api/rank/leaderboard"})
    public ResponseEntity<?> getLeaderboard() {
        List<User> rankUsers = gameService.getRankLeaderboard();
        List<User> wealthUsers = gameService.getWealthLeaderboard();

        List<Map<String, Object>> rankBoard = new ArrayList<>();
        for (int i = 0; i < rankUsers.size(); i++) {
            User u = rankUsers.get(i);
            Map<String, Object> map = new HashMap<>();
            map.put("rank", i + 1);
            map.put("id", u.getId());
            map.put("nickname", u.getNickname());
            map.put("avatar", u.getAvatar());
            map.put("avatarFrame", u.getAvatarFrame());
            map.put("vipLevel", u.getVipLevel());
            map.put("rankScore", u.getRankScore());
            map.put("rankTier", u.getRankTier());
            map.put("winCount", u.getWinCount());
            map.put("totalGames", u.getTotalGames());
            rankBoard.add(map);
        }

        List<Map<String, Object>> wealthBoard = new ArrayList<>();
        for (int i = 0; i < wealthUsers.size(); i++) {
            User u = wealthUsers.get(i);
            Map<String, Object> map = new HashMap<>();
            map.put("rank", i + 1);
            map.put("id", u.getId());
            map.put("nickname", u.getNickname());
            map.put("avatar", u.getAvatar());
            map.put("avatarFrame", u.getAvatarFrame());
            map.put("vipLevel", u.getVipLevel());
            map.put("coins", u.getCoins());
            map.put("diamonds", u.getDiamonds());
            wealthBoard.add(map);
        }

        Map<String, Object> data = new HashMap<>();
        data.put("rankBoard", rankBoard);
        data.put("wealthBoard", wealthBoard);
        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 游戏对局结算并入库历史对战记录
     */
    @PostMapping("/api/game/settle-rank")
    public ResponseEntity<?> settleRank(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        boolean isWin = Boolean.TRUE.equals(body.get("isWin"));
        String gameType = (String) body.get("gameType");
        if (userId == null) return ResponseEntity.badRequest().body(createError("用户编号不能为空"));
        try {
            Map<String, Object> res = gameService.settleRank(userId, isWin, gameType);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", isWin ? "🏆 恭喜对局大胜，段位积分已提升！" : "⚔️ 对局已结算");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 获取玩家真实历史对战记录 (支持默认查询最近5条并分页)
     */
    @GetMapping("/api/game/battle-records")
    public ResponseEntity<?> getBattleRecords(@RequestParam String userId,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "5") int size) {
        Page<BattleRecord> pageResult = gameService.getRecentBattleRecordsPaged(userId, page, size);
        Map<String, Object> data = new HashMap<>();
        data.put("records", pageResult.getContent());
        data.put("total", pageResult.getTotalElements());
        data.put("page", pageResult.getNumber());
        data.put("size", pageResult.getSize());
        data.put("totalPages", pageResult.getTotalPages());
        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 清空玩家战绩记录 (需使用【战绩清空卡】道具)
     */
    @PostMapping("/api/game/battle-records/clear")
    public ResponseEntity<?> clearBattleRecords(@RequestParam(required = false) String userId) {
        if (userId != null && !userId.isBlank()) {
            gameService.clearBattleRecords(userId);
            return ResponseEntity.ok(createSuccess(Map.of("message", "已使用【战绩清空卡】成功清空对战记录", "cleared", true)));
        } else {
            return ResponseEntity.badRequest().body(createError("清空对战记录必须指定玩家账号并消耗【战绩清空卡】道具！"));
        }
    }

    private Map<String, Object> createSuccess(Object data) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 0);
        map.put("data", data);
        return map;
    }

    private Map<String, Object> createError(String msg) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 400);
        map.put("message", msg);
        return map;
    }
}
