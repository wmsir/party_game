package com.partygame.controller;

import com.partygame.entity.User;
import com.partygame.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AuthController {

    private final UserService userService;

    /**
     * 发送模拟手机短信验证码
     */
    @PostMapping({"/api/auth/send-sms-code", "/party-game/api/auth/send-sms-code"})
    public ResponseEntity<?> sendSmsCode(@RequestBody Map<String, String> body) {
        String phone = body.get("phone");
        if (phone == null || phone.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("手机号不能为空"));
        }
        try {
            Map<String, Object> data = userService.sendSmsCode(phone);
            Map<String, Object> resp = createSuccess(data);
            resp.put("message", "模拟短信验证码已发送，5分钟内有效");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 发送免费试玩手机短信验证码 (5分钟内有效，支持阿里云/腾讯云与沙盒)
     */
    @PostMapping({"/api/auth/trial-sms/send", "/party-game/api/auth/trial-sms/send"})
    public ResponseEntity<?> sendTrialSms(@RequestBody Map<String, String> body) {
        String phone = body.get("phone");
        if (phone == null || phone.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("手机号不能为空"));
        }
        try {
            Map<String, Object> data = userService.sendTrialSmsCode(phone);
            Map<String, Object> resp = createSuccess(data);
            resp.put("message", "免费试玩短信验证码已发送，5分钟内有效");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 免费试玩手机验证码核验并进入游戏
     */
    @PostMapping({"/api/auth/trial-sms/verify", "/party-game/api/auth/trial-sms/verify"})
    public ResponseEntity<?> verifyTrialSms(@RequestBody Map<String, String> body) {
        String phone = body.get("phone");
        String code = body.get("code");
        String nickname = body.get("nickname");
        if (phone == null || phone.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("手机号不能为空"));
        }
        if (code == null || code.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("请输入短信验证码"));
        }
        try {
            User user = userService.verifyTrialSmsAndLogin(phone, code, nickname);
            Map<String, Object> resp = createSuccess(user);
            resp.put("message", "🎉 验证成功！已开通试玩权限并赠送初始金币钻石！");
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 真实手机号验证码登录 (真实查验并存入 MySQL 数据库)
     */
    @PostMapping({"/api/auth/phone-login", "/party-game/api/auth/phone-login"})
    public ResponseEntity<?> phoneLogin(@RequestBody Map<String, String> body) {
        String phone = body.get("phone");
        String code = body.get("code");
        if (phone == null || phone.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("手机号不能为空"));
        }
        try {
            User user;
            if (code != null && !code.trim().isEmpty()) {
                user = userService.phoneCodeLogin(phone, code);
            } else {
                user = userService.phoneLogin(phone);
            }
            return ResponseEntity.ok(createSuccess(user));
        } catch (Exception e) {
            log.error("手机验证码登录异常: {}", e.getMessage());
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 极速游客试玩模式 (自动入库创建游客档案)
     */
    @PostMapping({"/api/auth/guest", "/party-game/api/auth/guest"})
    public ResponseEntity<?> guestLogin() {
        try {
            User guest = userService.guestLogin();
            return ResponseEntity.ok(createSuccess(guest));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 兼容原生手机号与账号登录
     */
    @PostMapping({"/api/auth/login", "/party-game/api/auth/login"})
    public ResponseEntity<?> generalLogin(@RequestBody Map<String, Object> body) {
        String phone = (String) body.get("phone");
        String code = (String) body.get("code");
        String username = (String) body.get("username");
        String password = (String) body.get("password");

        // 优先按手机验证码登录逻辑处理
        if (phone != null && phone.trim().length() == 11) {
            Map<String, String> map = new HashMap<>();
            map.put("phone", phone.trim());
            if (code != null) map.put("code", code.trim());
            return phoneLogin(map);
        }
        if (username != null && username.trim().matches("^1\\d{10}$")) {
            Map<String, String> map = new HashMap<>();
            map.put("phone", username.trim());
            if (code != null) map.put("code", code.trim());
            return phoneLogin(map);
        }

        try {
            User user = userService.passwordLogin(username, password != null ? password : "123");
            return ResponseEntity.ok(createSuccess(user));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 用户账号注册
     */
    @PostMapping({"/api/auth/register", "/party-game/api/auth/register"})
    public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
        try {
            User user = userService.register(
                    body.get("username"),
                    body.get("nickname"),
                    body.get("password"),
                    body.get("phone")
            );
            return ResponseEntity.ok(createSuccess(user));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 同步最新玩家档案
     */
    @PostMapping({"/api/auth/sync-user", "/party-game/api/auth/sync-user"})
    public ResponseEntity<?> syncUser(@RequestBody User user) {
        if (user == null || user.getId() == null) {
            return ResponseEntity.badRequest().body(createError("无效用户数据"));
        }
        User saved = userService.saveUser(user);
        return ResponseEntity.ok(createSuccess(saved));
    }

    /**
     * 账号与安全中心：更新账号、密码、手机号、昵称、头像
     */
    @PostMapping("/api/auth/update-account")
    public ResponseEntity<?> updateAccount(@RequestBody Map<String, String> body) {
        try {
            User user = userService.updateAccountSecurity(
                    body.get("userId"),
                    body.get("username"),
                    body.get("nickname"),
                    body.get("password"),
                    body.get("phone"),
                    body.get("avatar")
            );
            return ResponseEntity.ok(createSuccess(user));
        } catch (Exception e) {
            log.error("更新账号信息异常: {}", e.getMessage());
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 检索真实玩家（按手机号、昵称、游戏号模糊搜索）
     */
    @GetMapping("/api/users/search")
    public ResponseEntity<?> searchUsers(@RequestParam(required = false, defaultValue = "") String keyword) {
        List<User> list = userService.searchUsers(keyword);
        return ResponseEntity.ok(createSuccess(list));
    }

    /**
     * 获取指定用户的完整公开资料卡与常用信息
     */
    @GetMapping({"/api/users/profile", "/api/user/profile", "/party-game/api/user/profile"})
    public ResponseEntity<?> getUserProfile(@RequestParam String userId, @RequestParam(required = false) String currentUserId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("用户编号不能为空"));
        }
        java.util.Optional<User> uOpt = userService.getUserById(userId.trim());
        if (uOpt.isEmpty()) {
            return ResponseEntity.badRequest().body(createError("未找到该用户"));
        }
        User u = uOpt.get();
        Map<String, Object> data = new HashMap<>();
        String cleanId = u.getId().replace("-", "");
        data.put("id", cleanId);
        data.put("rawId", u.getId());
        data.put("username", u.getUsername());
        data.put("nickname", u.getNickname());
        data.put("avatar", u.getAvatar());
        data.put("avatarFrame", u.getAvatarFrame() != null ? u.getAvatarFrame() : "FRAME_DEFAULT");
        data.put("entranceBanner", u.getEntranceBanner() != null ? u.getEntranceBanner() : "BANNER_DEFAULT");
        data.put("vipLevel", u.getVipLevel() != null ? u.getVipLevel() : 0);
        data.put("coins", u.getCoins() != null ? u.getCoins() : 0);
        data.put("diamonds", u.getDiamonds() != null ? u.getDiamonds() : 0);
        data.put("rankScore", u.getRankScore() != null ? u.getRankScore() : 0);
        data.put("rankTier", u.getRankTier() != null ? u.getRankTier() : "暂无段位");
        data.put("levelTitle", u.getLevelTitle() != null ? u.getLevelTitle() : "聚会好友");
        data.put("winCount", u.getWinCount() != null ? u.getWinCount() : 0);
        data.put("totalGames", u.getTotalGames() != null ? u.getTotalGames() : 0);
        data.put("chatTextColor", u.getChatTextColor() != null ? u.getChatTextColor() : "COLOR_DEFAULT");

        if (currentUserId != null && !currentUserId.trim().isEmpty()) {
            boolean isFriend = userService.isFriend(currentUserId.trim(), u.getId());
            data.put("isFriend", isFriend);
            String remark = userService.getFriendRemark(currentUserId.trim(), u.getId());
            data.put("remark", remark != null ? remark : "");
        } else {
            data.put("isFriend", false);
            data.put("remark", "");
        }

        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 推荐真实玩家
     */
    public static class QrSession {
        public String ticket;
        public String status; // "WAITING", "SCANNED", "CONFIRMED", "EXPIRED"
        public long createTime;
        public User user;
        public String targetRoomId;

        public QrSession(String ticket, String targetRoomId) {
            this.ticket = ticket;
            this.status = "WAITING";
            this.createTime = System.currentTimeMillis();
            this.targetRoomId = targetRoomId;
        }
    }

    private static final Map<String, QrSession> QR_STORE = new ConcurrentHashMap<>();

    private void cleanExpiredQrSessions() {
        long now = System.currentTimeMillis();
        QR_STORE.entrySet().removeIf(entry -> now - entry.getValue().createTime > 5 * 60 * 1000);
    }

    /**
     * H5端生成扫码登录 Ticket 与对应二维码链接
     */
    @GetMapping({"/api/auth/qr/create", "/party-game/api/auth/qr/create"})
    public ResponseEntity<?> createQrSession(@RequestParam(required = false, defaultValue = "") String roomId) {
        cleanExpiredQrSessions();
        String ticket = "QR-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        QrSession session = new QrSession(ticket, roomId);
        QR_STORE.put(ticket, session);

        Map<String, Object> res = new HashMap<>();
        res.put("ticket", ticket);
        res.put("qrUrl", "http://39.97.158.22/party-game/qr-auth?ticket=" + ticket + "&roomId=" + roomId);
        res.put("expireSeconds", 300);
        return ResponseEntity.ok(createSuccess(res));
    }

    /**
     * H5端轮询检测扫码登录状态
     */
    @GetMapping({"/api/auth/qr/check", "/party-game/api/auth/qr/check"})
    public ResponseEntity<?> checkQrSession(@RequestParam String ticket) {
        cleanExpiredQrSessions();
        QrSession session = QR_STORE.get(ticket);
        if (session == null) {
            return ResponseEntity.ok(Map.of("code", 0, "data", Map.of("status", "EXPIRED")));
        }

        Map<String, Object> data = new HashMap<>();
        data.put("status", session.status);
        if ("CONFIRMED".equals(session.status) && session.user != null) {
            data.put("user", session.user);
            data.put("userId", session.user.getId());
            data.put("nickname", session.user.getNickname());
            data.put("avatar", session.user.getAvatar());
            data.put("token", session.user.getToken());
            QR_STORE.remove(ticket); // 一次性消耗
        }
        return ResponseEntity.ok(createSuccess(data));
    }

    /**
     * 手机 APP 或手机扫码页提交确认授权登录
     */
    @PostMapping({"/api/auth/qr/confirm", "/party-game/api/auth/qr/confirm"})
    public ResponseEntity<?> confirmQrSession(@RequestBody Map<String, Object> body) {
        String ticket = (String) body.get("ticket");
        String userId = (String) body.get("userId");
        String username = (String) body.get("username");
        String password = (String) body.get("password");

        if (ticket == null || ticket.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("二维码凭证不能为空"));
        }

        QrSession session = QR_STORE.get(ticket);
        if (session == null) {
            return ResponseEntity.badRequest().body(createError("二维码已失效或过期，请在网页端刷新"));
        }

        User user = null;
        if (userId != null && !userId.trim().isEmpty()) {
            user = userService.getUserById(userId.trim()).orElse(null);
        } else if (username != null && !username.trim().isEmpty()) {
            try {
                user = userService.passwordLogin(username.trim(), password != null ? password : "123");
            } catch (Exception e) {
                return ResponseEntity.badRequest().body(createError(e.getMessage()));
            }
        }

        if (user == null) {
            return ResponseEntity.badRequest().body(createError("未找到有效用户档案，授权失败"));
        }

        session.status = "CONFIRMED";
        session.user = user;
        return ResponseEntity.ok(createSuccess(Map.of("message", "授权登录成功，电脑网页端已自动登入！", "nickname", user.getNickname())));
    }

    private Map<String, Object> createSuccess(Object data) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 0);
        map.put("data", data);
        return map;
    }

    private Map<String, Object> createError(String msg) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 400);
        map.put("message", msg);
        return map;
    }
}
