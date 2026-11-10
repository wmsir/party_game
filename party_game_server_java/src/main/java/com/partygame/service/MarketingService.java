package com.partygame.service;

import com.alibaba.fastjson2.JSON;
import com.partygame.entity.SystemConfig;
import com.partygame.repository.SystemConfigRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class MarketingService {

    public static final String KEY_MARKETING_BANNERS = "CONFIG_MARKETING_BANNERS";

    private final SystemConfigRepository configRepository;

    @PostConstruct
    public void initDefaultMarketingConfigs() {
        if (configRepository.findByConfigKey(KEY_MARKETING_BANNERS).isEmpty()) {
            List<Map<String, Object>> defaultBanners = new ArrayList<>();

            Map<String, Object> b1 = new HashMap<>();
            b1.put("id", "act_autumn_carnival");
            b1.put("title", "🍂 金秋聚会狂欢节 · 充值双倍送神龙");
            b1.put("subtitle", "首充享 100% 钻石返还，升级 VIP 免费领专属神龙骰盅与帝王框");
            b1.put("tag", "限时爆款");
            b1.put("colorStart", "#F59E0B");
            b1.put("colorEnd", "#DC2626");
            b1.put("badge", "HOT");
            b1.put("active", true);
            b1.put("sortOrder", 1);
            defaultBanners.add(b1);

            Map<String, Object> b2 = new HashMap<>();
            b2.put("id", "act_weekend_dice_king");
            b2.put("title", "👑 周末排位冲榜盛典 · 瓜分 100 万金币");
            b2.put("subtitle", "周末参与排位赛胜利胜点 +50%，全服排行榜前十名独享专属称号");
            b2.put("tag", "周末福利");
            b2.put("colorStart", "#6366F1");
            b2.put("colorEnd", "#8B5CF6");
            b2.put("badge", "NEW");
            b2.put("active", true);
            b2.put("sortOrder", 2);
            defaultBanners.add(b2);

            Map<String, Object> b3 = new HashMap<>();
            b3.put("id", "act_invite_friends");
            b3.put("title", "🎁 好友狂欢集结令 · 组队开黑赠礼包");
            b3.put("subtitle", "邀请好友成功开局即赠【酒桌互动大礼包】与 5000 聚会金币");
            b3.put("tag", "社交好礼");
            b3.put("colorStart", "#10B981");
            b3.put("colorEnd", "#059669");
            b3.put("badge", "UP");
            b3.put("active", true);
            b3.put("sortOrder", 3);
            defaultBanners.add(b3);

            SystemConfig cfg = SystemConfig.builder()
                    .configKey(KEY_MARKETING_BANNERS)
                    .configValue(JSON.toJSONString(defaultBanners))
                    .description("大厅营销活动与轮播横幅配置列表")
                    .build();
            configRepository.save(cfg);
            log.info("初始化营销活动与大厅轮播横幅配置");
        }
    }

    public List<Map<String, Object>> getAllBanners() {
        return configRepository.findByConfigKey(KEY_MARKETING_BANNERS)
                .map(c -> {
                    try {
                        List<Map> raw = JSON.parseArray(c.getConfigValue(), Map.class);
                        List<Map<String, Object>> res = new ArrayList<>();
                        for (Map m : raw) {
                            res.add(new HashMap<String, Object>(m));
                        }
                        return res;
                    } catch (Exception e) {
                        return new ArrayList<Map<String, Object>>();
                    }
                }).orElseGet(ArrayList::new);
    }

    public List<Map<String, Object>> getActiveBanners() {
        List<Map<String, Object>> all = getAllBanners();
        List<Map<String, Object>> active = new ArrayList<>();
        for (Map<String, Object> b : all) {
            if (Boolean.TRUE.equals(b.get("active"))) {
                active.add(b);
            }
        }
        active.sort(Comparator.comparingInt(b -> (int) b.getOrDefault("sortOrder", 0)));
        return active;
    }

    @Transactional
    public void saveBanners(List<Map<String, Object>> banners) {
        SystemConfig cfg = configRepository.findByConfigKey(KEY_MARKETING_BANNERS)
                .orElseGet(() -> SystemConfig.builder().configKey(KEY_MARKETING_BANNERS).build());
        cfg.setConfigValue(JSON.toJSONString(banners));
        cfg.setDescription("大厅营销活动与轮播横幅配置列表");
        configRepository.save(cfg);
        log.info("[MarketingService] 营销活动横幅已更新，当前共有 {} 条活动", banners.size());
    }
}
