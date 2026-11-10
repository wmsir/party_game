package com.partygame.controller;

import com.partygame.entity.User;
import com.partygame.entity.UserIntimacy;
import com.partygame.repository.UserIntimacyRepository;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class IntimacyController {

    private final UserIntimacyRepository intimacyRepository;
    private final UserRepository userRepository;

    // 关系与所需亲密度阈值字典
    public static final Map<String, Integer> RELATION_THRESHOLDS = new LinkedHashMap<>();
    static {
        RELATION_THRESHOLDS.put("朋友", 50);
        RELATION_THRESHOLDS.put("发小", 100);
        RELATION_THRESHOLDS.put("死党", 100);
        RELATION_THRESHOLDS.put("知己", 200);
        RELATION_THRESHOLDS.put("闺蜜", 200);
        RELATION_THRESHOLDS.put("基友", 200);
        RELATION_THRESHOLDS.put("情侣", 520);
        RELATION_THRESHOLDS.put("老婆", 520);
        RELATION_THRESHOLDS.put("老公", 520);
    }

    /**
     * 计算道具增加的亲密度点数
     */
    public static int calculateItemScore(String itemType, int combo) {
        if (combo <= 0) combo = 1;
        String type = itemType != null ? itemType.toUpperCase() : "EGG";
        int base = 5;
        switch (type) {
            case "EGG":
            case "SLIPPER":
                base = 5;
                break;
            case "BEER":
            case "WATERGUN":
                base = 10;
                break;
            case "FLOWER":
            case "KISS":
                base = 15;
                break;
            case "BOMB":
            case "CHAMPAGNE":
                base = 20;
                break;
            case "ROCKET":
            case "SUPERCAR":
            case "YACHT":
                base = 50;
                break;
            case "RING":
            case "CASTLE":
                base = 100;
                break;
            default:
                base = 5;
                break;
        }
        return base * combo;
    }

    /**
     * 规范化两个用户 ID 的顺序（小者在前，大者在后）
     */
    private String[] normalizePair(String u1, String u2) {
        if (u1.compareTo(u2) <= 0) {
            return new String[]{u1, u2};
        } else {
            return new String[]{u2, u1};
        }
    }

    /**
     * 增加亲密度 (送礼物 / 投掷互动道具触发)
     */
    @PostMapping({"/api/intimacy/add", "/party-game/api/intimacy/add"})
    public ResponseEntity<?> addIntimacy(@RequestBody Map<String, Object> body) {
        String fromUserId = (String) body.get("fromUserId");
        String toUserId = (String) body.get("toUserId");
        String itemType = (String) body.get("itemType");
        Integer combo = body.get("combo") instanceof Number ? ((Number) body.get("combo")).intValue() : 1;

        if (fromUserId == null || toUserId == null || fromUserId.trim().isEmpty() || toUserId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "用户编号不能为空"));
        }
        fromUserId = fromUserId.trim();
        toUserId = toUserId.trim();
        if (fromUserId.equals(toUserId) || toUserId.startsWith("AI-")) {
            return ResponseEntity.ok(Map.of("code", 200, "message", "无需与AI或自己计算亲密度"));
        }

        int scoreToAdd = calculateItemScore(itemType, combo);
        UserIntimacy record = addScoreInternal(fromUserId, toUserId, scoreToAdd);

        Map<String, Object> res = new HashMap<>();
        res.put("code", 200);
        res.put("message", "亲密度增加成功");
        res.put("scoreAdded", scoreToAdd);
        res.put("intimacyScore", record.getIntimacyScore());
        res.put("relationship", record.getRelationship());
        return ResponseEntity.ok(res);
    }

    public synchronized UserIntimacy addScoreInternal(String uidA, String uidB, int scoreToAdd) {
        String[] pair = normalizePair(uidA, uidB);
        UserIntimacy record = intimacyRepository.findByUser1IdAndUser2Id(pair[0], pair[1])
                .orElseGet(() -> UserIntimacy.builder()
                        .user1Id(pair[0])
                        .user2Id(pair[1])
                        .intimacyScore(0)
                        .relationship(null)
                        .build());
        record.setIntimacyScore((record.getIntimacyScore() != null ? record.getIntimacyScore() : 0) + scoreToAdd);
        return intimacyRepository.save(record);
    }

    /**
     * 查询两玩家之间的亲密关系与分数
     */
    @GetMapping({"/api/intimacy/detail", "/party-game/api/intimacy/detail"})
    public ResponseEntity<?> getIntimacyDetail(@RequestParam String user1Id, @RequestParam String user2Id) {
        if (user1Id == null || user2Id == null) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "缺少用户编号"));
        }
        String[] pair = normalizePair(user1Id.trim(), user2Id.trim());
        UserIntimacy record = intimacyRepository.findByUser1IdAndUser2Id(pair[0], pair[1]).orElse(null);
        int score = record != null && record.getIntimacyScore() != null ? record.getIntimacyScore() : 0;
        String relation = record != null ? record.getRelationship() : null;

        Map<String, Object> res = new HashMap<>();
        res.put("code", 200);
        res.put("intimacyScore", score);
        res.put("relationship", relation);
        res.put("thresholds", RELATION_THRESHOLDS);
        return ResponseEntity.ok(res);
    }

    /**
     * 设置双方亲密关系 (朋友、发小、老婆、老公等)
     */
    @PostMapping({"/api/intimacy/set-relationship", "/party-game/api/intimacy/set-relationship"})
    public ResponseEntity<?> setRelationship(@RequestBody Map<String, String> body) {
        String user1Id = body.get("user1Id");
        if (user1Id == null || user1Id.trim().isEmpty()) user1Id = body.get("userA");
        if (user1Id == null || user1Id.trim().isEmpty()) user1Id = body.get("userId");

        String user2Id = body.get("user2Id");
        if (user2Id == null || user2Id.trim().isEmpty()) user2Id = body.get("userB");
        if (user2Id == null || user2Id.trim().isEmpty()) user2Id = body.get("targetId");

        String relationship = body.get("relationship");

        if (user1Id == null || user2Id == null || relationship == null) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "缺少必要参数"));
        }
        user1Id = user1Id.trim();
        user2Id = user2Id.trim();
        relationship = relationship.trim();

        if (!RELATION_THRESHOLDS.containsKey(relationship)) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "不支持设置该亲密关系：" + relationship));
        }

        int requiredThreshold = RELATION_THRESHOLDS.get(relationship);
        String[] pair = normalizePair(user1Id, user2Id);
        UserIntimacy record = intimacyRepository.findByUser1IdAndUser2Id(pair[0], pair[1])
                .orElseGet(() -> {
                    String c1 = pair[0].replace("-", "").toLowerCase();
                    String c2 = pair[1].replace("-", "").toLowerCase();
                    for (UserIntimacy item : intimacyRepository.findAll()) {
                        String ic1 = item.getUser1Id() != null ? item.getUser1Id().replace("-", "").toLowerCase() : "";
                        String ic2 = item.getUser2Id() != null ? item.getUser2Id().replace("-", "").toLowerCase() : "";
                        if ((ic1.equals(c1) && ic2.equals(c2)) || (ic1.equals(c2) && ic2.equals(c1))) {
                            return item;
                        }
                    }
                    return UserIntimacy.builder()
                            .user1Id(pair[0])
                            .user2Id(pair[1])
                            .intimacyScore(0)
                            .build();
                });

        int currentScore = record.getIntimacyScore() != null ? record.getIntimacyScore() : 0;
        if (currentScore <= 0) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 400,
                    "message", "当前亲密度为 0，不能设置亲密关系！最低需达到 50 点方可设置【朋友】关系，快去送礼物增加亲密度吧～"
            ));
        }
        if (currentScore < requiredThreshold) {
            return ResponseEntity.badRequest().body(Map.of(
                    "code", 400,
                    "message", "亲密度不足！设置【" + relationship + "】需要 " + requiredThreshold + " 亲密度，当前仅有 " + currentScore + "，快去送礼物增加亲密度吧～"
            ));
        }

        record.setRelationship(relationship);
        intimacyRepository.save(record);

        Map<String, Object> res = new HashMap<>();
        res.put("code", 200);
        res.put("message", "🎉 恭喜！您与好友成功缔结【" + relationship + "】关系！");
        res.put("relationship", relationship);
        res.put("intimacyScore", currentScore);
        return ResponseEntity.ok(res);
    }

    /**
     * 解除亲密关系
     */
    @PostMapping({"/api/intimacy/remove-relationship", "/party-game/api/intimacy/remove-relationship"})
    public ResponseEntity<?> removeRelationship(@RequestBody Map<String, String> body) {
        String user1Id = body.get("user1Id");
        String user2Id = body.get("user2Id");
        if (user1Id == null || user2Id == null) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "缺少用户编号"));
        }
        String[] pair = normalizePair(user1Id.trim(), user2Id.trim());
        intimacyRepository.findByUser1IdAndUser2Id(pair[0], pair[1]).ifPresent(rec -> {
            rec.setRelationship(null);
            intimacyRepository.save(rec);
        });
        return ResponseEntity.ok(Map.of("code", 200, "message", "亲密关系已成功解除"));
    }

    /**
     * 获取我的所有亲密好友关系列表
     */
    @GetMapping({"/api/intimacy/my-relations", "/party-game/api/intimacy/my-relations"})
    public ResponseEntity<?> getMyRelations(@RequestParam String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.ok(Map.of("code", 200, "list", Collections.emptyList()));
        }
        String cleanUid = userId.trim();
        List<UserIntimacy> list = intimacyRepository.findByUser1IdOrUser2Id(cleanUid, cleanUid);
        List<Map<String, Object>> result = new ArrayList<>();

        for (UserIntimacy item : list) {
            String partnerId = cleanUid.equals(item.getUser1Id()) ? item.getUser2Id() : item.getUser1Id();
            User partner = userRepository.findById(partnerId).orElse(null);
            Map<String, Object> map = new HashMap<>();
            map.put("partnerId", partnerId);
            map.put("partnerName", partner != null && partner.getNickname() != null ? partner.getNickname() : "好友 " + partnerId);
            map.put("partnerAvatar", partner != null && partner.getAvatar() != null ? partner.getAvatar() : "🦊");
            map.put("intimacyScore", item.getIntimacyScore() != null ? item.getIntimacyScore() : 0);
            map.put("relationship", item.getRelationship());
            map.put("updatedAt", item.getUpdatedAt());
            result.add(map);
        }

        // 按亲密度由高到低排序
        result.sort((a, b) -> Integer.compare((Integer) b.get("intimacyScore"), (Integer) a.get("intimacyScore")));
        return ResponseEntity.ok(Map.of("code", 200, "list", result));
    }
}
