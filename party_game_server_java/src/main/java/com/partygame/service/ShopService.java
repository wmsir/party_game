package com.partygame.service;

import com.alibaba.fastjson2.JSON;
import com.partygame.entity.PaymentOrder;
import com.partygame.entity.User;
import com.partygame.repository.BattleRecordRepository;
import com.partygame.repository.PaymentOrderRepository;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class ShopService {

    private static final Set<String> DEFAULT_OWNED_ITEMS = Set.of(
            "CLASSIC_GOLD", "FRAME_DEFAULT", "BANNER_DEFAULT", "COLOR_DEFAULT"
    );
    private static final long VICTORY_DOUBLE_COOLDOWN_MS = 30_000L;
    private static final long AD_RELIEF_COOLDOWN_MS = 60_000L;
    private static final int MAX_DAILY_AD_RELIEF = 5;

    private final UserRepository userRepository;
    private final PaymentOrderRepository paymentOrderRepository;
    private final BattleRecordRepository battleRecordRepository;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${party.payment.sandbox-enabled:true}")
    private boolean paymentSandboxEnabled;

    private boolean isEffectiveSandbox() {
        return paymentSandboxEnabled && (environment == null || !environment.acceptsProfiles(Profiles.of("prod")));
    }

    private final Map<String, Object> userTaskLocks = new ConcurrentHashMap<>();

    // Daily anti-abuse & task tracking maps
    private static final Map<String, Integer> DAILY_THROW_COUNTS = new ConcurrentHashMap<>();
    private final Map<String, int[]> dailyReliefCounts = new ConcurrentHashMap<>(); // [standard, ad]
    private final Map<String, Long> lastAdReliefMs = new ConcurrentHashMap<>();
    private final Map<String, Long> lastVictoryDoubleMs = new ConcurrentHashMap<>();
    private final Map<String, Set<String>> dailyClaimedTasks = new ConcurrentHashMap<>();

    public static void recordDailyThrow(String userId) {
        if (userId == null || userId.isBlank() || userId.startsWith("U-") || userId.startsWith("AI-")) return;
        String today = LocalDate.now().toString();
        String key = userId.trim() + ":" + today;
        if (DAILY_THROW_COUNTS.size() > 10000) {
            DAILY_THROW_COUNTS.entrySet().removeIf(e -> !e.getKey().endsWith(":" + today));
        }
        DAILY_THROW_COUNTS.merge(key, 1, Integer::sum);
    }

    public static int getDailyThrowCount(String userId) {
        if (userId == null || userId.isBlank()) return 0;
        String key = userId.trim() + ":" + LocalDate.now().toString();
        return DAILY_THROW_COUNTS.getOrDefault(key, 0);
    }

    public User getOrCreateUser(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            throw new IllegalArgumentException("用户编号不能为空");
        }
        String finalUid = userId.trim();
        return userRepository.findById(finalUid)
                .orElseThrow(() -> new IllegalArgumentException("用户档案不存在，请先登录"));
    }

    public static int calculateVipLevel(int vipExp) {
        if (vipExp >= 188888) return 10;
        if (vipExp >= 100000) return 9;
        if (vipExp >= 50000) return 8;
        if (vipExp >= 20000) return 7;
        if (vipExp >= 10000) return 6;
        if (vipExp >= 5000) return 5;
        if (vipExp >= 2000) return 4;
        if (vipExp >= 500) return 3;
        if (vipExp >= 100) return 2;
        if (vipExp >= 10) return 1;
        return 0;
    }

    public List<Map<String, Object>> getGoodsCatalog() {
        List<Map<String, Object>> list = new ArrayList<>();
        // ===== 1. 骰盅皮肤专区 =====
        list.add(createGood("CLASSIC_GOLD", "dice_cup", "经典黑金骰盅", 0, 0, 0, "🏆", "尊贵黑金拉丝质感，聚会老手标志", true));
        list.add(createGood("NEON_CYBER", "dice_cup", "赛博霓虹骰盅", 5000, 0, 0, "⚡", "赛博朋克流光幻彩，夜晚开局焦点 (金币专享)", false));
        list.add(createGood("PURPLE_GALAXY", "dice_cup", "紫晶星系骰盅", 10000, 0, 0, "🌌", "星河流转璀璨迷人，运气爆棚加持 (金币专享)", false));
        list.add(createGood("FLAME_DRAGON", "dice_cup", "烈焰赤龙骰盅", 0, 88, 0, "🔥", "烈火熊熊势不可挡，纯钻石奢华专属", false));
        list.add(createGood("PURE_DIAMOND", "dice_cup", "璀璨钻石骰盅", 0, 188, 0, "💎", "八心八箭至尊水晶切割，闪耀全场 (纯钻石专属)", false));
        list.add(createGood("ROYAL_DRAGON_GOLD", "dice_cup", "至尊黄金神龙骰盅", 0, 288, 2, "👑", "VIP 2 专属奢华黄金盘龙，尊崇绝伦", false));

        // ===== 2. 头像框专区 =====
        list.add(createGood("FRAME_DEFAULT", "avatar_frame", "聚会新星框", 0, 0, 0, "⭐", "初入聚会社区基础装扮", true));
        list.add(createGood("FRAME_NEON", "avatar_frame", "赛博流光框", 3000, 0, 0, "🌈", "流光幻彩渐变边框，彰显个性 (金币专享)", false));
        list.add(createGood("FRAME_GOLD", "avatar_frame", "荣耀黄金框", 8000, 0, 0, "🥇", "璀璨真金抛光工艺，王者气派 (金币专享)", false));
        list.add(createGood("FRAME_GALAXY_DOMINATOR", "avatar_frame", "星空霸主框", 0, 128, 1, "🌌", "VIP 1 专属星辰环绕动效框 (纯钻石专属)", false));
        list.add(createGood("FRAME_BLACK_GOLD_ROYAL", "avatar_frame", "黑金至尊帝王框", 0, 388, 4, "🔱", "VIP 4 专属黑金龙纹霸气图腾 (纯钻石专属)", false));

        // ===== 3. 登场横幅专区 =====
        list.add(createGood("BANNER_DEFAULT", "entrance_banner", "普通登场横幅", 0, 0, 0, "🚪", "系统默认进房提示", true));
        list.add(createGood("BANNER_SHINE", "entrance_banner", "闪亮登场横幅", 5000, 0, 0, "✨", "全场星光闪烁，醒目进场 (金币专享)", false));
        list.add(createGood("BANNER_DRAGON", "entrance_banner", "凤舞龙吟横幅", 0, 128, 0, "🐉", "神龙破空进场横幅，全屏焦点 (纯钻石专属)", false));
        list.add(createGood("BANNER_EMPEROR", "entrance_banner", "君临天下横幅", 0, 588, 3, "👑", "VIP 3 专属尊贵入场全服公告 (纯钻石专属)", false));

        // ===== 4. 聊天文字颜色卡专区 =====
        list.add(createGood("COLOR_DEFAULT", "chat_text_color", "默认经典白", 0, 0, 0, "💬", "系统默认发言文字颜色 (#FFFFFF)", true));
        list.add(createGood("COLOR_SAKURA_PINK", "chat_text_color", "炫彩樱花粉", 3000, 0, 0, "🌸", "清新烂漫樱花粉，字字动人心弦 (金币专享)", false));
        list.add(createGood("COLOR_CYBER_BLUE", "chat_text_color", "赛博冰川蓝", 5000, 0, 0, "💎", "极客未来冷萃冰蓝，字迹冷酷吸睛 (金币专享)", false));
        list.add(createGood("COLOR_AURORA_GREEN", "chat_text_color", "翡翠极光绿", 0, 68, 0, "🍀", "青翠荧光草绿，生机盎然 (纯钻石专属)", false));
        list.add(createGood("COLOR_DEEP_PURPLE", "chat_text_color", "幻影深空紫", 0, 88, 0, "🔮", "神秘幽邃深空魅紫，尊贵迷人魅力 (纯钻石专属)", false));
        list.add(createGood("COLOR_BLAZING_GOLD", "chat_text_color", "炽焰曜石金", 0, 168, 2, "👑", "VIP 2 专属奢华曜石流金，牌局全场焦点", false));
        list.add(createGood("COLOR_QQ_RED", "chat_text_color", "至尊红钻绯红", 0, 288, 3, "🔥", "VIP 3 专属热烈至尊红，如火焰般炽热醒目", false));

        // ===== 5. 礼包、功能卡与特权专属道具 =====
        list.add(createGood("INTERACTION_BUNDLE", "pack", "酒桌互动大礼包", 2000, 0, 0, "🍻", "内含啤酒、鲜花、拖鞋各 10 个 (金币专享)", false));
        list.add(createGood("CARD_RENAME", "gift_prop", "改名换姓卡", 0, 50, 0, "🏷️", "尊贵昵称修改凭证，立即修改个人游戏昵称 (纯钻石专属)", false));
        list.add(createGood("GIFT_STARTER", "pack", "新手超值豪华包", 0, 60, 0, "🎁", "赠送 10,000 金币 + 鸡蛋啤酒道具各20个 (纯钻石专属)", false));
        list.add(createGood("PROP_TRUMPET_10", "gift_prop", "全服广播大喇叭", 0, 10, 0, "📢", "全服横幅跑马灯实时广播 1 次 (纯钻石专属)", false));
        list.add(createGood("PROP_ROCKET_100", "gift_prop", "全服超级火箭", 0, 100, 0, "🚀", "升空破云震撼全服，全服玩家见证盛典动效 (纯钻石专属)", false));
        list.add(createGood("PROP_SUPERCAR_300", "gift_prop", "全服豪华超跑", 0, 300, 0, "🏎️", "引擎轰鸣绝尘而去，引爆全服热度 (纯钻石专属)", false));
        list.add(createGood("PROP_CASTLE_680", "gift_prop", "全服梦幻城堡", 0, 680, 0, "🏰", "浪漫至极奢华加冕，全屏流光盛典 (纯钻石专属)", false));

        return list;
    }

    public List<Map<String, Object>> getRechargeTiers() {
        List<Map<String, Object>> list = new ArrayList<>();
        list.add(createTier("tier_6", 6, 60, 1000, 60, true, "6元聚会新手包", "首充双倍"));
        list.add(createTier("tier_30", 30, 300, 5000, 300, true, "30元微醺畅玩包", "超值特惠"));
        list.add(createTier("tier_68", 68, 680, 12000, 680, true, "68元骰王进阶包", "热门首选"));
        list.add(createTier("tier_128", 128, 1280, 25000, 1280, true, "128元雀圣霸主包", "尊享特权"));
        list.add(createTier("tier_328", 328, 3280, 70000, 3280, true, "328元至尊神豪包", "神豪首选"));
        list.add(createTier("tier_648", 648, 6480, 150000, 6480, true, "648元君临天下包", "至尊加冕"));
        return list;
    }

    public List<Map<String, Object>> getVipPrivileges() {
        List<Map<String, Object>> list = new ArrayList<>();
        list.add(Map.of("level", 0, "name", "VIP 0 · 聚会平民", "needExp", 0, "priceRmb", 0, "privileges", "• 基础大厅游戏游玩\n• 每日基础签到福利\n• 破产救济金基础保障"));
        list.add(Map.of("level", 1, "name", "VIP 1 · 聚会初贵 (王者初贵)", "needExp", 10, "priceRmb", 1, "privileges", "• 专属 VIP 1 贵族勋章标识\n• 解锁专属【星空霸主头像框】购买特权\n• 签到金币收益额外 +10%\n• 个人名片贵族初级微光"));
        list.add(Map.of("level", 2, "name", "VIP 2 · 聚会名流 (王者进阶)", "needExp", 100, "priceRmb", 10, "privileges", "• 专属 VIP 2 进阶贵族徽章\n• 解锁【至尊黄金神龙骰盅】与【曜石金字色】\n• 签到金币收益额外 +20%\n• 大厅房间优先入座特权"));
        list.add(Map.of("level", 3, "name", "VIP 3 · 牌桌宗师 (精英贵族)", "needExp", 500, "priceRmb", 50, "privileges", "• 专属 VIP 3 白银精英徽章\n• 解锁【君临天下入场横幅】与【至尊红字色】\n• 房间免踢特权，对局结算金币收益额外 +15%\n• 每日破产救济金额外领取 +1 次"));
        list.add(Map.of("level", 4, "name", "VIP 4 · 雀圣尊爵 (璀璨贵族·SVIP)", "needExp", 2000, "priceRmb", 200, "privileges", "• 专属 SVIP 4 璀璨流光徽章\n• 解锁【黑金至尊帝王头像框】\n• 全服大喇叭 8 折特惠使用权\n• 每日破产救济金额外领取 +2 次\n• 对局结算金币额外 +20%"));
        list.add(Map.of("level", 5, "name", "VIP 5 · 酒界至尊 (耀世贵族·SVIP)", "needExp", 5000, "priceRmb", 500, "privileges", "• 专属 SVIP 5 耀世金芒徽章\n• 进房触发专属金色全屏流光光晕\n• 好友上限扩充至 100 人，私信无限制\n• 破产救济金金币倍率提升至 1.5 倍\n• 对局结算金币额外 +25%"));
        list.add(Map.of("level", 6, "name", "VIP 6 · 豪门传奇 (至尊贵族·SVIP)", "needExp", 10000, "priceRmb", 1000, "privileges", "• 专属 SVIP 6 至尊金冠徽章\n• 尊贵黑金动态流光铭牌\n• 全服大喇叭 5 折特惠使用权\n• 每日破产救济金额外领取 +3 次\n• 对局结算金币额外 +30%"));
        list.add(Map.of("level", 7, "name", "VIP 7 · 巅峰霸主 (荣耀贵族·SVIP)", "needExp", 20000, "priceRmb", 2000, "privileges", "• 专属 SVIP 7 荣耀紫金徽章\n• 贵族专属动态彩色发言气泡\n• 全服盛典超级火箭/超跑专属折扣\n• 专属客服优先响应通道\n• 对局结算金币额外 +40%"));
        list.add(Map.of("level", 8, "name", "VIP 8 · 永恒传说 (传说贵族·SVIP)", "needExp", 50000, "priceRmb", 5000, "privileges", "• 专属 SVIP 8 传说荣耀皇冠勋章\n• 进房全服跑马灯公告通报（神豪降临）\n• 免广告特权（商业广告视频直达免等待）\n• 破产救济金金币翻倍（2.0 倍收益）\n• 对局结算金币额外 +50%"));
        list.add(Map.of("level", 9, "name", "VIP 9 · 神圣主宰 (神圣贵族·SVIP)", "needExp", 100000, "priceRmb", 10000, "privileges", "• 专属 SVIP 9 神圣永恒皇冠徽章\n• 个人主页专属金钻流光背景特效\n• 全服房间置顶广播特权\n• 每日破产救济金额外领取 +5 次\n• 对局结算金币额外 +70%"));
        list.add(Map.of("level", 10, "name", "VIP 10 · 荣耀无双 (至高无上·无双王者)", "needExp", 188888, "priceRmb", 18888, "privileges", "• 终极 SVIP 10 荣耀无双七彩神级徽章\n• 【同桌装扮共享特权】（牌友可共享使用您拥有的骰盅皮肤与牌桌特效）\n• 神级龙腾入场全服公告横幅\n• 每日破产救济金无限次保底领取\n• 对局结算金币收益额外 +100% (翻倍)"));
        return list;
    }

    @Transactional
    public Map<String, Object> convertDiamondsToCoins(String userId, int diamonds) {
        if (diamonds <= 0) {
            throw new IllegalArgumentException("兑换的钻石数量必须大于 0");
        }
        User user = getOrCreateUser(userId);
        if (user.getDiamonds() == null || user.getDiamonds() < diamonds) {
            throw new IllegalArgumentException("💎 钻石余额不足 (当前 " + (user.getDiamonds() != null ? user.getDiamonds() : 0) + " 钻)，请前往充值");
        }
        long coinsAward = (long) diamonds * 100L;
        user.setDiamonds(user.getDiamonds() - diamonds);
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + coinsAward);
        userRepository.save(user);

        log.info("[Wallet] 用户 {} 使用 {} 颗钻石兑换了 {} 聚会金币 (汇率 1:100)", userId, diamonds, coinsAward);

        Map<String, Object> res = new HashMap<>();
        res.put("diamondsSpent", diamonds);
        res.put("coinsAward", coinsAward);
        res.put("diamonds", user.getDiamonds());
        res.put("coins", user.getCoins());
        res.put("user", user);
        return res;
    }

    /**
     * 创建商业化支付订单 (持久化为 PENDING 状态，支持对接真实微信/支付宝回调)
     */
    @Transactional
    public Map<String, Object> createOrder(String userId, String tierId, String payChannel) {
        User user = getOrCreateUser(userId);
        String channel = normalizeChannel(payChannel);
        String cleanTierId = (tierId != null && !tierId.isBlank()) ? tierId.trim() : "tier_6";

        int priceRmb;
        int diamondsAward;
        int coinsAward;
        int vipExpAward;
        String title;

        if ("first_recharge_6".equalsIgnoreCase(cleanTierId)) {
            List<String> inv = parseInventory(user.getInventory());
            if (inv.contains("FIRST_RECHARGE_CLAIMED") || (inv.contains("PURPLE_GALAXY") && inv.contains("BANNER_DRAGON"))) {
                throw new IllegalArgumentException("您已领取过6元首充特惠礼包，每个账号仅限参与一次！");
            }
            priceRmb = 6;
            diamondsAward = 666;
            coinsAward = 66666;
            vipExpAward = 60;
            title = "6元首充至尊豪华大礼包";
        } else {
            Map<String, Object> tier = getRechargeTiers().stream()
                    .filter(t -> t.get("id").equals(cleanTierId))
                    .findFirst()
                    .orElseThrow(() -> new IllegalArgumentException("未知的充值档位: " + cleanTierId));
            priceRmb = (int) tier.get("priceRmb");
            int baseDiamonds = (int) tier.get("diamonds");
            boolean isFirstDouble = (boolean) tier.get("isFirstDouble");
            diamondsAward = isFirstDouble ? baseDiamonds * 2 : baseDiamonds;
            coinsAward = (int) tier.get("coins");
            vipExpAward = (int) tier.get("vipExp");
            title = String.valueOf(tier.get("title"));
        }

        String prefix = "WXPAY".equals(channel) ? "WX-" : "ALI-";
        String orderId = prefix + System.currentTimeMillis() + "-" + (1000 + secureRandom.nextInt(9000));

        PaymentOrder order = PaymentOrder.builder()
                .orderId(orderId)
                .userId(user.getId())
                .tierId(cleanTierId)
                .payChannel(channel)
                .amountRmb(priceRmb)
                .diamondsAward(diamondsAward)
                .coinsAward(coinsAward)
                .vipExpAward(vipExpAward)
                .status("PENDING")
                .sandboxMode(isEffectiveSandbox())
                .build();
        paymentOrderRepository.save(order);

        Map<String, Object> res = new HashMap<>();
        res.put("orderId", orderId);
        res.put("userId", user.getId());
        res.put("tierId", cleanTierId);
        res.put("title", title);
        res.put("payChannel", channel);
        res.put("payChannelName", "WXPAY".equals(channel) ? "微信支付" : "支付宝支付");
        res.put("amountRmb", priceRmb);
        res.put("diamondsAward", diamondsAward);
        res.put("coinsAward", coinsAward);
        res.put("vipExpAward", vipExpAward);
        res.put("status", "PENDING");
        res.put("sandboxEnabled", isEffectiveSandbox());
        return res;
    }

    /**
     * 幂等确认订单到账 (由沙盒收银台或已绑定本人的支付核销调用)
     */
    @Transactional
    public Map<String, Object> confirmOrder(String orderId, String tradeNo) {
        return confirmOrder(orderId, tradeNo, null);
    }

    @Transactional
    public Map<String, Object> confirmOrder(String orderId, String tradeNo, String expectedUserId) {
        if (orderId == null || orderId.isBlank()) {
            throw new IllegalArgumentException("订单号不能为空");
        }
        PaymentOrder order = paymentOrderRepository.findByOrderId(orderId.trim())
                .orElseThrow(() -> new IllegalArgumentException("支付订单不存在: " + orderId));
        if (expectedUserId != null && !expectedUserId.isBlank()
                && !expectedUserId.trim().replace("-", "").equalsIgnoreCase(String.valueOf(order.getUserId()).replace("-", ""))) {
            throw new SecurityException("无权核销他人支付订单");
        }
        if (!isEffectiveSandbox()) {
            throw new IllegalArgumentException("生产模式禁止客户端直接确认订单，请通过官方支付回调核销");
        }
        User user = getOrCreateUser(order.getUserId());

        if ("PAID".equalsIgnoreCase(order.getStatus())) {
            Map<String, Object> idempotentRes = buildPaymentSettlementMap(order, user, false);
            idempotentRes.put("alreadyPaid", true);
            return idempotentRes;
        }
        if (!"PENDING".equalsIgnoreCase(order.getStatus())) {
            throw new IllegalArgumentException("当前订单状态不可结算: " + order.getStatus());
        }

        if ("first_recharge_6".equalsIgnoreCase(order.getTierId())) {
            List<String> inventory = parseInventory(user.getInventory());
            if (!inventory.contains("FIRST_RECHARGE_CLAIMED")) inventory.add("FIRST_RECHARGE_CLAIMED");
            if (!inventory.contains("PURPLE_GALAXY")) inventory.add("PURPLE_GALAXY");
            if (!inventory.contains("BANNER_DRAGON")) inventory.add("BANNER_DRAGON");
            user.setInventory(JSON.toJSONString(inventory));
            user.setDiceCupSkin("PURPLE_GALAXY");
            user.setEntranceBanner("BANNER_DRAGON");
        }

        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0L) + order.getDiamondsAward());
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + order.getCoinsAward());
        user.setTotalRechargeRmb((user.getTotalRechargeRmb() != null ? user.getTotalRechargeRmb() : 0) + order.getAmountRmb());

        int currentExp = (user.getVipExp() != null ? user.getVipExp() : 0) + order.getVipExpAward();
        user.setVipExp(currentExp);
        int oldVip = user.getVipLevel() != null ? user.getVipLevel() : 0;
        int newVip = calculateVipLevel(currentExp);
        if ("first_recharge_6".equalsIgnoreCase(order.getTierId())) {
            newVip = Math.max(1, newVip);
        }
        user.setVipLevel(newVip);
        boolean isVipUpgraded = newVip > oldVip;
        userRepository.save(user);

        order.setStatus("PAID");
        order.setPaidAt(LocalDateTime.now());
        order.setTradeNo(tradeNo != null && !tradeNo.isBlank() ? tradeNo.trim() : ("TX-" + order.getOrderId()));
        paymentOrderRepository.save(order);

        log.info("[Payment] 订单 {} 已结算到账: user={}, channel={}, amount=¥{}, diamonds={}, coins={}, vip={}",
                order.getOrderId(), user.getId(), order.getPayChannel(), order.getAmountRmb(),
                order.getDiamondsAward(), order.getCoinsAward(), newVip);

        return buildPaymentSettlementMap(order, user, isVipUpgraded);
    }

    /**
     * 收银台直充 (沙盒开关开启时创建订单并立即核销；生产模式强制走标准订单/回调链路)
     */
    @Transactional
    public Map<String, Object> processPayment(String userId, String tierId, String payChannel) {
        if (!isEffectiveSandbox()) {
            throw new IllegalArgumentException("生产模式已关闭模拟直充，请通过官方支付收银台创建订单并完成支付");
        }
        Map<String, Object> created = createOrder(userId, tierId, payChannel);
        String orderId = String.valueOf(created.get("orderId"));
        return confirmOrder(orderId, "SANDBOX-" + orderId, userId);
    }

    @Transactional
    public Map<String, Object> recharge(String userId, String tierId) {
        return processPayment(userId, tierId, "WXPAY");
    }

    @Transactional
    public User buyItem(String userId, String itemId, boolean autoEquip) {
        User user = getOrCreateUser(userId);
        Map<String, Object> item = getGoodsCatalog().stream()
                .filter(g -> g.get("id").equals(itemId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("所购道具不存在"));

        List<String> inventory = parseInventory(user.getInventory());
        if (inventory.contains(itemId) && !"pack".equals(item.get("category")) && !"gift_prop".equals(item.get("category"))) {
            throw new IllegalArgumentException("您已拥有该永久装扮");
        }

        int minVip = (int) item.get("minVip");
        if (minVip > 0 && (user.getVipLevel() == null || user.getVipLevel() < minVip)) {
            throw new IllegalArgumentException("该商品为 VIP " + minVip + " 专属特权");
        }

        int priceDiamonds = (int) item.get("priceDiamonds");
        int priceCoins = (int) item.get("priceCoins");
        if (priceDiamonds > 0) {
            if (user.getDiamonds() == null || user.getDiamonds() < priceDiamonds) {
                throw new IllegalArgumentException("钻石不足，请前往充值");
            }
            user.setDiamonds(user.getDiamonds() - priceDiamonds);
        } else if (priceCoins > 0) {
            if (user.getCoins() == null || user.getCoins() < priceCoins) {
                throw new IllegalArgumentException("金币不足，快去对局赚取金币吧");
            }
            user.setCoins(user.getCoins() - priceCoins);
        }

        if ("GIFT_STARTER".equals(itemId)) {
            user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + 10000L);
        }

        if (!inventory.contains(itemId)) {
            inventory.add(itemId);
            user.setInventory(JSON.toJSONString(inventory));
        }

        if (autoEquip) {
            String cat = (String) item.get("category");
            if ("dice_cup".equals(cat)) user.setDiceCupSkin(itemId);
            if ("avatar_frame".equals(cat)) user.setAvatarFrame(itemId);
            if ("entrance_banner".equals(cat)) user.setEntranceBanner(itemId);
            if ("chat_text_color".equals(cat) || "chatTextColor".equals(cat)) user.setChatTextColor(itemId);
        }

        return userRepository.save(user);
    }

    @Transactional
    public User equipItem(String userId, String slot, String itemId) {
        if (itemId == null || itemId.isBlank()) {
            throw new IllegalArgumentException("装扮编号不能为空");
        }
        User user = getOrCreateUser(userId);
        List<String> inventory = parseInventory(user.getInventory());
        if (!DEFAULT_OWNED_ITEMS.contains(itemId) && !inventory.contains(itemId)) {
            throw new IllegalArgumentException("您尚未拥有该装扮，请先前往商城购买");
        }

        if ("dice_cup".equals(slot)) user.setDiceCupSkin(itemId);
        else if ("avatar_frame".equals(slot)) user.setAvatarFrame(itemId);
        else if ("entrance_banner".equals(slot)) user.setEntranceBanner(itemId);
        else if ("chat_text_color".equals(slot) || "chatTextColor".equals(slot)) user.setChatTextColor(itemId);
        else throw new IllegalArgumentException("不支持的装扮部位: " + slot);

        return userRepository.save(user);
    }

    @Transactional
    public Map<String, Object> getSignInStatus(String userId) {
        User user = getOrCreateUser(userId);
        String today = LocalDate.now().toString();
        boolean hasSignedInToday = today.equals(user.getLastSignDate());
        int streak = user.getSignInStreak() != null ? user.getSignInStreak() : 0;

        List<Map<String, Object>> schedule = new ArrayList<>();
        schedule.add(Map.of("day", 1, "coins", 500, "diamonds", 0, "prop", "", "desc", "🪙 500金币"));
        schedule.add(Map.of("day", 2, "coins", 1000, "diamonds", 0, "prop", "", "desc", "🪙 1,000金币"));
        schedule.add(Map.of("day", 3, "coins", 1200, "diamonds", 0, "prop", "PROP_TRUMPET_10", "desc", "📢 全服大喇叭 + 🪙 1,200金币"));
        schedule.add(Map.of("day", 4, "coins", 1500, "diamonds", 0, "prop", "", "desc", "🪙 1,500金币"));
        schedule.add(Map.of("day", 5, "coins", 1800, "diamonds", 0, "prop", "GIFT_ROSE_20", "desc", "💐 浪漫玫瑰x20 + 🪙 1,800金币"));
        schedule.add(Map.of("day", 6, "coins", 2500, "diamonds", 0, "prop", "", "desc", "🪙 2,500金币"));
        schedule.add(Map.of("day", 7, "coins", 6666, "diamonds", 66, "prop", "GIFT_BOX_LEGENDARY", "desc", "👑 66钻石 + 🪙 6,666金币满签豪礼"));

        Map<String, Object> res = new HashMap<>();
        res.put("hasSignedInToday", hasSignedInToday);
        res.put("streak", streak);
        res.put("currentDayInCycle", ((streak - (hasSignedInToday ? 1 : 0)) % 7) + 1);
        res.put("schedule", schedule);
        res.put("coins", user.getCoins());
        res.put("diamonds", user.getDiamonds());
        return res;
    }

    @Transactional
    public Map<String, Object> signIn(String userId) {
        User user = getOrCreateUser(userId);
        String today = LocalDate.now().toString();
        if (today.equals(user.getLastSignDate())) {
            throw new IllegalArgumentException("您今天已经签到打卡过了，明天再来领奖吧！");
        }

        int streak = (user.getSignInStreak() != null ? user.getSignInStreak() : 0) + 1;
        user.setLastSignDate(today);
        user.setSignInStreak(streak);

        int cycleDay = ((streak - 1) % 7) + 1;
        long rewardCoins = 500L;
        int rewardDiamonds = 0;
        String propAward = null;

        switch (cycleDay) {
            case 1 -> rewardCoins = 500L;
            case 2 -> rewardCoins = 1000L;
            case 3 -> {
                rewardCoins = 1200L;
                propAward = "PROP_TRUMPET_10";
            }
            case 4 -> rewardCoins = 1500L;
            case 5 -> rewardCoins = 1800L;
            case 6 -> rewardCoins = 2500L;
            case 7 -> {
                rewardCoins = 6666L;
                rewardDiamonds = 66;
            }
        }

        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + rewardCoins);
        if (rewardDiamonds > 0) {
            user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0L) + rewardDiamonds);
        }

        if (propAward != null) {
            List<String> inventory = parseInventory(user.getInventory());
            inventory.add(propAward);
            user.setInventory(JSON.toJSONString(inventory));
        }

        userRepository.save(user);

        Map<String, Object> res = new HashMap<>();
        res.put("streak", streak);
        res.put("cycleDay", cycleDay);
        res.put("coinsReward", rewardCoins);
        res.put("diamondsReward", rewardDiamonds);
        res.put("propReward", propAward);
        res.put("user", user);
        return res;
    }

    /**
     * 6元首充至尊豪华大礼包 (严格单账号限领一次)
     */
    @Transactional
    public Map<String, Object> claimFirstRecharge(String userId, String payChannel) {
        if (!isEffectiveSandbox()) {
            throw new IllegalArgumentException("生产模式已关闭模拟首充，请通过官方支付收银台完成 6 元首充订单");
        }
        User user = getOrCreateUser(userId);
        List<String> inventory = parseInventory(user.getInventory());
        if (inventory.contains("FIRST_RECHARGE_CLAIMED") ||
                (inventory.contains("PURPLE_GALAXY") && inventory.contains("BANNER_DRAGON"))) {
            throw new IllegalArgumentException("您已领取过6元首充特惠礼包，每个账号仅限参与一次！");
        }

        Map<String, Object> orderCreated = createOrder(user.getId(), "first_recharge_6", payChannel);
        String orderId = String.valueOf(orderCreated.get("orderId"));
        Map<String, Object> settled = confirmOrder(orderId, "SANDBOX-FR-" + orderId, user.getId());
        settled.put("diceCupSkin", "PURPLE_GALAXY");
        settled.put("entranceBanner", "BANNER_DRAGON");
        return settled;
    }

    /**
     * 每日破产救济金与激励广告领币 (带每日限次与防刷冷却)
     */
    @Transactional
    public Map<String, Object> claimBankruptRelief(String userId, boolean isWatchAd) {
        User user = getOrCreateUser(userId);
        String today = LocalDate.now().toString();
        String dayKey = user.getId() + ":" + today;
        if (dailyReliefCounts.size() > 10000) {
            dailyReliefCounts.entrySet().removeIf(e -> !e.getKey().endsWith(":" + today));
        }
        int[] counts = dailyReliefCounts.computeIfAbsent(dayKey, k -> new int[]{0, 0});

        long curCoins = user.getCoins() != null ? user.getCoins() : 0L;
        int vip = user.getVipLevel() != null ? user.getVipLevel() : 0;

        long awardCoins;
        if (isWatchAd) {
            long now = System.currentTimeMillis();
            Long lastAd = lastAdReliefMs.get(user.getId());
            if (lastAd != null && (now - lastAd) < AD_RELIEF_COOLDOWN_MS) {
                long remain = Math.max(1L, (AD_RELIEF_COOLDOWN_MS - (now - lastAd) + 999L) / 1000L);
                throw new IllegalArgumentException("激励视频冷却中，请 " + remain + " 秒后再试！");
            }
            if (counts[1] >= MAX_DAILY_AD_RELIEF) {
                throw new IllegalArgumentException("今日激励视频领币次数已达上限 (" + MAX_DAILY_AD_RELIEF + " 次)，明天再来吧！");
            }
            counts[1]++;
            lastAdReliefMs.put(user.getId(), now);
            awardCoins = 3000L;
        } else {
            if (curCoins >= 1000) {
                throw new IllegalArgumentException("当前金币充足 (" + curCoins + " 币)，未达到破产救济标准（<1000 币）哦！");
            }
            int vipExtra = (vip >= 9) ? 5 : (vip >= 6 ? 3 : (vip >= 4 ? 2 : (vip >= 3 ? 1 : 0)));
            int maxStandardDaily = (vip >= 10) ? Integer.MAX_VALUE : (3 + vipExtra);
            if (counts[0] >= maxStandardDaily) {
                throw new IllegalArgumentException("今日破产救济金已领完 (" + maxStandardDaily + " 次)，升级 VIP 或观看福利视频可继续领币！");
            }
            counts[0]++;
            awardCoins = (vip >= 8) ? 3000L : ((vip >= 5) ? 2500L : 1500L);
        }

        user.setCoins(curCoins + awardCoins);
        userRepository.save(user);
        log.info("[BankruptRelief] 用户 {} 领取破产救济 (isWatchAd={}), 金币 +{}, 现余额: {}",
                userId, isWatchAd, awardCoins, user.getCoins());

        Map<String, Object> res = new HashMap<>();
        res.put("awardCoins", awardCoins);
        res.put("isWatchAd", isWatchAd);
        res.put("coins", user.getCoins());
        res.put("remainingStandardToday", vip >= 10 ? 999 : Math.max(0, (3 + ((vip >= 9) ? 5 : (vip >= 6 ? 3 : (vip >= 4 ? 2 : (vip >= 3 ? 1 : 0))))) - counts[0]));
        res.put("remainingAdToday", Math.max(0, MAX_DAILY_AD_RELIEF - counts[1]));
        res.put("user", user);
        return res;
    }

    /**
     * 幸运夺宝盲盒抽奖转盘 (健康商业化 ~82% RTP 概率模型)
     */
    @Transactional
    public Map<String, Object> luckyDraw(String userId, int drawCount, String currency) {
        User user = getOrCreateUser(userId);
        int count = (drawCount == 10) ? 10 : 1;
        boolean isCoin = !"DIAMOND".equalsIgnoreCase(currency);

        long needCoins = (count == 10) ? 9000L : 1000L;
        int needDiamonds = (count == 10) ? 90 : 10;

        if (isCoin) {
            long curCoins = user.getCoins() != null ? user.getCoins() : 0L;
            if (curCoins < needCoins) {
                throw new IllegalArgumentException("聚会金币不足 (" + curCoins + "/" + needCoins + ")，可前往充值或看广告领取！");
            }
            user.setCoins(curCoins - needCoins);
        } else {
            long curDiamonds = user.getDiamonds() != null ? user.getDiamonds() : 0L;
            if (curDiamonds < needDiamonds) {
                throw new IllegalArgumentException("钻石不足 (" + curDiamonds + "/" + needDiamonds + ")，请前往充值！");
            }
            user.setDiamonds(curDiamonds - needDiamonds);
        }

        List<Map<String, Object>> prizesWon = new ArrayList<>();
        long totalCoinsWon = 0;
        int totalDiamondsWon = 0;

        for (int i = 0; i < count; i++) {
            int roll = secureRandom.nextInt(1000);
            Map<String, Object> prize = new HashMap<>();
            if (isCoin) {
                if (roll < 3) {
                    prize.put("name", "👑 88 璀璨钻石大奖");
                    prize.put("type", "DIAMOND");
                    prize.put("amount", 88);
                    prize.put("rarity", "LEGENDARY");
                    totalDiamondsWon += 88;
                } else if (roll < 20) {
                    prize.put("name", "🚀 全服超级火箭 x1");
                    prize.put("type", "PROP");
                    prize.put("propId", "PROP_ROCKET_100");
                    prize.put("rarity", "EPIC");
                } else if (roll < 100) {
                    prize.put("name", "🪙 3,888 金币惊喜袋");
                    prize.put("type", "COIN");
                    prize.put("amount", 3888);
                    prize.put("rarity", "RARE");
                    totalCoinsWon += 3888;
                } else if (roll < 300) {
                    prize.put("name", "📢 全服大喇叭 x1");
                    prize.put("type", "PROP");
                    prize.put("propId", "PROP_TRUMPET_10");
                    prize.put("rarity", "UNCOMMON");
                } else if (roll < 650) {
                    long c = 800 + secureRandom.nextInt(401);
                    prize.put("name", "🪙 " + c + " 金币好礼");
                    prize.put("type", "COIN");
                    prize.put("amount", c);
                    prize.put("rarity", "COMMON");
                    totalCoinsWon += c;
                } else {
                    long c = 300 + secureRandom.nextInt(301);
                    prize.put("name", "🪙 " + c + " 幸运金币");
                    prize.put("type", "COIN");
                    prize.put("amount", c);
                    prize.put("rarity", "COMMON");
                    totalCoinsWon += c;
                }
            } else {
                if (roll < 8) {
                    prize.put("name", "👑 188 璀璨钻石大奖");
                    prize.put("type", "DIAMOND");
                    prize.put("amount", 188);
                    prize.put("rarity", "LEGENDARY");
                    totalDiamondsWon += 188;
                } else if (roll < 40) {
                    prize.put("name", "🚀 全服超级火箭 x1");
                    prize.put("type", "PROP");
                    prize.put("propId", "PROP_ROCKET_100");
                    prize.put("rarity", "EPIC");
                } else if (roll < 160) {
                    prize.put("name", "🪙 8,888 金币狂欢袋");
                    prize.put("type", "COIN");
                    prize.put("amount", 8888);
                    prize.put("rarity", "RARE");
                    totalCoinsWon += 8888;
                } else if (roll < 400) {
                    prize.put("name", "📢 全服大喇叭 x1");
                    prize.put("type", "PROP");
                    prize.put("propId", "PROP_TRUMPET_10");
                    prize.put("rarity", "UNCOMMON");
                } else {
                    long c = 600 + secureRandom.nextInt(601);
                    prize.put("name", "🪙 " + c + " 金币好礼");
                    prize.put("type", "COIN");
                    prize.put("amount", c);
                    prize.put("rarity", "COMMON");
                    totalCoinsWon += c;
                }
            }
            prizesWon.add(prize);
        }

        List<String> inventory = parseInventory(user.getInventory());
        for (Map<String, Object> prize : prizesWon) {
            if ("PROP".equals(prize.get("type")) && prize.get("propId") != null) {
                String propId = (String) prize.get("propId");
                if (!inventory.contains(propId)) {
                    inventory.add(propId);
                }
            }
        }
        user.setInventory(JSON.toJSONString(inventory));

        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + totalCoinsWon);
        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0L) + totalDiamondsWon);
        userRepository.save(user);

        log.info("[LuckyDraw] 用户 {} 夺宝 {} 次 ({}), 赢得金币: {}, 钻石: {}", userId, count, isCoin ? "COIN" : "DIAMOND", totalCoinsWon, totalDiamondsWon);

        Map<String, Object> res = new HashMap<>();
        res.put("drawCount", count);
        res.put("currency", isCoin ? "COIN" : "DIAMOND");
        res.put("prizesWon", prizesWon);
        res.put("totalCoinsWon", totalCoinsWon);
        res.put("totalDiamondsWon", totalDiamondsWon);
        res.put("coins", user.getCoins());
        res.put("diamonds", user.getDiamonds());
        res.put("user", user);
        return res;
    }

    /**
     * 对局结算赢家翻倍卡 (单局封顶 2,000 金币 + 30 秒冷却)
     */
    @Transactional
    public Map<String, Object> settleVictoryDouble(String userId, long baseWinCoins) {
        User user = getOrCreateUser(userId);
        long now = System.currentTimeMillis();
        Long lastTs = lastVictoryDoubleMs.get(user.getId());
        if (lastTs != null && (now - lastTs) < VICTORY_DOUBLE_COOLDOWN_MS) {
            long remain = Math.max(1L, (VICTORY_DOUBLE_COOLDOWN_MS - (now - lastTs) + 999L) / 1000L);
            throw new IllegalArgumentException("翻倍卡冷却中，请 " + remain + " 秒后再试！");
        }

        long curDiamonds = user.getDiamonds() != null ? user.getDiamonds() : 0L;
        if (curDiamonds < 10) {
            throw new IllegalArgumentException("钻石不足 10 钻，无法激活本局翻倍！快去充值吧！");
        }
        user.setDiamonds(curDiamonds - 10L);
        long clampedBonus = Math.min(Math.max(100L, baseWinCoins), 2000L);
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + clampedBonus);
        userRepository.save(user);
        lastVictoryDoubleMs.put(user.getId(), now);

        Map<String, Object> res = new HashMap<>();
        res.put("extraCoins", clampedBonus);
        res.put("diamondsSpent", 10);
        res.put("coins", user.getCoins());
        res.put("diamonds", user.getDiamonds());
        res.put("user", user);
        return res;
    }

    /**
     * 获取每日任务列表 (基于今日真实对局与投掷统计)
     */
    public List<Map<String, Object>> getDailyTasks(String userId) {
        String today = LocalDate.now().toString();
        String uid = (userId != null && !userId.isBlank()) ? userId.trim() : "";
        Set<String> claimedSet = new HashSet<>();
        if (!uid.isEmpty()) {
            claimedSet.addAll(dailyClaimedTasks.getOrDefault(uid + ":" + today, Collections.emptySet()));
            userRepository.findById(uid).ifPresent(u -> claimedSet.addAll(readPersistedClaimedTasks(u, today)));
        }

        LocalDateTime todayStart = LocalDateTime.of(LocalDate.now(), LocalTime.MIN);
        int todayGames = uid.isEmpty() ? 0 : (int) battleRecordRepository.countByUserIdAndPlayedAtAfter(uid, todayStart);
        int todayWins = uid.isEmpty() ? 0 : (int) battleRecordRepository.countByUserIdAndIsWinTrueAndPlayedAtAfter(uid, todayStart);
        int todayThrows = uid.isEmpty() ? 0 : getDailyThrowCount(uid);

        List<Map<String, Object>> tasks = new ArrayList<>();
        tasks.add(buildTask("task_login", "每日登录打卡", 1, 1, 100, 5, claimedSet.contains("task_login")));
        tasks.add(buildTask("task_play_1", "参与 1 局聚会桌游", 1, Math.min(1, todayGames), 200, 10, claimedSet.contains("task_play_1")));
        tasks.add(buildTask("task_win_1", "赢得 1 场排位对局", 1, Math.min(1, todayWins), 300, 15, claimedSet.contains("task_win_1")));
        tasks.add(buildTask("task_throw_3", "向好友投掷 3 次互动道具", 3, Math.min(3, todayThrows), 150, 5, claimedSet.contains("task_throw_3")));
        tasks.add(buildTask("task_play_3", "累计完成 3 局桌游", 3, Math.min(3, todayGames), 500, 30, claimedSet.contains("task_play_3")));
        return tasks;
    }

    /**
     * 领取每日任务奖励 (校验真实进度、持久化每日已领记录、防并发重复刷取)
     */
    @Transactional
    public Map<String, Object> claimDailyTask(String userId, String taskId) {
        if (userId == null || userId.isBlank() || taskId == null || taskId.isBlank()) {
            throw new IllegalArgumentException("参数错误");
        }
        String cleanTaskId = taskId.trim();
        Object lock = userTaskLocks.computeIfAbsent(userId.trim(), k -> new Object());
        synchronized (lock) {
            User user = getOrCreateUser(userId);
            String today = LocalDate.now().toString();
            Set<String> persisted = readPersistedClaimedTasks(user, today);
            if (persisted.contains(cleanTaskId)) {
                throw new IllegalArgumentException("该任务今日奖励已领取过啦！");
            }

            List<Map<String, Object>> tasks = getDailyTasks(user.getId());
            Map<String, Object> task = tasks.stream()
                    .filter(t -> cleanTaskId.equals(t.get("id")))
                    .findFirst()
                    .orElseThrow(() -> new IllegalArgumentException("未知的每日任务: " + taskId));

            if (Boolean.TRUE.equals(task.get("isClaimed"))) {
                throw new IllegalArgumentException("该任务今日奖励已领取过啦！");
            }
            int current = ((Number) task.get("current")).intValue();
            int target = ((Number) task.get("target")).intValue();
            if (current < target) {
                throw new IllegalArgumentException("任务进度尚未达成 (" + current + "/" + target + ")，请先完成任务！");
            }

            String key = user.getId() + ":" + today;
            if (dailyClaimedTasks.size() > 10000) {
                dailyClaimedTasks.entrySet().removeIf(e -> !e.getKey().endsWith(":" + today));
            }
            Set<String> claimedSet = dailyClaimedTasks.computeIfAbsent(key, k -> ConcurrentHashMap.newKeySet());
            if (!claimedSet.add(cleanTaskId)) {
                throw new IllegalArgumentException("该任务今日奖励已领取过啦！");
            }

            persisted.add(cleanTaskId);
            user.setDailyTasksDate(today);
            user.setDailyClaimedTasksJson(JSON.toJSONString(persisted));

            int rewardCoins = ((Number) task.get("rewardCoins")).intValue();
            int rewardDiamonds = ((Number) task.get("rewardDiamonds")).intValue();
            user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + rewardCoins);
            user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0L) + rewardDiamonds);
            userRepository.save(user);

            Map<String, Object> res = new HashMap<>();
            res.put("taskId", cleanTaskId);
            res.put("rewardCoins", rewardCoins);
            res.put("rewardDiamonds", rewardDiamonds);
            res.put("user", user);
            return res;
        }
    }

    private Set<String> readPersistedClaimedTasks(User user, String today) {
        Set<String> set = new LinkedHashSet<>();
        if (user != null && today.equals(user.getDailyTasksDate())) {
            String raw = user.getDailyClaimedTasksJson();
            if (raw != null && !raw.isBlank()) {
                try {
                    List<String> parsed = JSON.parseArray(raw, String.class);
                    if (parsed != null) {
                        set.addAll(parsed);
                    }
                } catch (Exception ignored) {}
            }
        }
        return set;
    }

    private Map<String, Object> buildPaymentSettlementMap(PaymentOrder order, User user, boolean isVipUpgraded) {
        Map<String, Object> res = new HashMap<>();
        res.put("orderId", order.getOrderId());
        res.put("payChannel", order.getPayChannel());
        res.put("payChannelName", "WXPAY".equals(order.getPayChannel()) ? "微信支付" : "支付宝支付");
        res.put("priceRmb", order.getAmountRmb());
        res.put("diamondsAward", order.getDiamondsAward());
        res.put("coinsAward", order.getCoinsAward());
        res.put("vipExpAward", order.getVipExpAward());
        res.put("vipLevel", user.getVipLevel() != null ? user.getVipLevel() : 0);
        res.put("isVipUpgraded", isVipUpgraded);
        res.put("status", order.getStatus());
        res.put("user", user);
        return res;
    }

    private Map<String, Object> buildTask(String id, String title, int target, int current, int coins, int diamonds, boolean claimed) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", id);
        map.put("title", title);
        map.put("target", target);
        map.put("current", current);
        map.put("rewardCoins", coins);
        map.put("rewardDiamonds", diamonds);
        map.put("isClaimed", claimed);
        map.put("claimed", claimed);
        return map;
    }

    private List<String> parseInventory(String rawInventory) {
        List<String> inventory = new ArrayList<>();
        if (rawInventory != null && !rawInventory.trim().isEmpty()) {
            try {
                List<String> parsed = JSON.parseArray(rawInventory, String.class);
                if (parsed != null) inventory.addAll(parsed);
            } catch (Exception ignored) {}
        }
        return inventory;
    }

    private String normalizeChannel(String payChannel) {
        String channel = (payChannel != null && !payChannel.isBlank()) ? payChannel.trim().toUpperCase() : "WXPAY";
        if (!"WXPAY".equals(channel) && !"ALIPAY".equals(channel)) {
            return "WXPAY";
        }
        return channel;
    }

    private Map<String, Object> createGood(String id, String category, String name, int coins, int diamonds, int minVip, String icon, String desc, boolean isDefault) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", id);
        map.put("category", category);
        map.put("name", name);
        map.put("priceCoins", coins);
        map.put("priceDiamonds", diamonds);
        map.put("minVip", minVip);
        map.put("icon", icon);
        map.put("desc", desc);
        map.put("isDefault", isDefault);
        return map;
    }

    private Map<String, Object> createTier(String id, int rmb, int diamonds, int coins, int vipExp, boolean firstDouble, String title, String badge) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", id);
        map.put("priceRmb", rmb);
        map.put("diamonds", diamonds);
        map.put("coins", coins);
        map.put("vipExp", vipExp);
        map.put("isFirstDouble", firstDouble);
        map.put("title", title);
        map.put("badge", badge);
        return map;
    }
}
