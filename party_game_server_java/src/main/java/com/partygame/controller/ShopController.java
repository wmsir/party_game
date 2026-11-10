package com.partygame.controller;

import com.partygame.entity.User;
import com.partygame.service.ShopService;
import com.partygame.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class ShopController {

    private final ShopService shopService;
    private final UserService userService;

    /**
     * 获取商城商品与官方充值档位
     */
    @GetMapping({"/api/shop/goods", "/party-game/api/shop/goods"})
    public ResponseEntity<?> getGoods(@RequestParam(required = false) String userId) {
        Map<String, Object> data = new HashMap<>();
        data.put("goods", shopService.getGoodsCatalog());
        data.put("rechargeTiers", shopService.getRechargeTiers());

        if (userId != null && !userId.trim().isEmpty()) {
            userService.getUserById(userId).ifPresent(u -> {
                Map<String, Object> balance = new HashMap<>();
                balance.put("coins", u.getCoins());
                balance.put("diamonds", u.getDiamonds());
                balance.put("vipLevel", u.getVipLevel());
                balance.put("vipExp", u.getVipExp());
                balance.put("diceCupSkin", u.getDiceCupSkin());
                balance.put("avatarFrame", u.getAvatarFrame());
                balance.put("entranceBanner", u.getEntranceBanner());
                balance.put("chatTextColor", u.getChatTextColor());
                data.put("userBalance", balance);
            });
        }
        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 官方商业化充值与收银台支付 (支持微信支付 WXPAY / 支付宝 ALIPAY 模拟支付与入账)
     */
    @PostMapping({"/api/shop/pay", "/party-game/api/shop/pay"})
    public ResponseEntity<?> pay(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String tierId = body.get("tierId");
        String payChannel = body.get("payChannel"); // WXPAY or ALIPAY
        if (userId == null || tierId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.processPayment(userId, tierId, payChannel);
            Map<String, Object> resp = createSuccess(res);
            String channelName = (String) res.getOrDefault("payChannelName", "在线支付");
            resp.put("message", "🎉 " + channelName + "成功！钻石与金币已即时到账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 充值加币与升级 VIP (兼容老接口，默认走微信支付通道)
     */
    @PostMapping("/api/shop/recharge")
    public ResponseEntity<?> recharge(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String tierId = body.get("tierId");
        if (userId == null || tierId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.recharge(userId, tierId);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 充值成功！金币与钻石已到账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 钻石兑换金币 (严格按照 1 钻石 = 100 金币比例)
     */
    @PostMapping({"/api/shop/convert-diamonds", "/party-game/api/shop/convert-diamonds"})
    public ResponseEntity<?> convertDiamonds(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        Object diaObj = body.get("diamonds");
        int diamonds = 0;
        if (diaObj instanceof Number) {
            diamonds = ((Number) diaObj).intValue();
        } else if (diaObj != null) {
            try {
                diamonds = Integer.parseInt(diaObj.toString().trim());
            } catch (Exception ignored) {}
        }

        if (userId == null || diamonds <= 0) {
            return ResponseEntity.badRequest().body(createError("参数错误，兑换钻石数量需大于0"));
        }

        try {
            Map<String, Object> res = shopService.convertDiamondsToCoins(userId, diamonds);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 恭喜！成功使用 " + diamonds + " 钻石兑换 " + res.get("coinsAward") + " 聚会金币！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 获取全量 VIP 体系等级与专属特权说明
     */
    @GetMapping({"/api/shop/vip-privileges", "/party-game/api/shop/vip-privileges"})
    public ResponseEntity<?> getVipPrivileges() {
        return ResponseEntity.ok(createSuccess(shopService.getVipPrivileges()));
    }

    /**
     * 购买道具与装扮
     */
    @PostMapping("/api/shop/buy")
    public ResponseEntity<?> buyItem(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        String itemId = (String) body.get("itemId");
        boolean autoEquip = Boolean.TRUE.equals(body.get("autoEquip"));
        if (userId == null || itemId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            User user = shopService.buyItem(userId, itemId, autoEquip);
            Map<String, Object> resp = createSuccess(user);
            resp.put("message", "🎉 购买成功！装扮已加入背包！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 穿戴装扮
     */
    @PostMapping("/api/shop/equip")
    public ResponseEntity<?> equipItem(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String slot = body.get("slot");
        String itemId = body.get("itemId");
        if (userId == null || slot == null || itemId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            User user = shopService.equipItem(userId, slot, itemId);
            Map<String, Object> resp = createSuccess(user);
            resp.put("message", "装扮已生效！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 7天每日签到状态与打卡
     */
    @GetMapping({"/api/activity/sign-in", "/party-game/api/activity/sign-in"})
    public ResponseEntity<?> getSignInStatus(@RequestParam(required = false) String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.ok(createSuccess(Map.of("hasSignedInToday", false, "streak", 0)));
        }
        return ResponseEntity.ok(createSuccess(shopService.getSignInStatus(userId)));
    }

    @PostMapping({"/api/activity/sign-in", "/party-game/api/activity/sign-in"})
    public ResponseEntity<?> doSignIn(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        if (userId == null) return ResponseEntity.badRequest().body(createError("用户编号不能为空"));
        try {
            Map<String, Object> res = shopService.signIn(userId);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 签到成功！奖励已到账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 每日任务
     */
    @GetMapping("/api/tasks/daily")
    public ResponseEntity<?> getDailyTasks(@RequestParam(required = false) String userId) {
        List<Map<String, Object>> tasks = new ArrayList<>();
        tasks.add(createTask("task_login", "每日登录打卡", 1, 1, 100, 5, false));
        tasks.add(createTask("task_play_1", "参与 1 局聚会桌游", 1, 0, 200, 10, false));
        tasks.add(createTask("task_win_1", "赢得 1 场排位对局", 1, 0, 300, 15, false));
        tasks.add(createTask("task_throw_3", "向好友投掷 3 次互动道具", 3, 0, 150, 5, false));
        tasks.add(createTask("task_play_3", "累计完成 3 局桌游", 3, 0, 500, 30, false));
        return ResponseEntity.ok(createSuccess(tasks));
    }

    @PostMapping("/api/tasks/claim")
    public ResponseEntity<?> claimTask(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String taskId = body.get("taskId");
        if (userId == null || taskId == null) return ResponseEntity.badRequest().body(createError("参数错误"));
        User user = userService.getUserById(userId).orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + 200);
        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + 10);
        userService.saveUser(user);
        Map<String, Object> res = createSuccess(user);
        res.put("message", "🎉 任务奖励已成功领取！");
        return ResponseEntity.ok(res);
    }

    private Map<String, Object> createTask(String id, String title, int target, int current, int coins, int diamonds, boolean claimed) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", id);
        map.put("title", title);
        map.put("target", target);
        map.put("current", current);
        map.put("rewardCoins", coins);
        map.put("rewardDiamonds", diamonds);
        map.put("isClaimed", claimed);
        return map;
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

    /**
     * 6元首充至尊豪华大礼包
     */
    @PostMapping({"/api/shop/first-recharge", "/party-game/api/shop/first-recharge"})
    public ResponseEntity<?> claimFirstRecharge(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String payChannel = body.getOrDefault("payChannel", "WXPAY");
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.claimFirstRecharge(userId, payChannel);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 恭喜！6元首充至尊豪华大礼包已到账，绝版装扮与资产已激活！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 破产救济金与看广告领币
     */
    @PostMapping({"/api/shop/bankrupt-relief", "/party-game/api/shop/bankrupt-relief"})
    public ResponseEntity<?> claimBankruptRelief(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        boolean isWatchAd = Boolean.TRUE.equals(body.get("isWatchAd"));
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.claimBankruptRelief(userId, isWatchAd);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", isWatchAd ? "🎉 赞助广告观看完成！奖励 3,000 金币已发放！" : "🎉 破产救济金领取成功！祝您牌局大逆转！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 幸运夺宝盲盒抽奖
     */
    @PostMapping({"/api/shop/lucky-draw", "/party-game/api/shop/lucky-draw"})
    public ResponseEntity<?> luckyDraw(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        int count = body.get("count") != null ? ((Number) body.get("count")).intValue() : 1;
        String currency = (String) body.getOrDefault("currency", "COIN");
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.luckyDraw(userId, count, currency);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 恭喜获得夺宝奖励！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 对局结算赢家收益翻倍
     */
    @PostMapping({"/api/shop/settle-double", "/party-game/api/shop/settle-double"})
    public ResponseEntity<?> settleVictoryDouble(@RequestBody Map<String, Object> body) {
        String userId = (String) body.get("userId");
        long baseCoins = body.get("baseCoins") != null ? ((Number) body.get("baseCoins")).longValue() : 1000L;
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        try {
            Map<String, Object> res = shopService.settleVictoryDouble(userId, baseCoins);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🔥 翻倍成功！本局胜利金币已翻倍入账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

}
