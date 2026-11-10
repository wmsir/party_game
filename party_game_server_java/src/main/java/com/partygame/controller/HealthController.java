package com.partygame.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@CrossOrigin(origins = "*")
public class HealthController {

    private static final long START_TIME = System.currentTimeMillis();

    @GetMapping("/health")
    public ResponseEntity<?> health() {
        Map<String, Object> map = new HashMap<>();
        map.put("status", "ok");
        map.put("service", "PartyGameServer-Java");
        map.put("port", 9001);
        map.put("timestamp", Instant.now().toString());
        map.put("uptimeSeconds", (System.currentTimeMillis() - START_TIME) / 1000);
        return ResponseEntity.ok(map);
    }
}
