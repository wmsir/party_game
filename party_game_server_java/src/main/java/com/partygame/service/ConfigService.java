package com.partygame.service;

import com.partygame.entity.SystemConfig;
import com.partygame.repository.SystemConfigRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class ConfigService {

    private final SystemConfigRepository configRepository;

    public static final String KEY_PROP_DURATION = "PROP_DISPLAY_DURATION_SECONDS";

    @PostConstruct
    public void initDefaultConfigs() {
        if (configRepository.findByConfigKey(KEY_PROP_DURATION).isEmpty()) {
            SystemConfig cfg = SystemConfig.builder()
                    .configKey(KEY_PROP_DURATION)
                    .configValue("3")
                    .description("道具投掷命中后在屏幕停留展示时长(秒)，默认3秒，开发者管理后台可动态调整")
                    .build();
            configRepository.save(cfg);
            log.info("初始化系统默认配置: {} = 3 秒", KEY_PROP_DURATION);
        }
    }

    public int getPropDisplayDuration() {
        return configRepository.findByConfigKey(KEY_PROP_DURATION)
                .map(c -> {
                    try {
                        return Integer.parseInt(c.getConfigValue().trim());
                    } catch (Exception e) {
                        return 3;
                    }
                })
                .orElse(3);
    }

    @Transactional
    public int setPropDisplayDuration(int seconds) {
        int val = Math.max(1, Math.min(seconds, 30)); // 允许 1~30 秒
        SystemConfig cfg = configRepository.findByConfigKey(KEY_PROP_DURATION)
                .orElseGet(() -> SystemConfig.builder().configKey(KEY_PROP_DURATION).build());
        cfg.setConfigValue(String.valueOf(val));
        cfg.setDescription("道具投掷命中后在屏幕停留展示时长(秒)，开发者管理后台可动态调整");
        configRepository.save(cfg);
        log.info("开发者后台更新道具展示时长: {} 秒", val);
        return val;
    }
}
