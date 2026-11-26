package com.partygame.security;

import com.partygame.entity.User;
import com.partygame.repository.UserRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserAuthService {

    private static final long TOKEN_TTL_MS = 7L * 24 * 60 * 60 * 1000L;
    private static final String TOKEN_PREFIX = "PGU1.";

    private final UserRepository userRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${party.auth.token-secret:}")
    private String configuredSecret;

    private byte[] hmacKeyBytes;

    @PostConstruct
    public void init() {
        ensureSecret();
    }

    private synchronized byte[] ensureSecret() {
        if (hmacKeyBytes != null) {
            return hmacKeyBytes;
        }
        if (configuredSecret != null && configuredSecret.trim().length() >= 32) {
            hmacKeyBytes = configuredSecret.trim().getBytes(StandardCharsets.UTF_8);
        } else {
            byte[] generated = new byte[32];
            secureRandom.nextBytes(generated);
            hmacKeyBytes = generated;
        }
        return hmacKeyBytes;
    }

    public String issueSignedToken(String userId) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("用户编号不能为空");
        }
        long expiresAt = System.currentTimeMillis() + TOKEN_TTL_MS;
        byte[] nonce = new byte[12];
        secureRandom.nextBytes(nonce);
        String payload = Base64.getUrlEncoder().withoutPadding().encodeToString(
                (userId.trim() + "|" + expiresAt + "|" + Base64.getUrlEncoder().withoutPadding().encodeToString(nonce))
                        .getBytes(StandardCharsets.UTF_8)
        );
        String sig = signHmac(payload);
        return TOKEN_PREFIX + payload + "." + sig;
    }

    public User authenticate(String rawToken) {
        String token = normalizeToken(rawToken);
        if (token == null) {
            return null;
        }
        if (token.startsWith(TOKEN_PREFIX)) {
            User verified = verifySignedToken(token);
            if (verified != null) {
                return verified;
            }
        }
        Optional<User> dbUser = userRepository.findByToken(token);
        if (dbUser.isEmpty()) {
            return null;
        }
        User u = dbUser.get();
        if (u.getToken() == null || !MessageDigest.isEqual(
                u.getToken().getBytes(StandardCharsets.UTF_8),
                token.getBytes(StandardCharsets.UTF_8))) {
            return null;
        }
        return u;
    }

    private User verifySignedToken(String token) {
        try {
            String rest = token.substring(TOKEN_PREFIX.length());
            int dot = rest.indexOf('.');
            if (dot <= 0 || dot >= rest.length() - 1) {
                return null;
            }
            String payloadB64 = rest.substring(0, dot);
            String sigB64 = rest.substring(dot + 1);
            String expectedSig = signHmac(payloadB64);
            if (!MessageDigest.isEqual(
                    expectedSig.getBytes(StandardCharsets.UTF_8),
                    sigB64.getBytes(StandardCharsets.UTF_8))) {
                return null;
            }
            String payload = new String(Base64.getUrlDecoder().decode(payloadB64), StandardCharsets.UTF_8);
            String[] parts = payload.split("\\|");
            if (parts.length < 2) {
                return null;
            }
            String userId = parts[0];
            long expiresAt = Long.parseLong(parts[1]);
            if (System.currentTimeMillis() > expiresAt) {
                return null;
            }
            Optional<User> uOpt = userRepository.findById(userId);
            if (uOpt.isEmpty()) {
                return null;
            }
            User u = uOpt.get();
            if (u.getToken() == null || !MessageDigest.isEqual(
                    u.getToken().getBytes(StandardCharsets.UTF_8),
                    token.getBytes(StandardCharsets.UTF_8))) {
                return null;
            }
            return u;
        } catch (Exception e) {
            return null;
        }
    }

    public User requireUser(String authHeader, String userTokenHeader, String expectedUserId) {
        return requireUser(authHeader, userTokenHeader, null, expectedUserId);
    }

    public User requireUser(String authHeader, String userTokenHeader, String fallbackToken, String expectedUserId) {
        String token = extractToken(authHeader, userTokenHeader, fallbackToken);
        User authed = authenticate(token);
        if (authed == null) {
            throw new SecurityException("未登录或登录凭证已失效，请重新登录");
        }
        if (expectedUserId != null && !expectedUserId.trim().isEmpty() && !isSameUserId(authed.getId(), expectedUserId)) {
            throw new SecurityException("登录凭证与目标账号不匹配，禁止越权操作");
        }
        return authed;
    }

    public boolean isSameUserId(String a, String b) {
        if (a == null || b == null) return false;
        String ca = a.trim().replace("-", "");
        String cb = b.trim().replace("-", "");
        return !ca.isEmpty() && ca.equalsIgnoreCase(cb);
    }

    public String extractToken(String authHeader, String userTokenHeader, String fallbackToken) {
        String t = normalizeToken(authHeader);
        if (t != null) return t;
        t = normalizeToken(userTokenHeader);
        if (t != null) return t;
        return normalizeToken(fallbackToken);
    }

    private String normalizeToken(String rawToken) {
        if (rawToken == null) return null;
        String trimmed = rawToken.trim();
        if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            trimmed = trimmed.substring(7).trim();
        }
        if (trimmed.isEmpty() || "null".equalsIgnoreCase(trimmed) || "undefined".equalsIgnoreCase(trimmed)) {
            return null;
        }
        return trimmed;
    }

    private String signHmac(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(ensureSecret(), "HmacSHA256"));
            byte[] raw = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        } catch (Exception e) {
            throw new IllegalStateException("Token signing failed", e);
        }
    }
}
