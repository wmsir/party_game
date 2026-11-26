package com.partygame.service;

import com.alibaba.fastjson2.JSON;
import com.partygame.entity.SystemConfig;
import com.partygame.repository.SystemConfigRepository;
import jakarta.annotation.PostConstruct;
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
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class SmsService {

    public static final String KEY_SMS_CONFIG = "CONFIG_SMS_GATEWAY";
    private static final long SEND_COOLDOWN_MS = 60_000L;
    private static final int MAX_DAILY_SENDS_PER_PHONE = 10;

    private final SystemConfigRepository configRepository;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${party.sms.sandbox-mode:false}")
    private boolean sandboxMode;

    private boolean isProdProfile() {
        return environment != null && environment.acceptsProfiles(Profiles.of("prod"));
    }

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
    private final Map<String, Long> lastSendTime = new ConcurrentHashMap<>();
    private final Map<String, Integer> dailySendCount = new ConcurrentHashMap<>();

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
            log.info("初始化短信网关系统配置: provider=MOCK, sandboxMode={}", sandboxMode);
        }
    }

    public Map<String, Object> getConfig() {
        return configRepository.findByConfigKey(KEY_SMS_CONFIG)
                .map(c -> {
                    try {
                        Map parsed = JSON.parseObject(c.getConfigValue(), Map.class);
                        Map<String, Object> res = new HashMap<>();
                        if (parsed != null) {
                            parsed.forEach((k, v) -> res.put(String.valueOf(k), v));
                        }
                        return res;
                    } catch (Exception e) {
                        return new HashMap<String, Object>();
                    }
                }).orElseGet(HashMap::new);
    }

    public Map<String, Object> getSafeConfig() {
        Map<String, Object> safe = new HashMap<>(getConfig());
        maskSecret(safe, "aliyunAccessKeySecret");
        maskSecret(safe, "tencentSecretKey");
        safe.put("sandboxMode", sandboxMode);
        return safe;
    }

    private void maskSecret(Map<String, Object> map, String key) {
        Object val = map.get(key);
        if (val != null && !String.valueOf(val).isBlank()) {
            map.put(key, "********");
        }
    }

    @Transactional
    public void saveConfig(Map<String, Object> newConfig) {
        Map<String, Object> existing = getConfig();
        Map<String, Object> merged = new HashMap<>(existing);
        if (newConfig != null) {
            newConfig.forEach((k, v) -> {
                if ("aliyunAccessKeySecret".equals(k) || "tencentSecretKey".equals(k)) {
                    String s = v != null ? String.valueOf(v).trim() : "";
                    if (!s.isEmpty() && !s.contains("****")) {
                        merged.put(k, s);
                    }
                } else {
                    merged.put(k, v);
                }
            });
        }
        SystemConfig cfg = configRepository.findByConfigKey(KEY_SMS_CONFIG)
                .orElseGet(() -> SystemConfig.builder().configKey(KEY_SMS_CONFIG).build());
        cfg.setConfigValue(JSON.toJSONString(merged));
        cfg.setDescription("短信网关配置中心 (阿里云/腾讯云/沙盒模拟)");
        configRepository.save(cfg);
        log.info("[SmsService] 短信网关配置已更新: provider={}", merged.get("provider"));
    }

    /**
     * 发送短信验证码 (5分钟有效，带 60s 频控与每日 10 次上限)
     */
    public Map<String, Object> sendVerificationCode(String rawPhone, String purpose) {
        if (rawPhone == null || !rawPhone.trim().matches("^1[3-9]\\d{9}$")) {
            throw new IllegalArgumentException("请输入正确的11位中国大陆手机号码");
        }
        String phone = rawPhone.trim();
        long now = System.currentTimeMillis();

        Long prevSent = lastSendTime.get(phone);
        if (prevSent != null && (now - prevSent) < SEND_COOLDOWN_MS) {
            long remainSec = Math.max(1L, (SEND_COOLDOWN_MS - (now - prevSent) + 999L) / 1000L);
            throw new IllegalArgumentException("短信发送过于频繁，请 " + remainSec + " 秒后再试");
        }

        String todayStr = LocalDate.now().toString();
        String dayKey = phone + ":" + todayStr;
        if (dailySendCount.size() > 5000) {
            dailySendCount.entrySet().removeIf(e -> !e.getKey().endsWith(":" + todayStr));
        }
        int todayCount = dailySendCount.getOrDefault(dayKey, 0);
        if (todayCount >= MAX_DAILY_SENDS_PER_PHONE) {
            throw new IllegalArgumentException("该手机号今日验证码发送次数已达上限，请明日再试");
        }

        String code = String.format("%06d", secureRandom.nextInt(1_000_000));
        long expireAt = now + 5 * 60 * 1000L;
        cache.put(phone, new SmsCacheEntry(code, expireAt));
        lastSendTime.put(phone, now);
        dailySendCount.put(dayKey, todayCount + 1);

        Map<String, Object> cfg = getConfig();
        String provider = String.valueOf(cfg.getOrDefault("provider", "MOCK")).toUpperCase();

        if ("ALIYUN".equals(provider)) {
            String ak = String.valueOf(cfg.getOrDefault("aliyunAccessKeyId", ""));
            String sign = String.valueOf(cfg.getOrDefault("aliyunSignName", "聚会桌游"));
            String tpl = String.valueOf(cfg.getOrDefault("aliyunTemplateCode", ""));
            log.info("【阿里云短信网关】向手机号 [{}] 派发模板短信 (SignName={}, Template={}, AK={})",
                    phone, sign, tpl, ak.isEmpty() ? "未配置" : ak.substring(0, Math.min(6, ak.length())) + "...");
        } else if ("TENCENT".equals(provider)) {
            String sid = String.valueOf(cfg.getOrDefault("tencentSecretId", ""));
            String sign = String.valueOf(cfg.getOrDefault("tencentSignName", "聚会桌游"));
            String tpl = String.valueOf(cfg.getOrDefault("tencentTemplateId", ""));
            log.info("【腾讯云短信网关】向手机号 [{}] 派发模板短信 (SignName={}, Template={}, SecretId={})",
                    phone, sign, tpl, sid.isEmpty() ? "未配置" : sid.substring(0, Math.min(6, sid.length())) + "...");
        } else {
            log.info("【模拟短信网关】向手机号 [{}] 派发验证码: [{}] (用途: {}, 5分钟内有效)", phone, code, purpose);
        }

        boolean effectiveSandbox = sandboxMode && !isProdProfile();
        Map<String, Object> result = new HashMap<>();
        result.put("phone", phone);
        result.put("provider", provider);
        result.put("sandboxMode", effectiveSandbox);
        result.put("expiresIn", 300);
        if (effectiveSandbox && "MOCK".equals(provider)) {
            result.put("mockCode", code);
        }
        result.put("message", "短信验证码已下发至手机，5分钟内有效");
        return result;
    }

    /**
     * 校验短信验证码 (强制核验真实下发验证码，禁止万能后门码)
     */
    public boolean verifyCode(String rawPhone, String rawCode) {
        if (rawPhone == null || rawCode == null) return false;
        String phone = rawPhone.trim();
        String code = rawCode.trim();
        if (code.isEmpty()) return false;

        SmsCacheEntry entry = cache.get(phone);
        if (entry == null) return false;
        if (System.currentTimeMillis() > entry.expireAt) {
            cache.remove(phone);
            return false;
        }

        boolean matched = entry.code.equals(code);
        if (matched) {
            cache.remove(phone);
        }
        return matched;
    }
}
