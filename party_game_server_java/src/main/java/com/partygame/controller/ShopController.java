package com.partygame.controller;

import com.partygame.entity.User;
import com.partygame.security.UserAuthService;
import com.partygame.service.ShopService;
import com.partygame.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@Slf4j
@RestController
@RequiredArgsConstructor
public class ShopController {

    private final ShopService shopService;
    private final UserService userService;
    private final UserAuthService userAuthService;

    /**
     * 获取商城商品与官方充值档位
     */
    @GetMapping({"/api/shop/goods", "/party-game/api/shop/goods"})
    public ResponseEntity<?> getGoods(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestParam(required = false) String userId) {
        Map<String, Object> data = new HashMap<>();
        data.put("goods", shopService.getGoodsCatalog());
        data.put("rechargeTiers", shopService.getRechargeTiers());

        String tok = userAuthService.extractToken(authHeader, userTokenHeader, null);
        User authed = tok != null ? userAuthService.authenticate(tok) : null;
        if (authed != null && (userId == null || userId.trim().isEmpty() || userAuthService.isSameUserId(authed.getId(), userId))) {
            Map<String, Object> balance = new HashMap<>();
            balance.put("coins", authed.getCoins());
            balance.put("diamonds", authed.getDiamonds());
            balance.put("vipLevel", authed.getVipLevel());
            balance.put("vipExp", authed.getVipExp());
            balance.put("diceCupSkin", authed.getDiceCupSkin());
            balance.put("avatarFrame", authed.getAvatarFrame());
            balance.put("entranceBanner", authed.getEntranceBanner());
            balance.put("chatTextColor", authed.getChatTextColor());
            data.put("userBalance", balance);
        }
        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 创建商业化充值订单 (PENDING 待支付状态，用于标准微信/支付宝收银台与验签回调)
     */
    @PostMapping({"/api/shop/order/create", "/party-game/api/shop/order/create"})
    public ResponseEntity<?> createOrder(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String tierId = body.get("tierId");
        String payChannel = body.get("payChannel");
        if (tierId == null || tierId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.createOrder(authed.getId(), tierId, payChannel);
            return ResponseEntity.ok(createSuccess(res));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 幂等确认订单到账 (校验本人会话凭证并核销入账)
     */
    @PostMapping({"/api/shop/order/confirm", "/party-game/api/shop/order/confirm"})
    public ResponseEntity<?> confirmOrder(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String orderId = body.get("orderId");
        String tradeNo = body.get("tradeNo");
        if (orderId == null || orderId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("订单号不能为空"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, body.get("userId"));
        try {
            Map<String, Object> res = shopService.confirmOrder(orderId, tradeNo, authed.getId());
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 订单支付确认成功！钻石与金币已到账！");
            return ResponseEntity.ok(resp);
        } catch (SecurityException se) {
            throw se;
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 官方商业化充值与收银台支付 (支持微信支付 WXPAY / 支付宝 ALIPAY 沙盒支付与订单留痕)
     */
    @PostMapping({"/api/shop/pay", "/party-game/api/shop/pay"})
    public ResponseEntity<?> pay(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String tierId = body.get("tierId");
        String payChannel = body.get("payChannel"); // WXPAY or ALIPAY
        if (tierId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.processPayment(authed.getId(), tierId, payChannel);
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
    @PostMapping({"/api/shop/recharge", "/party-game/api/shop/recharge"})
    public ResponseEntity<?> recharge(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String tierId = body.get("tierId");
        if (tierId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.recharge(authed.getId(), tierId);
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
    public ResponseEntity<?> convertDiamonds(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? String.valueOf(body.get("userId")) : null;
        Object diaObj = body.get("diamonds");
        int diamonds = 0;
        if (diaObj instanceof Number) {
            diamonds = ((Number) diaObj).intValue();
        } else if (diaObj != null) {
            try {
                diamonds = Integer.parseInt(diaObj.toString().trim());
            } catch (Exception ignored) {}
        }

        if (diamonds <= 0) {
            return ResponseEntity.badRequest().body(createError("参数错误，兑换钻石数量需大于0"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);

        try {
            Map<String, Object> res = shopService.convertDiamondsToCoins(authed.getId(), diamonds);
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
    @PostMapping({"/api/shop/buy", "/party-game/api/shop/buy"})
    public ResponseEntity<?> buyItem(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? String.valueOf(body.get("userId")) : null;
        String itemId = body.get("itemId") != null ? String.valueOf(body.get("itemId")) : null;
        boolean autoEquip = Boolean.TRUE.equals(body.get("autoEquip"));
        if (itemId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            User user = shopService.buyItem(authed.getId(), itemId, autoEquip);
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
    @PostMapping({"/api/shop/equip", "/party-game/api/shop/equip"})
    public ResponseEntity<?> equipItem(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String slot = body.get("slot");
        String itemId = body.get("itemId");
        if (slot == null || itemId == null) {
            return ResponseEntity.badRequest().body(createError("参数错误"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            User user = shopService.equipItem(authed.getId(), slot, itemId);
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
    public ResponseEntity<?> getSignInStatus(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestParam(required = false) String userId) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        return ResponseEntity.ok(createSuccess(shopService.getSignInStatus(authed.getId())));
    }

    @PostMapping({"/api/activity/sign-in", "/party-game/api/activity/sign-in"})
    public ResponseEntity<?> doSignIn(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, body.get("userId"));
        try {
            Map<String, Object> res = shopService.signIn(authed.getId());
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🎉 签到成功！奖励已到账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 每日任务 (基于今日真实对局与互动进度)
     */
    @GetMapping({"/api/tasks/daily", "/party-game/api/tasks/daily"})
    public ResponseEntity<?> getDailyTasks(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestParam(required = false) String userId) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        return ResponseEntity.ok(createSuccess(shopService.getDailyTasks(authed.getId())));
    }

    @PostMapping({"/api/tasks/claim", "/party-game/api/tasks/claim"})
    public ResponseEntity<?> claimTask(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String taskId = body.get("taskId");
        if (taskId == null) return ResponseEntity.badRequest().body(createError("参数错误"));
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> claimed = shopService.claimDailyTask(authed.getId(), taskId);
            Map<String, Object> res = createSuccess(claimed);
            res.put("message", "🎉 任务奖励已成功领取！");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
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

    /**
     * 6元首充至尊豪华大礼包
     */
    @PostMapping({"/api/shop/first-recharge", "/party-game/api/shop/first-recharge"})
    public ResponseEntity<?> claimFirstRecharge(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String payChannel = body.getOrDefault("payChannel", "WXPAY");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.claimFirstRecharge(authed.getId(), payChannel);
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
    public ResponseEntity<?> claimBankruptRelief(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? String.valueOf(body.get("userId")) : null;
        boolean isWatchAd = Boolean.TRUE.equals(body.get("isWatchAd"));
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.claimBankruptRelief(authed.getId(), isWatchAd);
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
    public ResponseEntity<?> luckyDraw(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? String.valueOf(body.get("userId")) : null;
        int count = body.get("count") != null ? ((Number) body.get("count")).intValue() : 1;
        String currency = (String) body.getOrDefault("currency", "COIN");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.luckyDraw(authed.getId(), count, currency);
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
    public ResponseEntity<?> settleVictoryDouble(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? String.valueOf(body.get("userId")) : null;
        long baseCoins = body.get("baseCoins") != null ? ((Number) body.get("baseCoins")).longValue() : 1000L;
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        try {
            Map<String, Object> res = shopService.settleVictoryDouble(authed.getId(), baseCoins);
            Map<String, Object> resp = createSuccess(res);
            resp.put("message", "🔥 翻倍成功！本局胜利金币已翻倍入账！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

}
