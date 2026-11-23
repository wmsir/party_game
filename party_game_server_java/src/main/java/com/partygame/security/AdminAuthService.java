package com.partygame.security;

import com.partygame.entity.User;
import com.partygame.service.UserService;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Slf4j
@Service
public class AdminAuthService {

    private static final long SESSION_TTL_MS = 12L * 60 * 60 * 1000;

    @Getter
    public static class AdminSession {
        private final String username;
        private final String displayName;
        private final String role;
        private final long expiresAt;

        public AdminSession(String username, String displayName, String role, long expiresAt) {
            this.username = username;
            this.displayName = displayName;
            this.role = role;
            this.expiresAt = expiresAt;
        }
    }

    private final SecureRandom secureRandom = new SecureRandom();
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private final Map<String, AdminSession> sessions = new ConcurrentHashMap<>();

    @Value("${party.admin.password-hash:}")
    private String adminPasswordHash;

    @Value("${party.admin.password:}")
    private String adminPlainPassword;

    @Value("${party.admin.allowed-usernames:admin}")
    private String allowedUsernamesCsv;

    public AdminSession authenticate(String username, String password, UserService userService) {
        if (username == null || username.isBlank() || password == null || password.isBlank()) {
            return null;
        }
        String cleanUser = username.trim();
        long expiresAt = System.currentTimeMillis() + SESSION_TTL_MS;

        if ("admin".equalsIgnoreCase(cleanUser)) {
            if (adminPasswordHash != null && !adminPasswordHash.isBlank()) {
                try {
                    if (passwordEncoder.matches(password, adminPasswordHash.trim())) {
                        return new AdminSession("admin", "系统总开发者", "SYSTEM_DEVELOPER", expiresAt);
                    }
                } catch (Exception e) {
                    log.warn("[AdminAuth] BCrypt hash check error: {}", e.getMessage());
                }
            }
            if (adminPlainPassword != null && !adminPlainPassword.isBlank()) {
                byte[] inputBytes = password.getBytes(StandardCharsets.UTF_8);
                byte[] expectedBytes = adminPlainPassword.trim().getBytes(StandardCharsets.UTF_8);
                if (MessageDigest.isEqual(inputBytes, expectedBytes)) {
                    return new AdminSession("admin", "系统总开发者", "SYSTEM_DEVELOPER", expiresAt);
                }
            }
        }

        Set<String> allowed = Arrays.stream(allowedUsernamesCsv.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(String::toLowerCase)
                .collect(Collectors.toSet());

        if (allowed.contains(cleanUser.toLowerCase())) {
            try {
                User user = userService.passwordLogin(cleanUser, password);
                if (user != null) {
                    String display = (user.getNickname() != null && !user.getNickname().isBlank())
                            ? user.getNickname()
                            : user.getUsername();
                    return new AdminSession(cleanUser, display, "SYSTEM_DEVELOPER", expiresAt);
                }
            } catch (Exception e) {
                log.info("[AdminAuth] Allowlisted user authentication failed for {}: {}", cleanUser, e.getMessage());
            }
        }

        return null;
    }

    public String issueToken(AdminSession session) {
        cleanExpiredSessions();
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        String token = "ADM-" + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        sessions.put(token, session);
        return token;
    }

    public AdminSession validateToken(String rawToken) {
        String token = normalizeToken(rawToken);
        if (token == null) return null;
        AdminSession session = sessions.get(token);
        if (session == null) return null;
        if (System.currentTimeMillis() > session.getExpiresAt()) {
            sessions.remove(token);
            return null;
        }
        return session;
    }

    public void revokeToken(String rawToken) {
        String token = normalizeToken(rawToken);
        if (token != null) {
            sessions.remove(token);
        }
    }

    private String normalizeToken(String rawToken) {
        if (rawToken == null) return null;
        String trimmed = rawToken.trim();
        if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            trimmed = trimmed.substring(7).trim();
        }
        return trimmed.isEmpty() ? null : trimmed;
    }

    private void cleanExpiredSessions() {
        long now = System.currentTimeMillis();
        sessions.entrySet().removeIf(entry -> now > entry.getValue().getExpiresAt());
    }
}
