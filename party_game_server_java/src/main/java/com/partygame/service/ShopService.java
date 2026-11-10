package com.partygame.service;

import com.alibaba.fastjson2.JSON;
import com.partygame.entity.User;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class ShopService {

    private final UserRepository userRepository;

    public User getOrCreateUser(String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            userId = "WEB" + (System.currentTimeMillis() % 1000000);
        }
        String finalUid = userId.trim();
        return userRepository.findById(finalUid).orElseGet(() -> {
            User u = User.builder()
                    .id(finalUid)
                    .username("web_" + finalUid)
                    .nickname("玩家_" + (finalUid.length() > 4 ? finalUid.substring(finalUid.length() - 4) : finalUid))
                    .avatar("🦊")
                    .coins(2000L)
                    .diamonds(50L)
                    .vipLevel(1)
                    .vipExp(10)
                    .build();
            return userRepository.save(u);
        });
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
        // 钻石专属道具（金币无法购买）
        list.add(createGood("FLAME_DRAGON", "dice_cup", "烈焰赤龙骰盅", 0, 88, 0, "🔥", "烈火熊熊势不可挡，纯钻石奢华专属", false));
        list.add(createGood("PURE_DIAMOND", "dice_cup", "璀璨钻石骰盅", 0, 188, 0, "💎", "八心八箭至尊水晶切割，闪耀全场 (纯钻石专属)", false));
        list.add(createGood("ROYAL_DRAGON_GOLD", "dice_cup", "至尊黄金神龙骰盅", 0, 288, 2, "👑", "VIP 2 专属奢华黄金盘龙，尊崇绝伦", false));

        // ===== 2. 头像框专区 =====
        list.add(createGood("FRAME_DEFAULT", "avatar_frame", "聚会新星框", 0, 0, 0, "⭐", "初入聚会社区基础装扮", true));
        list.add(createGood("FRAME_NEON", "avatar_frame", "赛博流光框", 3000, 0, 0, "🌈", "流光幻彩渐变边框，彰显个性 (金币专享)", false));
        list.add(createGood("FRAME_GOLD", "avatar_frame", "荣耀黄金框", 8000, 0, 0, "🥇", "璀璨真金抛光工艺，王者气派 (金币专享)", false));
        // 钻石专属头像框（金币无法购买）
        list.add(createGood("FRAME_GALAXY_DOMINATOR", "avatar_frame", "星空霸主框", 0, 128, 1, "🌌", "VIP 1 专属星辰环绕动效框 (纯钻石专属)", false));
        list.add(createGood("FRAME_BLACK_GOLD_ROYAL", "avatar_frame", "黑金至尊帝王框", 0, 388, 4, "🔱", "VIP 4 专属黑金龙纹霸气图腾 (纯钻石专属)", false));

        // ===== 3. 登场横幅专区 =====
        list.add(createGood("BANNER_DEFAULT", "entrance_banner", "普通登场横幅", 0, 0, 0, "🚪", "系统默认进房提示", true));
        list.add(createGood("BANNER_SHINE", "entrance_banner", "闪亮登场横幅", 5000, 0, 0, "✨", "全场星光闪烁，醒目进场 (金币专享)", false));
        // 钻石专属入场横幅（金币无法购买）
        list.add(createGood("BANNER_DRAGON", "entrance_banner", "凤舞龙吟横幅", 0, 128, 0, "🐉", "神龙破空进场横幅，全屏焦点 (纯钻石专属)", false));
        list.add(createGood("BANNER_EMPEROR", "entrance_banner", "君临天下横幅", 0, 588, 3, "👑", "VIP 3 专属尊贵入场全服公告 (纯钻石专属)", false));

        // ===== 4. 聊天文字颜色卡专区 =====
        list.add(createGood("COLOR_DEFAULT", "chat_text_color", "默认经典白", 0, 0, 0, "💬", "系统默认发言文字颜色 (#FFFFFF)", true));
        list.add(createGood("COLOR_SAKURA_PINK", "chat_text_color", "炫彩樱花粉", 3000, 0, 0, "🌸", "清新烂漫樱花粉，字字动人心弦 (金币专享)", false));
        list.add(createGood("COLOR_CYBER_BLUE", "chat_text_color", "赛博冰川蓝", 5000, 0, 0, "💎", "极客未来冷萃冰蓝，字迹冷酷吸睛 (金币专享)", false));
        // 钻石专属聊天字色（金币无法购买）
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

    /**
     * 官方标准充值档位 (严格遵循 1元RMB = 10钻石，1钻石 = 100金币，充值赠送超值福利)
     */
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

    /**
     * VIP 等级权益详细体系表
     */
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
        list.add(Map.of("level", 10, "name", "VIP 10 · 荣耀无双 (至高无上·无双王者)", "needExp", 188888, "priceRmb", 18888, "privileges", "• 终极 SVIP 10 荣耀无双七彩神级徽章\n• 【同桌装扮共享特权】（牌友可共享使用您拥有的骰盅皮肤与牌桌特效，对标王者荣耀皮肤共享）\n• 神级龙腾入场全服公告横幅\n• 每日破产救济金无限次保底领取\n• 对局结算金币收益额外 +100% (翻倍)"));
        return list;
    }

    /**
     * 钻石兑换金币 (严格按照 1 钻石 = 100 金币比例兑换)
     */
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
     * 预留微信与支付宝支付网关 (支持模拟支付与真实入账流程)
     */
    @Transactional
    public Map<String, Object> processPayment(String userId, String tierId, String payChannel) {
        String channel = (payChannel != null && !payChannel.isBlank()) ? payChannel.toUpperCase() : "WXPAY";
        if (!"WXPAY".equals(channel) && !"ALIPAY".equals(channel)) {
            channel = "WXPAY";
        }

        User user = getOrCreateUser(userId);
        Map<String, Object> tier = getRechargeTiers().stream()
                .filter(t -> t.get("id").equals(tierId))
                .findFirst()
                .orElse(getRechargeTiers().get(0));

        int priceRmb = (int) tier.get("priceRmb");
        int diamonds = (int) tier.get("diamonds");
        boolean isFirstDouble = (boolean) tier.get("isFirstDouble");
        int diamondsAward = isFirstDouble ? diamonds * 2 : diamonds;
        int coinsAward = (int) tier.get("coins");
        int vipExpAward = (int) tier.get("vipExp");

        // 模拟支付订单生成 (预留微信 prepay_id 与支付宝 trade_no 规范字段)
        String orderId = (("WXPAY".equals(channel) ? "WX-" : "ALI-") + System.currentTimeMillis() + "-" + (1000 + new Random().nextInt(9000)));

        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + diamondsAward);
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + coinsAward);
        user.setTotalRechargeRmb((user.getTotalRechargeRmb() != null ? user.getTotalRechargeRmb() : 0) + priceRmb);

        int currentExp = (user.getVipExp() != null ? user.getVipExp() : 0) + vipExpAward;
        user.setVipExp(currentExp);
        int oldVip = user.getVipLevel() != null ? user.getVipLevel() : 0;
        int newVip = calculateVipLevel(currentExp);
        user.setVipLevel(newVip);
        boolean isVipUpgraded = newVip > oldVip;

        userRepository.save(user);

        log.info("[Payment] 用户 {} 通过 [{}] 成功支付 {} 元 (订单号: {}), 到账 {} 钻石 + {} 金币, VIP 等级: {}",
                userId, ("WXPAY".equals(channel) ? "微信支付" : "支付宝支付"), priceRmb, orderId, diamondsAward, coinsAward, newVip);

        Map<String, Object> res = new HashMap<>();
        res.put("orderId", orderId);
        res.put("payChannel", channel);
        res.put("payChannelName", "WXPAY".equals(channel) ? "微信支付" : "支付宝支付");
        res.put("priceRmb", priceRmb);
        res.put("diamondsAward", diamondsAward);
        res.put("coinsAward", coinsAward);
        res.put("vipExpAward", vipExpAward);
        res.put("vipLevel", newVip);
        res.put("isVipUpgraded", isVipUpgraded);
        res.put("user", user);
        return res;
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

        List<String> inventory = new ArrayList<>();
        if (user.getInventory() != null && !user.getInventory().trim().isEmpty()) {
            try {
                inventory = JSON.parseArray(user.getInventory(), String.class);
            } catch (Exception ignored) {}
        }
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
        User user = getOrCreateUser(userId);
        if ("dice_cup".equals(slot)) user.setDiceCupSkin(itemId);
        else if ("avatar_frame".equals(slot)) user.setAvatarFrame(itemId);
        else if ("entrance_banner".equals(slot)) user.setEntranceBanner(itemId);
        else if ("chat_text_color".equals(slot) || "chatTextColor".equals(slot)) user.setChatTextColor(itemId);
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

        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + rewardCoins);
        if (rewardDiamonds > 0) {
            user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + rewardDiamonds);
        }

        if (propAward != null) {
            List<String> inventory = new ArrayList<>();
            if (user.getInventory() != null && !user.getInventory().trim().isEmpty()) {
                try {
                    inventory = JSON.parseArray(user.getInventory(), String.class);
                } catch (Exception ignored) {}
            }
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

    /**
     * 6元首充至尊豪华大礼包 (破冰转化)
     */
    @Transactional
    public Map<String, Object> claimFirstRecharge(String userId, String payChannel) {
        User user = getOrCreateUser(userId);
        
        List<String> inventory = new ArrayList<>();
        if (user.getInventory() != null && !user.getInventory().trim().isEmpty()) {
            try {
                inventory = JSON.parseArray(user.getInventory(), String.class);
            } catch (Exception ignored) {}
        }
                if (inventory.contains("PURPLE_GALAXY")) {
            user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + 666L);
            user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + 66666L);
            user.setTotalRechargeRmb((user.getTotalRechargeRmb() != null ? user.getTotalRechargeRmb() : 0) + 6);
            int currentExp = (user.getVipExp() != null ? user.getVipExp() : 0) + 60;
            user.setVipExp(currentExp);
            int newVip = Math.max(1, calculateVipLevel(currentExp));
            user.setVipLevel(newVip);
            userRepository.save(user);
            Map<String, Object> repeatRes = new HashMap<>();
            repeatRes.put("diamondsAward", 666);
            repeatRes.put("coinsAward", 66666);
            repeatRes.put("vipLevel", newVip);
            repeatRes.put("user", user);
            return repeatRes;
        }

        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + 666L);
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + 66666L);
        user.setTotalRechargeRmb((user.getTotalRechargeRmb() != null ? user.getTotalRechargeRmb() : 0) + 6);

        int currentExp = (user.getVipExp() != null ? user.getVipExp() : 0) + 60;
        user.setVipExp(currentExp);
        int oldVip = user.getVipLevel() != null ? user.getVipLevel() : 0;
        int newVip = Math.max(1, calculateVipLevel(currentExp));
        user.setVipLevel(newVip);

        if (!inventory.contains("PURPLE_GALAXY")) inventory.add("PURPLE_GALAXY");
        if (!inventory.contains("BANNER_DRAGON")) inventory.add("BANNER_DRAGON");
        user.setInventory(JSON.toJSONString(inventory));
        user.setDiceCupSkin("PURPLE_GALAXY");
        user.setEntranceBanner("BANNER_DRAGON");

        userRepository.save(user);
        log.info("[FirstRecharge] 用户 {} 成功激活 6元首充大礼包，到账 666 钻石 + 66666 金币，获得紫晶骰盅与龙吟横幅，VIP 直升至 {}", userId, newVip);

        Map<String, Object> res = new HashMap<>();
        res.put("diamondsAward", 666);
        res.put("coinsAward", 66666);
        res.put("vipLevel", newVip);
        res.put("diceCupSkin", "PURPLE_GALAXY");
        res.put("entranceBanner", "BANNER_DRAGON");
        res.put("user", user);
        return res;
    }

    /**
     * 每日破产救济金与激励广告领币 (挫败挽留与广告流量变现)
     */
    @Transactional
    public Map<String, Object> claimBankruptRelief(String userId, boolean isWatchAd) {
        User user = getOrCreateUser(userId);
        
        long curCoins = user.getCoins() != null ? user.getCoins() : 0L;
        if (curCoins >= 1000 && !isWatchAd) {
            throw new IllegalArgumentException("当前金币充足 (" + curCoins + " 币)，未达到破产救济标准（<1000 币）哦！");
        }

        long awardCoins;
        if (isWatchAd) {
            awardCoins = 3000L;
        } else {
            int vip = user.getVipLevel() != null ? user.getVipLevel() : 0;
            awardCoins = (vip >= 5) ? 2500L : 1500L;
        }

        user.setCoins(curCoins + awardCoins);
        userRepository.save(user);
        log.info("[BankruptRelief] 用户 {} 领取破产救济 (isWatchAd: {}), 金币 +{}, 现余额: {}", userId, isWatchAd, awardCoins, user.getCoins());

        Map<String, Object> res = new HashMap<>();
        res.put("awardCoins", awardCoins);
        res.put("isWatchAd", isWatchAd);
        res.put("coins", user.getCoins());
        res.put("user", user);
        return res;
    }

    /**
     * 幸运夺宝盲盒抽奖转盘 (金币水池回收与钻石消耗)
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
        Random rand = new Random();
        long totalCoinsWon = 0;
        int totalDiamondsWon = 0;

        for (int i = 0; i < count; i++) {
            int roll = rand.nextInt(1000);
            Map<String, Object> prize = new HashMap<>();
            if (roll < 5) {
                prize.put("name", "👑 888 璀璨钻石大奖");
                prize.put("type", "DIAMOND");
                prize.put("amount", 888);
                prize.put("rarity", "LEGENDARY");
                totalDiamondsWon += 888;
            } else if (roll < 30) {
                prize.put("name", "🚀 全服超级火箭 x1");
                prize.put("type", "PROP");
                prize.put("propId", "PROP_ROCKET_100");
                prize.put("rarity", "EPIC");
            } else if (roll < 120) {
                prize.put("name", "🪙 18,888 金币狂欢袋");
                prize.put("type", "COIN");
                prize.put("amount", 18888);
                prize.put("rarity", "RARE");
                totalCoinsWon += 18888;
            } else if (roll < 350) {
                prize.put("name", "📢 全服大喇叭 x1");
                prize.put("type", "PROP");
                prize.put("propId", "PROP_TRUMPET_10");
                prize.put("rarity", "UNCOMMON");
            } else {
                long c = 1200 + rand.nextInt(1800);
                prize.put("name", "🪙 " + c + " 金币保底");
                prize.put("type", "COIN");
                prize.put("amount", c);
                prize.put("rarity", "COMMON");
                totalCoinsWon += c;
            }
            prizesWon.add(prize);
        }

        List<String> inventory = new ArrayList<>();
        if (user.getInventory() != null && !user.getInventory().trim().isEmpty()) {
            try {
                inventory = JSON.parseArray(user.getInventory(), String.class);
            } catch (Exception ignored) {}
        }
        for (Map<String, Object> prize : prizesWon) {
            if ("PROP".equals(prize.get("type")) && prize.get("propId") != null) {
                inventory.add((String) prize.get("propId"));
            }
        }
        user.setInventory(JSON.toJSONString(inventory));

        user.setCoins((user.getCoins() != null ? user.getCoins() : 0) + totalCoinsWon);
        user.setDiamonds((user.getDiamonds() != null ? user.getDiamonds() : 0) + totalDiamondsWon);
        userRepository.save(user);

        log.info("[LuckyDraw] 用户 {} 夺宝 {} 次, 赢得金币: {}, 钻石: {}", userId, count, totalCoinsWon, totalDiamondsWon);

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
     * 对局结算赢家翻倍卡 (局内即时冲动付费)
     */
    @Transactional
    public Map<String, Object> settleVictoryDouble(String userId, long baseWinCoins) {
        User user = getOrCreateUser(userId);
        long curDiamonds = user.getDiamonds() != null ? user.getDiamonds() : 0L;
        if (curDiamonds < 10) {
            throw new IllegalArgumentException("钻石不足 10 钻，无法激活本局翻倍！快去充值吧！");
        }
        user.setDiamonds(curDiamonds - 10L);
        long doubleAward = Math.max(1000L, baseWinCoins);
        user.setCoins((user.getCoins() != null ? user.getCoins() : 0L) + doubleAward);
        userRepository.save(user);

        Map<String, Object> res = new HashMap<>();
        res.put("extraCoins", doubleAward);
        res.put("diamondsSpent", 10);
        res.put("coins", user.getCoins());
        res.put("diamonds", user.getDiamonds());
        res.put("user", user);
        return res;
    }

}
