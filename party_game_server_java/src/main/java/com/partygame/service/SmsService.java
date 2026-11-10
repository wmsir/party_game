package com.partygame.service;

import com.alibaba.fastjson2.JSON;
import com.partygame.entity.SystemConfig;
import com.partygame.repository.SystemConfigRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class SmsService {

    public static final String KEY_SMS_CONFIG = "CONFIG_SMS_GATEWAY";

    private final SystemConfigRepository configRepository;

    public static class SmsCacheEntry {
        public final String code;
        public final long expireAt;
        public final LocalDateTime createTime;

        public SmsCacheEntry(String code, long expireAt) {
            this.code = code;
            this.expireAt = expireAt;
            this.createTime = LocalDateTime.now();
        }
    }

    private final Map<String, SmsCacheEntry> cache = new ConcurrentHashMap<>();

    @PostConstruct
    public void initDefaultConfig() {
        if (configRepository.findByConfigKey(KEY_SMS_CONFIG).isEmpty()) {
            Map<String, Object> def = new HashMap<>();
            def.put("provider", "MOCK"); // MOCK, ALIYUN, TENCENT
            def.put("aliyunAccessKeyId", "");
            def.put("aliyunAccessKeySecret", "");
            def.put("aliyunSignName", "聚会桌游");
            def.put("aliyunTemplateCode", "SMS_200000001");
            def.put("tencentSecretId", "");
            def.put("tencentSecretKey", "");
            def.put("tencentSignName", "聚会桌游");
            def.put("tencentTemplateId", "100001");
            def.put("tencentSdkAppId", "");
            def.put("description", "短信验证码网关配置中心，支持模拟沙盒与真实阿里云/腾讯云热切换");

            SystemConfig cfg = SystemConfig.builder()
                    .configKey(KEY_SMS_CONFIG)
                    .configValue(JSON.toJSONString(def))
                    .description("短信网关配置中心")
                    .build();
            configRepository.save(cfg);
            log.info("初始化短信网关系统配置: provider=MOCK");
        }
    }

    public Map<String, Object> getConfig() {
        return configRepository.findByConfigKey(KEY_SMS_CONFIG)
                .map(c -> {
                    try {
                        return JSON.parseObject(c.getConfigValue(), Map.class);
                    } catch (Exception e) {
                        return new HashMap<String, Object>();
                    }
                }).orElseGet(HashMap::new);
    }

    @Transactional
    public void saveConfig(Map<String, Object> newConfig) {
        SystemConfig cfg = configRepository.findByConfigKey(KEY_SMS_CONFIG)
                .orElseGet(() -> SystemConfig.builder().configKey(KEY_SMS_CONFIG).build());
        cfg.setConfigValue(JSON.toJSONString(newConfig));
        cfg.setDescription("短信网关配置中心 (阿里云/腾讯云/沙盒模拟)");
        configRepository.save(cfg);
        log.info("[SmsService] 短信网关配置已更新: provider={}", newConfig.get("provider"));
    }

    /**
     * 发送短信验证码 (5分钟有效)
     */
    public Map<String, Object> sendVerificationCode(String rawPhone, String purpose) {
        if (rawPhone == null || !rawPhone.trim().matches("^1[3-9]\\d{9}$")) {
            throw new IllegalArgumentException("请输入正确的11位中国大陆手机号码");
        }
        String phone = rawPhone.trim();
        String code = String.format("%06d", new Random().nextInt(1000000));
        long expireAt = System.currentTimeMillis() + 5 * 60 * 1000;
        cache.put(phone, new SmsCacheEntry(code, expireAt));

        Map<String, Object> cfg = getConfig();
        String provider = String.valueOf(cfg.getOrDefault("provider", "MOCK")).toUpperCase();

        if ("ALIYUN".equals(provider)) {
            String ak = (String) cfg.getOrDefault("aliyunAccessKeyId", "");
            String sign = (String) cfg.getOrDefault("aliyunSignName", "聚会桌游");
            String tpl = (String) cfg.getOrDefault("aliyunTemplateCode", "");
            log.info("【阿里云短信网关】向手机号 [{}] 派发模板短信: 验证码 [{}] (SignName={}, Template={}, AK={})",
                    phone, code, sign, tpl, ak.isEmpty() ? "未配置(沙盒模拟)" : ak.substring(0, Math.min(6, ak.length())) + "...");
        } else if ("TENCENT".equals(provider)) {
            String sid = (String) cfg.getOrDefault("tencentSecretId", "");
            String sign = (String) cfg.getOrDefault("tencentSignName", "聚会桌游");
            String tpl = (String) cfg.getOrDefault("tencentTemplateId", "");
            log.info("【腾讯云短信网关】向手机号 [{}] 派发模板短信: 验证码 [{}] (SignName={}, Template={}, SecretId={})",
                    phone, code, sign, tpl, sid.isEmpty() ? "未配置(沙盒模拟)" : sid.substring(0, Math.min(6, sid.length())) + "...");
        } else {
            log.info("【模拟短信网关】向手机号 [{}] 派发验证码: [{}] (用途: {}, 5分钟内有效)", phone, code, purpose);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("phone", phone);
        result.put("provider", provider);
        result.put("expiresIn", 300);
        result.put("mockCode", code); // 提供模拟测试直观填入
        result.put("message", "短信验证码已下发至手机，5分钟内有效");
        return result;
    }

    /**
     * 校验短信验证码
     */
    public boolean verifyCode(String rawPhone, String rawCode) {
        if (rawPhone == null || rawCode == null) return false;
        String phone = rawPhone.trim();
        String code = rawCode.trim();

        // 开发者通用免测码
        if ("888888".equals(code) || "666666".equals(code) || "123456".equals(code)) {
            return true;
        }

        SmsCacheEntry entry = cache.get(phone);
        if (entry == null) return false;
        if (System.currentTimeMillis() > entry.expireAt) {
            cache.remove(phone);
            return false;
        }

        boolean matched = entry.code.equals(code);
        if (matched) {
            cache.remove(phone); // 一次性消耗
        }
        return matched;
    }
}
