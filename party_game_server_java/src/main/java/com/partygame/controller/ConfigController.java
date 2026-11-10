package com.partygame.controller;

import com.partygame.repository.BattleRecordRepository;
import com.partygame.repository.UserRepository;
import com.partygame.service.ConfigService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class ConfigController {

    private final ConfigService configService;
    private final UserRepository userRepository;
    private final BattleRecordRepository battleRecordRepository;

    /**
     * 获取系统运行全局配置 (供 APP 客户端动态读取道具停留时长等)
     */
    @GetMapping("/api/config/system")
    public ResponseEntity<?> getSystemConfig() {
        int propDuration = configService.getPropDisplayDuration();
        Map<String, Object> cfg = new HashMap<>();
        cfg.put("propDisplayDurationSeconds", propDuration);
        cfg.put("propDisplayDurationMs", propDuration * 1000);
        cfg.put("serverTime", System.currentTimeMillis());
        cfg.put("version", "2.0.0-commercial-java");
        return ResponseEntity.ok(createSuccess(cfg));
    }

    /**
     * 开发者管理后台配置：修改道具投掷后在屏幕停留时长(秒)
     */
    @PostMapping("/api/admin/config/prop-duration")
    public ResponseEntity<?> updatePropDuration(@RequestBody Map<String, Object> body) {
        Object val = body.get("seconds");
        int seconds = 3;
        if (val instanceof Number) {
            seconds = ((Number) val).intValue();
        } else if (val != null) {
            seconds = Integer.parseInt(val.toString());
        }
        int updated = configService.setPropDisplayDuration(seconds);
        Map<String, Object> res = new HashMap<>();
        res.put("propDisplayDurationSeconds", updated);
        res.put("message", "✅ 道具展示停留时长已成功修改为 " + updated + " 秒！全服即时生效！");
        return ResponseEntity.ok(createSuccess(res));
    }

    /**
     * 开发者后台综合概览监控面板
     */
    @GetMapping("/api/admin/dashboard")
    public ResponseEntity<?> getAdminDashboard() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalUsers", userRepository.count());
        stats.put("totalBattleRecords", battleRecordRepository.count());
        stats.put("propDisplayDurationSeconds", configService.getPropDisplayDuration());
        stats.put("serviceArchitecture", "Java 17 (Spring Boot 3 + JPA + MySQL + WebSocket)");
        stats.put("database", "Aliyun RDS MySQL (party_game_db)");
        return ResponseEntity.ok(createSuccess(stats));
    }

    private Map<String, Object> createSuccess(Object data) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 0);
        map.put("data", data);
        return map;
    }
}
