package com.partygame.service;

import com.partygame.entity.User;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {
    private static final org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder passwordEncoder = new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder();

    private final UserRepository userRepository;
    private final com.partygame.repository.FriendRelationRepository friendRelationRepository;
    private final SmsService smsService;

    private static final String[] AVATARS = {"🦊", "🐼", "🦁", "🐯", "🐰", "🦄", "🐨", "🐺"};

    /**
     * 发送短信验证码 (支持沙盒模拟与真实阿里云/腾讯云)
     */
    public Map<String, Object> sendSmsCode(String rawPhone) {
        return smsService.sendVerificationCode(rawPhone, "登录验证");
    }

    /**
     * 发送免费试玩短信验证码 (5分钟有效)
     */
    public Map<String, Object> sendTrialSmsCode(String rawPhone) {
        return smsService.sendVerificationCode(rawPhone, "免费试玩验证");
    }

    /**
     * 免费试玩手机短信验证并登录/创建试玩账号
     */
    @Transactional
    public User verifyTrialSmsAndLogin(String rawPhone, String rawCode) {
        return verifyTrialSmsAndLogin(rawPhone, rawCode, null);
    }

    @Transactional
    public User verifyTrialSmsAndLogin(String rawPhone, String rawCode, String customNickname) {
        if (rawPhone == null || !rawPhone.trim().matches("^1[3-9]\\d{9}$")) {
            throw new IllegalArgumentException("请输入正确的11位手机号码");
        }
        String phone = rawPhone.trim();
        String code = rawCode != null ? rawCode.trim() : "";
        if (code.isEmpty()) {
            throw new IllegalArgumentException("请输入短信验证码");
        }

        boolean ok = smsService.verifyCode(phone, code);
        if (!ok) {
            throw new IllegalArgumentException("验证码错误或已失效(5分钟有效)，请重新获取");
        }

        // 1. 若该手机号已有账号，更新登录时间直接登入
        List<User> userList = userRepository.findAllByPhone(phone);
        if (userList.isEmpty()) {
            userList = userRepository.findAllByUsername(phone);
        }
        if (!userList.isEmpty()) {
            User user = userList.get(0);
            user.setLastLoginAt(java.time.LocalDateTime.now());
            user.setToken("token_trial_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8));
            if (customNickname != null && !customNickname.trim().isEmpty() && (user.getNickname() == null || user.getNickname().startsWith("试玩玩家_"))) {
                user.setNickname(customNickname.trim());
            }
            log.info("手机试玩检测到已有账号直接登入: id={}, phone={}", user.getId(), phone);
            return userRepository.save(user);
        }

        // 2. 新试玩用户：创建试玩档案，赠送2000金币与50钻石福利
        String suffix = phone.substring(7);
        String userId = "9" + suffix + String.format("%03d", (int)((Math.random() * 900) + 100));
        String randomAvatar = AVATARS[(int)(Math.random() * AVATARS.length)];
        String finalNickname = (customNickname != null && !customNickname.trim().isEmpty()) ? customNickname.trim() : ("试玩玩家_" + suffix);

        User trialUser = User.builder()
                .id(userId)
                .username("trial_" + phone)
                .phone(phone)
                .nickname(finalNickname)
                .avatar(randomAvatar)
                .levelTitle("初入江湖")
                .coins(2000L)
                .diamonds(50L)
                .vipLevel(0)
                .vipExp(0)
                .rankScore(1200)
                .rankTier("黄金II")
                .stamina(100)
                .winCount(0)
                .totalGames(0)
                .isGuest(true)
                .avatarFrame("FRAME_DEFAULT")
                .entranceBanner("BANNER_DEFAULT")
                .diceCupSkin("CLASSIC_GOLD")
                .inventory("[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]")
                .token("token_trial_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8))
                .lastLoginAt(java.time.LocalDateTime.now())
                .build();

        User saved = userRepository.save(trialUser);
        log.info("手机试玩验证成功，已自动开通试玩账号: id={}, phone={}", saved.getId(), phone);
        return saved;
    }

    /**
     * 手机号 + 验证码 商业化真实登录
     */
    @Transactional
    public User phoneCodeLogin(String rawPhone, String rawCode) {
        if (rawPhone == null || !rawPhone.trim().matches("^1[3-9]\\d{9}$")) {
            throw new IllegalArgumentException("请输入正确的11位手机号码");
        }
        String phone = rawPhone.trim();
        String code = rawCode != null ? rawCode.trim() : "";
        if (code.isEmpty()) {
            throw new IllegalArgumentException("请输入验证码");
        }

        boolean ok = smsService.verifyCode(phone, code);
        if (!ok) {
            throw new IllegalArgumentException("验证码错误或已失效，请重新获取");
        }

        return phoneLogin(phone);
    }

    /**
     * 手机免密真实登录：真实入库查验与自动注册持久化
     */
    @Transactional
    public User phoneLogin(String rawPhone) {
        if (rawPhone == null || rawPhone.trim().length() != 11) {
            throw new IllegalArgumentException("请输入有效的11位手机号码");
        }
        String phone = rawPhone.trim();

        // 1. 查询数据库中是否已存在该手机号真实账号
        List<User> userList = userRepository.findAllByPhone(phone);
        if (userList.isEmpty()) {
            userList = userRepository.findAllByUsername(phone);
        }
        if (!userList.isEmpty()) {
            User user = userList.stream().max(Comparator.comparingInt((User u) -> u.getVipLevel() != null ? u.getVipLevel() : 0)
                    .thenComparingLong(u -> u.getCoins() != null ? u.getCoins() : 0L)
                    .thenComparingLong(u -> u.getDiamonds() != null ? u.getDiamonds() : 0L)
            ).orElse(userList.get(0));

            user.setLastLoginAt(java.time.LocalDateTime.now());
            user.setToken("token_phone_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8));
            userRepository.save(user);
            log.info("老用户手机免密登录成功: id={}, phone={}, nickname={}, vipLevel={}", user.getId(), phone, user.getNickname(), user.getVipLevel());
            return user;
        }

        // 2. 新手机号：真实写入 MySQL 数据库，分配真实商业化初始资产
        String suffix = phone.substring(7);
        String userId = "8" + suffix + String.format("%03d", (int)((Math.random() * 900) + 100));
        String randomAvatar = AVATARS[(int)(Math.random() * AVATARS.length)];

        User newUser = User.builder()
                .id(userId)
                .username(phone)
                .phone(phone)
                .nickname("聚会好友_" + suffix)
                .avatar(randomAvatar)
                .levelTitle("聚会萌新")
                .coins(0L) // 商业化真实数据：新账号初始资产为 0
                .diamonds(0L) // 商业化真实数据：新账号初始钻石为 0
                .vipLevel(0)
                .vipExp(0)
                .rankScore(0)
                .rankTier("暂无段位")
                .stamina(100)
                .winCount(0)
                .totalGames(0)
                .isGuest(false)
                .avatarFrame("FRAME_DEFAULT")
                .entranceBanner("BANNER_DEFAULT")
                .diceCupSkin("CLASSIC_GOLD")
                .inventory("[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]")
                .token("token_phone_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8))
                .lastLoginAt(java.time.LocalDateTime.now())
                .build();

        User saved = userRepository.save(newUser);
        log.info("新用户手机免密入库成功: id={}, phone={}, nickname={}", saved.getId(), phone, saved.getNickname());
        return saved;
    }

    /**
     * 游客体验模式快速入库
     */
    @Transactional
    public User guestLogin() {
        int rand = (int)(1000 + Math.random() * 9000);
        String userId = "9" + rand + String.format("%04d", System.currentTimeMillis() % 10000);
        String randomAvatar = AVATARS[rand % AVATARS.length];

        User guest = User.builder()
                .id(userId)
                .username("guest_" + rand)
                .phone("139" + rand + "0000")
                .nickname("试玩客官_" + rand)
                .avatar(randomAvatar)
                .levelTitle("初入江湖")
                .coins(2000L)
                .diamonds(50L)
                .vipLevel(0)
                .vipExp(0)
                .rankScore(1200)
                .rankTier("黄金II")
                .stamina(100)
                .winCount(0)
                .totalGames(0)
                .isGuest(true)
                .avatarFrame("FRAME_DEFAULT")
                .entranceBanner("BANNER_DEFAULT")
                .diceCupSkin("CLASSIC_GOLD")
                .inventory("[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]")
                .token("token_guest_" + System.currentTimeMillis())
                .lastLoginAt(java.time.LocalDateTime.now())
                .build();

        return userRepository.save(guest);
    }

    /**
     * 账号密码登录（全面兼容 FWPT 全平台统一通行证与本地专属账号）
     */
    @Transactional
    public User passwordLogin(String username, String password) {
        if (username == null || username.trim().isEmpty()) {
            throw new IllegalArgumentException("账号不能为空");
        }
        String clean = username.trim();
        List<User> userList = userRepository.findAllByUsername(clean);
        if (userList.isEmpty()) {
            userList = userRepository.findAllByPhone(clean);
        }

        User user = null;
        if (!userList.isEmpty()) {
            user = userList.stream().max(Comparator.comparingInt((User u) -> u.getVipLevel() != null ? u.getVipLevel() : 0)
                    .thenComparingLong(u -> u.getCoins() != null ? u.getCoins() : 0L)
                    .thenComparingLong(u -> u.getDiamonds() != null ? u.getDiamonds() : 0L)
            ).orElse(userList.get(0));
        }

        // 1. 优先联动校验 FWPT 统一通行证 (OneID)，确保密码变更、冻结状态与全站审计轨迹实时同步
        Map<String, Object> fwptAuth = verifyFwptAuth(clean, password);
        if (fwptAuth != null) {
            if (Boolean.TRUE.equals(fwptAuth.get("frozen"))) {
                throw new IllegalArgumentException("该通行证账号已被管理员冻结，请联系平台客服");
            }
            String fwptRealName = (String) fwptAuth.get("realName");
            String fwptPhone = (String) fwptAuth.get("phone");
            if (user == null) {
                // 首次通过 FWPT 统一通行证进入桌游吧，自动初始化玩家档案与新人福利礼包
                String suffix = clean.length() >= 4 ? clean.substring(clean.length() - 4) : clean;
                String userId = "9" + String.format("%07d", Math.abs((clean + "_" + System.currentTimeMillis()).hashCode()) % 10000000);
                String randomAvatar = AVATARS[(int)(Math.random() * AVATARS.length)];
                String nickname = (fwptRealName != null && !fwptRealName.trim().isEmpty()) ? fwptRealName.trim() : ("FWPT玩家_" + suffix);

                user = User.builder()
                        .id(userId)
                        .username(clean)
                        .phone(fwptPhone != null && !fwptPhone.isEmpty() ? fwptPhone : (clean.matches("^1\\d{10}$") ? clean : ""))
                        .password(passwordEncoder.encode(password))
                        .nickname(nickname)
                        .avatar(randomAvatar)
                        .levelTitle("聚会新秀")
                        .coins(10000L) // 赠送新人 10,000 金币
                        .diamonds(100L) // 赠送新人 100 钻石
                        .vipLevel(1)
                        .vipExp(100)
                        .rankScore(1000)
                        .rankTier("青铜萌新")
                        .stamina(100)
                        .winCount(0)
                        .totalGames(0)
                        .isGuest(false)
                        .avatarFrame("FRAME_DEFAULT")
                        .entranceBanner("BANNER_DEFAULT")
                        .diceCupSkin("CLASSIC_GOLD")
                        .inventory("[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]")
                        .token("token_fwpt_" + System.currentTimeMillis())
                        .lastLoginAt(java.time.LocalDateTime.now())
                        .build();
                log.info("FWPT 统一用户首次登录桌游吧，自动初始化档案: username={}, nickname={}", clean, nickname);
            } else {
                // 已有老玩家，同步最新 FWPT 口令与活跃态
                user.setPassword(password);
                if (fwptRealName != null && !fwptRealName.trim().isEmpty() && (user.getNickname() == null || user.getNickname().startsWith("聚会好友_"))) {
                    user.setNickname(fwptRealName.trim());
                }
                user.setLastLoginAt(java.time.LocalDateTime.now());
                user.setToken("token_fwpt_" + System.currentTimeMillis());
                log.info("FWPT 统一用户在桌游吧核验成功并同步最新口令: username={}", clean);
            }
            return userRepository.save(user);
        }

        // 2. 本地密码比对（支持 BCrypt 哈希比对与历史明文自动升级迁移）
        if (user != null && user.getPassword() != null) {
            String storedPwd = user.getPassword();
            boolean isBcrypt = storedPwd.startsWith("$2a$") || storedPwd.startsWith("$2b$") || storedPwd.startsWith("$2y$");
            boolean matched = false;
            if (isBcrypt) {
                matched = passwordEncoder.matches(password, storedPwd);
            } else if (storedPwd.equals(password)) {
                matched = true;
                // 历史明文密码自动平滑无感升级为 BCrypt 哈希
                user.setPassword(passwordEncoder.encode(password));
                log.info("安全加固：已自动将用户 {} 的历史明文密码平滑升级为 BCrypt 哈希", user.getUsername());
            }
            if (matched) {
                user.setLastLoginAt(java.time.LocalDateTime.now());
                user.setToken("token_user_" + System.currentTimeMillis());
                return userRepository.save(user);
            }
        }

        // 3. 校验均未通过
        if (user == null) {
            throw new IllegalArgumentException("用户不存在，请在 FWPT 统一平台注册或使用手机免密登录");
        } else {
            throw new IllegalArgumentException("账号或密码错误");
        }
    }

    /**
     * 联动 FWPT 统一通行证中心 (OneID) 校验账号与口令
     */
    private Map<String, Object> verifyFwptAuth(String username, String password) {
        if (username == null || password == null || username.trim().isEmpty() || password.trim().isEmpty()) {
            return null;
        }
        String[] candidateUrls = new String[]{
                "http://101.35.100.169:8088/api/v1/auth/login",
                "https://fwpt.cn/api/v1/auth/login"
        };
        for (String targetUrl : candidateUrls) {
            try {
                java.net.URL url = new java.net.URL(targetUrl);
                java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
                if (conn instanceof javax.net.ssl.HttpsURLConnection) {
                    ((javax.net.ssl.HttpsURLConnection) conn).setHostnameVerifier((hostname, session) -> true);
                }
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
                conn.setRequestProperty("User-Agent", "PartyGameServer/1.0 (FWPT-OneID-Bridge)");
                conn.setConnectTimeout(2500);
                conn.setReadTimeout(3000);
                conn.setDoOutput(true);

                String payload = "{\"username\":\"" + escapeJson(username) + "\",\"password\":\"" + escapeJson(password) + "\",\"account\":\"" + escapeJson(username) + "\"}";
                try (java.io.OutputStream os = conn.getOutputStream()) {
                    os.write(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                }

                int code = conn.getResponseCode();
                if (code == 200) {
                    try (java.io.InputStream is = conn.getInputStream();
                         java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(is, java.nio.charset.StandardCharsets.UTF_8))) {
                        StringBuilder sb = new StringBuilder();
                        String line;
                        while ((line = reader.readLine()) != null) {
                            sb.append(line);
                        }
                        String respBody = sb.toString();
                        if (respBody.contains("已被管理员冻结")) {
                            Map<String, Object> frozenMap = new HashMap<>();
                            frozenMap.put("frozen", true);
                            return frozenMap;
                        }
                        if (respBody.contains("\"00000\"") && respBody.contains("\"token\"")) {
                            Map<String, Object> result = new HashMap<>();
                            result.put("username", username);
                            String realName = extractJsonField(respBody, "realName");
                            String phone = extractJsonField(respBody, "phone");
                            if (realName != null) result.put("realName", realName);
                            if (phone != null) result.put("phone", phone);
                            log.info("FWPT 统一通行证核验成功: account={}, realName={}", username, realName);
                            return result;
                        }
                        // 已连通主节点但返回非 00000（如密码错误或不存在），无需再重试备用域名
                        break;
                    }
                }
            } catch (Exception e) {
                log.warn("FWPT 统一通行证校验异常 ({}): {}", targetUrl, e.getMessage());
            }
        }
        return null;
    }

    private void syncRegisterToFwpt(String username, String nickname, String password, String phone) {
        try {
            java.net.URL url = new java.net.URL("http://101.35.100.169:8088/api/v1/auth/register");
            java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            conn.setRequestProperty("User-Agent", "PartyGameServer/1.0 (FWPT-OneID-Bridge)");
            conn.setConnectTimeout(2500);
            conn.setReadTimeout(3000);
            conn.setDoOutput(true);
            String payload = "{\"registerType\":\"GAME\",\"username\":\"" + escapeJson(username)
                    + "\",\"realName\":\"" + escapeJson(nickname)
                    + "\",\"password\":\"" + escapeJson(password)
                    + "\",\"phone\":\"" + escapeJson(phone != null ? phone : "") + "\"}";
            try (java.io.OutputStream os = conn.getOutputStream()) {
                os.write(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            }
            int code = conn.getResponseCode();
            log.info("桌游吧新注册用户同步至 FWPT 统一通行证完成: username={}, httpCode={}", username, code);
        } catch (Exception e) {
            log.warn("桌游吧新注册用户同步 FWPT 异常: {}", e.getMessage());
        }
    }

    private static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static String extractJsonField(String json, String field) {
        try {
            String pattern = "\"" + field + "\":\"";
            int idx = json.indexOf(pattern);
            if (idx != -1) {
                int start = idx + pattern.length();
                int end = json.indexOf("\"", start);
                if (end != -1) {
                    return json.substring(start, end);
                }
            }
        } catch (Exception ignored) {}
        return null;
    }

    /**
     * 新账号注册（同时自动同步至 FWPT 统一通行证中心）
     */
    @Transactional
    public User register(String username, String nickname, String password, String phone) {
        String cleanUser = username.trim();
        if (userRepository.findByUsername(cleanUser).isPresent()) {
            throw new IllegalArgumentException("该用户名已被注册");
        }
        String finalNick = nickname != null && !nickname.trim().isEmpty() ? nickname.trim() : "玩家_" + cleanUser;
        String userId = "6" + String.format("%07d", System.currentTimeMillis() % 10000000);
        User newUser = User.builder()
                .id(userId)
                .username(cleanUser)
                .nickname(finalNick)
                .password(passwordEncoder.encode(password))
                .phone(phone != null ? phone.trim() : "")
                .avatar(AVATARS[(int)(Math.random() * AVATARS.length)])
                .levelTitle("聚会萌新")
                .coins(10000L)
                .diamonds(100L)
                .vipLevel(1)
                .vipExp(100)
                .rankScore(1000)
                .rankTier("青铜萌新")
                .stamina(100)
                .winCount(0)
                .totalGames(0)
                .isGuest(false)
                .avatarFrame("FRAME_DEFAULT")
                .entranceBanner("BANNER_DEFAULT")
                .diceCupSkin("CLASSIC_GOLD")
                .inventory("[\"CLASSIC_GOLD\",\"FRAME_DEFAULT\",\"BANNER_DEFAULT\"]")
                .token("token_reg_" + System.currentTimeMillis())
                .lastLoginAt(java.time.LocalDateTime.now())
                .build();
        User saved = userRepository.save(newUser);
        syncRegisterToFwpt(cleanUser, finalNick, password, phone);
        return saved;
    }

    public Optional<User> getUserById(String id) {
        if (id == null) return Optional.empty();
        Optional<User> u = userRepository.findById(id);
        if (u.isPresent()) return u;
        return userRepository.findById(id.replace("-", ""));
    }

    @Transactional
    public User saveUser(User user) {
        return userRepository.save(user);
    }

    public List<User> searchUsers(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) return Collections.emptyList();
        return userRepository.searchUsers(keyword.trim());
    }

    public List<User> getRecommendedUsers() {
        return userRepository.findTop20ByOrderByUpdatedAtDesc();
    }

    /**
     * 账号与安全中心：修改账号名、昵称、密码、手机号等
     */
    @Transactional
    public User updateAccountSecurity(String userId, String username, String nickname, String password, String phone, String avatar) {
        if (userId == null || userId.trim().isEmpty()) {
            throw new IllegalArgumentException("用户编号不能为空");
        }
        User user = userRepository.findById(userId.trim())
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        if (username != null && !username.trim().isEmpty()) {
            String cleanUser = username.trim();
            Optional<User> existingUser = userRepository.findByUsername(cleanUser);
            if (existingUser.isPresent() && !existingUser.get().getId().equalsIgnoreCase(user.getId())) {
                throw new IllegalArgumentException("该用户名已被其他玩家使用");
            }
            user.setUsername(cleanUser);
        }

        if (phone != null && !phone.trim().isEmpty()) {
            String cleanPhone = phone.trim();
            if (!cleanPhone.matches("^1[3-9]\\d{9}$")) {
                throw new IllegalArgumentException("请输入正确的11位中国大陆手机号码");
            }
            Optional<User> existingPhone = userRepository.findByPhone(cleanPhone);
            if (existingPhone.isPresent() && !existingPhone.get().getId().equalsIgnoreCase(user.getId())) {
                throw new IllegalArgumentException("该手机号已被其他账号绑定");
            }
            user.setPhone(cleanPhone);
        }

        if (nickname != null && !nickname.trim().isEmpty()) {
            user.setNickname(nickname.trim());
        }

        if (password != null && !password.trim().isEmpty()) {
            if (password.length() < 3) {
                throw new IllegalArgumentException("密码长度不能少于3位");
            }
            user.setPassword(password.trim());
        }

        if (avatar != null && !avatar.trim().isEmpty()) {
            user.setAvatar(avatar.trim());
        }

        log.info("用户 [{}] 成功更新账号安全资料: username={}, phone={}, nickname={}", user.getId(), user.getUsername(), user.getPhone(), user.getNickname());
        return userRepository.save(user);
    }

    public boolean isFriend(String userId, String friendId) {
        if (userId == null || friendId == null) return false;
        return friendRelationRepository.existsByUserIdAndFriendId(userId.trim(), friendId.trim());
    }

    public String getFriendRemark(String userId, String friendId) {
        if (userId == null || friendId == null) return "";
        return friendRelationRepository.findByUserIdAndFriendId(userId.trim(), friendId.trim())
                .map(com.partygame.entity.FriendRelation::getRemark)
                .orElse("");
    }
}
