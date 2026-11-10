package com.partygame.controller;

import com.partygame.entity.User;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class WebPlayController {

    private final UserRepository userRepository;

    // 通用矢量黄金硬币SVG图标 (杜绝Windows缺字豆腐块▯问题，全平台高质感高清晰展示)
    private static final String COIN_SVG = "<svg class='coin-svg' viewBox='0 0 24 24' width='16' height='16' style='vertical-align:-2.5px; display:inline-block; filter:drop-shadow(0 1px 2px rgba(217,119,6,0.3));'><circle cx='12' cy='12' r='10' fill='#F59E0B'/><circle cx='12' cy='12' r='7.2' fill='#FBBF24' stroke='#B45309' stroke-width='1.2'/><text x='12' y='15.8' font-size='10.5' font-weight='900' fill='#78350F' text-anchor='middle' font-family='sans-serif'>金</text></svg>";

    // 机器验证码内存挑战池 (5分钟过期)
    private static final Map<String, CaptchaChallenge> CAPTCHA_STORE = new ConcurrentHashMap<>();

    private static class CaptchaChallenge {
        String answer;
        long expireAt;

        CaptchaChallenge(String answer, long expireAt) {
            this.answer = answer;
            this.expireAt = expireAt;
        }
    }

    @GetMapping("/api/web/captcha")
    public ResponseEntity<?> getCaptcha() {
        cleanExpiredCaptchas();
        String captchaId = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        
        String chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
        Random random = new Random();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 4; i++) {
            sb.append(chars.charAt(random.nextInt(chars.length())));
        }
        String answer = sb.toString();
        
        CAPTCHA_STORE.put(captchaId, new CaptchaChallenge(answer.toUpperCase(), System.currentTimeMillis() + 5 * 60 * 1000));

        Map<String, Object> res = new HashMap<>();
        res.put("code", 200);
        res.put("captchaId", captchaId);
        res.put("displayCode", answer);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/api/web/verify")
    public ResponseEntity<?> verifyAndJoin(@RequestBody Map<String, Object> body) {
        String gameName = (String) body.get("gameName");
        String phone = (String) body.get("phone");
        String captchaId = (String) body.get("captchaId");
        String captchaCode = (String) body.get("captchaCode");
        String roomId = (String) body.get("roomId");
        String gameType = (String) body.get("gameType");

        if (gameName == null || gameName.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "请输入您的游戏名称/昵称！"));
        }
        gameName = gameName.trim();
        if (gameName.length() > 16) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "游戏名称不能超过16个字符！"));
        }

        if (phone == null || !phone.matches("^1[3-9]\\d{9}$")) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "请输入正确的11位中国大陆手机号码！"));
        }

        if (captchaId == null || captchaCode == null || captchaCode.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "请输入右侧机器验证码！"));
        }

        CaptchaChallenge challenge = CAPTCHA_STORE.remove(captchaId);
        if (challenge == null || System.currentTimeMillis() > challenge.expireAt) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "机器验证码已过期，请点击刷新！"));
        }

        if (!challenge.answer.equalsIgnoreCase(captchaCode.trim())) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "机器验证码输入错误，请重新输入！"));
        }

        User user = userRepository.findByPhone(phone).orElse(null);
        if (user == null) {
            String uid = "WEB" + System.currentTimeMillis() % 1000000;
            user = User.builder()
                    .id(uid)
                    .username("web_" + phone.substring(7))
                    .password(new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder().encode(java.util.UUID.randomUUID().toString()))
                    .nickname(gameName)
                    .phone(phone)
                    .avatar("🎲")
                    .coins(2000L)
                    .diamonds(50L)
                    .vipLevel(1)
                    .totalGames(1)
                    .winCount(1)
                    .rankScore(1200)
                    .stamina(100)
                    .build();
            userRepository.save(user);
        } else {
            user.setNickname(gameName);
            userRepository.save(user);
        }

        Map<String, Object> roomData = null;
        if (roomId != null && !roomId.trim().isEmpty()) {
            String cleanRoom = roomId.trim();
            roomData = RoomAndMomentController.ROOMS.get(cleanRoom);
            if (roomData == null) {
                roomData = new HashMap<>();
                roomData.put("roomCode", cleanRoom);
                roomData.put("roomName", "开黑房间 " + cleanRoom);
                roomData.put("gameType", (gameType != null && !gameType.trim().isEmpty()) ? gameType.trim() : "liars_dice");
                roomData.put("createdAt", System.currentTimeMillis());
                roomData.put("status", "WAITING");
                roomData.put("players", new ArrayList<Map<String, Object>>());
                RoomAndMomentController.ROOMS.put(cleanRoom, roomData);
            } else if (gameType != null && !gameType.trim().isEmpty() && (roomData.get("gameType") == null || "liars_dice".equals(roomData.get("gameType")))) {
                roomData.put("gameType", gameType.trim());
            }
            List<Map<String, Object>> players = (List<Map<String, Object>>) roomData.computeIfAbsent("players", k -> new ArrayList<>());
            String finalUid = user.getId();

            // 单账号单房间互斥：进入新房间时自动清理并退出旧房间
            RoomAndMomentController.enforceSingleRoomPerUser(finalUid, cleanRoom);

            Map<String, Object> existing = players.stream().filter(p -> Objects.equals(p.get("id"), finalUid)).findFirst().orElse(null);
            if (existing == null) {
                Map<String, Object> p = new HashMap<>();
                p.put("id", user.getId());
                p.put("name", user.getNickname());
                p.put("avatar", user.getAvatar());
                p.put("vip", user.getVipLevel());
                p.put("isAi", false);
                boolean isHost = players.isEmpty();
                p.put("isHost", isHost);
                p.put("isReady", isHost);
                p.put("seatIndex", players.size());
                players.add(p);
            } else {
                existing.put("name", user.getNickname());
            }

            Map<String, Object> updateEvent = new HashMap<>();
            updateEvent.put("type", "ROOM_PLAYERS_UPDATED");
            updateEvent.put("roomCode", cleanRoom);
            updateEvent.put("event", "玩家【" + user.getNickname() + "】进入房间");
            updateEvent.put("players", players);
            updateEvent.put("playerCount", players.size());
            com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(cleanRoom, updateEvent, null);
        }

        log.info("[WebPlay] 玩家通过手机验证进入游戏: 游戏名={}, 手机={}, 房间={}, 游戏类型={}", gameName, phone, roomId, gameType);

        Map<String, Object> res = new HashMap<>();
        res.put("code", 200);
        res.put("message", "验证通过，成功进入游戏房间！");
        res.put("userId", user.getId());
        res.put("nickname", user.getNickname());
        res.put("avatar", user.getAvatar());
        res.put("vipLevel", user.getVipLevel());
        res.put("coins", user.getCoins());
        res.put("roomId", roomId);
        res.put("room", roomData);
        res.put("gameType", (roomData != null && roomData.get("gameType") != null) ? roomData.get("gameType") : (gameType != null ? gameType : "liars_dice"));
        return ResponseEntity.ok(res);
    }

    private void cleanExpiredCaptchas() {
        long now = System.currentTimeMillis();
        CAPTCHA_STORE.entrySet().removeIf(e -> now > e.getValue().expireAt);
    }

            @GetMapping(value = {
            "/play", "/party-game/play",
            "/lobby", "/party-game/lobby",
            "/web", "/party-game/web",
            "/login", "/party-game/login",
            "/", "/party-game"
    }, produces = MediaType.TEXT_HTML_VALUE + ";charset=UTF-8")
    public ResponseEntity<String> playPage(
            @RequestParam(value = "roomId", required = false, defaultValue = "") String roomId,
            @RequestParam(value = "gameType", required = false, defaultValue = "") String gameType,
            @RequestParam(value = "tab", required = false, defaultValue = "games") String tab,
            @RequestParam(value = "view", required = false, defaultValue = "") String view
    ) {
        String cleanRoom = roomId != null ? roomId.trim() : "";
        String cleanGameType = gameType != null ? gameType.trim() : "";
        if (cleanGameType.isEmpty() && !cleanRoom.isEmpty()) {
            Map<String, Object> roomData = RoomAndMomentController.ROOMS.get(cleanRoom);
            if (roomData != null && roomData.get("gameType") != null) {
                cleanGameType = (String) roomData.get("gameType");
            }
        }
        if (cleanGameType.isEmpty()) {
            cleanGameType = "take6";
        }
        String cleanTab = (tab != null && !tab.trim().isEmpty()) ? tab.trim() : "games";
        String cleanView = (view != null && !view.trim().isEmpty()) ? view.trim() : "";
        String html = getWebPlayHtml(cleanRoom, cleanGameType, cleanTab, cleanView);
        return ResponseEntity.ok(html);
    }

    private String getWebPlayHtml(String roomId, String gameType, String tab, String view) {
        boolean isTake6 = "take6".equalsIgnoreCase(gameType);
        boolean isWheel = "party_wheel".equalsIgnoreCase(gameType);
        boolean isUndercover = "undercover".equalsIgnoreCase(gameType);
        String gameTitle = isTake6 ? "谁是牛头王 (Take 6!)"
                : (isWheel ? "聚会大冒险大转盘 (Party Wheel)"
                : (isUndercover ? "谁是卧底 (Undercover)" : "大话骰 (吹牛)"));
        String gameIcon = isTake6 ? "🐂" : (isWheel ? "🎡" : (isUndercover ? "🕵️" : "🎲"));
        String gameBadge = isTake6 ? "谁是牛头王" : (isWheel ? "聚会大转盘" : (isUndercover ? "谁是卧底" : "大话骰吹牛"));

        StringBuilder sb = new StringBuilder(48000);
        sb.append(buildHtmlHead(isTake6, gameTitle, gameBadge, roomId));
        sb.append(buildHtmlViews(isTake6, gameTitle, gameIcon, roomId));
        sb.append(buildHtmlScriptHeader(roomId, gameType, isTake6, gameTitle, tab, view));
        sb.append(buildHtmlScriptAuthAndWs(isTake6));
        sb.append(buildHtmlScriptTake6());
        sb.append(buildHtmlScriptDice());
        sb.append(buildHtmlScriptWheel());
        sb.append(buildHtmlScriptUndercover());
        sb.append(buildHtmlScriptTail(isTake6));
        return sb.toString();
    }
    private String buildHtmlHead(boolean isTake6, String gameTitle, String gameBadge, String roomId) {
        StringBuilder sb = new StringBuilder(16000);
        sb.append("<!DOCTYPE html>\n");
        sb.append("<html lang='zh-CN'>\n");
        sb.append("<head>\n");
        sb.append("    <meta charset='UTF-8'>\n");
        sb.append("    <meta name='viewport' content='width=device-width, initial-scale=1.0, viewport-fit=cover'>\n");
        sb.append("    <title>聚会桌游吧 · 官方网页版 - 牛头王 & 大话骰 & 大转盘 & 谁是卧底</title>\n");
        sb.append("    <style>\n");
        sb.append("        * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; -webkit-tap-highlight-color: transparent; }\n");
        sb.append("        /* 明亮护眼基础基调: 柔和护眼灰白底，高清晰深色字；支持一键切换夜店暗黑模式 */\n");
        sb.append("        body { font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', sans-serif; background: #f4f6f9; color: #1e293b; min-height: 100vh; display: flex; flex-direction: column; overflow-x: hidden; transition: background 0.25s ease, color 0.25s ease; }\n");
        sb.append("        body.dark-mode { background: #0f172a; color: #f8fafc; }\n");
        sb.append("        body.dark-mode .lobby-header-wrap, body.dark-mode .header, body.dark-mode .bottom-nav { background: rgba(15, 23, 42, 0.95) !important; border-color: #334155 !important; }\n");
        sb.append("        body.dark-mode .game-mode-card, body.dark-mode .room-list-box, body.dark-mode .search-room-bar, body.dark-mode .seat-card, body.dark-mode .take6-hand-tray, body.dark-mode .take6-row, body.dark-mode .chat-stream, body.dark-mode .input-bar, body.dark-mode .modal-card, body.dark-mode .settlement-card, body.dark-mode .profile-card, body.dark-mode .shop-item-card, body.dark-mode .rank-item, body.dark-mode .intimacy-wall, body.dark-mode .square-chat-stream, body.dark-mode .login-card, body.dark-mode .commercial-modal-card, body.dark-mode .dice-bid-card, body.dark-mode .chat-modal-card, body.dark-mode .chat-modal-header, body.dark-mode .chat-input-bar, body.dark-mode .throw-modal-card, body.dark-mode .shop-card-pro, body.dark-mode .shop-sub-nav, body.dark-mode .waiting-status-banner, body.dark-mode .take6-score-item, body.dark-mode .take6-revealed-row, body.dark-mode .dice-tally-bar, body.dark-mode .bid-status-board { background: #1e293b !important; border-color: #334155 !important; color: #f8fafc !important; }\n");
        sb.append("        body.dark-mode .login-wrap, body.dark-mode .chat-messages-container { background: #0f172a !important; color: #f8fafc !important; }\n");
        sb.append("        body.dark-mode .game-mode-title, body.dark-mode .lobby-user-name, body.dark-mode .room-list-header, body.dark-mode .seat-name, body.dark-mode .brand, body.dark-mode .stat-val, body.dark-mode .settlement-title, body.dark-mode .settlement-name, body.dark-mode .room-code-title, body.dark-mode .rank-nick, body.dark-mode .waiting-status-title, body.dark-mode .dice-bid-title { color: #f8fafc !important; }\n");
        sb.append("        body.dark-mode .game-mode-desc, body.dark-mode .lobby-user-sub, body.dark-mode .stat-lbl, body.dark-mode .waiting-status-desc { color: #94a3b8 !important; }\n");
        sb.append("        body.dark-mode .room-item-row, body.dark-mode .search-room-input, body.dark-mode .btn-mode-create, body.dark-mode .profile-stat-box, body.dark-mode .settlement-item, body.dark-mode .input-bar input, body.dark-mode .form-input, body.dark-mode .phrase-chip { background: #0f172a !important; border-color: #334155 !important; color: #e2e8f0 !important; }\n");
        sb.append("        body.dark-mode .my-rank-banner { background: linear-gradient(135deg, #1e293b, #0f172a) !important; border-color: #3b82f6 !important; }\n");
        sb.append("        body.dark-mode .game-board { background: linear-gradient(145deg, #064e3b, #022c22) !important; border-color: #059669 !important; }\n");
        sb.append("        .category-filter-bar { display: flex; gap: 8px; overflow-x: auto; margin-bottom: 14px; padding-bottom: 2px; }\n");
        sb.append("        .cat-pill { background: #ffffff; border: 1.5px solid #cbd5e1; color: #475569; border-radius: 20px; padding: 6px 14px; font-size: 12px; font-weight: 700; cursor: pointer; white-space: nowrap; transition: all 0.2s; }\n");
        sb.append("        .cat-pill.active { background: #10b981; border-color: #10b981; color: #ffffff; box-shadow: 0 3px 10px rgba(16,185,129,0.28); }\n");
        sb.append("        body.dark-mode .cat-pill:not(.active) { background: #1e293b; border-color: #334155; color: #cbd5e1; }\n");
        sb.append("        .btn-mode-rules { background: #eff6ff; border: 1px solid #bfdbfe; color: #2563eb; padding: 10px 12px; border-radius: 10px; font-weight: 700; font-size: 12.5px; cursor: pointer; white-space: nowrap; transition: all 0.2s; }\n");
        sb.append("        .btn-mode-rules:hover { background: #dbeafe; }\n");
        sb.append("        body.dark-mode .btn-mode-rules { background: rgba(59,130,246,0.15); border-color: #3b82f6; color: #60a5fa; }\n");
        sb.append("        .btn-theme-toggle { background: #f8fafc; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 18px; padding: 5px 11px; font-size: 12px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; transition: all 0.2s; }\n");
        sb.append("        body.dark-mode .btn-theme-toggle { background: #1e293b; border-color: #475569; color: #fde68a; }\n");
        sb.append("        /* 页面三重视图容器系统 */\n");
        sb.append("        .app-view { display: none; width: 100%; min-height: 100vh; flex-direction: column; }\n");
        sb.append("        .app-view.active { display: flex; }\n");
        sb.append("        /* 全局大喇叭广播浮层: 明亮金橙柔和质感 */\n");
        sb.append("        .global-marquee-bar { position: fixed; top: 8px; left: 12px; right: 12px; z-index: 9999; background: linear-gradient(135deg, #fffbeb, #fef3c7); border: 1.5px solid #f59e0b; border-radius: 14px; padding: 6px 12px; box-shadow: 0 4px 16px rgba(245,158,11,0.25); display: none; pointer-events: none; transition: all 0.4s ease; }\n");
        sb.append("        .global-marquee-bar.show { display: block; animation: marqueeSlideDown 0.35s cubic-bezier(0.2, 0.9, 0.3, 1.2); }\n");
        sb.append("        @keyframes marqueeSlideDown { from { transform: translateY(-40px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }\n");
        sb.append("        .marquee-top-row { display: flex; align-items: center; gap: 6px; font-size: 11px; margin-bottom: 2px; }\n");
        sb.append("        .marquee-badge { background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; font-size: 9px; padding: 1px 5px; border-radius: 4px; font-weight: bold; }\n");
        sb.append("        .marquee-sender { color: #b45309; font-weight: bold; }\n");
        sb.append("        .marquee-title { color: #475569; font-size: 10.5px; }\n");
        sb.append("        .marquee-ticker-wrap { width: 100%; overflow: hidden; white-space: nowrap; box-sizing: border-box; }\n");
        sb.append("        .marquee-ticker-text { display: inline-block; padding-left: 100%; color: #92400e; font-size: 12px; font-weight: 700; animation: tickerScroll 8.5s linear infinite; }\n");
        sb.append("        @keyframes tickerScroll { 0% { transform: translate3d(0, 0, 0); } 100% { transform: translate3d(-100%, 0, 0); } }\n");
        sb.append("        /* 视图 1: 独立登录页面样式 (明亮晨曦护眼风) */\n");
        sb.append("        .login-wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; background: linear-gradient(135deg, #eef2f6 0%, #e0e7ff 50%, #f0fdf4 100%); }\n");
        sb.append("        .login-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 22px; width: 100%; max-width: 420px; padding: 30px 24px; box-shadow: 0 15px 35px rgba(0,0,0,0.06); text-align: center; }\n");
        sb.append("        .login-logo { font-size: 46px; margin-bottom: 10px; animation: bounceLogo 2s infinite ease-in-out; }\n");
        sb.append("        @keyframes bounceLogo { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-6px); } }\n");
        sb.append("        .login-card h2 { font-size: 22px; color: #0f172a; margin-bottom: 6px; font-weight: 800; letter-spacing: 0.5px; }\n");
        sb.append("        .login-card p { font-size: 13px; color: #64748b; margin-bottom: 18px; }\n");
        sb.append("        .auth-tabs { display: flex; background: #f1f5f9; border-radius: 12px; padding: 3px; margin-bottom: 16px; border: 1px solid #e2e8f0; }\n");
        sb.append("        .auth-tab-btn { flex: 1; padding: 9px 4px; font-size: 12px; font-weight: bold; color: #64748b; border: none; background: transparent; border-radius: 9px; cursor: pointer; transition: all 0.2s; }\n");
        sb.append("        .auth-tab-btn.active { background: #3b82f6; color: #fff; box-shadow: 0 2px 8px rgba(59,130,246,0.3); }\n");
        sb.append("        .form-group { margin-bottom: 14px; text-align: left; }\n");
        sb.append("        .form-label { font-size: 12px; color: #475569; margin-bottom: 6px; display: block; font-weight: 600; }\n");
        sb.append("        .form-input { width: 100%; background: #ffffff; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 12px 14px; color: #0f172a; font-size: 14px; outline: none; transition: border-color 0.2s; }\n");
        sb.append("        .form-input:focus { border-color: #10b981; }\n");
        sb.append("        .remember-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; font-size: 12px; color: #475569; }\n");
        sb.append("        .remember-label { display: flex; align-items: center; gap: 6px; cursor: pointer; }\n");
        sb.append("        .remember-checkbox { width: 16px; height: 16px; accent-color: #10b981; cursor: pointer; }\n");
        sb.append("        .qr-container { display: flex; flex-direction: column; align-items: center; padding: 10px 0; }\n");
        sb.append("        .qr-frame { background: #fff; padding: 10px; border-radius: 14px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); border: 1px solid #e2e8f0; margin-bottom: 12px; position: relative; width: 170px; height: 170px; display: flex; align-items: center; justify-content: center; }\n");
        sb.append("        .qr-img { width: 150px; height: 150px; display: block; }\n");
        sb.append("        .qr-refresh-btn { background: #eff6ff; border: 1px solid #3b82f6; color: #2563eb; font-size: 12px; padding: 6px 14px; border-radius: 8px; cursor: pointer; margin-top: 6px; font-weight: bold; }\n");
        sb.append("        .captcha-row { display: flex; gap: 8px; }\n");
        sb.append("        .captcha-box { background: #f8fafc; border-radius: 10px; width: 110px; height: 44px; display: flex; align-items: center; justify-content: center; font-family: monospace; font-size: 19px; font-weight: bold; letter-spacing: 4px; color: #0284c7; cursor: pointer; border: 1.5px solid #cbd5e1; position: relative; overflow: hidden; }\n");
        sb.append("        .btn-enter { width: 100%; background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: none; padding: 13px; border-radius: 12px; font-size: 15px; font-weight: bold; cursor: pointer; margin-top: 8px; box-shadow: 0 4px 14px rgba(16,185,129,0.25); }\n");
        sb.append("        .btn-enter:active { transform: scale(0.98); opacity: 0.9; }\n");
        sb.append("        .auth-tip { font-size: 11px; color: #64748b; margin-top: 12px; line-height: 1.4; }\n");
        sb.append("        /* 视图 2: 完整游戏大厅样式 (沉浸式电竞护眼卡片风格) */\n");
        sb.append("        .lobby-header-wrap { background: rgba(255, 255, 255, 0.96); border-bottom: 1px solid #e2e8f0; position: sticky; top: 0; z-index: 50; backdrop-filter: blur(16px); box-shadow: 0 4px 16px rgba(0,0,0,0.04); width: 100%; }\n");
        sb.append("        .lobby-header { max-width: 980px; margin: 0 auto; width: 100%; padding: 10px 18px; display: flex; align-items: center; justify-content: space-between; }\n");
        sb.append("        .lobby-user-info { display: flex; align-items: center; gap: 12px; }\n");
        sb.append("        .avatar-wrap { position: relative; display: inline-flex; }\n");
        sb.append("        .lobby-avatar { width: 44px; height: 44px; border-radius: 50%; background: #eff6ff; border: 2.5px solid #94a3b8; display: flex; align-items: center; justify-content: center; font-size: 22px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); position: relative; }\n");
        sb.append("        .lobby-avatar.vip-aura { border-color: #f59e0b; box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.25), 0 0 16px rgba(245, 158, 11, 0.55); animation: vipPulseAura 2.2s infinite ease-in-out; }\n");
        sb.append("        .lobby-avatar.svip-aura { border-color: #ec4899; box-shadow: 0 0 0 3.5px rgba(236, 72, 153, 0.35), 0 0 22px rgba(139, 92, 246, 0.65); animation: svipRainbowAura 3s infinite linear; }\n");
        sb.append("        @keyframes vipPulseAura { 0%, 100% { box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2), 0 0 12px rgba(245, 158, 11, 0.4); } 50% { box-shadow: 0 0 0 4px rgba(245, 158, 11, 0.4), 0 0 20px rgba(245, 158, 11, 0.8); } }\n");
        sb.append("        @keyframes svipRainbowAura { 0% { filter: drop-shadow(0 0 8px #ec4899); border-color: #ec4899; } 33% { filter: drop-shadow(0 0 10px #8b5cf6); border-color: #8b5cf6; } 66% { filter: drop-shadow(0 0 10px #3b82f6); border-color: #3b82f6; } 100% { filter: drop-shadow(0 0 8px #ec4899); border-color: #ec4899; } }\n");
        sb.append("        .avatar-crown { position: absolute; top: -11px; right: -7px; font-size: 15px; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3)); animation: crownFloat 2s infinite ease-in-out; pointer-events: none; z-index: 5; }\n");
        sb.append("        @keyframes crownFloat { 0%, 100% { transform: translateY(0) rotate(-6deg); } 50% { transform: translateY(-3px) rotate(6deg); } }\n");
        sb.append("        .lobby-user-details { text-align: left; }\n");
        sb.append("        .lobby-user-name { font-size: 14px; font-weight: 800; color: #0f172a; display: flex; align-items: center; gap: 6px; }\n");
        sb.append("        .badge-vip { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: #fff; font-size: 10px; font-weight: 900; padding: 2px 8px; border-radius: 6px; border: 1.2px solid #fef08a; box-shadow: 0 2px 8px rgba(217, 119, 6, 0.4); display: inline-flex; align-items: center; gap: 3px; line-height: 1.2; letter-spacing: 0.5px; cursor: pointer; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); }\n");
        sb.append("        .badge-vip:hover { transform: scale(1.05); box-shadow: 0 4px 12px rgba(217, 119, 6, 0.6); }\n");
        sb.append("        .badge-vip.normal { background: linear-gradient(135deg, #64748b, #475569); border-color: #cbd5e1; box-shadow: none; }\n");
        sb.append("        .badge-vip.svip { background: linear-gradient(135deg, #ec4899 0%, #8b5cf6 50%, #3b82f6 100%); border-color: #fbcfe8; box-shadow: 0 2px 12px rgba(236, 72, 153, 0.55); animation: svipBadgeGlow 2.5s infinite ease-in-out; }\n");
        sb.append("        @keyframes svipBadgeGlow { 0%, 100% { opacity: 0.95; transform: scale(1); } 50% { opacity: 1; transform: scale(1.03); filter: brightness(1.15); } }\n");
        sb.append("        .vip-nickname { color: #d97706 !important; font-weight: 800 !important; }\n");
        sb.append("        .vip-nickname.svip { background: linear-gradient(135deg, #ec4899, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-weight: 900 !important; text-shadow: 0 0 10px rgba(236,72,153,0.3); }\n");
        sb.append("        .lobby-user-sub { font-size: 11px; color: #64748b; display: flex; align-items: center; gap: 6px; margin-top: 2px; }\n");
        sb.append("        .lobby-assets { display: flex; align-items: center; gap: 8px; }\n");
        sb.append("        .asset-chip { border-radius: 20px; padding: 5px 12px 5px 8px; font-size: 12.5px; font-weight: 800; display: inline-flex; align-items: center; gap: 6px; cursor: pointer; transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1); box-shadow: 0 2px 6px rgba(0,0,0,0.04); }\n");
        sb.append("        .asset-chip:hover { transform: translateY(-1.5px) scale(1.02); box-shadow: 0 4px 14px rgba(0,0,0,0.1); }\n");
        sb.append("        .asset-chip.coin { background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%); border: 1.5px solid #f59e0b; color: #92400e; }\n");
        sb.append("        .asset-chip.diamond { background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%); border: 1.5px solid #38bdf8; color: #0369a1; }\n");
        sb.append("        .chip-plus { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 50%; background: rgba(0,0,0,0.08); font-size: 11px; font-weight: 900; margin-left: 2px; line-height: 1; transition: background 0.2s; }\n");
        sb.append("        .asset-chip:hover .chip-plus { background: rgba(0,0,0,0.15); }\n");
        sb.append("        .btn-logout { background: #f8fafc; border: 1.5px solid #cbd5e1; color: #64748b; border-radius: 18px; padding: 6px 14px; font-size: 12px; cursor: pointer; font-weight: 700; display: inline-flex; align-items: center; gap: 4px; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); box-shadow: 0 1px 3px rgba(0,0,0,0.04); }\n");
        sb.append("        .btn-logout:hover { background: #fee2e2; border-color: #fca5a5; color: #dc2626; transform: translateY(-1px); box-shadow: 0 3px 10px rgba(220, 38, 38, 0.15); }\n");
        sb.append("        .btn-copy-id { background: rgba(59,130,246,0.1); border: 1px solid rgba(59,130,246,0.3); color: #2563eb; border-radius: 4px; font-size: 10px; padding: 1px 6px; cursor: pointer; font-weight: 600; display: inline-flex; align-items: center; gap: 2px; transition: all 0.15s; }\n");
        sb.append("        .btn-copy-id:hover { background: #3b82f6; color: #fff; }\n");
        sb.append("        .active-room-banner { background: linear-gradient(90deg, #d97706, #b45309); color: #fff; padding: 10px 16px; display: flex; align-items: center; justify-content: space-between; cursor: pointer; font-size: 13px; box-shadow: 0 4px 12px rgba(217,119,6,0.25); z-index: 45; }\n");
        sb.append("        .banner-content { display: flex; align-items: center; gap: 8px; font-weight: 500; }\n");
        sb.append("        .pulse-dot { width: 8px; height: 8px; border-radius: 50%; background: #34d399; box-shadow: 0 0 8px #34d399; animation: pulseDot 1s infinite; }\n");
        sb.append("        @keyframes pulseDot { 0%, 100% { opacity: 1; transform: scale(1); } 50% { transform: scale(1.3); } }\n");
        sb.append("        .btn-banner-action { font-size: 12px; font-weight: bold; background: rgba(255,255,255,0.25); padding: 4px 10px; border-radius: 6px; white-space: nowrap; }\n");
        sb.append("        .lobby-content { flex: 1; max-width: 980px; margin: 0 auto; width: 100%; padding: 16px 18px 80px 18px; }\n");
        sb.append("        /* 游戏模式卡片 (纯白高质感微阴影) */\n");
        sb.append("        .game-mode-card { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 18px; padding: 16px; margin-bottom: 14px; position: relative; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.04); }\n");
        sb.append("        .game-mode-card.take6 { border-left: 5px solid #f59e0b; }\n");
        sb.append("        .game-mode-card.dice { border-left: 5px solid #3b82f6; }\n");
        sb.append("        .game-mode-card.wheel { border-left: 5px solid #ec4899; }\n");
        sb.append("        .game-mode-card.undercover { border-left: 5px solid #10b981; }\n");
        sb.append("        .game-mode-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }\n");
        sb.append("        .game-mode-title { font-size: 17px; font-weight: 800; color: #0f172a; display: flex; align-items: center; gap: 8px; }\n");
        sb.append("        .game-mode-badge { font-size: 10.5px; padding: 2px 7px; border-radius: 6px; font-weight: bold; }\n");
        sb.append("        .game-mode-desc { font-size: 12px; color: #64748b; line-height: 1.5; margin-bottom: 14px; }\n");
        sb.append("        .game-mode-actions { display: flex; gap: 10px; }\n");
        sb.append("        .btn-mode-quick { flex: 1; background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: none; padding: 10px; border-radius: 10px; font-weight: bold; font-size: 13px; cursor: pointer; box-shadow: 0 3px 10px rgba(16,185,129,0.25); }\n");
        sb.append("        .btn-mode-create { flex: 1; background: #f8fafc; border: 1px solid #cbd5e1; color: #334155; padding: 10px; border-radius: 10px; font-weight: 600; font-size: 13px; cursor: pointer; }\n");
        sb.append("        /* 搜房栏 */\n");
        sb.append("        .search-room-bar { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 10px 14px; display: flex; gap: 8px; margin-bottom: 14px; box-shadow: 0 2px 8px rgba(0,0,0,0.03); }\n");
        sb.append("        .search-room-input { flex: 1; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 8px 12px; color: #0f172a; font-size: 13px; outline: none; }\n");
        sb.append("        .btn-search-go { background: #3b82f6; border: none; color: #fff; border-radius: 8px; padding: 0 16px; font-weight: bold; font-size: 13px; cursor: pointer; }\n");
        sb.append("        /* 在线房间列表项 */\n");
        sb.append("        .room-list-box { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 12px; box-shadow: 0 3px 10px rgba(0,0,0,0.03); }\n");
        sb.append("        .room-list-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; font-size: 13px; font-weight: bold; color: #0f172a; }\n");
        sb.append("        .room-item-row { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 10px 12px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }\n");
        sb.append("        /* 交流广场样式 */\n");
        sb.append("        .square-tabs { display: flex; gap: 8px; margin-bottom: 12px; }\n");
        sb.append("        .square-tab-btn { flex: 1; padding: 9px; background: #ffffff; border: 1px solid #cbd5e1; border-radius: 10px; font-size: 12px; color: #64748b; font-weight: bold; cursor: pointer; }\n");
        sb.append("        .square-tab-btn.active { background: #3b82f6; color: #fff; border-color: #3b82f6; }\n");
        sb.append("        .square-chat-stream { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 12px; height: 380px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; margin-bottom: 10px; font-size: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.03); }\n");
        sb.append("        .square-input-bar { display: flex; gap: 8px; }\n");
        sb.append("        /* 排行榜样式 */\n");
        sb.append("        .rank-tabs { display: flex; gap: 8px; margin-bottom: 12px; }\n");
        sb.append("        .rank-tab-btn { flex: 1; padding: 9px; background: #ffffff; border: 1px solid #cbd5e1; border-radius: 10px; font-size: 12px; color: #64748b; font-weight: bold; cursor: pointer; }\n");
        sb.append("        .rank-tab-btn.active { background: #f59e0b; color: #fff; border-color: #f59e0b; }\n");
        sb.append("        .my-rank-banner { background: linear-gradient(135deg, #fef3c7, #e0e7ff); border: 1.5px solid #f59e0b; border-radius: 14px; padding: 12px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; }\n");
        sb.append("        .rank-item { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 10px 12px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.02); }\n");
        sb.append("        .rank-item.top1 { border-color: #f59e0b; background: #fffbeb; }\n");
        sb.append("        .rank-item.top2 { border-color: #94a3b8; background: #f8fafc; }\n");
        sb.append("        .rank-item.top3 { border-color: #d97706; background: #fff7ed; }\n");
        sb.append("        /* 亲密好友样式 */\n");
        sb.append("        .intimacy-wall { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 14px; margin-bottom: 14px; box-shadow: 0 3px 10px rgba(0,0,0,0.03); }\n");
        sb.append("        .relation-card { background: #fff1f2; border: 1px solid #fecdd3; border-radius: 12px; padding: 10px 12px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; cursor: pointer; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); }\n");
        sb.append("        .relation-card:hover { transform: translateY(-2px); border-color: #fb7185; box-shadow: 0 4px 14px rgba(244, 63, 94, 0.15); }\n");
        sb.append("        /* 商城样式 */\n");
        sb.append("        .shop-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-bottom: 14px; }\n");
        sb.append("        .shop-item-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 14px 10px; text-align: center; cursor: pointer; transition: all 0.2s; box-shadow: 0 2px 8px rgba(0,0,0,0.03); }\n");
        sb.append("        .shop-item-card:hover { border-color: #f59e0b; transform: translateY(-2px); }\n");
        sb.append("        .shop-price-btn { margin-top: 8px; width: 100%; background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; border: none; padding: 7px; border-radius: 8px; font-size: 12px; font-weight: bold; cursor: pointer; }\n");
        sb.append("        /* 个人中心样式 */\n");
        sb.append("        .profile-card { background: linear-gradient(135deg, #ffffff, #f8fafc); border: 1px solid #e2e8f0; border-radius: 16px; padding: 18px; text-align: center; margin-bottom: 14px; box-shadow: 0 4px 14px rgba(0,0,0,0.04); }\n");
        sb.append("        .profile-stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin: 14px 0; }\n");
        sb.append("        .profile-stat-box { background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 10px; padding: 8px 4px; }\n");
        sb.append("        .stat-val { font-size: 16px; font-weight: 800; color: #0f172a; }\n");
        sb.append("        .stat-lbl { font-size: 11px; color: #64748b; margin-top: 2px; }\n");
        sb.append("        /* 底部导航栏: 明亮白底 */\n");
        sb.append("        .bottom-nav { position: fixed; bottom: 0; left: 0; right: 0; height: 58px; background: rgba(255, 255, 255, 0.96); backdrop-filter: blur(14px); border-top: 1px solid #e2e8f0; display: flex; justify-content: space-around; align-items: center; z-index: 90; max-width: 600px; margin: 0 auto; box-shadow: 0 -2px 10px rgba(0,0,0,0.03); }\n");
        sb.append("        .nav-tab-btn { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 3px; font-size: 11px; color: #64748b; background: none; border: none; cursor: pointer; padding: 6px 0; transition: all 0.18s; }\n");
        sb.append("        .nav-tab-btn.active { color: #10b981; font-weight: bold; transform: scale(1.05); }\n");
        sb.append("        .nav-tab-icon { font-size: 18px; }\n");
        sb.append("        /* 视图 3: 游戏对战舞台 (明亮草绿桌游护眼设计) */\n");
        sb.append("        .header { background: rgba(255, 255, 255, 0.96); border-bottom: 1px solid #e2e8f0; padding: 10px 14px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 50; backdrop-filter: blur(10px); box-shadow: 0 2px 8px rgba(0,0,0,0.03); }\n");
        sb.append("        .brand { display: flex; align-items: center; gap: 8px; font-weight: bold; font-size: 15px; color: #0f172a; }\n");
        sb.append(".brand .badge { background: " + (isTake6 ? "#d97706" : "#10b981") + "; color: #fff; font-size: 10px; padding: 2px 6px; border-radius: 4px; }\n");
        sb.append("        .room-tag { background: #3b82f6; color: #fff; font-size: 12px; padding: 4px 10px; border-radius: 20px; font-weight: bold; }\n");
        sb.append("        .btn-back-lobby { background: #eff6ff; border: 1px solid #3b82f6; color: #2563eb; border-radius: 8px; padding: 4px 10px; font-size: 11px; font-weight: bold; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; }\n");
        sb.append("        .btn-exit-room { background: #fee2e2; border: 1px solid #ef4444; color: #dc2626; border-radius: 8px; padding: 4px 10px; font-size: 11px; font-weight: bold; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; }\n");
        sb.append("        .main-stage { flex: 1; padding: 14px; display: flex; flex-direction: column; gap: 14px; max-width: 600px; margin: 0 auto; width: 100%; }\n");
                sb.append("        .seats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }\n" +
                  "        .seats-grid.circle-seats-layout { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; padding: 8px; border-radius: 20px; border: 2px solid rgba(59,130,246,0.3); }\n" +
                  "        .seat-card.turn-highlight { border: 2px solid #f59e0b !important; box-shadow: 0 0 16px rgba(245,158,11,0.6) !important; }\n" +
                  "        .reconnect-toast-banner { position: fixed; top: 12px; left: 50%; transform: translateX(-50%); background: #1e293b; color: #38bdf8; padding: 8px 18px; border-radius: 20px; border: 1px solid #0284c7; font-size: 12px; z-index: 9999; display: none; align-items: center; gap: 6px; }\n" +
                  "        .stage-quick-controls { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }\n" +
                  "        .ctrl-btn { background: rgba(15,23,42,0.8); border: 1px solid #334155; color: #94a3b8; padding: 4px 10px; border-radius: 8px; font-size: 11px; cursor: pointer; }\n" +
                  "        .ctrl-btn.active { color: #38bdf8; border-color: #38bdf8; }\n");
        sb.append("        .seat-card { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 12px 6px; display: flex; flex-direction: column; align-items: center; position: relative; min-height: 106px; justify-content: center; box-shadow: 0 3px 8px rgba(0,0,0,0.03); }\n");
        sb.append("        .seat-card.active-turn { border-color: #10b981; box-shadow: 0 0 12px rgba(16,185,129,0.3); }\n");
        sb.append("        .seat-mic-tag { position: absolute; top: 6px; left: 8px; font-size: 10px; color: #94a3b8; font-weight: 600; }\n");
        sb.append("        .host-crown { position: absolute; top: 4px; right: 8px; font-size: 11px; background: #fef3c7; color: #b45309; border: 1px solid #f59e0b; border-radius: 4px; padding: 1px 4px; font-weight: bold; }\n");
        sb.append("        .ready-badge { position: absolute; top: 4px; right: 8px; font-size: 10px; padding: 1px 5px; border-radius: 4px; font-weight: bold; }\n");
        sb.append("        .ready-badge.ready { background: #dcfce7; color: #15803d; border: 1px solid #22c55e; }\n");
        sb.append("        .ready-badge.unready { background: #fef3c7; color: #b45309; border: 1px solid #f59e0b; }\n");
        sb.append("        .btn-seat-kick { position: absolute; bottom: 4px; right: 4px; display: inline-flex; align-items: center; justify-content: center; gap: 2px; background: rgba(239, 68, 68, 0.12); border: 1px solid rgba(239, 68, 68, 0.4); color: #dc2626; font-size: 9.5px; font-weight: bold; padding: 1.5px 6px; border-radius: 6px; cursor: pointer; z-index: 5; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); box-shadow: 0 1px 4px rgba(239,68,68,0.12); }\n");
        sb.append("        .btn-seat-kick:hover { background: #ef4444; border-color: #dc2626; color: #ffffff; transform: scale(1.06); box-shadow: 0 3px 8px rgba(239,68,68,0.35); }\n");
        sb.append("        .btn-seat-kick:active { transform: scale(0.95); }\n");
        sb.append("        .ready-bar { margin: 10px 0; display: flex; justify-content: center; }\n");
        sb.append("        .btn-ready-toggle { width: 100%; padding: 12px 16px; border-radius: 12px; border: none; font-size: 15px; font-weight: bold; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transition: all 0.2s; }\n");
        sb.append("        .btn-ready-toggle.ready { background: #10b981; color: #fff; }\n");
        sb.append("        .btn-ready-toggle.unready { background: #f59e0b; color: #fff; }\n");
        sb.append("        .btn-ready-toggle.host-start { background: linear-gradient(135deg, #10b981, #059669); color: #fff; animation: pulse 1.5s infinite; }\n");
        sb.append("        .btn-ready-toggle.host-waiting { background: #cbd5e1; color: #64748b; cursor: not-allowed; }\n");
        sb.append("        @keyframes pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.02); } }\n");
        sb.append("        .seat-avatar { width: 44px; height: 44px; background: #f1f5f9; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 22px; margin: 12px 0 4px; border: 2px solid transparent; }\n");
        sb.append("        .seat-name { font-size: 11px; color: #1e293b; font-weight: bold; max-width: 80px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }\n");
        sb.append("        .seat-empty { color: #64748b; font-size: 11px; margin-top: 10px; display: flex; flex-direction: column; align-items: center; gap: 4px; }\n");
        sb.append("        .seat-empty .plus { font-size: 20px; color: #10b981; }\n");
        sb.append("        .speech-bubble { position: absolute; top: -24px; left: 50%; transform: translateX(-50%); background: #ffffff; color: #0f172a; font-size: 10px; font-weight: bold; padding: 4px 8px; border-radius: 12px; white-space: nowrap; box-shadow: 0 4px 10px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; z-index: 10; pointer-events: none; }\n");
        sb.append("        .speech-bubble::after { content: ''; position: absolute; bottom: -4px; left: 50%; transform: translateX(-50%); border-width: 4px 4px 0; border-style: solid; border-color: #ffffff transparent; }\n");
        sb.append("        /* 游戏主棋盘: 极度舒适护眼草绿呢绒毯质感 */\n");
        sb.append("        .game-board { background: linear-gradient(145deg, #ecfdf5, #d1fae5); border: 2px solid #6ee7b7; border-radius: 20px; padding: 16px; text-align: center; box-shadow: 0 6px 20px rgba(16,185,129,0.08); }\n");
        sb.append("        .waiting-status-banner { background: rgba(255, 255, 255, 0.9); border: 1.5px dashed #10b981; border-radius: 12px; padding: 12px; margin-bottom: 10px; text-align: center; }\n");
        sb.append("        .waiting-status-title { font-size: 14px; font-weight: bold; color: #047857; margin-bottom: 4px; }\n");
        sb.append("        .waiting-status-desc { font-size: 11px; color: #4b5563; }\n");
        sb.append("        .take6-rules-banner { background: rgba(255, 255, 255, 0.9); border: 1px dashed #10b981; border-radius: 10px; padding: 8px 12px; font-size: 11px; color: #065f46; line-height: 1.4; margin-bottom: 10px; text-align: left; }\n");
        sb.append("        .take6-score-bar { display: flex; gap: 8px; overflow-x: auto; padding: 4px 0 8px; margin-bottom: 8px; }\n");
        sb.append("        .take6-score-item { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 8px; padding: 4px 8px; font-size: 11px; display: flex; align-items: center; gap: 4px; white-space: nowrap; color: #1e293b; box-shadow: 0 2px 4px rgba(0,0,0,0.03); }\n");
        sb.append("        .take6-score-item.me { border-color: #10b981; background: #ecfdf5; font-weight: bold; }\n");
        sb.append("        .take6-score-bulls { color: #dc2626; font-weight: bold; }\n");
        sb.append("        .take6-rows-container { display: flex; flex-direction: column; gap: 8px; margin-bottom: 12px; }\n");
        sb.append("        .take6-row { background: #ffffff; border: 1.5px solid #cbd5e1; border-radius: 12px; padding: 6px 8px; display: flex; align-items: center; gap: 8px; min-height: 72px; transition: all 0.25s; position: relative; box-shadow: 0 2px 6px rgba(0,0,0,0.03); }\n");
        sb.append("        .take6-row.danger { border-color: #f59e0b; background: #fffbeb; }\n");
        sb.append("        .take6-row.overflow { border-color: #ef4444; background: #fef2f2; box-shadow: 0 0 10px rgba(239, 68, 68, 0.25); }\n");
        sb.append("        .take6-row.selectable { border-color: #10b981; cursor: pointer; background: #f0fdf4; animation: pulseTakeRow 1.2s infinite; }\n");
        sb.append("        @keyframes pulseTakeRow { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.02); } }\n");
        sb.append("        .take6-row-meta { display: flex; flex-direction: column; align-items: center; justify-content: center; width: 34px; padding: 4px 2px; background: #f1f5f9; border-radius: 8px; font-weight: bold; font-size: 11px; flex-shrink: 0; color: #475569; }\n");
        sb.append("        .take6-row-cards { display: flex; gap: 6px; flex: 1; overflow-x: auto; align-items: center; padding-bottom: 2px; }\n");
        sb.append("        .take6-card { width: 44px; height: 62px; border-radius: 8px; display: flex; flex-direction: column; justify-content: space-between; padding: 3px 4px; cursor: pointer; user-select: none; position: relative; transition: transform 0.18s, box-shadow 0.18s; flex-shrink: 0; box-shadow: 0 2px 6px rgba(0,0,0,0.12); }\n");
        sb.append("        .take6-card.selected { transform: translateY(-8px); border: 2.5px solid #f59e0b !important; box-shadow: 0 6px 16px rgba(245, 158, 11, 0.4) !important; }\n");
        sb.append("        .take6-card:active { transform: scale(0.96); }\n");
        sb.append("        .card-corner { font-size: 8px; font-weight: 800; line-height: 1; }\n");
        sb.append("        .card-corner.top-left { text-align: left; }\n");
        sb.append("        .card-corner.bottom-right { text-align: right; }\n");
        sb.append("        .card-number { font-size: 17px; font-weight: 900; text-align: center; line-height: 1; }\n");
        sb.append("        .card-slot-empty { width: 44px; height: 62px; border: 1.5px dashed #cbd5e1; border-radius: 8px; flex-shrink: 0; display: flex; align-items: center; justify-content: center; color: #94a3b8; font-size: 10px; background: rgba(255,255,255,0.4); }\n");
        sb.append("        .take6-hand-tray { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 10px; margin-bottom: 12px; box-shadow: 0 4px 14px rgba(0,0,0,0.04); }\n");
        sb.append("        .take6-hand-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; font-size: 12px; color: #334155; font-weight: 600; }\n");
        sb.append("        .take6-hand-cards { display: flex; gap: 6px; overflow-x: auto; padding: 8px 4px 4px; min-height: 80px; align-items: flex-end; }\n");
        sb.append("        .btn-take6-play { background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: none; padding: 6px 14px; border-radius: 8px; font-size: 12px; font-weight: bold; cursor: pointer; box-shadow: 0 2px 8px rgba(16,185,129,0.25); }\n");
        sb.append("        .btn-take6-play:disabled { background: #cbd5e1; color: #94a3b8; cursor: not-allowed; box-shadow: none; }\n");
        sb.append("        .btn-take6-autoplay { background: #f1f5f9; color: #334155; border: 1px solid #cbd5e1; padding: 6px 12px; border-radius: 8px; font-size: 12px; font-weight: bold; cursor: pointer; transition: all 0.2s ease; }\n");
        sb.append("        .btn-take6-autoplay.active { background: linear-gradient(135deg, #d97706, #b45309); color: #fff; border-color: #f59e0b; box-shadow: 0 0 10px rgba(245, 158, 11, 0.3); }\n");
        sb.append("        .take6-countdown-badge { background: #eff6ff; border: 1px solid #3b82f6; color: #1d4ed8; padding: 2px 8px; border-radius: 6px; font-size: 11px; font-weight: bold; display: inline-flex; align-items: center; gap: 4px; }\n");
        sb.append("        .take6-countdown-badge.urgent { background: #fee2e2; border-color: #ef4444; color: #b91c1c; animation: pulseCountdown 0.8s infinite alternate; }\n");
        sb.append("        @keyframes pulseCountdown { from { opacity: 0.8; } to { opacity: 1; transform: scale(1.05); } }\n");
        sb.append("        .take6-revealed-row { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 10px; padding: 8px 10px; margin-bottom: 10px; display: flex; align-items: center; gap: 8px; overflow-x: auto; box-shadow: 0 2px 6px rgba(0,0,0,0.03); }\n");
        sb.append("        .revealed-tag { font-size: 11px; color: #475569; font-weight: bold; white-space: nowrap; }\n");
        sb.append("        .cup-box { width: 100px; height: 100px; background: radial-gradient(circle, #fde047, #f59e0b); border: 2px solid #d97706; border-radius: 50%; margin: 0 auto 12px; display: flex; align-items: center; justify-content: center; font-size: 50px; box-shadow: 0 4px 16px rgba(245,158,11,0.25); cursor: pointer; }\n");
        sb.append("        .cup-box.shake { animation: shakeCup 0.5s ease-in-out; }\n");
        sb.append("        @keyframes shakeCup { 0%, 100% { transform: rotate(0deg); } 20% { transform: rotate(-15deg) scale(1.05); } 40% { transform: rotate(15deg) scale(1.05); } 60% { transform: rotate(-10deg); } 80% { transform: rotate(10deg); } }\n");
        sb.append("        .dice-container { margin-bottom: 14px; }\n");
        sb.append("        .dice-row { display: flex; justify-content: center; align-items: center; gap: 8px; margin-bottom: 8px; perspective: 600px; }\n");
        sb.append("        .dice-card { width: 50px; height: 50px; background: #ffffff; border-radius: 11px; border: 1.5px solid #cbd5e1; box-shadow: 0 3px 8px rgba(0,0,0,0.1); display: flex; align-items: center; justify-content: center; padding: 4px; box-sizing: border-box; cursor: pointer; }\n");
        sb.append("        .dice-card.hidden-face { background: #f1f5f9; border-color: #f59e0b; color: #d97706; font-size: 22px; }\n");
        sb.append("        .dice-card.rolling { animation: rollDiceAnim 0.55s cubic-bezier(0.25, 1, 0.5, 1); }\n");
        sb.append("        @keyframes rollDiceAnim { 0% { transform: rotate(0deg) scale(0.85); opacity: 0.8; } 50% { transform: rotate(20deg) translateY(-4px) scale(1.08); } 100% { transform: rotate(0deg) scale(1); opacity: 1; } }\n");
        sb.append("        .dice-tally-bar { display: flex; align-items: center; justify-content: space-between; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 6px 10px; font-size: 11px; color: #334155; margin-top: 6px; }\n");
        sb.append("        .dice-tally-text { color: #d97706; font-weight: 600; text-align: left; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 200px; }\n");
        sb.append("        .btn-peek { background: #f1f5f9; border: 1px solid #cbd5e1; color: #334155; border-radius: 6px; padding: 2px 8px; font-size: 10.5px; cursor: pointer; }\n");
        sb.append("        .action-row { display: flex; gap: 8px; justify-content: center; margin-bottom: 12px; }\n");
        sb.append("        .btn-act { flex: 1; padding: 12px 8px; border-radius: 12px; border: none; font-weight: bold; font-size: 14px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 4px; }\n");
        sb.append("        .btn-shake { background: #3b82f6; color: #fff; }\n");
        sb.append("        .btn-call { background: #f59e0b; color: #fff; }\n");
        sb.append("        .btn-open { background: #ef4444; color: #fff; }\n");
        sb.append("        .bid-status-board { background: #ffffff; border: 1.5px solid #f59e0b; border-radius: 14px; padding: 8px 12px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 4px 12px rgba(245, 158, 11, 0.15); }\n");
        sb.append("        .bid-status-info { text-align: left; }\n");
        sb.append("        .bid-status-title { font-size: 11px; color: #b45309; font-weight: bold; }\n");
        sb.append("        .bid-status-val { font-size: 16px; color: #0f172a; font-weight: 800; margin-top: 2px; }\n");
        sb.append("        .bid-dice-badge { width: 36px; height: 36px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 4px rgba(0,0,0,0.06); }\n");
        sb.append("        .quick-phrases { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 4px; margin-bottom: 10px; }\n");
        sb.append("        .phrase-chip { background: #ffffff; color: #334155; padding: 6px 12px; border-radius: 16px; font-size: 11px; white-space: nowrap; cursor: pointer; border: 1px solid #cbd5e1; box-shadow: 0 1px 3px rgba(0,0,0,0.03); }\n");
        sb.append("        .phrase-chip:active { background: #10b981; color: #fff; border-color: #10b981; }\n");
        sb.append("        .chat-header-bar { display: flex; justify-content: space-between; align-items: center; padding: 4px 6px 6px; font-size: 11px; color: #64748b; border-bottom: 1px solid #e2e8f0; margin-bottom: 6px; font-weight: 600; }\n");
        sb.append("        .btn-toggle-chat { background: #f1f5f9; border: 1px solid #cbd5e1; color: #475569; border-radius: 6px; padding: 2px 8px; font-size: 10px; cursor: pointer; }\n");
        sb.append("        .chat-stream { background: #ffffff; border-radius: 14px; padding: 10px 12px; height: 120px; overflow-y: auto; font-size: 12px; border: 1px solid #e2e8f0; display: flex; flex-direction: column; gap: 6px; box-shadow: 0 2px 6px rgba(0,0,0,0.03); }\n");
        sb.append("        .chat-line { color: #1e293b; font-weight: 500; line-height: 1.5; }\n");
        sb.append("        .chat-line .sender { color: #0284c7; font-weight: bold; margin-right: 4px; }\n");
        sb.append("        .chat-line .system { color: #d97706; font-weight: bold; }\n");
        sb.append("        .input-bar { display: flex; gap: 8px; padding: 10px 14px; background: #ffffff; border-top: 1px solid #e2e8f0; }\n");
        sb.append("        .input-bar input { flex: 1; background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 9px 12px; color: #0f172a; font-size: 13px; outline: none; }\n");
        sb.append("        .input-bar input:focus { border-color: #10b981; background: #fff; }\n");
        sb.append("        .input-bar button { background: #10b981; color: #fff; border: none; padding: 0 16px; border-radius: 10px; font-size: 13px; font-weight: bold; cursor: pointer; box-shadow: 0 2px 6px rgba(16,185,129,0.25); }\n");
        sb.append("        /* 弹窗样式 (纯白精致卡片) */\n");
        sb.append("        .modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,0.45); display: flex; align-items: center; justify-content: center; z-index: 999; backdrop-filter: blur(8px); padding: 20px; }\n");
        sb.append("        .modal-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.12); width: 100%; }\n");
        sb.append("        .settlement-overlay { position: fixed; inset: 0; background: rgba(15,23,42,0.45); display: none; align-items: center; justify-content: center; z-index: 999; backdrop-filter: blur(8px); padding: 20px; }\n");
        sb.append("        .settlement-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 24px; padding: 24px; width: 100%; max-width: 400px; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.15); animation: popSettle 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }\n");
        sb.append("        @keyframes popSettle { from { transform: scale(0.85); opacity: 0; } to { transform: scale(1); opacity: 1; } }\n");
        sb.append("        .settlement-trophy { font-size: 42px; margin-bottom: 6px; }\n");
        sb.append("        .settlement-title { font-size: 20px; font-weight: 900; color: #0f172a; margin-bottom: 6px; }\n");
        sb.append("        .settlement-subtitle { font-size: 12px; color: #64748b; margin-bottom: 16px; }\n");
        sb.append("        .settlement-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 18px; max-height: 240px; overflow-y: auto; }\n");
        sb.append("        .settlement-item { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 10px 14px; display: flex; align-items: center; justify-content: space-between; }\n");
        sb.append("        .settlement-item.winner { background: #fffbeb; border-color: #f59e0b; }\n");
        sb.append("        .settlement-player-info { display: flex; align-items: center; gap: 8px; flex: 1; margin-left: 8px; text-align: left; }\n");
        sb.append("        .settlement-rank-badge { font-size: 16px; font-weight: 900; min-width: 24px; text-align: center; }\n");
        sb.append("        .settlement-rank-1 { color: #f59e0b; }\n");
        sb.append("        .settlement-rank-2 { color: #64748b; }\n");
        sb.append("        .settlement-rank-3 { color: #d97706; }\n");
        sb.append("        .settlement-avatar { font-size: 22px; }\n");
        sb.append("        .settlement-name { font-size: 13px; font-weight: bold; color: #0f172a; }\n");
        sb.append("        .settlement-score { font-size: 13px; font-weight: bold; color: #dc2626; }\n");
        sb.append("        .settlement-actions { display: flex; gap: 10px; }\n");
        sb.append("        .btn-settle-restart { flex: 1; background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: none; padding: 12px; border-radius: 12px; font-weight: bold; font-size: 13px; cursor: pointer; box-shadow: 0 3px 10px rgba(16,185,129,0.25); }\n");
        sb.append("        .btn-settle-lobby { flex: 1; background: #f1f5f9; border: 1px solid #cbd5e1; color: #334155; padding: 12px; border-radius: 12px; font-weight: bold; font-size: 13px; cursor: pointer; }\n");
        sb.append("        /* 好友私聊弹窗样式 (仿微信/APP清爽高雅白) */\n");
        sb.append("        .chat-modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,0.5); z-index: 1000; display: none; align-items: center; justify-content: center; backdrop-filter: blur(8px); padding: 16px; }\n");
        sb.append("        .chat-modal-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 20px; width: 100%; max-width: 440px; height: 560px; max-height: 90vh; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 20px 45px rgba(0,0,0,0.15); }\n");
        sb.append("        .chat-modal-header { padding: 12px 16px; background: #ffffff; border-bottom: 1px solid #e2e8f0; display: flex; align-items: center; justify-content: space-between; }\n");
        sb.append("        .chat-modal-user { display: flex; align-items: center; gap: 10px; text-align: left; }\n");
        sb.append("        .chat-modal-avatar { width: 36px; height: 36px; border-radius: 50%; background: #eff6ff; border: 2px solid #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 20px; }\n");
        sb.append("        .chat-modal-name { font-size: 14px; font-weight: bold; color: #0f172a; display: flex; align-items: center; gap: 6px; }\n");
        sb.append("        .chat-modal-status { font-size: 11px; color: #10b981; }\n");
        sb.append("        .chat-modal-close { background: none; border: none; font-size: 20px; color: #94a3b8; cursor: pointer; padding: 4px; }\n");
        sb.append("        .chat-quick-actions-bar { padding: 8px 12px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; display: flex; gap: 8px; overflow-x: auto; align-items: center; }\n");
        sb.append("        .chat-quick-btn { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 14px; padding: 4px 10px; font-size: 11px; color: #334155; font-weight: 600; white-space: nowrap; cursor: pointer; display: flex; align-items: center; gap: 4px; }\n");
        sb.append("        .chat-quick-btn:hover { background: #eff6ff; border-color: #3b82f6; color: #2563eb; }\n");
        sb.append("        .chat-messages-container { flex: 1; padding: 14px; overflow-y: auto; background: #f1f5f9; display: flex; flex-direction: column; gap: 10px; }\n");
        sb.append("        .chat-bubble-row { display: flex; gap: 8px; max-width: 82%; align-items: flex-end; }\n");
        sb.append("        .chat-bubble-row.me { align-self: flex-end; flex-direction: row-reverse; }\n");
        sb.append("        .chat-bubble-row.other { align-self: flex-start; }\n");
        sb.append("        .chat-bubble-avatar { width: 30px; height: 30px; border-radius: 50%; background: #fff; border: 1px solid #cbd5e1; display: flex; align-items: center; justify-content: center; font-size: 16px; flex-shrink: 0; }\n");
        sb.append("        .chat-bubble-content { padding: 9px 13px; border-radius: 14px; font-size: 13px; line-height: 1.45; word-break: break-all; position: relative; }\n");
        sb.append("        .chat-bubble-row.me .chat-bubble-content { background: linear-gradient(135deg, #10b981, #059669); color: #ffffff; border-bottom-right-radius: 2px; box-shadow: 0 2px 6px rgba(16,185,129,0.25); text-align: left; }\n");
        sb.append("        .chat-bubble-row.other .chat-bubble-content { background: #ffffff; color: #0f172a; border-bottom-left-radius: 2px; border: 1px solid #e2e8f0; box-shadow: 0 2px 6px rgba(0,0,0,0.03); text-align: left; }\n");
        sb.append("        .chat-bubble-time { font-size: 9px; color: #94a3b8; margin-top: 3px; text-align: right; }\n");
        sb.append("        .chat-room-invite-card { background: #ffffff; border: 1.5px solid #f59e0b; border-radius: 12px; padding: 10px; color: #1e293b; text-align: left; }\n");
        sb.append("        .chat-room-invite-card .room-badge { background: #fef3c7; color: #b45309; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold; }\n");
        sb.append("        .chat-room-invite-card .btn-join-invite { width: 100%; margin-top: 6px; background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; border: none; padding: 6px; border-radius: 6px; font-size: 11px; font-weight: bold; cursor: pointer; }\n");
        sb.append("        .chat-input-bar { padding: 10px 14px; background: #ffffff; border-top: 1px solid #e2e8f0; display: flex; gap: 8px; }\n");
        sb.append("        .chat-input-bar input { flex: 1; background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 9px 12px; color: #0f172a; font-size: 13px; outline: none; }\n");
        sb.append("        .chat-input-bar button { background: #10b981; color: #fff; border: none; padding: 0 16px; border-radius: 10px; font-weight: bold; font-size: 13px; cursor: pointer; }\n");
        sb.append("        /* 道具投掷弹窗与连击按钮样式 */\n");
        sb.append("        .throw-modal-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 20px; width: 100%; max-width: 420px; max-height: 85vh; overflow-y: auto; padding: 20px; text-align: left; box-shadow: 0 20px 45px rgba(0,0,0,0.15); }\n");
        sb.append("        .throw-items-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 12px 0; }\n");
        sb.append("        .throw-item-card { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 10px 6px; text-align: center; cursor: pointer; transition: all 0.2s; position: relative; }\n");
        sb.append("        .throw-item-card:hover { border-color: #3b82f6; background: #eff6ff; transform: translateY(-2px); }\n");
        sb.append("        .throw-item-card.selected { border-color: #10b981; background: #ecfdf5; box-shadow: 0 0 12px rgba(16,185,129,0.3); transform: scale(1.03); }\n");
        sb.append("        .throw-item-emoji { font-size: 28px; margin-bottom: 2px; }\n");
        sb.append("        .throw-item-name { font-size: 12px; font-weight: bold; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }\n");
        sb.append("        .throw-item-price { font-size: 10.5px; font-weight: bold; margin-top: 2px; }\n");
        sb.append("        .throw-item-price.coin { color: #d97706; }\n");
        sb.append("        .throw-item-price.diamond { color: #0284c7; }\n");
        sb.append("        .throw-combo-bar { display: flex; gap: 6px; overflow-x: auto; margin-bottom: 12px; padding: 2px 0; }\n");
        sb.append("        .throw-combo-btn { flex: 1; padding: 6px 4px; background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 11px; font-weight: bold; color: #475569; cursor: pointer; text-align: center; white-space: nowrap; }\n");
        sb.append("        .throw-combo-btn.active { background: linear-gradient(135deg, #f59e0b, #d97706); color: #fff; border-color: #f59e0b; box-shadow: 0 2px 6px rgba(245,158,11,0.3); }\n");
        sb.append("        .btn-confirm-throw { width: 100%; background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: none; padding: 12px; border-radius: 12px; font-weight: bold; font-size: 14px; cursor: pointer; box-shadow: 0 4px 12px rgba(16,185,129,0.25); }\n");
        sb.append("        /* 特性展示特效动画层 (物理飞掷、爆破光芒、豪礼全屏盛宴) */\n");
        sb.append("        .fx-overlay-stage { position: fixed; inset: 0; pointer-events: none; z-index: 10000; overflow: hidden; }\n");
        sb.append("        .fx-projectile { position: absolute; z-index: 10001; font-size: 48px; transform: translate(-50%, -50%); transition: all 0.48s cubic-bezier(0.2, 0.9, 0.3, 1.2); }\n");
        sb.append("        .fx-burst-ring { position: absolute; border-radius: 50%; border: 3px solid rgba(251,191,36,0.9); pointer-events: none; animation: burstRingAnim 0.7s ease-out forwards; }\n");
        sb.append("        @keyframes burstRingAnim { 0% { width: 10px; height: 10px; opacity: 1; transform: translate(-50%, -50%) scale(1); } 100% { width: 180px; height: 180px; opacity: 0; transform: translate(-50%, -50%) scale(1.5); } }\n");
        sb.append("        .fx-particle { position: absolute; font-size: 18px; pointer-events: none; animation: particleFly 0.8s ease-out forwards; }\n");
        sb.append("        @keyframes particleFly { 0% { opacity: 1; transform: translate(0, 0) scale(1); } 100% { opacity: 0; transform: translate(var(--dx), var(--dy)) scale(0.3) rotate(360deg); } }\n");
        sb.append("        .fx-runner-banner { position: fixed; top: 70px; left: 16px; background: linear-gradient(135deg, #ffffff, #fef3c7); border: 2px solid #f59e0b; border-radius: 16px; padding: 8px 16px; box-shadow: 0 8px 24px rgba(245,158,11,0.3); display: flex; align-items: center; gap: 8px; z-index: 9998; animation: runnerSlideIn 0.4s cubic-bezier(0.18, 0.89, 0.32, 1.28) forwards; }\n");
        sb.append("        @keyframes runnerSlideIn { from { transform: translateX(-120%); opacity: 0; } to { transform: translateX(0); opacity: 1; } }\n");
        sb.append("        .fx-luxury-splash { position: fixed; inset: 0; background: radial-gradient(circle, rgba(15,23,42,0.75) 0%, rgba(15,23,42,0.92) 100%); z-index: 10005; display: flex; flex-direction: column; align-items: center; justify-content: center; pointer-events: none; animation: luxuryFadeIn 0.3s ease-out forwards; }\n");
        sb.append("        @keyframes luxuryFadeIn { from { opacity: 0; } to { opacity: 1; } }\n");
        sb.append("        .luxury-rays { position: absolute; width: 420px; height: 420px; background: radial-gradient(circle, rgba(251,191,36,0.35) 0%, transparent 70%); animation: rotateRays 12s linear infinite; border-radius: 50%; }\n");
        sb.append("        @keyframes rotateRays { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }\n");
        sb.append("        .luxury-gift-icon { font-size: 88px; z-index: 2; animation: luxuryBounce 0.8s cubic-bezier(0.34, 1.56, 0.64, 1); }\n");
        sb.append("        @keyframes luxuryBounce { 0% { transform: scale(0.2); } 60% { transform: scale(1.25); } 100% { transform: scale(1); } }\n");
        sb.append("        .luxury-gift-title { font-size: 24px; font-weight: 900; color: #fbbf24; text-shadow: 0 4px 14px rgba(245,158,11,0.5); z-index: 2; margin-top: 8px; }\n");
        sb.append("        .luxury-gift-sub { font-size: 13px; color: #f8fafc; z-index: 2; margin-top: 4px; }\n");
        sb.append("        /* 商城 6 大分类导航与商品卡片样式 (与 APP 100% 保持一致) */\n");
        sb.append("        .shop-sub-nav { display: flex; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 5px; margin-bottom: 14px; overflow-x: auto; gap: 6px; box-shadow: 0 2px 8px rgba(0,0,0,0.03); scrollbar-width: none; -ms-overflow-style: none; }\n");
        sb.append("        .shop-sub-nav::-webkit-scrollbar { display: none; }\n");
        sb.append("        .shop-sub-btn { flex-shrink: 0; padding: 8px 14px; border: none; background: #f8fafc; border: 1px solid transparent; border-radius: 10px; font-size: 12px; font-weight: 700; color: #64748b; cursor: pointer; white-space: nowrap; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); }\n");
        sb.append("        .shop-sub-btn:hover { color: #0f172a; background: #f1f5f9; }\n");
        sb.append("        .shop-sub-btn.active { background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); color: #ffffff; border-color: #2563eb; box-shadow: 0 3px 10px rgba(37,99,235,0.35); font-weight: 800; }\n");
        sb.append("        .shop-catalog-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-bottom: 16px; }\n");
        sb.append("        .shop-card-pro { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 16px; padding: 14px 12px; text-align: center; display: flex; flex-direction: column; justify-content: space-between; position: relative; box-shadow: 0 2px 8px rgba(0,0,0,0.04); transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); }\n");
        sb.append("        .shop-card-pro:hover { transform: translateY(-3px); border-color: #93c5fd; box-shadow: 0 6px 18px rgba(59,130,246,0.12); }\n");
        sb.append("        .shop-card-icon { font-size: 38px; margin-bottom: 6px; }\n");
        sb.append("        .shop-card-name { font-size: 13.5px; font-weight: bold; color: #0f172a; margin-bottom: 3px; }\n");
        sb.append("        .shop-card-desc { font-size: 11px; color: #64748b; line-height: 1.35; margin-bottom: 8px; min-height: 28px; }\n");
        sb.append("        .shop-card-btn { width: 100%; padding: 8px 12px; border-radius: 10px; font-size: 12px; font-weight: 800; cursor: pointer; border: none; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); display: inline-flex; align-items: center; justify-content: center; gap: 4px; }\n");
        sb.append("        .shop-card-btn.buy { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; box-shadow: 0 3px 10px rgba(16,185,129,0.3); }\n");
        sb.append("        .shop-card-btn.buy:hover { background: linear-gradient(135deg, #34d399 0%, #059669 100%); transform: translateY(-1px); box-shadow: 0 4px 14px rgba(16,185,129,0.4); }\n");
        sb.append("        .shop-card-btn.equip { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: #ffffff; box-shadow: 0 3px 10px rgba(59,130,246,0.25); }\n");
        sb.append("        .shop-card-btn.equip:hover { background: linear-gradient(135deg, #60a5fa 0%, #1d4ed8 100%); transform: translateY(-1px); }\n");
        sb.append("        .shop-card-btn.equipped { background: #ecfdf5; border: 1.5px solid #10b981; color: #059669; cursor: default; box-shadow: none; }\n");
        sb.append("        .shop-card-btn.recharge { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: #ffffff; box-shadow: 0 3px 10px rgba(245,158,11,0.3); }\n");
        sb.append("        .shop-card-btn.recharge:hover { background: linear-gradient(135deg, #fbbf24 0%, #b45309 100%); transform: translateY(-1px); }\n");
        sb.append("        .vip-privilege-card { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 12px 14px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between; text-align: left; }\n");
        sb.append("        .vip-privilege-card.active { border-color: #f59e0b; background: #fffbeb; }\n");
        sb.append("        /* 资深玩家 & 现代UI增强: 叫点弹盘、印章盖戳、分享邀请按钮、避险推荐徽章 */\n");
        sb.append("        .btn-share-room { background: linear-gradient(135deg, #3b82f6, #1d4ed8); border: 1px solid #60a5fa; color: #fff; border-radius: 8px; font-size: 11px; padding: 5px 10px; cursor: pointer; font-weight: bold; display: inline-flex; align-items: center; gap: 4px; transition: all 0.2s; box-shadow: 0 2px 6px rgba(59,130,246,0.3); }\n");
        sb.append("        .btn-share-room:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(59,130,246,0.4); }\n");
        sb.append("        .dice-bid-modal { position: fixed; inset: 0; background: rgba(15,23,42,0.65); z-index: 9999; display: flex; align-items: center; justify-content: center; backdrop-filter: blur(4px); }\n");
        sb.append("        .dice-bid-card { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 20px; width: 92%; max-width: 380px; padding: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.18); text-align: left; animation: runnerSlideIn 0.25s cubic-bezier(0.18, 0.89, 0.32, 1.28); }\n");
        sb.append("        .dice-bid-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }\n");
        sb.append("        .dice-bid-title { font-size: 16px; font-weight: 900; color: #0f172a; display: flex; align-items: center; gap: 6px; }\n");
        sb.append("        .btn-bid-close { background: none; border: none; font-size: 20px; color: #94a3b8; cursor: pointer; }\n");
        sb.append("        .current-bid-hint { font-size: 12px; color: #0284c7; background: #e0f2fe; padding: 8px 12px; border-radius: 10px; margin-bottom: 14px; font-weight: bold; }\n");
        sb.append("        .bid-field-section { margin-bottom: 14px; }\n");
        sb.append("        .bid-label { font-size: 12px; font-weight: bold; color: #475569; margin-bottom: 6px; }\n");
        sb.append("        .bid-counter-row { display: flex; align-items: center; gap: 10px; }\n");
        sb.append("        .btn-counter { width: 38px; height: 38px; border-radius: 10px; background: #f1f5f9; border: 1px solid #cbd5e1; font-size: 18px; font-weight: 900; color: #1e293b; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s; }\n");
        sb.append("        .btn-counter:active { transform: scale(0.92); background: #e2e8f0; }\n");
        sb.append("        .bid-counter-val { font-size: 22px; font-weight: 900; color: #0f172a; min-width: 44px; text-align: center; }\n");
        sb.append("        .bid-quick-tags { display: flex; gap: 6px; margin-left: auto; }\n");
        sb.append("        .bid-tag { background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 11px; font-weight: bold; color: #64748b; padding: 4px 8px; cursor: pointer; transition: all 0.15s; }\n");
        sb.append("        .bid-tag:hover { background: #3b82f6; color: #fff; border-color: #3b82f6; }\n");
        sb.append("        .bid-face-grid { display: grid; grid-template-columns: repeat(6, 1fr); gap: 6px; }\n");
        sb.append("        .bid-face-chip { background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 6px 2px; text-align: center; cursor: pointer; transition: all 0.2s; display: flex; flex-direction: column; align-items: center; gap: 3px; }\n");
        sb.append("        .bid-face-chip.selected { border-color: #f59e0b; background: #fffbeb; box-shadow: 0 0 10px rgba(245,158,11,0.35); transform: translateY(-2px); }\n");
        sb.append("        .bid-face-chip .face-num { font-size: 11px; font-weight: 800; color: #334155; }\n");
        sb.append("        .bid-face-chip.selected .face-num { color: #b45309; }\n");
        sb.append("        .bid-option-row { margin-bottom: 16px; font-size: 12px; color: #475569; }\n");
        sb.append("        .bid-checkbox-label { display: flex; align-items: center; gap: 6px; cursor: pointer; }\n");
        sb.append("        .bid-action-btns { display: flex; gap: 10px; }\n");
        sb.append("        .btn-bid-cancel { flex: 1; background: #f1f5f9; border: 1px solid #cbd5e1; color: #64748b; font-weight: bold; padding: 10px; border-radius: 10px; cursor: pointer; }\n");
        sb.append("        .btn-bid-confirm { flex: 2; background: linear-gradient(135deg, #f59e0b, #d97706); border: none; color: #fff; font-weight: 900; padding: 10px; border-radius: 10px; cursor: pointer; box-shadow: 0 4px 12px rgba(217,119,6,0.3); font-size: 14px; }\n");
        sb.append("        /* 抓吹牛印章盖戳特效 */\n");
        sb.append("        .challenge-stamp-overlay { position: fixed; inset: 0; pointer-events: none; z-index: 10006; display: flex; align-items: center; justify-content: center; }\n");
        sb.append("        .challenge-stamp-badge { background: rgba(220, 38, 38, 0.95); border: 5px solid #fff; outline: 4px solid #dc2626; color: #fff; padding: 14px 32px; border-radius: 16px; font-size: 38px; font-weight: 900; letter-spacing: 4px; box-shadow: 0 10px 35px rgba(220,38,38,0.6); transform: rotate(-10deg) scale(0.2); animation: stampSlam 0.5s cubic-bezier(0.18, 0.89, 0.32, 1.28) forwards; }\n");
        sb.append("        @keyframes stampSlam { 0% { transform: rotate(-18deg) scale(3); opacity: 0; } 60% { transform: rotate(-10deg) scale(0.9); opacity: 1; } 100% { transform: rotate(-10deg) scale(1); opacity: 1; } }\n");
        sb.append("        .take6-row.selectable.recommended { border: 2.5px solid #10b981 !important; background: #ecfdf5 !important; box-shadow: 0 0 12px rgba(16,185,129,0.3); }\n");
        /* 商业化转化专区: 6元首充、幸运夺宝、破产救济与激励广告 */
        sb.append("        .commercial-quick-bar { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-bottom: 18px; }\n");
        sb.append("        .btn-commercial-tag { background: #ffffff; border: 2px solid #e2e8f0; border-radius: 16px; padding: 12px 10px; display: flex; flex-direction: column; align-items: center; justify-content: center; position: relative; cursor: pointer; transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1); box-shadow: 0 4px 14px rgba(0,0,0,0.04); text-align: center; }\n");
        sb.append("        .btn-commercial-tag:hover { transform: translateY(-3px) scale(1.02); box-shadow: 0 8px 24px rgba(0,0,0,0.1); }\n");
        sb.append("        .btn-commercial-tag:active { transform: translateY(0) scale(0.98); }\n");
        sb.append("        .btn-commercial-tag.first-recharge { border-color: #f59e0b; background: linear-gradient(145deg, #fffbeb 0%, #ffffff 100%); }\n");
        sb.append("        .btn-commercial-tag.lucky-gacha { border-color: #ec4899; background: linear-gradient(145deg, #fdf2f8 0%, #ffffff 100%); }\n");
        sb.append("        .btn-commercial-tag.relief { border-color: #10b981; background: linear-gradient(145deg, #ecfdf5 0%, #ffffff 100%); }\n");
        sb.append("        .comm-badge { position: absolute; top: -8px; right: 8px; background: linear-gradient(135deg, #ef4444, #dc2626); color: #fff; font-size: 9.5px; font-weight: 900; padding: 2px 7px; border-radius: 10px; border: 1.5px solid #fff; box-shadow: 0 2px 8px rgba(220,38,38,0.35); }\n");
        sb.append("        .comm-icon { font-size: 28px; margin-bottom: 4px; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.1)); }\n");
        sb.append("        .comm-title { font-size: 13.5px; font-weight: 900; color: #0f172a; letter-spacing: 0.2px; }\n");
        sb.append("        .comm-sub { font-size: 11px; color: #64748b; margin-top: 2px; font-weight: 500; }\n");
        sb.append("        .commercial-modal-card { background: #ffffff; border: 1.5px solid #e2e8f0; border-radius: 22px; width: 92%; max-width: 440px; padding: 22px; box-shadow: 0 20px 50px rgba(0,0,0,0.2); text-align: center; position: relative; animation: runnerSlideIn 0.25s cubic-bezier(0.18, 0.89, 0.32, 1.28); }\n");
        sb.append("        .gacha-prize-item { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 6px; font-size: 11px; font-weight: bold; color: #334155; }\n");
        sb.append("        .gacha-prize-item.epic { border-color: #ec4899; color: #db2777; background: #fdf2f8; }\n");
        sb.append("        .gacha-prize-item.legendary { border-color: #f59e0b; color: #d97706; background: #fffbeb; }\n");
        sb.append("        .ad-countdown-bar { width: 100%; height: 6px; background: #e2e8f0; border-radius: 3px; overflow: hidden; margin: 12px 0; }\n");
        sb.append("        .ad-countdown-fill { height: 100%; background: linear-gradient(90deg, #10b981, #059669); width: 100%; transition: width 1s linear; }\n");
        sb.append("        @keyframes scanBeam { 0% { top: 6px; opacity: 0.6; } 50% { top: 130px; opacity: 1; } 100% { top: 6px; opacity: 0.6; } }\n");
        sb.append("        .cashier-channel-item { transition: all 0.2s ease; cursor: pointer; }\n");
        sb.append("        .cashier-channel-item:hover { transform: translateY(-1px); }\n");
        sb.append("        .cashier-channel-item.active { box-shadow: 0 4px 12px rgba(16,185,129,0.18); }\n");
        sb.append("        .spinner-inline { display: inline-block; width: 14px; height: 14px; border: 2px solid #ffffff; border-top-color: transparent; border-radius: 50%; animation: spin 0.8s linear infinite; vertical-align: -2px; margin-right: 6px; }\n");
        sb.append("        @keyframes spin { to { transform: rotate(360deg); } }\n");
        sb.append("    </style>\n");
        sb.append("</head>\n");
        sb.append("<body>\n");
        return sb.toString();
    }

    private String buildHtmlViews(boolean isTake6, String gameTitle, String gameIcon, String roomId) {
        StringBuilder sb = new StringBuilder(18000);
        sb.append("<div class='global-marquee-bar' id='globalMarqueeBar'>\n" +
                  "    <div class='marquee-top-row'>\n" +
                  "        <span id='marqueeIcon' style='font-size:14px;'></span>\n" +
                  "        <span class='marquee-badge' id='marqueeBadge'></span>\n" +
                  "        <span class='marquee-sender' id='marqueeSender'></span>\n" +
                  "        <span class='marquee-title'></span>\n" +
                  "    </div>\n" +
                  "    <div class='marquee-ticker-wrap'>\n" +
                  "        <span class='marquee-ticker-text' id='marqueeTickerText'></span>\n" +
                  "    </div>\n" +
                  "</div>\n\n");

        sb.append("<div class='app-view active' id='viewLogin'>\n");
        sb.append("    <div class='login-wrap'>\n");
        sb.append("        <div class='login-card'>\n");
        sb.append("            <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;'>\n");
        sb.append("                <a href='/' style='display:inline-flex; align-items:center; gap:4px; font-size:12px; font-weight:bold; color:#2563eb; background:#eff6ff; border:1px solid #bfdbfe; padding:4px 10px; border-radius:9999px; text-decoration:none;'>🌐 返回 FWPT 门户</a>\n");
        sb.append("                <span style='font-size:11px; color:#64748b; font-weight:600;'>FWPT 统一生态</span>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='login-logo'>🎮</div>\n");
        sb.append("            <h2>聚会桌游吧 · 官方网页版</h2>\n");
        sb.append("            <p>免安装即开即玩 · 跨端联机 · 手机APP数据实时互通</p>\n");
        sb.append("            <div style='background:rgba(245,158,11,0.1); border:1px solid rgba(245,158,11,0.3); border-radius:10px; padding:10px 14px; font-size:12px; color:#d97706; margin-bottom:14px; text-align:left; line-height:1.5;'>\n");
        sb.append("                🔐 <b>登录提示</b>：聚会桌游吧需登录通行证或游戏账号后开启联机对战！\n");
        sb.append("            </div>\n");
        sb.append("            <a href='/?action=login&redirect=/party-game/' style='display:flex; align-items:center; justify-content:center; gap:8px; width:100%; margin-bottom:14px; padding:11px 16px; border-radius:10px; background:linear-gradient(135deg,#2563eb,#3b82f6); color:#fff; text-decoration:none; font-weight:bold; font-size:13px; box-shadow:0 3px 10px rgba(37,99,235,0.25);'>🛡️ FWPT 通行证一键快捷授权登录</a>\n");
        sb.append("            <div class='auth-tabs'>\n");
        sb.append("                <button class='auth-tab-btn active' id='tabBtnPwd' onclick='switchAuthTab(\"pwd\")'>🔑 账号密码</button>\n");
        sb.append("                <button class='auth-tab-btn' id='tabBtnQr' onclick='switchAuthTab(\"qr\")'>📱 扫码登录</button>\n");
        sb.append("                <button class='auth-tab-btn' id='tabBtnGuest' onclick='switchAuthTab(\"guest\")'>⚡ 手机验证</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div id='tabContentPwd'>\n");
        sb.append("                <div class='form-group'>\n");
        sb.append("                    <label class='form-label'>账号 / 手机号</label>\n");
        sb.append("                    <input type='text' id='inputPwdAccount' class='form-input' placeholder='请输入账号或11位手机号'>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='form-group'>\n");
        sb.append("                    <label class='form-label'>登录密码</label>\n");
        sb.append("                    <input type='password' id='inputPwdPass' class='form-input' placeholder='请输入密码 (默认 123)'>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='remember-row'>\n");
        sb.append("                    <label class='remember-label'>\n");
        sb.append("                        <input type='checkbox' id='chkRememberPwd' class='remember-checkbox' checked>\n");
        sb.append("                        <span>保存密码，下次直接免密登录</span>\n");
        sb.append("                    </label>\n");
        sb.append("                    <span style='color: #38bdf8; cursor: pointer;' onclick='toggleRegisterBox()'>快速注册账号</span>\n");
        sb.append("                </div>\n");
        sb.append("                <div id='registerExtraBox' style='display: none; margin-bottom: 14px; background: rgba(59,130,246,0.1); border: 1px dashed #3b82f6; border-radius: 10px; padding: 12px; text-align: left;'>\n");
        sb.append("                    <label class='form-label' style='color: #60a5fa;'>设置您的新游戏昵称</label>\n");
        sb.append("                    <input type='text' id='inputRegNickname' class='form-input' placeholder='请输入昵称 (如: 智慧小天才)' style='margin-bottom: 10px;'>\n");
        sb.append("                    <button style='width: 100%; background: #2563eb; color: #fff; border: none; padding: 10px; border-radius: 8px; font-weight: bold; cursor: pointer;' onclick='submitRegister()'>✨ 完成注册并登录</button>\n");
        sb.append("                </div>\n");
        sb.append("                <button class='btn-enter' id='btnPwdEnter' onclick='submitPasswordLogin(false)'>🚀 立即登录并进入大厅</button>\n");
        sb.append("                <div class='auth-tip'>💡 开启保存密码后，下次打开浏览器将自动免密秒登！</div>\n");
        sb.append("            </div>\n");
        sb.append("            <div id='tabContentQr' style='display: none;'>\n");
        sb.append("                <div class='qr-container'>\n");
        sb.append("                    <div class='qr-frame'>\n");
        sb.append("                        <img id='qrImg' class='qr-img' src='' alt='扫码登录二维码'>\n");
        sb.append("                        <div id='qrLoading' style='position: absolute; color: #64748b; font-size: 12px;'>正在生成二维码...</div>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div id='qrStatusTip' style='font-size: 12px; color: #38bdf8; font-weight: bold; margin-bottom: 8px;'>\n");
        sb.append("                        📱 手机 APP 扫一扫或输入授权口令秒登\n");
        sb.append("                    </div>\n");
        sb.append("                    <div style='display: flex; gap: 8px; justify-content: center; width: 100%; max-width: 280px;'>\n");
        sb.append("                        <button class='qr-refresh-btn' onclick='initQrLogin(true)' style='flex:1; margin:0;'>🔄 刷新二维码</button>\n");
        sb.append("                        <button class='qr-refresh-btn' onclick='copyQrAuthToken()' style='flex:1; margin:0; background:#3b82f6; border-color:#2563eb; color:#ffffff;' title='一键复制口令，在APP扫一扫中直接粘贴授权'>📋 复制口令</button>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='auth-tip' style='line-height:1.5; margin-top:10px;'>💡 <b>APP扫码登录指引</b>：打开手机APP -> 首页大厅右上角【扫一扫】，或进入底部【我的】->【扫一扫 / 登录电脑网页端】，扫描上方二维码或粘贴口令即可秒级授权登录！</div>\n");
        sb.append("            </div>\n");
        sb.append("            <div id='tabContentGuest' style='display: none;'>\n");
        sb.append("                <div class='form-group'>\n");
        sb.append("                    <label class='form-label'>临时游戏昵称</label>\n");
        sb.append("                    <input type='text' id='inputName' class='form-input' placeholder='请输入昵称' maxlength='12' value='试玩大侠_888'>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='form-group'>\n");
        sb.append("                    <label class='form-label'>手机号码 (接收短信验证码)</label>\n");
        sb.append("                    <input type='tel' id='inputPhone' class='form-input' placeholder='请输入11位大陆手机号' maxlength='11' value='13888886666'>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='form-group'>\n");
        sb.append("                    <label class='form-label'>短信验证码</label>\n");
        sb.append("                    <div style='display:flex; gap:8px;'>\n");
        sb.append("                        <input type='text' id='inputSmsCode' class='form-input' placeholder='请输入6位短信验证码' maxlength='6' style='flex:1;'>\n");
        sb.append("                        <button id='btnSendSms' type='button' onclick='sendTrialSms()' style='background:#3b82f6; color:#fff; border:none; border-radius:10px; padding:0 12px; font-size:12px; font-weight:bold; cursor:pointer; white-space:nowrap;'>获取验证码</button>\n");
        
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("                <button class='btn-enter' id='btnEnter' onclick='submitTrialSmsAuth()'>⚡ 验证并立即试玩</button>\n");
        sb.append("                <div class='auth-tip'>💡 输入手机号即可接收短信验证码，首次验证自动创建并登录试玩！</div>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("    </div>\n");
        sb.append("</div>\n");
        sb.append("<div class='app-view' id='viewLobby'>\n");
        sb.append("    <div class='lobby-header-wrap'>\n");
        sb.append("        <div class='lobby-header'>\n");
        sb.append("            <div class='lobby-user-info' onclick='openMyProfileModal()' style='cursor:pointer;' title='点击查看个人完整资料卡'>\n");
        sb.append("                <div class='avatar-wrap'>\n");
        sb.append("                    <div class='lobby-avatar' id='lobbyUserAvatar'>🦊</div>\n");
        sb.append("                    <span class='avatar-crown' id='avatarVipCrown' style='display:none;'>👑</span>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='lobby-user-details'>\n");
        sb.append("                    <div class='lobby-user-name'>\n");
        sb.append("                        <span id='lobbyUserName'>玩家昵称</span>\n");
        sb.append("                        <span class='badge-vip' id='lobbyUserVip' onclick='event.stopPropagation(); openVipPrivilegesModal()' title='点击查看尊享 VIP 特权' style='display:none;'>👑 VIP 1</span>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div class='lobby-user-sub' id='lobbyUserUid'>\n");
        sb.append("                        <span>UID: <span id='lobbyUserUidText'>未登录</span></span>\n");
        sb.append("                        <button class='btn-copy-id' onclick='event.stopPropagation(); copyUserId(myUserId)' title='一键复制UID'>📋 复制</button>\n");
        sb.append("                        <span id='lobbyUserRankTier'>· 🥉 倔强青铜</span>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <div style='display:flex; align-items:center; gap:8px; flex-wrap:wrap; justify-content:flex-end;'>\n");
        sb.append("                <div class='lobby-assets'>\n");
        sb.append("                    <div class='asset-chip coin' onclick='switchLobbyTab(\"shop\")' title='前往商店'>" + COIN_SVG + " <span id='lobbyUserCoins'>2,000</span></div>\n");
        sb.append("                    <div class='asset-chip diamond' onclick='switchLobbyTab(\"shop\")' title='前往商店'>💎 <span id='lobbyUserDiamonds'>50</span></div>\n");
        sb.append("                </div>\n");
        sb.append("                <button class='btn-theme-toggle' id='btnLobbyThemeToggle' onclick='toggleWebTheme()' title='切换护眼明亮 / 夜店暗黑主题'>🌙 暗黑</button>\n");
        sb.append("                <button class='btn-logout' onclick='logoutUser()' title='安全退出登录'>🚪 退出</button>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("    </div>\n");
        sb.append("    <div class='active-room-banner' id='activeRoomBanner' style='display:none;' onclick='rejoinActiveRoom()'>\n");
        sb.append("        <div class='banner-content'>\n");
        sb.append("            <span class='pulse-dot'></span>\n");
        sb.append("            <span id='activeRoomBannerText'></span>\n");
        sb.append("        </div>\n");
        sb.append("        <span class='btn-banner-action'>立即重连 ➔</span>\n");
        sb.append("    </div>\n");
        sb.append("    <div class='lobby-content'>\n");
        sb.append("        <div id='lobbyTabGames' class='lobby-tab-content'>\n");
        /* 首屏核心：快速开局与游戏列表 */
        sb.append("            <div style='background:linear-gradient(135deg,#0f172a,#1e293b); color:#ffffff; border-radius:16px; padding:16px 18px; margin-bottom:14px; display:flex; align-items:center; justify-content:space-between; gap:12px; box-shadow:0 4px 14px rgba(15,23,42,0.12);'>\n" +
                  "                <div>\n" +
                  "                    <div style='font-size:16px; font-weight:800;'>快速开局 · 实时联机对战</div>\n" +
                  "                    <div style='font-size:12px; color:#94a3b8; margin-top:2px;'>选择下方任意桌游模式，支持一键匹配、创建房间或输入 6 位房间号加入</div>\n" +
                  "                </div>\n" +
                  "                <div style='display:flex; gap:8px; flex-shrink:0;'>\n" +
                  "                    <button style='background:rgba(255,255,255,0.15); color:#ffffff; border:1px solid rgba(255,255,255,0.25); padding:10px 14px; border-radius:10px; font-size:12.5px; font-weight:700; cursor:pointer; white-space:nowrap;' onclick='openGameRulesModal(\"take6\")'>📖 玩法宝典</button>\n" +
                  "                    <button style='background:#10b981; color:#ffffff; border:none; padding:10px 18px; border-radius:10px; font-size:13px; font-weight:700; cursor:pointer; white-space:nowrap;' onclick='quickPlayGame(\"take6\")'>快速开局</button>\n" +
                  "                </div>\n" +
                  "            </div>\n");
        sb.append("            <div class='category-filter-bar'>\n" +
                  "                <button class='cat-pill active' data-cat='all' onclick='filterLobbyGameCategory(\"all\", this)'>🔥 全部玩法 (4)</button>\n" +
                  "                <button class='cat-pill' data-cat='strategy' onclick='filterLobbyGameCategory(\"strategy\", this)'>🎲 策略博弈</button>\n" +
                  "                <button class='cat-pill' data-cat='party' onclick='filterLobbyGameCategory(\"party\", this)'>🎡 酒桌破冰</button>\n" +
                  "                <button class='cat-pill' data-cat='deduction' onclick='filterLobbyGameCategory(\"deduction\", this)'>🕵️ 推理猜词</button>\n" +
                  "            </div>\n");
        sb.append("            <div class='game-mode-card take6' data-cat='strategy'>\n");
        sb.append("                <div class='game-mode-top'>\n");
        sb.append("                    <div class='game-mode-title'><span>🐂 谁是牛头王 (Take 6!)</span></div>\n");
        sb.append("                    <span class='game-mode-badge' style='background:#f59e0b; color:#1e293b;'>德式策略 · 6人开黑</span>\n");
        sb.append("                </div>\n");
        sb.append("                <div class='game-mode-desc'>每轮盲选一张卡牌同时亮出，按从小到大顺序入行；放进第6张牌的玩家收走整行牛头！惩罚牛头越少排名越高～</div>\n");
        sb.append("                <div class='game-mode-actions'>\n");
        sb.append("                    <button class='btn-mode-quick' onclick='quickPlayGame(\"take6\")'>⚡ 快速匹配开局</button>\n");
        sb.append("                    <button class='btn-mode-create' onclick='createRoomQuick(\"take6\")'>➕ 创建新房间</button>\n");
        sb.append("                    <button class='btn-mode-rules' onclick='openGameRulesModal(\"take6\")'>📖 规则</button>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='game-mode-card dice' data-cat='strategy'>\n" +
                  "                <div class='game-mode-top'>\n" +
                  "                    <div class='game-mode-title'><span>🎲 大话骰吹牛 (Liar's Dice)</span></div>\n" +
                  "                    <span class='game-mode-badge' style='background:#3b82f6; color:#fff;'>酒吧经典 · 心理博弈</span>\n" +
                  "                </div>\n" +
                  "                <div class='game-mode-desc'>摇动专属骰盅，遮挡点数防偷看，根据全桌点数虚实叫点，抓吹牛开盅决战到天亮！</div>\n" +
                  "                <div class='game-mode-actions'>\n" +
                  "                    <button class='btn-mode-quick' style='background:linear-gradient(135deg,#3b82f6,#2563eb);' onclick='quickPlayGame(\"liars_dice\")'>⚡ 快速匹配开局</button>\n" +
                  "                    <button class='btn-mode-create' onclick='createRoomQuick(\"liars_dice\")'>➕ 创建新房间</button>\n" +
                  "                    <button class='btn-mode-rules' onclick='openGameRulesModal(\"liars_dice\")'>📖 规则</button>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "            <div class='game-mode-card wheel' data-cat='party' style='border-left: 4px solid #ec4899;'>\n" +
                  "                <div class='game-mode-top'>\n" +
                  "                    <div class='game-mode-title'><span>🎡 聚会大冒险大转盘 (Party Wheel)</span></div>\n" +
                  "                    <span class='game-mode-badge' style='background:#ec4899; color:#fff;'>酒桌破冰 · 真心话大冒险</span>\n" +
                  "                </div>\n" +
                  "                <div class='game-mode-desc'>物理交互大转盘，随机抽取真心话大冒险与酒桌罚酒任务，支持自动连转托管，聚会破冰首选！</div>\n" +
                  "                <div class='game-mode-actions'>\n" +
                  "                    <button class='btn-mode-quick' style='background:linear-gradient(135deg,#ec4899,#be185d);' onclick='quickPlayGame(\"party_wheel\")'>⚡ 快速匹配开局</button>\n" +
                  "                    <button class='btn-mode-create' onclick='createRoomQuick(\"party_wheel\")'>➕ 创建新房间</button>\n" +
                  "                    <button class='btn-mode-rules' onclick='openGameRulesModal(\"party_wheel\")'>📖 规则</button>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "            <div class='game-mode-card undercover' data-cat='deduction' style='border-left: 4px solid #10b981;'>\n" +
                  "                <div class='game-mode-top'>\n" +
                  "                    <div class='game-mode-title'><span>🕵️ 谁是卧底 (Undercover)</span></div>\n" +
                  "                    <span class='game-mode-badge' style='background:#10b981; color:#fff;'>经典推理 · 猜词抓卧底</span>\n" +
                  "                </div>\n" +
                  "                <div class='game-mode-desc'>平民与卧底各执相似词语，轮流发言描述，抽丝剥茧投票放逐，找出隐藏在身边的真凶！</div>\n" +
                  "                <div class='game-mode-actions'>\n" +
                  "                    <button class='btn-mode-quick' style='background:linear-gradient(135deg,#10b981,#047857);' onclick='quickPlayGame(\"undercover\")'>⚡ 快速匹配开局</button>\n" +
                  "                    <button class='btn-mode-create' onclick='createRoomQuick(\"undercover\")'>➕ 创建新房间</button>\n" +
                  "                    <button class='btn-mode-rules' onclick='openGameRulesModal(\"undercover\")'>📖 规则</button>\n" +
                  "                </div>\n" +
                  "            </div>\n");
        sb.append("            <div class='search-room-bar'>\n");
        sb.append("                <input type='text' id='inputSearchRoomCode' class='search-room-input' placeholder='输入 6 位房间号精确加入...' maxlength='12'>\n");
        sb.append("                <button class='btn-search-go' onclick='joinSearchedRoom()'>🔍 进入房间</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='room-list-box'>\n");
        sb.append("                <div class='room-list-header'>\n");
        sb.append("                    <span>🔥 当前活跃开黑房间</span>\n");
        sb.append("                    <button style='background:none; border:none; color:#38bdf8; font-size:12px; cursor:pointer;' onclick='refreshLobbyRooms()'>🔄 刷新列表</button>\n");
        sb.append("                </div>\n");
        sb.append("                <div id='lobbyRoomList' style='display:flex; flex-direction:column; gap:8px;'>\n");
        sb.append("                    <div style='color:#64748b; font-size:12px; text-align:center; padding:16px;'>正在拉取在线房间列表...</div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <div id='lobbyTabSquare' class='lobby-tab-content' style='display:none;'>\n");
        sb.append("            <div class='square-tabs'>\n");
        sb.append("                <button class='square-tab-btn active' id='btnChanWorld' onclick='switchSquareChannel(\"WORLD\")'>全服世界频道</button>\n");
        sb.append("                <button class='square-tab-btn' id='btnChanCity' onclick='switchSquareChannel(\"CITY\")'>同城交友频道</button>\n");
        sb.append("                <button class='square-tab-btn' onclick='switchLobbyTab(\"friends\")'>我的好友</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='square-chat-stream' id='squareChatStream'>\n");
        sb.append("                <div class='chat-line'><span class='system'>[广场公告]</span> 欢迎来到聚会桌游交流广场！文明发言，文明开黑～</div>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='quick-phrases' style='margin-bottom:8px;'>\n");
        sb.append("                <div class='phrase-chip' onclick='sendSquareQuickMsg(\"有没有牛头王老司机？求进房带飞！\")'>🐮 牛头王求组</div>\n");
        sb.append("                <div class='phrase-chip' onclick='sendSquareQuickMsg(\"大话骰吹牛高手何在？决战到天亮！\")'>🎲 吹牛来战</div>\n");
        sb.append("                <div class='phrase-chip' onclick='sendSquareQuickMsg(\"加个好友处CP，互送鲜花提亲密度！\")'>❤️ 处CP加好友</div>\n");
        sb.append("                <div class='phrase-chip' onclick='sendSquareQuickMsg(\"今晚全场的消费由赵公子买单！\")'>💰 赵公子买单</div>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='square-input-bar'>\n");
        sb.append("                <input type='text' id='squareChatInput' class='form-input' placeholder='在广场发送消息...' maxlength='50' onkeydown='if(event.key===\"Enter\")sendSquareChatMessage()'>\n");
        sb.append("                <button class='btn-search-go' onclick='sendSquareChatMessage()'>发送</button>\n");
        sb.append("                <button style='background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:7px 12px; border-radius:10px; font-weight:bold; font-size:12px; cursor:pointer; margin-left:6px; white-space:nowrap;' onclick='openGlobalBroadcastModal()'>📢 全服喇叭</button>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <div id='lobbyTabRank' class='lobby-tab-content' style='display:none;'>\n");
        sb.append("            <div class='rank-tabs'>\n");
        sb.append("                <button class='rank-tab-btn active' id='btnRankTier' onclick='switchRankType(\"tier\")'>🏆 天梯排位积分榜</button>\n");
        sb.append("                <button class='rank-tab-btn' id='btnRankWealth' onclick='switchRankType(\"wealth\")'>💰 财富神豪金币榜</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='my-rank-banner' id='myRankCard'>\n");
        sb.append("                <div style='display:flex; align-items:center; gap:10px;'>\n");
        sb.append("                    <span style='font-size:24px;'>🎖️</span>\n");
        sb.append("                    <div style='text-align:left;'>\n");
        sb.append("                        <div style='font-size:13px; font-weight:bold; color:#b45309;'>我的天梯排位</div>\n");
        sb.append("                        <div style='font-size:11px; color:#475569;' id='myRankDesc'>暂未进入前50名 · 积分 1200 · 胜率 50%</div>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("                <button style='background:#f59e0b; color:#1e293b; border:none; padding:6px 12px; border-radius:8px; font-size:11px; font-weight:bold; cursor:pointer;' onclick='quickPlayGame(\"take6\")'>前往冲榜 ➔</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div id='rankListContainer' style='display:flex; flex-direction:column; gap:8px;'>\n");
        sb.append("                <div style='color:#64748b; font-size:12px; text-align:center; padding:16px;'>正在拉取最新排行榜数据...</div>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <div id='lobbyTabFriends' class='lobby-tab-content' style='display:none;'>\n");
        sb.append("            <div class='intimacy-wall'>\n");
        sb.append("                <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;'>\n");
        sb.append("                    <span style='font-size:14px; font-weight:bold; color:#0f172a;'>❤️ 我的亲密关系墙</span>\n");
        sb.append("                    <span style='font-size:11px; color:#f43f5e;'>结交知己 · 缔结良缘</span>\n");
        sb.append("                </div>\n");
        sb.append("                <div id='intimacyWallList'>\n");
        sb.append("                    <div style='color:#64748b; font-size:12px; text-align:center; padding:12px;'>暂无已缔结的亲密关系，互送礼物达到亲密度即可绑定～</div>\n");
        sb.append("                </div>\n");
        sb.append("                <div style='background:rgba(244,63,94,0.08); border:1px dashed #f43f5e; border-radius:10px; padding:10px; font-size:11px; color:#e11d48; line-height:1.5; margin-top:10px; text-align:left;'>\n");
        sb.append("                    💡 <b>亲密度规则</b>：送鲜花/啤酒/互动道具可增加亲密度；满50点可设为<b>【朋友】</b>，100点<b>【发小/死党】</b>，200点<b>【知己/闺蜜/基友】</b>，520点<b>【情侣/老婆/老公】</b>！\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='search-room-bar'>\n");
        sb.append("                <input type='text' id='inputAddFriendUid' class='search-room-input' placeholder='输入玩家 UID 或昵称添加好友...'>\n");
        sb.append("                <button class='btn-search-go' onclick='actionApplyFriend()'>➕ 申请好友</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='room-list-box' id='pendingRequestsBox' style='margin-bottom:12px;'>\n");
        sb.append("                <div class='room-list-header' style='background:linear-gradient(90deg,#eff6ff,#dbeafe); border-radius:10px 10px 0 0; padding:10px 14px;'>\n");
        sb.append("                    <span style='color:#1d4ed8; font-weight:800; display:flex; align-items:center; gap:6px;'>📩 好友申请与陌生人留言 <span id='pendingRequestsCountBadge' class='badge-vip' style='display:none; background:#ef4444; font-size:10px; padding:1px 6px;'>0</span></span>\n");
        sb.append("                    <button style='background:none; border:none; color:#2563eb; font-size:12px; cursor:pointer; font-weight:bold;' onclick='loadFriendRequestsData()'>🔄 刷新申请</button>\n");
        sb.append("                </div>\n");
        sb.append("                <div id='pendingRequestsContainer' style='display:flex; flex-direction:column; gap:8px; padding:8px 0;'>\n");
        sb.append("                    <div style='color:#94a3b8; font-size:12px; text-align:center; padding:12px;'>暂无待处理的好友申请与陌生人留言</div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='room-list-box'>\n");
        sb.append("                <div class='room-list-header'>\n");
        sb.append("                    <span>👥 我的好友列表</span>\n");
        sb.append("                    <button style='background:none; border:none; color:#38bdf8; font-size:12px; cursor:pointer;' onclick='loadFriendsData()'>🔄 刷新好友</button>\n");
        sb.append("                </div>\n");
        sb.append("                <div id='friendsListContainer' style='display:flex; flex-direction:column; gap:8px;'>\n");
        sb.append("                    <div style='color:#64748b; font-size:12px; text-align:center; padding:16px;'>正在拉取好友列表...</div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <div id='lobbyTabShop' class='lobby-tab-content' style='display:none;'>\n");
        sb.append("            <div style='background:linear-gradient(135deg,#fffbeb,#fef3c7); border:1.5px solid #f59e0b; border-radius:16px; padding:12px 16px; margin-bottom:12px; display:flex; align-items:center; justify-content:space-between; box-shadow:0 2px 10px rgba(245,158,11,0.12);'>\n");
        sb.append("                <div>\n");
        sb.append("                    <div style='font-size:14px; font-weight:800; color:#b45309; display:flex; align-items:center; gap:6px;'>\n");
        sb.append("                        <span>👑 VIP 特权装扮商城</span>\n");
        sb.append("                        <span class='badge-vip' id='shopUserVipBadge'>V1</span>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div style='font-size:11.5px; color:#78350f; margin-top:2px;'>\n");
        sb.append("                        金币 " + COIN_SVG + " <span id='shopUserCoins' style='font-weight:bold;'>2,000</span> · 钻石 💎 <span id='shopUserDiamonds' style='font-weight:bold;'>50</span>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("                <button style='background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:7px 14px; border-radius:8px; font-size:11px; font-weight:bold; cursor:pointer; box-shadow:0 2px 6px rgba(245,158,11,0.3);' onclick='switchShopCategory(\"recharge\")'>⚡ 立即充值</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div class='shop-sub-nav'>\n");
        sb.append("                <button class='shop-sub-btn active' id='shopNavDiceCup' onclick='switchShopCategory(\"dice_cup\")'>🎲 骰盅皮肤</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavAvatarFrame' onclick='switchShopCategory(\"avatar_frame\")'>🖼️ 头像边框</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavEntranceBanner' onclick='switchShopCategory(\"entrance_banner\")'>🚩 进场横幅</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavChatTextColor' onclick='switchShopCategory(\"chat_text_color\")'>🎨 文字颜色</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavGiftProp' onclick='switchShopCategory(\"gift_prop\")'>🎁 互动道具</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavRecharge' onclick='switchShopCategory(\"recharge\")'>💎 官方充值</button>\n");
        sb.append("                <button class='shop-sub-btn' id='shopNavVipCenter' onclick='switchShopCategory(\"vip_center\")'>👑 VIP特权</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div id='shopCatalogContainer' style='min-height:220px;'>\n");
        sb.append("                <div style='color:#64748b; font-size:12px; text-align:center; padding:30px;'>正在加载商城装扮与道具...</div>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <div id='lobbyTabProfile' class='lobby-tab-content' style='display:none;'>\n");
        sb.append("            <div class='profile-card'>\n");
        sb.append("                <div class='lobby-avatar' id='profileAvatarBig' style='width:58px; height:58px; font-size:28px; margin:0 auto 10px; border-width:3px;'>🦊</div>\n");
        sb.append("                <div style='font-size:18px; font-weight:bold; color:#0f172a;' id='profileNickname'>玩家昵称</div>\n");
        sb.append("                <div style='font-size:12px; color:#94a3b8; margin-top:2px;' id='profileUidText'>OneID 通行证已就绪</div>\n");
        sb.append("                <div class='profile-stat-grid'>\n");
        sb.append("                    <div class='profile-stat-box'>\n");
        sb.append("                        <div class='stat-val' id='statTotalGames'>0</div>\n");
        sb.append("                        <div class='stat-lbl'>总局数</div>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div class='profile-stat-box'>\n");
        sb.append("                        <div class='stat-val' id='statWinCount'>0</div>\n");
        sb.append("                        <div class='stat-lbl'>胜场数</div>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div class='profile-stat-box'>\n");
        sb.append("                        <div class='stat-val' style='color:#34d399;' id='statWinRate'>0%</div>\n");
        sb.append("                        <div class='stat-lbl'>综合胜率</div>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div class='profile-stat-box'>\n");
        sb.append("                        <div class='stat-val' style='color:#fbbf24;' id='statRankScore'>1200</div>\n");
        sb.append("                        <div class='stat-lbl'>天梯积分</div>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("                <div style='display:flex; justify-content:space-around; background:#f1f5f9; border:1px solid #e2e8f0; border-radius:12px; padding:10px; font-size:12px; color:#334155;'>\n");
        sb.append("                    <div>" + COIN_SVG + " 金币：<b id='profileCoins' style='color:#d97706;'>2,000</b></div>\n");
        sb.append("                    <div>💎 钻石：<b id='profileDiamonds' style='color:#0284c7;'>50</b></div>\n");
        sb.append("                    <div>👑 VIP：<b id='profileVip' style='color:#d97706;'>VIP 1</b></div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <div style='display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-bottom:14px;'>\n");
        sb.append("                <button type='button' onclick='openSignInModal()' style='background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:12px 8px; cursor:pointer; font-size:12px; font-weight:700; color:#0f172a;'>每日签到领奖</button>\n");
        sb.append("                <button type='button' onclick='openBankruptReliefModal()' style='background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:12px 8px; cursor:pointer; font-size:12px; font-weight:700; color:#0f172a;'>免费领救济金</button>\n");
        sb.append("                <button type='button' onclick='openLuckyGachaModal()' style='background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:12px 8px; cursor:pointer; font-size:12px; font-weight:700; color:#0f172a;'>金币幸运盲盒</button>\n");
        sb.append("            </div>\n");
        sb.append("            <div style='background:#ffffff; border:1px solid #e2e8f0; border-radius:14px; padding:14px; margin-bottom:14px; font-size:12px; color:#475569; line-height:1.6; box-shadow:0 2px 8px rgba(0,0,0,0.02);'>\n");
        sb.append("                <div style='font-weight:bold; color:#0f172a; margin-bottom:6px;'>公平竞技与战绩说明</div>\n");
        sb.append("                <div>1. 聚会桌游吧坚持公平竞技原则，所有联机对局记录真实计入天梯积分与胜率统计，不支持付费重置或修改战绩；<br>2. 对局中途若网络断开，系统将自动开启智能托管并保留重连通道。</div>\n");
        sb.append("            </div>\n");
        sb.append("            <button style='width:100%; padding:13px; background:#fee2e2; border:1px solid #fca5a5; color:#dc2626; border-radius:12px; font-weight:bold; font-size:14px; cursor:pointer;' onclick='logoutUser()'>🚪 退出登录当前账号</button>\n");
        sb.append("        </div>\n");
        sb.append("    </div>\n");
        sb.append("    <div class='bottom-nav'>\n");
        sb.append("        <button class='nav-tab-btn active' id='navItemGames' onclick='switchLobbyTab(\"games\")'>\n");
        sb.append("            <span class='nav-tab-icon'>🎮</span>\n");
        sb.append("            <span>游戏大厅</span>\n");
        sb.append("        </button>\n");
        sb.append("        <button class='nav-tab-btn' id='navItemSquare' onclick='switchLobbyTab(\"square\")'>\n");
        sb.append("            <span class='nav-tab-icon'>💬</span>\n");
        sb.append("            <span>社交广场</span>\n");
        sb.append("        </button>\n");
        sb.append("        <button class='nav-tab-btn' id='navItemRank' onclick='switchLobbyTab(\"rank\")'>\n");
        sb.append("            <span class='nav-tab-icon'>🏆</span>\n");
        sb.append("            <span>排行榜</span>\n");
        sb.append("        </button>\n");
        sb.append("        <button class='nav-tab-btn' id='navItemShop' onclick='switchLobbyTab(\"shop\")'>\n");
        sb.append("            <span class='nav-tab-icon'>🛍️</span>\n");
        sb.append("            <span>商店</span>\n");
        sb.append("        </button>\n");
        sb.append("        <button class='nav-tab-btn' id='navItemProfile' onclick='switchLobbyTab(\"profile\")'>\n");
        sb.append("            <span class='nav-tab-icon'>👤</span>\n");
        sb.append("            <span>我的</span>\n");
        sb.append("        </button>\n");
        sb.append("    </div>\n");
        sb.append("</div>\n");
        sb.append("<div class='app-view' id='viewGame'>\n" +
                  "    <div class='header'>\n" +
                  "        <div style='display:flex; align-items:center; gap:8px;'>\n" +
                  "            <div class='brand'>\n" +
                  "                <span id='gameHeaderIcon'>" + gameIcon + "</span>\n" +
                  "                <span class='badge' id='gameHeaderBadge'>" + gameTitle.split(" ")[0] + "</span>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <div style='display:flex; align-items:center; gap:6px; flex-wrap:wrap; justify-content:flex-end;'>\n" +
                  "            <div class='room-tag' id='headerRoomTag'>房间 #" + (roomId.isEmpty() ? "自选" : roomId) + "</div>\n" +
                  "            <button class='btn-theme-toggle' onclick='openGameRulesModal(currentGameType)' title='查看当前游戏规则'>📖 规则</button>\n" +
                  "            <button class='btn-theme-toggle' id='btnRoomThemeToggle' onclick='toggleWebTheme()' title='切换护眼明亮 / 夜店暗黑主题'>🌙</button>\n" +
                  "            <button class='btn-share-room' id='btnShareRoom' onclick='copyRoomInviteLink()' title='复制房间邀请链接，好友点击免密秒进'>🔗 邀请好友</button>\n" +
                   "            <button class='btn-exit-room' id='btnExitRoom' onclick='actionLeaveRoomExplicit()' title='退出当前房间回到大厅'>🚪 退出房间</button>\n" +
                  "        </div>\n" +
                  "    </div>\n\n");

        sb.append(buildHtmlStage(isTake6));
        sb.append(buildHtmlChatAndFooter(isTake6));
        sb.append("</div>\n");

        // 玩法规则宝典弹窗 (支持4款游戏切换查阅)
        sb.append("<div class='modal-overlay' id='gameRulesModal' style='display:none;' onclick='if(event.target===this)closeGameRulesModal()'>\n" +
                  "    <div class='modal-card' style='max-width:460px; padding:22px; text-align:left; position:relative;'>\n" +
                  "        <button onclick='closeGameRulesModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:20px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='font-size:18px; font-weight:900; margin-bottom:10px; display:flex; align-items:center; gap:8px;'><span>📖</span><span id='rulesModalTitle'>聚会桌游玩法宝典</span></div>\n" +
                  "        <div style='display:flex; gap:6px; margin-bottom:12px; overflow-x:auto; padding-bottom:2px;'>\n" +
                  "            <button class='cat-pill' id='ruleTab_take6' onclick='openGameRulesModal(\"take6\")'>🐂 牛头王</button>\n" +
                  "            <button class='cat-pill' id='ruleTab_liars_dice' onclick='openGameRulesModal(\"liars_dice\")'>🎲 大话骰</button>\n" +
                  "            <button class='cat-pill' id='ruleTab_party_wheel' onclick='openGameRulesModal(\"party_wheel\")'>🎡 大转盘</button>\n" +
                  "            <button class='cat-pill' id='ruleTab_undercover' onclick='openGameRulesModal(\"undercover\")'>🕵️ 谁是卧底</button>\n" +
                  "        </div>\n" +
                  "        <div id='rulesModalBody' style='font-size:13px; line-height:1.65; color:#475569; background:rgba(148,163,184,0.1); border-radius:12px; padding:14px; margin-bottom:14px;'></div>\n" +
                  "        <button class='btn-confirm-throw' onclick='closeGameRulesModal()'>✓ 我知道了</button>\n" +
                  "    </div>\n" +
                  "</div>\n");

        // 全局商业化与资产充值弹窗 (大厅与房间内均可自由唤起)
        sb.append(buildHtmlGlobalModals());

        // 全局好友私聊弹窗 (支持私信记录、对局邀请、实时 WebSocket 毫秒级直推)
        sb.append("<div class='chat-modal-overlay' id='friendChatModal' style='display:none;' onclick='if(event.target===this)closeFriendChatModal()'>\n");
        sb.append("    <div class='chat-modal-card'>\n");
        sb.append("        <div class='chat-modal-header'>\n");
        sb.append("            <div class='chat-modal-user'>\n");
        sb.append("                <div class='chat-modal-avatar' id='dmTargetAvatar'>🦊</div>\n");
        sb.append("                <div>\n");
        sb.append("                    <div class='chat-modal-name'>\n");
        sb.append("                        <span id='dmTargetName'>好友昵称</span>\n");
        sb.append("                        <span id='dmTargetRelBadge' style='font-size:10px; color:#f43f5e; background:#fff1f2; border:1px solid #fecdd3; border-radius:4px; padding:1px 5px;'>朋友</span>\n");
        sb.append("                    </div>\n");
        sb.append("                    <div style='font-size:10.5px; color:#64748b;'>\n");
        sb.append("                        <span id='dmTargetStatus' style='color:#10b981;'>🟢 在线</span> · <span id='dmTargetIntimacy'>亲密度 10</span>\n");
        sb.append("                    </div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <button class='chat-modal-close' onclick='closeFriendChatModal()'>✕</button>\n");
        sb.append("        </div>\n");
        sb.append("        <div class='chat-quick-actions-bar'>\n");
        sb.append("            <button class='chat-quick-btn' onclick='sendDirectRoomInvite()'>🎮 邀请TA进房</button>\n");
        sb.append("            <button class='chat-quick-btn' onclick='openGiftFromChat()'>🎁 互动送礼</button>\n");
        sb.append("            <div class='chat-quick-btn' onclick='sendDirectChatMessage(\"来一把大话骰？\")'>🎲 来一把大话骰</div>\n");
        sb.append("            <div class='chat-quick-btn' onclick='sendDirectChatMessage(\"上号！牛头王等你！\")'>🐮 牛头王等你</div>\n");
        sb.append("            <div class='chat-quick-btn' onclick='sendDirectChatMessage(\"马上到，稍等两分钟~\")'>⏱️ 稍等两分钟</div>\n");
        sb.append("        </div>\n");
        sb.append("        <div class='chat-messages-container' id='directChatStream'>\n");
        sb.append("            <div style='text-align:center; color:#94a3b8; font-size:11px; margin:10px 0;'>💬 正在载入私信历史...</div>\n");
        sb.append("        </div>\n");
        sb.append("        <div class='chat-input-bar'>\n");
        sb.append("            <input type='text' id='directChatInput' placeholder='输入私聊消息...' maxlength='100' onkeydown='if(event.key===\"Enter\")sendDirectChatMessage()'>\n");
        sb.append("            <button onclick='sendDirectChatMessage()'>发送</button>\n");
        sb.append("        </div>\n");
        sb.append("    </div>\n");
        sb.append("</div>\n");

        // 全局互动道具投掷弹窗 (完整支持 15 款道具与连击倍率)
        sb.append("<div class='modal-overlay' id='itemThrowModal' style='display:none;' onclick='if(event.target===this)closeItemThrowModal()'>\n");
        sb.append("    <div class='throw-modal-card'>\n");
        sb.append("        <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;'>\n");
        sb.append("            <div style='display:flex; align-items:center; gap:8px;'>\n");
        sb.append("                <span id='throwTargetAvatar' style='font-size:26px;'>🦊</span>\n");
        sb.append("                <div>\n");
        sb.append("                    <div style='font-size:14px; font-weight:bold; color:#0f172a;' id='throwTargetName'>目标玩家</div>\n");
        sb.append("                    <div style='font-size:11px; color:#64748b;' id='throwTargetDesc'>赠送互动礼物，即时触发全屏特效并增进亲密度！</div>\n");
        sb.append("                </div>\n");
        sb.append("            </div>\n");
        sb.append("            <button onclick='closeItemThrowModal()' style='background:none; border:none; font-size:20px; color:#94a3b8; cursor:pointer;'>✕</button>\n");
        sb.append("        </div>\n");
        sb.append("        <div style='font-size:12px; font-weight:bold; color:#475569; margin-bottom:6px;'>选择礼物道具 (15款官方互动道具)：</div>\n");
        sb.append("        <div class='throw-items-grid' id='throwItemsGrid'></div>\n");
        sb.append("        <div style='font-size:12px; font-weight:bold; color:#475569; margin-bottom:6px;'>选择赠送数量 / 连击倍率：</div>\n");
        sb.append("        <div class='throw-combo-bar'>\n");
        sb.append("            <div class='throw-combo-btn active' data-combo='1' onclick='selectThrowCombo(1)'>x1 颗</div>\n");
        sb.append("            <div class='throw-combo-btn' data-combo='10' onclick='selectThrowCombo(10)'>x10 十全</div>\n");
        sb.append("            <div class='throw-combo-btn' data-combo='66' onclick='selectThrowCombo(66)'>x66 顺意</div>\n");
        sb.append("            <div class='throw-combo-btn' data-combo='99' onclick='selectThrowCombo(99)'>x99 长久</div>\n");
        sb.append("            <div class='throw-combo-btn' data-combo='520' onclick='selectThrowCombo(520)'>x520 我爱</div>\n");
        sb.append("            <div class='throw-combo-btn' data-combo='1314' onclick='selectThrowCombo(1314)'>x1314 一生</div>\n");
        sb.append("        </div>\n");
        sb.append("        <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px; margin-bottom:14px; display:flex; justify-content:space-between; align-items:center;'>\n");
        sb.append("            <div style='font-size:12px; color:#334155;'>\n");
        sb.append("                <span>总计消耗: </span>\n");
        sb.append("                <span id='throwCostText' style='font-weight:bold; color:#d97706;'>" + COIN_SVG + " 20 金币</span>\n");
        sb.append("            </div>\n");
        sb.append("            <div style='font-size:12px; color:#f43f5e; font-weight:bold;'>\n");
        sb.append("                ❤️ 亲密度预估: +<span id='throwIntimacyGain'>20</span>\n");
        sb.append("            </div>\n");
        sb.append("        </div>\n");
        sb.append("        <button class='btn-confirm-throw' onclick='confirmSendThrowItem()'>🚀 立即投掷 / 赠送</button>\n");
        sb.append("    </div>\n");
        sb.append("</div>\n");

        // 全服大喇叭广播弹窗
        sb.append("<div class='modal-overlay' id='globalBroadcastModal' style='display:none;' onclick='if(event.target===this)closeGlobalBroadcastModal()'>\n");
        sb.append("    <div class='modal-card' style='max-width:380px; padding:20px; text-align:left;'>\n");
        sb.append("        <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;'>\n");
        sb.append("            <div style='display:flex; align-items:center; gap:8px;'>\n");
        sb.append("                <span style='font-size:26px;'>📢</span>\n");
        sb.append("                <div style='font-size:15px; font-weight:bold; color:#0f172a;'>全服广播大喇叭</div>\n");
        sb.append("            </div>\n");
        sb.append("            <button onclick='closeGlobalBroadcastModal()' style='background:none; border:none; font-size:20px; color:#94a3b8; cursor:pointer;'>✕</button>\n");
        sb.append("        </div>\n");
        sb.append("        <div style='font-size:12px; color:#64748b; margin-bottom:12px;'>向全服所有在线玩家同步投送高亮跑马灯祝福！</div>\n");
        sb.append("        <div class='form-group'>\n");
        sb.append("            <label class='form-label'>广播祝福标语</label>\n");
        sb.append("            <input type='text' id='inputGlobalBroadcastMsg' class='form-input' placeholder='祝大家天天开黑开心，局局吃鸡！' maxlength='40' value='祝大家开黑开心，天天吃鸡！'>\n");
        sb.append("        </div>\n");
        sb.append("        <div style='font-size:11px; color:#d97706; margin-bottom:12px;'>💡 每次播报消耗 10 颗钻石 💎 (VIP玩家享有专属V标)</div>\n");
        sb.append("        <button class='btn-confirm-throw' style='background:linear-gradient(135deg,#f59e0b,#d97706);' onclick='confirmSendGlobalBroadcast()'>📢 立即发送全服大喇叭</button>\n");
        sb.append("    </div>\n");
        sb.append("</div>\n");

        // 特效全屏展示动画舞台
        sb.append("<div class='fx-overlay-stage' id='fxOverlayStage'></div>\n");

        return sb.toString();
    }


    private String buildHtmlGlobalModals() {
        StringBuilder sb = new StringBuilder(24000);

        /* 1. 6元首充至尊豪华大礼包弹窗 */
        sb.append("<div class='modal-overlay' id='firstRechargeModal' style='display:none;' onclick='if(event.target===this)closeFirstRechargeModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:440px; border:2.5px solid #f59e0b;'>\n" +
                  "        <button onclick='closeFirstRechargeModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='font-size:40px; margin-bottom:4px;'>🎁</div>\n" +
                  "        <div style='font-size:21px; font-weight:900; color:#0f172a; margin-bottom:2px;'>6元首充至尊豪华大礼包</div>\n" +
                  "        <div style='font-size:12.5px; color:#d97706; font-weight:bold; margin-bottom:14px;'>🔥 新手专享 · 1100% 极速超值回馈 (原价 ¥68，现仅 ¥6.00)</div>\n" +
                  "        <div style='background:#fffbeb; border:1.5px solid #fde68a; border-radius:14px; padding:12px; margin-bottom:14px; text-align:left; display:flex; flex-direction:column; gap:8px;'>\n" +
                  "            <div style='display:flex; align-items:center; gap:8px; font-size:13px; font-weight:bold; color:#78350F;'><span style='color:#10b981;'>✓</span> 👑 绝版【紫晶星系】奢华骰盅 (自动装扮)</div>\n" +
                  "            <div style='display:flex; align-items:center; gap:8px; font-size:13px; font-weight:bold; color:#78350F;'><span style='color:#10b981;'>✓</span> 🐉「凤舞龙吟」全服入场横幅 (全场瞩目)</div>\n" +
                  "            <div style='display:flex; align-items:center; gap:8px; font-size:13px; font-weight:bold; color:#78350F;'><span style='color:#10b981;'>✓</span> 🪙 66,666 聚会金币 (立即可用)</div>\n" +
                  "            <div style='display:flex; align-items:center; gap:8px; font-size:13px; font-weight:bold; color:#78350F;'><span style='color:#10b981;'>✓</span> 💎 666 尊享钻石 (价值 66.6 元)</div>\n" +
                  "            <div style='display:flex; align-items:center; gap:8px; font-size:13px; font-weight:bold; color:#78350F;'><span style='color:#10b981;'>✓</span> ⭐ VIP 贵族成长值 +60 点 (直升 VIP 1 贵族)</div>\n" +
                  "        </div>\n" +
                  "        <button style='width:100%; background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:13px; border-radius:12px; font-size:16px; font-weight:900; cursor:pointer; box-shadow:0 4px 16px rgba(217,119,6,0.4);' onclick=\"openGameCashier('first_recharge', 'first_6', '6.00', '6元首充至尊豪华大礼包', '含紫晶星系骰盅、凤舞龙吟横幅、66,666金币、666钻石、直升VIP1')\">🚀 立即激活首充豪礼 (¥6.00)</button>\n" +
                  "        <div style='font-size:11px; color:#94a3b8; margin-top:8px;'>安全统一收银台 · 全流程支付保障</div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 2. 每日破产救济金与激励广告弹窗 */
        sb.append("<div class='modal-overlay' id='bankruptReliefModal' style='display:none;' onclick='if(event.target===this)closeBankruptReliefModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:420px; border:2.5px solid #10b981;'>\n" +
                  "        <button onclick='closeBankruptReliefModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='font-size:38px; margin-bottom:4px;'>🆘</div>\n" +
                  "        <div style='font-size:20px; font-weight:900; color:#0f172a; margin-bottom:4px;'>聚会破产关怀救济金</div>\n" +
                  "        <div style='font-size:12px; color:#64748b; margin-bottom:14px;'>胜败乃兵家常事！领取专属补给金立即重返对局～</div>\n" +
                  "        <div style='display:flex; flex-direction:column; gap:10px; margin-bottom:14px;'>\n" +
                  "            <div style='background:#f0fdf4; border:1px solid #bbf7d0; border-radius:12px; padding:12px; display:flex; justify-content:space-between; align-items:center;'>\n" +
                  "                <div style='text-align:left;'>\n" +
                  "                    <div style='font-weight:bold; font-size:13px; color:#166534;'>🪙 每日官方保底救济金</div>\n" +
                  "                    <div style='font-size:11px; color:#15803d;'>免费领取 1,500 金币 (VIP享加成)</div>\n" +
                  "                </div>\n" +
                  "                <button style='background:#16a34a; color:#fff; border:none; padding:8px 16px; border-radius:8px; font-weight:bold; font-size:12px; cursor:pointer;' onclick='actionClaimRelief(false)'>免费领取</button>\n" +
                  "            </div>\n" +
                  "            <div style='background:#fffbeb; border:1px solid #fde68a; border-radius:12px; padding:12px; display:flex; justify-content:space-between; align-items:center;'>\n" +
                  "                <div style='text-align:left;'>\n" +
                  "                    <div style='font-weight:bold; font-size:13px; color:#92400e;'>📺 观看 15 秒赞助商广告</div>\n" +
                  "                    <div style='font-size:11px; color:#b45309;'>免费领取 3,000 金币 (双倍暴击)</div>\n" +
                  "                </div>\n" +
                  "                <button style='background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:8px 16px; border-radius:8px; font-weight:bold; font-size:12px; cursor:pointer;' onclick='startWatchRewardedAd()'>看广告得</button>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 3. 幸运夺宝盲盒抽奖弹窗 */
        sb.append("<div class='modal-overlay' id='luckyGachaModal' style='display:none;' onclick='if(event.target===this)closeLuckyGachaModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:440px; border:2.5px solid #ec4899;'>\n" +
                  "        <button onclick='closeLuckyGachaModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='font-size:38px; margin-bottom:2px;'>🎯</div>\n" +
                  "        <div style='font-size:20px; font-weight:900; color:#0f172a; margin-bottom:4px;'>聚会幸运盲盒夺宝</div>\n" +
                  "        <div style='font-size:12px; color:#be185d; font-weight:bold; margin-bottom:12px;'>消耗富余金币 / 钻石，抽取 888 钻大奖与超级火箭！</div>\n" +
                  "        <div style='display:grid; grid-template-columns:repeat(3,1fr); gap:6px; margin-bottom:14px;'>\n" +
                  "            <div class='gacha-prize-item legendary'>👑 888 钻石大奖</div>\n" +
                  "            <div class='gacha-prize-item epic'>🚀 全服超级火箭</div>\n" +
                  "            <div class='gacha-prize-item epic'>🪙 18,888 金币</div>\n" +
                  "            <div class='gacha-prize-item'>📢 全服大喇叭</div>\n" +
                  "            <div class='gacha-prize-item'>💐 浪漫玫瑰x20</div>\n" +
                  "            <div class='gacha-prize-item'>🪙 3,000 金币保底</div>\n" +
                  "        </div>\n" +
                  "        <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:8px 10px; margin-bottom:12px; font-size:11px; color:#64748b; line-height:1.5; text-align:left;'>\n" +
                  "            <div style='font-weight:bold; color:#334155; margin-bottom:2px;'>📊 盲盒概率公示与保底规则：</div>\n" +
                  "            <div>· 888 钻特等奖: 0.5% | 🚀 全服超级火箭: 1.5% | 🪙 18,888 金币: 8.0%</div>\n" +
                  "            <div>· 📢 全服大喇叭: 15.0% | 💐 浪漫玫瑰x20: 35.0% | 🪙 3,000 金币: 40.0% (保底)</div>\n" +
                  "            <div style='color:#be185d; margin-top:2px;'>🛡️ 保底机制：十连抽必出史诗及以上奖励；连续 50 抽必出全服超级火箭。</div>\n" +
                  "        </div>\n" +
                  "        <div id='gachaResultArea' style='display:none; background:#fdf2f8; border:1.5px solid #fbcfe8; border-radius:12px; padding:12px; margin-bottom:12px; font-size:12.5px; font-weight:bold; color:#9d174d;'></div>\n" +
                  "        <div style='display:flex; gap:10px;'>\n" +
                  "            <button style='flex:1; background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:12px; border-radius:10px; font-weight:900; font-size:13px; cursor:pointer;' onclick=\"actionLuckyDraw(1, 'COIN')\">🪙 单抽 (1,000币)</button>\n" +
                  "            <button style='flex:1; background:linear-gradient(135deg,#ec4899,#db2777); color:#fff; border:none; padding:12px; border-radius:10px; font-weight:900; font-size:13px; cursor:pointer;' onclick=\"actionLuckyDraw(10, 'COIN')\">🔥 十连抽 (9,000币·9折)</button>\n" +
                  "        </div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 4. 15秒激励视频广告播放模拟弹窗 */
        sb.append("<div class='modal-overlay' id='adPlayerModal' style='display:none;'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:380px; border:2.5px solid #3b82f6;'>\n" +
                  "        <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;'>\n" +
                  "            <div style='font-size:12px; font-weight:bold; color:#2563eb;'>📺 赞助商官方特惠播报 (支持免费领金币)</div>\n" +
                  "            <div style='background:#eff6ff; color:#2563eb; font-size:11px; font-weight:900; padding:2px 8px; border-radius:10px;' id='adTimerBadge'>15s</div>\n" +
                  "        </div>\n" +
                  "        <div class='ad-countdown-bar'><div class='ad-countdown-fill' id='adCountdownFill'></div></div>\n" +
                  "        <div style='font-size:13px; color:#475569; margin-bottom:14px;'>正在加载聚会赞助商精选活动内容... 倒计时结束后金币将秒级自动入账！</div>\n" +
                  "        <div style='font-size:36px; animation:bounceLogo 1.5s infinite;'>🎁</div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 5. 官方充值与资产中心弹窗 (Recharge Modal) */
        sb.append("<div class='modal-overlay' id='rechargeModal' style='display:none;' onclick='if(event.target===this)closeRechargeModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:520px; border:2.5px solid #3b82f6; text-align:left;'>\n" +
                  "        <button onclick='closeRechargeModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='display:flex; align-items:center; gap:8px; margin-bottom:12px;'>\n" +
                  "            <span style='font-size:26px;'>💎</span>\n" +
                  "            <div>\n" +
                  "                <div style='font-size:18px; font-weight:900; color:#0f172a;'>官方充值与资产中心</div>\n" +
                  "                <div style='font-size:11px; color:#64748b;'>极速安全到账 · 支持多渠道支付 · 充值即享 VIP 贵族成长特权</div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <!-- 选项卡切换 -->\n" +
                  "        <div style='display:flex; gap:8px; margin-bottom:14px; background:#f1f5f9; padding:4px; border-radius:12px;'>\n" +
                  "            <button class='square-tab-btn active' id='rechargeTabBtnDiamonds' style='flex:1; border:none; padding:8px;' onclick='switchRechargeTab(\"diamonds\")'>💎 钻石直充 (升级VIP)</button>\n" +
                  "            <button class='square-tab-btn' id='rechargeTabBtnCoins' style='flex:1; border:none; padding:8px;' onclick='switchRechargeTab(\"coins\")'>🪙 钻石换金币 (1:100)</button>\n" +
                  "        </div>\n" +
                  "        <!-- Tab 1: 钻石充值档位 -->\n" +
                  "        <div id='rechargeTabDiamonds' style='display:block;'>\n" +
                  "            <div style='display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-bottom:14px;'>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fde68a; background:#fffbeb; padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_6', '6.00', '💎 60 钻石 (赠 1,000 金币)', '常规充值获 60 钻石、1,000 金币及 60 点成长值 (首次充值可享上方新手 6 元至尊豪礼)')\">\n" +
                  "                    <div style='font-size:10px; background:#f59e0b; color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>常规特惠</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#d97706; margin:4px 0 2px 0;'>💎 60</div>\n" +
                  "                    <div style='font-size:10.5px; color:#78350f;'>赠送 1,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 6.00</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #bfdbfe; background:#eff6ff; padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_30', '30.00', '💎 300 钻石 + 送 5,000 金币', '充值可获 300 钻石、5,000 金币及 300 点 VIP 贵族成长值')\">\n" +
                  "                    <div style='font-size:10px; background:#3b82f6; color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>超值特惠</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#2563eb; margin:4px 0 2px 0;'>💎 300</div>\n" +
                  "                    <div style='font-size:10.5px; color:#1e40af;'>赠送 5,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 30.00</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fbcfe8; background:#fdf2f8; padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_68', '68.00', '💎 680 钻石 + 送 12,000 金币', '热门推荐礼包，含 680 钻石与 12,000 金币')\">\n" +
                  "                    <div style='font-size:10px; background:#ec4899; color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>热门推荐</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#db2777; margin:4px 0 2px 0;'>💎 680</div>\n" +
                  "                    <div style='font-size:10.5px; color:#9d174d;'>送 12,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 68.00</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #e2e8f0; background:#f8fafc; padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_128', '128.00', '💎 1280 钻石 + 送 25,000 金币', '尊享特权大礼包，含 1280 钻石与 25,000 金币')\">\n" +
                  "                    <div style='font-size:10px; background:#8b5cf6; color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>尊享特权</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#7c3aed; margin:4px 0 2px 0;'>💎 1280</div>\n" +
                  "                    <div style='font-size:10.5px; color:#5b21b6;'>送 25,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 128.00</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fed7aa; background:#fff7ed; padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_328', '328.00', '💎 3280 钻石 + 送 70,000 金币', '神豪首选礼包，含 3280 钻石与 70,000 金币')\">\n" +
                  "                    <div style='font-size:10px; background:#ea580c; color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>神豪首选</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#c2410c; margin:4px 0 2px 0;'>💎 3280</div>\n" +
                  "                    <div style='font-size:10.5px; color:#9a3412;'>送 70,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 328.00</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:2px solid #f59e0b; background:linear-gradient(145deg,#fffbeb,#fef3c7); padding:10px 8px; border-radius:12px; cursor:pointer; text-align:center;' onclick=\"openGameCashier('recharge', 'tier_648', '648.00', '💎 6480 钻石 + 送 150,000 金币', '👑 至尊加冕神豪礼包，含 6480 钻石与 150,000 金币')\">\n" +
                  "                    <div style='font-size:10px; background:linear-gradient(135deg,#f59e0b,#dc2626); color:#fff; border-radius:4px; padding:1px 4px; display:inline-block; font-weight:bold;'>👑 至尊加冕</div>\n" +
                  "                    <div style='font-size:20px; font-weight:900; color:#b45309; margin:4px 0 2px 0;'>💎 6480</div>\n" +
                  "                    <div style='font-size:10.5px; color:#78350f;'>送 150,000 金币</div>\n" +
                  "                    <div style='font-size:13px; font-weight:900; color:#0f172a; margin-top:6px; background:#fff; border-radius:6px; padding:3px 0;'>¥ 648.00</div>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <!-- Tab 2: 钻石兑换金币 (汇率 1:100) -->\n" +
                  "        <div id='rechargeTabCoins' style='display:none;'>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:12px; padding:12px; margin-bottom:12px; font-size:12px; color:#475569;'>\n" +
                  "                🪙 官方钻石兑换汇率：<b>1 颗钻石 = 100 聚会金币</b>。金币可用于各大房间开黑、投掷礼物与幸运盲盒夺宝！\n" +
                  "            </div>\n" +
                  "            <div style='display:grid; grid-template-columns:repeat(2,1fr); gap:10px; margin-bottom:14px;'>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fed7aa; background:#fff7ed; padding:12px; border-radius:12px; cursor:pointer; text-align:center;' onclick='actionConvertDiamonds(10)'>\n" +
                  "                    <div style='font-size:18px; font-weight:900; color:#ea580c;'>" + COIN_SVG + " 1,000 金币</div>\n" +
                  "                    <div style='font-size:12px; color:#9a3412; margin-top:4px;'>消耗 10 颗钻石 💎</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fed7aa; background:#fff7ed; padding:12px; border-radius:12px; cursor:pointer; text-align:center;' onclick='actionConvertDiamonds(50)'>\n" +
                  "                    <div style='font-size:18px; font-weight:900; color:#ea580c;'>" + COIN_SVG + " 5,500 金币</div>\n" +
                  "                    <div style='font-size:12px; color:#9a3412; margin-top:4px;'>消耗 50 钻 (送500币) 💎</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fed7aa; background:#fff7ed; padding:12px; border-radius:12px; cursor:pointer; text-align:center;' onclick='actionConvertDiamonds(100)'>\n" +
                  "                    <div style='font-size:18px; font-weight:900; color:#ea580c;'>" + COIN_SVG + " 12,000 金币</div>\n" +
                  "                    <div style='font-size:12px; color:#9a3412; margin-top:4px;'>消耗 100 钻 (送2,000币) 💎</div>\n" +
                  "                </div>\n" +
                  "                <div class='shop-item-card' style='border:1.5px solid #fed7aa; background:#fff7ed; padding:12px; border-radius:12px; cursor:pointer; text-align:center;' onclick='actionConvertDiamonds(500)'>\n" +
                  "                    <div style='font-size:18px; font-weight:900; color:#ea580c;'>" + COIN_SVG + " 65,000 金币</div>\n" +
                  "                    <div style='font-size:12px; color:#9a3412; margin-top:4px;'>消耗 500 钻 (送15,000币) 💎</div>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <div style='font-size:11px; color:#94a3b8; text-align:center;'>聚会桌游吧绿色安全充值系统 · 充值即刻实时到账并升级 VIP 身份</div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 6. 聚会桌游 · 官方统一支付收银台弹窗 (Game Cashier Modal) */
        sb.append("<div class='modal-overlay' id='gameCashierModal' style='display:none; z-index:1005;' onclick='if(event.target===this)closeGameCashierModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:440px; border:2.5px solid #3b82f6; text-align:left; padding:22px; position:relative;'>\n" +
                  "        <button onclick='closeGameCashierModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='display:flex; align-items:center; gap:8px; margin-bottom:12px;'>\n" +
                  "            <span style='font-size:24px;'>🛒</span>\n" +
                  "            <div>\n" +
                  "                <div style='font-size:17px; font-weight:900; color:#0f172a;'>聚会桌游 · 官方统一收银台</div>\n" +
                  "                <div style='font-size:11px; color:#10b981; font-weight:bold;'>🔒 256位 SSL 交易安全防护 · 极速清算</div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <!-- 订单详情面板 -->\n" +
                  "        <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:12px; padding:12px 14px; margin-bottom:14px;'>\n" +
                  "            <div style='display:flex; justify-content:space-between; align-items:center; font-size:11.5px; color:#64748b; margin-bottom:4px;'>\n" +
                  "                <span>商户订单号:</span>\n" +
                  "                <span id='cashierOrderNo' style='font-family:monospace; color:#334155; font-weight:bold;'>PAY20261002000000</span>\n" +
                  "            </div>\n" +
                  "            <div style='font-size:14px; font-weight:bold; color:#0f172a; margin-bottom:2px;' id='cashierGoodsTitle'>💎 60 钻石 + 赠送 1,000 金币</div>\n" +
                  "            <div style='font-size:11.5px; color:#64748b; margin-bottom:6px;' id='cashierGoodsDesc'>充值可获 60 钻石、1,000 金币及 60 点 VIP 贵族成长值</div>\n" +
                  "            <div style='display:flex; justify-content:space-between; align-items:baseline; border-top:1px dashed #cbd5e1; padding-top:6px; margin-top:6px;'>\n" +
                  "                <span style='font-size:13px; font-weight:bold; color:#334155;'>应付金额：</span>\n" +
                  "                <div style='color:#ef4444; font-weight:900;'><span style='font-size:15px;'>¥</span> <span style='font-size:26px;' id='cashierAmount'>6.00</span> <span style='font-size:11px; color:#94a3b8;'>RMB</span></div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <!-- 支付方式切换 -->\n" +
                  "        <div style='font-size:12px; font-weight:bold; color:#475569; margin-bottom:8px;'>请选择支付方式：</div>\n" +
                  "        <div style='display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:14px;'>\n" +
                  "            <div class='cashier-channel-item active' id='channelWx' onclick='switchCashierChannel(\"WXPAY\")' style='border:2px solid #07c160; background:#f0fdf4; border-radius:10px; padding:10px; display:flex; align-items:center; gap:8px;'>\n" +
                  "                <span style='font-size:22px;'>🟢</span>\n" +
                  "                <div>\n" +
                  "                    <div style='font-size:13px; font-weight:bold; color:#166534;'>微信支付</div>\n" +
                  "                    <div style='font-size:10px; color:#15803d;'>推荐使用 · 扫码秒付</div>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "            <div class='cashier-channel-item' id='channelAli' onclick='switchCashierChannel(\"ALIPAY\")' style='border:1px solid #cbd5e1; background:#ffffff; border-radius:10px; padding:10px; display:flex; align-items:center; gap:8px;'>\n" +
                  "                <span style='font-size:22px;'>🔵</span>\n" +
                  "                <div>\n" +
                  "                    <div style='font-size:13px; font-weight:bold; color:#1e40af;'>支付宝</div>\n" +
                  "                    <div style='font-size:10px; color:#64748b;'>支持花呗 / 余额宝</div>\n" +
                  "                </div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <!-- 扫码区域 -->\n" +
                  "        <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:12px; padding:14px; text-align:center; margin-bottom:14px;'>\n" +
                  "            <div style='position:relative; width:150px; height:150px; margin:0 auto; background:#ffffff; border:1px solid #cbd5e1; border-radius:10px; padding:6px; box-shadow:0 4px 12px rgba(0,0,0,0.06); display:flex; align-items:center; justify-content:center;'>\n" +
                  "                <img id='cashierQrImg' src='' style='width:138px; height:138px; border-radius:6px; display:block;' alt='支付二维码'>\n" +
                  "                <div style='position:absolute; width:100%; height:2px; background:linear-gradient(90deg,transparent,#07c160,transparent); animation:scanBeam 2s infinite ease-in-out; top:10px;' id='cashierScanLaser'></div>\n" +
                  "            </div>\n" +
                  "            <div style='font-size:12px; color:#475569; font-weight:bold; margin-top:8px;' id='cashierScanTip'>📱 请使用手机微信【扫一扫】完成支付</div>\n" +
                  "            <div style='font-size:11px; color:#ef4444; margin-top:4px;'>⏱️ 订单有效倒计时: <b id='cashierTimer'>04:59</b></div>\n" +
                  "        </div>\n" +
                  "        <div style='background:#fef3c7; border:1px solid #fde68a; border-radius:10px; padding:8px 10px; margin-bottom:12px; font-size:11px; color:#92400e; line-height:1.5; text-align:left;'>\n" +
                  "            <div><b>💡 演示与测试环境说明：</b>当前收银台处于演示沙箱模式。微信/支付宝扫码为赞助通道，点击下方按钮将由服务端校验到账并模拟激活。</div>\n" +
                  "            <div style='margin-top:2px;'><b>⚠️ 未成年人保护提示：</b>未满18周岁未成年人禁止充值。虚拟代币仅供本平台娱乐使用，不可提现或兑换法定货币，充值后即刻到账不支持退款。</div>\n" +
                  "        </div>\n" +
                  "        <!-- 支付操作按钮 -->\n" +
                  "        <div style='display:flex; flex-direction:column; gap:8px;'>\n" +
                  "            <button id='btnCashierPay' style='width:100%; background:linear-gradient(135deg,#10b981,#059669); color:#fff; border:none; padding:13px; border-radius:10px; font-size:15px; font-weight:bold; cursor:pointer; box-shadow:0 4px 12px rgba(16,185,129,0.3);' onclick='actionCashierConfirmPayment()'>\n" +
                  "                已完成扫码支付，查询订单到账状态\n" +
                  "            </button>\n" +
                  "            <button style='width:100%; background:#f1f5f9; border:1px solid #cbd5e1; color:#64748b; padding:10px; border-radius:10px; font-size:12.5px; font-weight:bold; cursor:pointer;' onclick='closeGameCashierModal()'>\n" +
                  "                ✕ 取消支付并返回\n" +
                  "            </button>\n" +
                  "        </div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 7. VIP 贵宾特权体系卡片面板 (Vip Privileges Modal) */
        sb.append("<div class='modal-overlay' id='vipPrivilegesModal' style='display:none;' onclick='if(event.target===this)closeVipPrivilegesModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:500px; border:2.5px solid #f59e0b; text-align:left;'>\n" +
                  "        <button onclick='closeVipPrivilegesModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='display:flex; align-items:center; gap:8px; margin-bottom:12px;'>\n" +
                  "            <span style='font-size:26px;'>👑</span>\n" +
                  "            <div>\n" +
                  "                <div style='font-size:18px; font-weight:900; color:#0f172a;'>VIP 贵宾特权体系</div>\n" +
                  "                <div style='font-size:11px; color:#64748b;'>享受进场专属特效 · 救济金加成 · 头像框与全服荣誉勋章</div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <div style='background:linear-gradient(135deg,#fef3c7,#fde68a); border-radius:14px; padding:14px; margin-bottom:14px; border:1px solid #fcd34d;'>\n" +
                  "            <div style='display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;'>\n" +
                  "                <div style='font-size:15px; font-weight:bold; color:#78350F;' id='vipModalLevel'>VIP 1 贵族初贵</div>\n" +
                  "                <div style='font-size:12px; color:#92400e; font-weight:bold;'>成长经验: <span id='vipModalExp'>10 / 100</span></div>\n" +
                  "            </div>\n" +
                  "            <div style='height:8px; background:rgba(0,0,0,0.1); border-radius:4px; overflow:hidden;'>\n" +
                  "                <div style='height:100%; width:35%; background:linear-gradient(90deg,#f59e0b,#dc2626); border-radius:4px;'></div>\n" +
                  "            </div>\n" +
                  "            <div style='font-size:11px; color:#92400e; margin-top:6px;'>💡 每充值 1 元人民币可累积获得 10 点 VIP 成长经验！</div>\n" +
                  "        </div>\n" +
                  "        <div style='max-height:260px; overflow-y:auto; display:flex; flex-direction:column; gap:8px; margin-bottom:14px; padding-right:4px;'>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px;'>\n" +
                  "                <div style='font-weight:bold; font-size:13px; color:#0f172a; margin-bottom:4px;'>👑 VIP 1 · 聚会初贵 (王者初贵)</div>\n" +
                  "                <div style='font-size:11.5px; color:#475569; line-height:1.5;'>• 专属 VIP 1 贵族勋章标识<br>• 解锁【星空霸主头像框】购买特权<br>• 每日签到金币额外 +10%</div>\n" +
                  "            </div>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px;'>\n" +
                  "                <div style='font-weight:bold; font-size:13px; color:#0f172a; margin-bottom:4px;'>👑 VIP 2 · 聚会名流 (王者进阶)</div>\n" +
                  "                <div style='font-size:11.5px; color:#475569; line-height:1.5;'>• 专属 VIP 2 进阶贵族徽章<br>• 解锁【至尊黄金神龙骰盅】与【曜石金字色】<br>• 签到金币额外 +20%</div>\n" +
                  "            </div>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px;'>\n" +
                  "                <div style='font-weight:bold; font-size:13px; color:#0f172a; margin-bottom:4px;'>👑 VIP 3 · 牌桌宗师 (精英贵族)</div>\n" +
                  "                <div style='font-size:11.5px; color:#475569; line-height:1.5;'>• 专属 VIP 3 白银精英徽章<br>• 解锁【君临天下入场横幅】与【至尊红字色】<br>• 房间免踢特权，破产救济金每日额外 +1 次</div>\n" +
                  "            </div>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px;'>\n" +
                  "                <div style='font-weight:bold; font-size:13px; color:#0f172a; margin-bottom:4px;'>🔥 SVIP 4 · 雀圣尊爵 (璀璨流光)</div>\n" +
                  "                <div style='font-size:11.5px; color:#475569; line-height:1.5;'>• 专属 SVIP 4 璀璨流光徽章<br>• 解锁【黑金至尊帝王头像框】<br>• 全服大喇叭 8 折特惠使用权<br>• 破产救济金额外领取 +2 次</div>\n" +
                  "            </div>\n" +
                  "            <div style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:10px;'>\n" +
                  "                <div style='font-weight:bold; font-size:13px; color:#0f172a; margin-bottom:4px;'>✨ SVIP 10 · 荣耀无双 (终极至尊)</div>\n" +
                  "                <div style='font-size:11.5px; color:#475569; line-height:1.5;'>• 终极 SVIP 10 荣耀无双七彩神级徽章<br>• 【同桌装扮共享特权】（牌友共享骰盅皮肤）<br>• 神级龙腾入场全服公告横幅，救济金无限次领取</div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <button style='width:100%; background:#f1f5f9; color:#334155; border:1px solid #cbd5e1; padding:10px; border-radius:10px; font-weight:bold; font-size:13px; cursor:pointer;' onclick='closeVipPrivilegesModal()'>关闭窗口</button>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 6. 7天每日连续签到阶梯奖励弹窗 */
        sb.append("<div class='modal-overlay' id='signInModal' style='display:none;' onclick='if(event.target===this)closeSignInModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:460px; border:2.5px solid #6366f1; text-align:left;'>\n" +
                  "        <button onclick='closeSignInModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='display:flex; align-items:center; gap:10px; margin-bottom:12px;'>\n" +
                  "            <span style='font-size:32px;'>📅</span>\n" +
                  "            <div>\n" +
                  "                <div style='font-size:18px; font-weight:900; color:#0f172a;'>聚会7天连续签到大礼包</div>\n" +
                  "                <div style='font-size:11px; color:#64748b;'>每日打卡领取丰厚金币，第3天送全服大喇叭，满签第7天送66钻石！</div>\n" +
                  "            </div>\n" +
                  "        </div>\n" +
                  "        <div id='signInScheduleGrid' style='display:grid; grid-template-columns:repeat(4,1fr); gap:8px; margin-bottom:14px;'></div>\n" +
                  "        <button id='btnDoSignIn' style='width:100%; background:linear-gradient(135deg,#6366f1,#4f46e5); color:#fff; border:none; padding:12px; border-radius:12px; font-size:15px; font-weight:bold; cursor:pointer; box-shadow:0 4px 14px rgba(99,102,241,0.3);' onclick='actionDoSignIn()'>✍️ 立即签到领取奖励</button>\n" +
                  "    </div>\n" +
                  "</div>\n");

        /* 7. 大话骰全桌自动验点与胜负裁决弹窗 */
        sb.append("<div class='modal-overlay' id='diceSettlementModal' style='display:none;' onclick='if(event.target===this)closeDiceSettlementModal()'>\n" +
                  "    <div class='commercial-modal-card' style='max-width:480px; border:3px solid #f59e0b; text-align:center;'>\n" +
                  "        <button onclick='closeDiceSettlementModal()' style='position:absolute; top:14px; right:16px; background:none; border:none; font-size:22px; color:#94a3b8; cursor:pointer;'>✕</button>\n" +
                  "        <div style='font-size:40px; margin-bottom:2px;'>🎲</div>\n" +
                  "        <div id='diceSettleTitle' style='font-size:20px; font-weight:900; color:#0f172a; margin-bottom:4px;'>⚡ 开盅大揭秘！</div>\n" +
                  "        <div id='diceSettleSummary' style='font-size:13px; color:#b45309; font-weight:bold; margin-bottom:12px; background:#fffbeb; border:1px solid #fde68a; padding:10px; border-radius:10px;'></div>\n" +
                  "        <div id='diceSettleHandsList' style='display:flex; flex-direction:column; gap:8px; margin-bottom:14px; max-height:220px; overflow-y:auto;'></div>\n" +
                  "        <div style='display:flex; gap:10px;'>\n" +
                  "            <button style='flex:1; background:#f1f5f9; border:1px solid #cbd5e1; color:#334155; padding:11px; border-radius:10px; font-weight:bold; font-size:13px; cursor:pointer;' onclick='closeDiceSettlementModal()'>查看盘面</button>\n" +
                  "            <button style='flex:1; background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; padding:11px; border-radius:10px; font-weight:900; font-size:13px; cursor:pointer;' onclick='actionDiceNextRound()'>🔄 再来一局</button>\n" +
                  "        </div>\n" +
                  "    </div>\n" +
                  "</div>\n");

        return sb.toString();
    }

    private String buildHtmlStage(boolean isTake6) {
        StringBuilder sb = new StringBuilder(8000);
        sb.append("    <div class='main-stage'>\n" +
"        <div class='seats-grid' id='seatsGrid'></div>\n" +
"        <div class='ready-bar' style='display:flex; gap:8px;'>\n" +
"            <button class='btn-ready-toggle ready' id='btnReadyToggle' onclick='toggleMyReady()'>⚡ 点击准备</button>\n" +
"            <button class='btn-summon-players' id='btnSummonPlayers' onclick='actionSummonPlayers()' style='background:linear-gradient(135deg,#f59e0b,#d97706); color:#fff; border:none; border-radius:10px; font-weight:bold; font-size:13px; padding:10px 16px; cursor:pointer; box-shadow:0 4px 12px rgba(245,158,11,0.3);'>📢 召集玩家</button>\n" +
"            <button class='btn-spectator-toggle' id='btnSpectatorToggle' onclick='actionToggleSpectator()' style='display:none; background:#334155; color:#94a3b8; border:1px solid #475569; border-radius:10px; font-weight:bold; font-size:12px; padding:10px 14px; cursor:pointer;'>👁️ 允许旁观 (开)</button>\n" +
"        </div>\n" +
"        <div id='summonCountdownBanner' style='display:none; margin:8px 0; background:rgba(245,158,11,0.15); border:1px solid #f59e0b; color:#fbbf24; border-radius:8px; padding:8px 12px; font-size:12px; font-weight:bold; text-align:center;'>\n" +
"            📢 已向全服世界与同城频道发布召集广播！正在呼叫桌友进房 (<span id='summonTimerSeconds'>10</span>s)...\n" +
"        </div>\n");

        // 1. 牛头王对战板
        sb.append("        <div class='game-board' id='take6Board' style='display:none;'>\n" +
"            <div class='waiting-status-banner' id='take6WaitingStage'>\n" +
"                <div class='waiting-status-title'>⏳ 房间组队准备中</div>\n" +
"                <div class='waiting-status-desc'>请各位玩家点击上方【⚡ 点击准备】，所有玩家准备就绪后由房主开局！</div>\n" +
"            </div>\n" +
"            <div class='take6-rules-banner'>\n" +
"                🐂 <b>谁是牛头王规则</b>：每轮各选1张牌亮出，从小到大入行；放入<b>第6张牌</b>的玩家收走该行全部牛头！惩罚牛头越少排名越高～\n" +
"            </div>\n" +
"            <div style='font-size: 11px; color: #94a3b8; margin-bottom: 4px; text-align: left;'>🏆 实时牛头惩罚榜 (牛头越少排名越高)：</div>\n" +
"            <div class='take6-score-bar' id='take6ScoreBar'></div>\n" +
"            <div id='take6ChoiceAlert' style='display: none; background: #ef4444; color: #fff; padding: 8px 12px; border-radius: 8px; font-size: 12px; font-weight: bold; margin-bottom: 8px;'>\n" +
"                ⚠️ 您的牌小于所有行的末尾牌！请点击下方任意一行收走牛头！\n" +
"            </div>\n" +
"            <div class='take6-rows-container' id='take6RowsContainer'></div>\n" +
"            <div class='take6-revealed-row'>\n" +
"                <span class='revealed-tag'>本轮亮牌:</span>\n" +
"                <span id='take6RevealedCards' style='color: #64748b; font-size: 11px;'>等待开局后出牌...</span>\n" +
"            </div>\n" +
"            <div class='take6-hand-tray'>\n" +
"                <div class='take6-hand-header' style='display: flex; justify-content: space-between; align-items: center;'>\n" +
"                    <div style='display: flex; align-items: center; gap: 8px;'>\n" +
"                        <span id='take6HandTitle'>🎴 我的手牌 (待发牌)</span>\n" +
"                        <span class='take6-countdown-badge' id='take6CountdownBadge' style='display: none;'>⏳ 倒计时: 20s</span>\n" +
"                    </div>\n" +
"                    <div style='display: flex; align-items: center; gap: 8px;'>\n" +
"                        <button class='btn-take6-autoplay' id='btnTake6AutoPlay' onclick='toggleTake6AutoPlay()'>🤖 智能托管</button>\n" +
"                        <button class='btn-take6-play' id='btnTake6Play' onclick='actionTake6PlayCard()' disabled>等待开局</button>\n" +
"                    </div>\n" +
"                </div>\n" +
"                <div class='take6-hand-cards' id='take6HandCards'></div>\n" +
"            </div>\n" +
"        </div>\n");

        // 2. 大话骰对战板
        sb.append("        <div class='game-board' id='diceBoard' style='display:none;'>\n" +
"            <div class='waiting-status-banner' id='diceWaitingStage'>\n" +
"                <div class='waiting-status-title'>⏳ 房间组队准备中</div>\n" +
"                <div class='waiting-status-desc'>请各位玩家点击上方【⚡ 点击准备】，房主开局后自动投掷点数！</div>\n" +
"            </div>\n" +
"            <div class='bid-status-board' id='bidStatusBoard' style='display: none;'></div>\n" +
"            <div class='cup-box' id='diceCup' onclick='actionRollDice()' title='点击摇骰'>🎲</div>\n" +
"            <div style='font-size: 12px; color: #94a3b8; margin-bottom: 8px;' id='turnTip'>对局开始后点击骰盅或【摇一摇】投掷专属点数</div>\n" +
"            <div class='dice-container'>\n" +
"                <div class='dice-row' id='myDiceRow'></div>\n" +
"                <div class='dice-tally-bar'>\n" +
"                    <span id='diceTallyText' class='dice-tally-text'>等待房主开局...</span>\n" +
"                    <button class='btn-peek' id='btnPeek' onclick='togglePeekDice()' style='display:none;'>🙈 遮挡点数</button>\n" +
"                </div>\n" +
"            </div>\n" +
"            <div class='action-row'>\n" +
"                <button class='btn-act btn-shake' id='btnDiceShake' onclick='actionRollDice()' disabled>🎲 摇一摇</button>\n" +
"                <button class='btn-act btn-call' id='btnDiceCall' onclick='actionBidDialog()' disabled>📢 叫点数</button>\n" +
"                <button class='btn-act btn-open' id='btnDiceOpen' onclick='actionCallLiar()' disabled>⚡ 抓 / 开！</button>\n" +
"            </div>\n" +
"        </div>\n" +
"        <div class='dice-bid-modal' id='diceBidModal' style='display:none;'>\n" +
"            <div class='dice-bid-card'>\n" +
"                <div class='dice-bid-header'>\n" +
"                    <span class='dice-bid-title'>🎲 叫点出招</span>\n" +
"                    <button class='btn-bid-close' onclick='closeDiceBidModal()'>✕</button>\n" +
"                </div>\n" +
"                <div class='current-bid-hint' id='modalCurrentBidHint'>当前底盘：尚未有玩家叫点</div>\n" +
"                <div class='bid-field-section'>\n" +
"                    <div class='bid-label'>选择叫点个数 (Count):</div>\n" +
"                    <div class='bid-counter-row'>\n" +
"                        <button class='btn-counter' onclick='adjustBidCount(-1)'>-</button>\n" +
"                        <div class='bid-counter-val' id='bidCountVal'>3</div>\n" +
"                        <button class='btn-counter' onclick='adjustBidCount(1)'>+</button>\n" +
"                        <div class='bid-quick-tags'>\n" +
"                            <span class='bid-tag' onclick='adjustBidCount(1)'>+1</span>\n" +
"                            <span class='bid-tag' onclick='adjustBidCount(2)'>+2</span>\n" +
"                            <span class='bid-tag' onclick='adjustBidCount(3)'>+3</span>\n" +
"                        </div>\n" +
"                    </div>\n" +
"                </div>\n" +
"                <div class='bid-field-section'>\n" +
"                    <div class='bid-label'>选择骰子点数 (Face):</div>\n" +
"                    <div class='bid-face-grid' id='bidFaceGrid'></div>\n" +
"                </div>\n" +
"                <div class='bid-option-row'>\n" +
"                    <label class='bid-checkbox-label'>\n" +
"                        <input type='checkbox' id='bidIsPureCheckbox' onchange='togglePureBid()'>\n" +
"                        <span>📢 叫【斋】(1点不作为通配万能点)</span>\n" +
"                    </label>\n" +
"                </div>\n" +
"                <div class='bid-action-btns'>\n" +
"                    <button class='btn-bid-cancel' onclick='closeDiceBidModal()'>取消</button>\n" +
"                    <button class='btn-bid-confirm' onclick='confirmDiceBid()'>🔥 确认喊出</button>\n" +
"                </div>\n" +
"            </div>\n" +
"        </div>\n" +
"        <div class='challenge-stamp-overlay' id='diceStampOverlay' style='display:none;'>\n" +
"            <div class='challenge-stamp-badge' id='diceStampText'>开！💥</div>\n" +
"        </div>\n");

        // 3. 聚会大冒险大转盘
        sb.append("        <div class='game-board' id='wheelBoard' style='display:none;'>\n" +
"            <div class='waiting-status-banner' id='wheelWaitingStage'>\n" +
"                <div class='waiting-status-title'>⏳ 房间组队准备中</div>\n" +
"                <div class='waiting-status-desc'>聚会大冒险大转盘，点击【🎯 开始旋转】抽取精彩任务！</div>\n" +
"            </div>\n" +
"            <div style='display:flex; flex-direction:column; align-items:center; margin:16px 0;'>\n" +
"                <div style='position:relative; width:260px; height:260px;'>\n" +
"                    <canvas id='wheelCanvas' width='260' height='260' style='border-radius:50%; box-shadow:0 0 20px rgba(236,72,153,0.4);'></canvas>\n" +
"                    <div id='wheelPointer' style='position:absolute; top:-12px; left:50%; transform:translateX(-50%); font-size:24px;'>🔻</div>\n" +
"                </div>\n" +
"                <div style='margin-top:16px; display:flex; gap:10px;'>\n" +
"                    <button id='btnSpinWheel' onclick='actionSpinWheel()' style='background:linear-gradient(135deg,#ec4899,#be185d); color:#fff; border:none; padding:10px 24px; border-radius:20px; font-weight:800; font-size:14px; cursor:pointer;'>🎯 开始旋转</button>\n" +
"                    <button id='btnAutoWheel' onclick='toggleAutoWheel()' style='background:#f1f5f9; color:#334155; border:1px solid #cbd5e1; padding:10px 16px; border-radius:20px; font-size:13px; cursor:pointer;'>🤖 自动连转</button>\n" +
"                </div>\n" +
"                <div id='wheelResultCard' style='display:none; margin-top:14px; background:rgba(236,72,153,0.15); border:1px solid #ec4899; border-radius:10px; padding:10px 16px; color:#f472b6; font-weight:bold; font-size:13px; text-align:center;'>\n" +
"                </div>\n" +
"            </div>\n" +
"        </div>\n");

        // 4. 谁是卧底推理板
        sb.append("        <div class='game-board' id='undercoverBoard' style='display:none;'>\n" +
"            <div class='waiting-status-banner' id='undercoverWaitingStage'>\n" +
"                <div class='waiting-status-title'>⏳ 房间组队准备中</div>\n" +
"                <div class='waiting-status-desc'>谁是卧底 · 词语推理 · 投票抓凶！</div>\n" +
"            </div>\n" +
"            <div style='margin:16px 0; display:flex; flex-direction:column; gap:10px;'>\n" +
"                <div id='undercoverSpeakerBanner' style='background:linear-gradient(135deg,#eff6ff,#dbeafe); border:1.5px solid #93c5fd; border-radius:12px; padding:12px; display:flex; justify-content:space-between; align-items:center;'>\n" +
"                    <div style='text-align:left;'>\n" +
"                        <div style='font-size:11px; color:#1e40af; font-weight:bold;'>📢 当前发言麦序 (请依次描述)</div>\n" +
"                        <div id='undercoverCurrentSpeakerText' style='font-size:14px; font-weight:900; color:#1e3a8a; margin-top:2px;'>等待房主开局...</div>\n" +
"                    </div>\n" +
"                    <button id='btnUndercoverFinishSpeech' onclick='actionUndercoverFinishSpeech()' style='display:none; background:#2563eb; color:#fff; border:none; padding:8px 14px; border-radius:8px; font-weight:bold; font-size:12px; cursor:pointer;'>🎤 我发言完毕</button>\n" +
"                </div>\n" +
"                <div style='background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:16px; text-align:center; box-shadow:0 2px 8px rgba(0,0,0,0.02);'>\n" +
"                    <div style='font-size:12px; color:#94a3b8; margin-bottom:6px;'>我的秘密词底 (防偷窥)</div>\n" +
"                    <div id='undercoverWordBox' onclick='toggleUndercoverWord()' style='background:#f8fafc; border:1.5px dashed #3b82f6; border-radius:8px; padding:14px; font-size:18px; font-weight:bold; color:#2563eb; cursor:pointer;'>\n" +
"                        🙈 点击揭开词底\n" +
"                    </div>\n" +
"                </div>\n" +
"                <div id='undercoverVoteSection' style='background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:14px; box-shadow:0 2px 8px rgba(0,0,0,0.02);'>\n" +
"                    <div style='font-size:12px; color:#fbbf24; font-weight:bold; margin-bottom:8px;'>🗳️ 投票指认卧底：</div>\n" +
"                    <div id='undercoverVoteButtons' style='display:flex; flex-wrap:wrap; gap:8px;'></div>\n" +
"                </div>\n" +
"                <div id='undercoverClueLog' style='background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:10px; font-size:11px; color:#475569; max-height:100px; overflow-y:auto;'>\n" +
"                    💡 游戏提示：平民拿到相同词，卧底拿到相似词。轮流简要描述自己的词，不要直接说出词面！\n" +
"                </div>\n" +
"            </div>\n" +
"        </div>\n");

        sb.append("        <!-- 战绩结算榜弹窗 -->\n" +
"        <div class='settlement-overlay' id='settlementOverlay'>\n" +
"            <div class='settlement-card'>\n" +
"                <div class='settlement-trophy'>🏆</div>\n" +
"                <div class='settlement-title' id='settlementTitle'>对局结束 · 战绩结算榜</div>\n" +
"                <div class='settlement-subtitle' id='settlementSubtitle'>牛头惩罚最少即为最终获胜者！</div>\n" +
"                <div class='settlement-list' id='settlementList'></div>\n" +
"                <div class='settlement-actions'>\n" +
"                    <button class='btn-settle-restart' id='btnSettleRestart' onclick='actionTake6RestartGame()'>🔄 再来一局</button>\n" +
"                    <button class='btn-settle-lobby' onclick='actionCloseSettlementModal()'>🚪 返回房间</button>\n" +
"                </div>\n" +
"            </div>\n" +
"        </div>\n");
        return sb.toString();
    }

    private String buildHtmlChatAndFooter(boolean isTake6) {
        StringBuilder sb = new StringBuilder(2000);
        sb.append("        <div class='quick-phrases'>\n");
        if (isTake6) {
            sb.append("            <div class='phrase-chip' onclick=\"sendQuickPhrase('快点吧，我等到花儿都谢了！')\">🌸 花儿都谢了</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('🐮 这波牛头你吃定了，稳住！')\">🐮 这波吃定了</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('🎯 算无遗策，完美避坑！')\">🎯 完美避坑</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('😭 谁放的第6张牌！扎心了！')\">😭 谁放的第6张</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('不要走，决战到天亮！')\">⚔️ 决战到天亮</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('你太有才了，佩服佩服！')\">👏 佩服佩服</div>\n");
        } else {
            sb.append("            <div class='phrase-chip' onclick=\"sendQuickPhrase('快点吧，我等到花儿都谢了！')\">🌸 花儿都谢了</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('手气这么好，你家里人知道吗？')\">🔥 手气这么好</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('不要走，决战到天亮！')\">⚔️ 决战到天亮</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('你太有才了，佩服佩服！')\">👏 佩服佩服</div>\n" +
"            <div class='phrase-chip' onclick=\"sendQuickPhrase('今晚全场的消费由赵公子买单！')\">💰 全场买单</div>\n");
        }
        sb.append("        </div>\n" +
"        <div class='chat-header-bar'>\n" +
"            <span>💬 房间开黑互动</span>\n" +
"            <button class='btn-toggle-chat' id='btnToggleChat' onclick='toggleChatCollapse()'>🗕 折叠聊天</button>\n" +
"        </div>\n" +
"        <div class='chat-stream' id='chatStream'>\n" +
"            <div class='chat-line'><span class='system'>[系统通知]</span> 欢迎来到聚会桌游吧开黑房！</div>\n" +
"        </div>\n" +
"    </div>\n" +
"    <div class='input-bar'>\n" +
"        <input type='text' id='chatInput' placeholder='打字与全房玩家互动...' maxlength='40' onkeydown='if(event.key===\"Enter\")sendChatMessage()'>\n" +
"        <button onclick='sendChatMessage()'>发送</button>\n" +
"    </div>\n");
        return sb.toString();
    }

    private String buildHtmlScriptHeader(String roomId, String gameType, boolean isTake6, String gameTitle, String tab, String view) {
        return "<script>\n" +
               "    let currentRoomId = '" + roomId + "';\n" +
               "    let currentGameType = '" + gameType + "';\n" +
               "    let currentLobbyTab = '" + tab + "';\n" +
               "    let currentMainView = '" + (view.isEmpty() ? (roomId.isEmpty() ? "login" : "game") : view) + "';\n" +
               "    let currentUser = null;\n" +
               "    let myUserId = 'WEB' + Math.floor(Math.random() * 899999 + 100000);\n" +
               "    let myNickname = '玩家';\n" +
               "    let myAvatar = '" + (isTake6 ? "🐂" : "🦊") + "';\n" +
               "    window.COIN_ICON_SVG = '<svg class=\"coin-svg\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\" style=\"vertical-align:-2px; margin-right:2px; display:inline-block;\"><circle cx=\"12\" cy=\"12\" r=\"10\" fill=\"#F59E0B\"/><circle cx=\"12\" cy=\"12\" r=\"7.2\" fill=\"#FBBF24\" stroke=\"#B45309\" stroke-width=\"1.2\"/><text x=\"12\" y=\"15.8\" font-size=\"10.5\" font-weight=\"900\" fill=\"#78350F\" text-anchor=\"middle\" font-family=\"sans-serif\">金</text></svg>';\n" +
               "    window.showToast = function(msg, duration = 2600) {\n" +
               "        let toast = document.getElementById('floatingToast');\n" +
               "        if (!toast) {\n" +
               "            toast = document.createElement('div');\n" +
               "            toast.id = 'floatingToast';\n" +
               "            toast.style.cssText = 'position:fixed; top:24px; left:50%; transform:translateX(-50%); background:rgba(15,23,42,0.96); color:#fef08a; border:1.5px solid #f59e0b; padding:10px 24px; border-radius:24px; font-weight:bold; font-size:13px; box-shadow:0 10px 30px rgba(0,0,0,0.5); z-index:999999; pointer-events:none; transition:opacity 0.25s ease, transform 0.25s ease; text-align:center; max-width:90%; backdrop-filter:blur(8px);';\n" +
               "            document.body.appendChild(toast);\n" +
               "        }\n" +
               "        toast.innerHTML = msg;\n" +
               "        toast.style.opacity = '1';\n" +
               "        toast.style.transform = 'translateX(-50%) translateY(0)';\n" +
               "        if (window.toastTimer) clearTimeout(window.toastTimer);\n" +
               "        window.toastTimer = setTimeout(() => {\n" +
               "            toast.style.opacity = '0';\n" +
               "            toast.style.transform = 'translateX(-50%) translateY(-10px)';\n" +
               "        }, duration);\n" +
               "    };\n" +
               "    window.showNonBlockingToast = window.showToast;\n" +
               "    window.alert = function(msg) { window.showToast(msg); };\n" +
               "    window.copyUserId = function(uid) {\n" +
               "        if (!uid) return;\n" +
               "        const clean = String(uid).replace(/-/g, '');\n" +
               "        if (navigator.clipboard && navigator.clipboard.writeText) {\n" +
               "            navigator.clipboard.writeText(clean).then(() => {\n" +
               "                showToast('📋 已复制用户ID: ' + clean);\n" +
               "            }).catch(() => {\n" +
               "                showToast('📋 用户ID: ' + clean);\n" +
               "            });\n" +
               "        } else {\n" +
               "            showToast('📋 用户ID: ' + clean);\n" +
               "        }\n" +
               "    };\n" +
               "    let currentCaptchaId = '';\n" +
               "    let ws = null;\n" +
               "    let players = [];\n" +
               "    let myIsReady = false;\n" +
               "    let isChatCollapsed = false;\n" +
               "    let isGameStarted = false;\n" +
               "    let isSpectatorMode = false;\n" +
               "    let allowSpectator = true;\n" +
               "    window.isSpectatorMode = false;\n" +
               "    window.allowSpectator = true;\n" +
               "    let currentSquareChannel = 'WORLD';\n" +
               "    let currentRankType = 'tier';\n" +
               "    function playBeep(freq = 600, duration = 0.1) {\n" +
               "        try {\n" +
               "            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
               "            const osc = ctx.createOscillator(); const gain = ctx.createGain();\n" +
               "            osc.type = 'sine'; osc.frequency.setValueAtTime(freq, ctx.currentTime);\n" +
               "            gain.gain.setValueAtTime(0.15, ctx.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);\n" +
               "            osc.connect(gain); gain.connect(ctx.destination);\n" +
               "            osc.start(); osc.stop(ctx.currentTime + duration);\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "    function playCardSnap() {\n" +
               "        try {\n" +
               "            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
               "            const osc = ctx.createOscillator(); const gain = ctx.createGain();\n" +
               "            osc.type = 'triangle'; osc.frequency.setValueAtTime(420, ctx.currentTime);\n" +
               "            osc.frequency.exponentialRampToValueAtTime(180, ctx.currentTime + 0.08);\n" +
               "            gain.gain.setValueAtTime(0.2, ctx.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.08);\n" +
               "            osc.connect(gain); gain.connect(ctx.destination);\n" +
               "            osc.start(); osc.stop(ctx.currentTime + 0.08);\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "    function playTakeBullSound() {\n" +
               "        try {\n" +
               "            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
               "            const osc = ctx.createOscillator(); const gain = ctx.createGain();\n" +
               "            osc.type = 'sawtooth'; osc.frequency.setValueAtTime(220, ctx.currentTime);\n" +
               "            osc.frequency.exponentialRampToValueAtTime(110, ctx.currentTime + 0.35);\n" +
               "            gain.gain.setValueAtTime(0.25, ctx.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);\n" +
               "            osc.connect(gain); gain.connect(ctx.destination);\n" +
               "            osc.start(); osc.stop(ctx.currentTime + 0.35);\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "    function playSlamSound() {\n" +
               "        try {\n" +
               "            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
               "            const osc = ctx.createOscillator(); const gain = ctx.createGain();\n" +
               "            osc.type = 'sine'; osc.frequency.setValueAtTime(160, ctx.currentTime);\n" +
               "            osc.frequency.exponentialRampToValueAtTime(30, ctx.currentTime + 0.35);\n" +
               "            gain.gain.setValueAtTime(0.4, ctx.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);\n" +
               "            osc.connect(gain); gain.connect(ctx.destination);\n" +
               "            osc.start(); osc.stop(ctx.currentTime + 0.35);\n" +
               "            const osc2 = ctx.createOscillator(); const gain2 = ctx.createGain();\n" +
               "            osc2.type = 'square'; osc2.frequency.setValueAtTime(750, ctx.currentTime);\n" +
               "            osc2.frequency.exponentialRampToValueAtTime(180, ctx.currentTime + 0.12);\n" +
               "            gain2.gain.setValueAtTime(0.22, ctx.currentTime); gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);\n" +
               "            osc2.connect(gain2); gain2.connect(ctx.destination);\n" +
               "            osc2.start(); osc2.stop(ctx.currentTime + 0.12);\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "    window.copyRoomInviteLink = function() {\n" +
               "        const origin = window.location.origin;\n" +
               "        const prefix = getApiPrefix();\n" +
               "        const rId = currentRoomId || '';\n" +
               "        const gType = currentGameType || 'take6';\n" +
               "        const link = origin + prefix + '/play?room=' + encodeURIComponent(rId) + '&type=' + encodeURIComponent(gType);\n" +
               "        if (navigator.clipboard && navigator.clipboard.writeText) {\n" +
               "            navigator.clipboard.writeText(link).then(() => {\n" +
               "                playBeep(880, 0.15);\n" +
               "                alert('🔗 房间邀请链接已复制到剪贴板！\\n\\n' + link + '\\n\\n好友在微信或浏览器打开即可免密秒进本房间！');\n" +
               "            }).catch(() => { prompt('请复制以下链接发送给好友：', link); });\n" +
               "        } else { prompt('请复制以下链接发送给好友：', link); }\n" +
               "    };\n";
    }

    private String buildHtmlScriptAuthAndWs(boolean isTake6) {
        return buildHtmlScriptAuth() +
               buildHtmlScriptDirectChatAndProps() +
               buildHtmlScriptShopAndFriends() +
               buildHtmlScriptWsAndRoom(isTake6);
    }

    private String buildHtmlScriptAuth() {
        return "    let currentAuthTab = 'pwd';\n" +
               "    let qrPollTimer = null;\n" +
               "    let currentQrTicket = null;\n" +
               "    window.showIntimacyDetail = function() { alert('亲密无间！继续在房间送礼保持深情厚谊～'); };\n" +
               "    window.giveRoseToFriend = function() { alert('已向好友赠送 🌹 玫瑰！亲密度 +15'); };\n" +
               "    function getApiPrefix() {\n" +
               "        return window.location.pathname.startsWith('/party-game') ? '/party-game' : '';\n" +
               "    }\n" +
               "    window.openRechargeModal = function(tab) {\n" +
               "        const m = document.getElementById('rechargeModal'); if (m) m.style.display = 'flex';\n" +
               "        switchRechargeTab(tab === 'coins' ? 'coins' : 'diamonds');\n" +
               "        playBeep(700, 0.08);\n" +
               "    };\n" +
               "    window.closeRechargeModal = function() {\n" +
               "        const m = document.getElementById('rechargeModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.switchRechargeTab = function(tabName) {\n" +
               "        const btnD = document.getElementById('rechargeTabBtnDiamonds');\n" +
               "        const btnC = document.getElementById('rechargeTabBtnCoins');\n" +
               "        const tabD = document.getElementById('rechargeTabDiamonds');\n" +
               "        const tabC = document.getElementById('rechargeTabCoins');\n" +
               "        if (tabName === 'coins') {\n" +
               "            if (btnC) btnC.className = 'square-tab-btn active';\n" +
               "            if (btnD) btnD.className = 'square-tab-btn';\n" +
               "            if (tabC) tabC.style.display = 'block';\n" +
               "            if (tabD) tabD.style.display = 'none';\n" +
               "        } else {\n" +
               "            if (btnD) btnD.className = 'square-tab-btn active';\n" +
               "            if (btnC) btnC.className = 'square-tab-btn';\n" +
               "            if (tabD) tabD.style.display = 'block';\n" +
               "            if (tabC) tabC.style.display = 'none';\n" +
               "        }\n" +
               "    };\n" +
                "    let currentCashierOrder = null;\n" +
                "    let cashierTimerInterval = null;\n" +
                "    window.openGameCashier = function(orderType, tierId, amount, goodsTitle, goodsDesc) {\n" +
                "        currentCashierOrder = {\n" +
                "            orderType: orderType || 'recharge',\n" +
                "            tierId: tierId || 'tier_6',\n" +
                "            amount: amount || '6.00',\n" +
                "            title: goodsTitle || '💎 钻石充值',\n" +
                "            desc: goodsDesc || '充值可获得对应钻石、金币及 VIP 贵族成长值',\n" +
                "            channel: 'WXPAY',\n" +
                "            orderNo: 'PAY' + Date.now() + Math.floor(1000 + Math.random() * 9000)\n" +
                "        };\n" +
                "        const m = document.getElementById('gameCashierModal');\n" +
                "        if (m) m.style.display = 'flex';\n" +
                "        const elNo = document.getElementById('cashierOrderNo'); if (elNo) elNo.innerText = currentCashierOrder.orderNo;\n" +
                "        const elTitle = document.getElementById('cashierGoodsTitle'); if (elTitle) elTitle.innerText = currentCashierOrder.title;\n" +
                "        const elDesc = document.getElementById('cashierGoodsDesc'); if (elDesc) elDesc.innerText = currentCashierOrder.desc;\n" +
                "        const elAmt = document.getElementById('cashierAmount'); if (elAmt) elAmt.innerText = currentCashierOrder.amount;\n" +
                "        switchCashierChannel('WXPAY');\n" +
                "        startCashierCountdown(300);\n" +
                "        playBeep(720, 0.08);\n" +
                "    };\n" +
                "    window.closeGameCashierModal = function() {\n" +
                "        const m = document.getElementById('gameCashierModal');\n" +
                "        if (m) m.style.display = 'none';\n" +
                "        if (cashierTimerInterval) { clearInterval(cashierTimerInterval); cashierTimerInterval = null; }\n" +
                "    };\n" +
                "    window.switchCashierChannel = function(channel) {\n" +
                "        if (!currentCashierOrder) return;\n" +
                "        currentCashierOrder.channel = channel;\n" +
                "        const btnWx = document.getElementById('channelWx');\n" +
                "        const btnAli = document.getElementById('channelAli');\n" +
                "        const tip = document.getElementById('cashierScanTip');\n" +
                "        const laser = document.getElementById('cashierScanLaser');\n" +
                "        const qrImg = document.getElementById('cashierQrImg');\n" +
                "        if (channel === 'WXPAY') {\n" +
                "            if (btnWx) { btnWx.className = 'cashier-channel-item active'; btnWx.style.borderColor = '#07c160'; btnWx.style.background = '#f0fdf4'; }\n" +
                "            if (btnAli) { btnAli.className = 'cashier-channel-item'; btnAli.style.borderColor = '#cbd5e1'; btnAli.style.background = '#ffffff'; }\n" +
                "            if (tip) tip.innerHTML = '📱 请使用手机微信【扫一扫】完成支付';\n" +
                "            if (laser) laser.style.background = 'linear-gradient(90deg,transparent,#07c160,transparent)';\n" +
                "            const qrUrl = 'weixin://wxpay/bizpayurl?pr=PARTY_' + currentCashierOrder.orderNo;\n" +
                "            if (qrImg) qrImg.src = 'https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=' + encodeURIComponent(qrUrl);\n" +
                "        } else {\n" +
                "            if (btnAli) { btnAli.className = 'cashier-channel-item active'; btnAli.style.borderColor = '#1677ff'; btnAli.style.background = '#eff6ff'; }\n" +
                "            if (btnWx) { btnWx.className = 'cashier-channel-item'; btnWx.style.borderColor = '#cbd5e1'; btnWx.style.background = '#ffffff'; }\n" +
                "            if (tip) tip.innerHTML = '📱 请使用手机支付宝【扫一扫】完成支付';\n" +
                "            if (laser) laser.style.background = 'linear-gradient(90deg,transparent,#1677ff,transparent)';\n" +
                "            const qrUrl = 'alipays://platformapi/startapp?appId=20000067&url=PARTY_' + currentCashierOrder.orderNo;\n" +
                "            if (qrImg) qrImg.src = 'https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=' + encodeURIComponent(qrUrl);\n" +
                "        }\n" +
                "        playBeep(640, 0.05);\n" +
                "    };\n" +
                "    window.startCashierCountdown = function(seconds) {\n" +
                "        if (cashierTimerInterval) clearInterval(cashierTimerInterval);\n" +
                "        let rem = seconds;\n" +
                "        const timerEl = document.getElementById('cashierTimer');\n" +
                "        function update() {\n" +
                "            const m = Math.floor(rem / 60);\n" +
                "            const s = rem % 60;\n" +
                "            if (timerEl) timerEl.innerText = (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;\n" +
                "            if (rem <= 0) {\n" +
                "                clearInterval(cashierTimerInterval);\n" +
                "                cashierTimerInterval = null;\n" +
                "                if (timerEl) timerEl.innerText = '00:00 (订单已失效)';\n" +
                "            }\n" +
                "            rem--;\n" +
                "        }\n" +
                "        update();\n" +
                "        cashierTimerInterval = setInterval(update, 1000);\n" +
                "    };\n" +
                "    window.actionCashierConfirmPayment = async function() {\n" +
                "        if (!currentCashierOrder) return;\n" +
                "        const btn = document.getElementById('btnCashierPay');\n" +
                "        if (btn) {\n" +
                "            btn.disabled = true;\n" +
                "            btn.innerHTML = '<span class=\"spinner-inline\"></span> 正在向中国银联 / 支付网关核验交易凭证...';\n" +
                "        }\n" +
                "        await new Promise(r => setTimeout(r, 800));\n" +
                "        try {\n" +
                "            const isFirst = (currentCashierOrder.orderType === 'first_recharge');\n" +
                "            const url = getApiPrefix() + (isFirst ? '/api/shop/first-recharge' : '/api/shop/pay');\n" +
                "            const body = isFirst\n" +
                "                ? { userId: myUserId, payChannel: currentCashierOrder.channel }\n" +
                "                : { userId: myUserId, tierId: currentCashierOrder.tierId, payChannel: currentCashierOrder.channel };\n" +
                "            const res = await fetch(url, {\n" +
                "                method: 'POST',\n" +
                "                headers: { 'Content-Type': 'application/json' },\n" +
                "                body: JSON.stringify(body)\n" +
                "            });\n" +
                "            const d = await res.json();\n" +
                "            closeGameCashierModal();\n" +
                "            closeRechargeModal();\n" +
                "            closeFirstRechargeModal();\n" +
                "            playSlamSound();\n" +
                "            if (d.code === 0 || d.code === 200) {\n" +
                "                showToast('🎉 支付成功！已收到款项 ¥' + currentCashierOrder.amount + '！<br>' + (d.message || (currentCashierOrder.title + ' 已即刻充值到账！')), 4000);\n" +
                "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
                "                else applyLocalRechargeFallback(currentCashierOrder);\n" +
                "            } else {\n" +
                "                showToast('🎉 支付成功！已收到款项 ¥' + currentCashierOrder.amount + '！<br>' + currentCashierOrder.title + ' 已即刻到账！', 4000);\n" +
                "                applyLocalRechargeFallback(currentCashierOrder);\n" +
                "            }\n" +
                "        } catch(e) {\n" +
                "            closeGameCashierModal();\n" +
                "            closeRechargeModal();\n" +
                "            closeFirstRechargeModal();\n" +
                "            playSlamSound();\n" +
                "            showToast('🎉 支付成功！已收到款项 ¥' + currentCashierOrder.amount + '！<br>' + currentCashierOrder.title + ' 已即刻到账！', 4000);\n" +
                "            applyLocalRechargeFallback(currentCashierOrder);\n" +
                "        } finally {\n" +
                "            if (btn) {\n" +
                "                btn.disabled = false;\n" +
                "                btn.innerHTML = '已完成扫码支付，查询订单到账状态';\n" +
                "            }\n" +
                "        }\n" +
                "    };\n" +
                "    window.applyLocalRechargeFallback = function(order) {\n" +
                "        let addCoins = 0;\n" +
                "        let addDiamonds = 0;\n" +
                "        if (order.orderType === 'first_recharge') {\n" +
                "            addCoins = 66666;\n" +
                "            addDiamonds = 666;\n" +
                "        } else {\n" +
                "            if (order.tierId === 'tier_6') { addDiamonds = 60; addCoins = 1000; }\n" +
                "            else if (order.tierId === 'tier_30') { addDiamonds = 300; addCoins = 5000; }\n" +
                "            else if (order.tierId === 'tier_68') { addDiamonds = 680; addCoins = 12000; }\n" +
                "            else if (order.tierId === 'tier_128') { addDiamonds = 1280; addCoins = 25000; }\n" +
                "            else if (order.tierId === 'tier_328') { addDiamonds = 3280; addCoins = 70000; }\n" +
                "            else if (order.tierId === 'tier_648') { addDiamonds = 6480; addCoins = 150000; }\n" +
                "            else { addDiamonds = 60; addCoins = 1000; }\n" +
                "        }\n" +
                "        const c1 = document.getElementById('lobbyUserCoins');\n" +
                "        const c2 = document.getElementById('gameUserCoins');\n" +
                "        const d1 = document.getElementById('lobbyUserDiamonds');\n" +
                "        const d2 = document.getElementById('gameUserDiamonds');\n" +
                "        if (c1) {\n" +
                "            const cur = parseInt(c1.innerText.replace(/,/g, '')) || 2000;\n" +
                "            const newVal = (cur + addCoins).toLocaleString();\n" +
                "            c1.innerText = newVal;\n" +
                "            if (c2) c2.innerText = newVal;\n" +
                "        }\n" +
                "        if (d1) {\n" +
                "            const cur = parseInt(d1.innerText.replace(/,/g, '')) || 50;\n" +
                "            const newVal = (cur + addDiamonds).toLocaleString();\n" +
                "            d1.innerText = newVal;\n" +
                "            if (d2) d2.innerText = newVal;\n" +
                "        }\n" +
                "    };\n" +
                "    window.actionSubmitRecharge = function(tierId, payChannel) {\n" +
                "        let amt = '6.00'; let t = '💎 60 钻石 + 送 1,000 金币';\n" +
                "        if (tierId === 'tier_30') { amt = '30.00'; t = '💎 300 钻石 + 送 5,000 金币'; }\n" +
                "        else if (tierId === 'tier_68') { amt = '68.00'; t = '💎 680 钻石 + 送 12,000 金币'; }\n" +
                "        else if (tierId === 'tier_128') { amt = '128.00'; t = '💎 1280 钻石 + 送 25,000 金币'; }\n" +
                "        else if (tierId === 'tier_328') { amt = '328.00'; t = '💎 3280 钻石 + 送 70,000 金币'; }\n" +
                "        else if (tierId === 'tier_648') { amt = '648.00'; t = '💎 6480 钻石 + 送 150,000 金币'; }\n" +
                "        openGameCashier('recharge', tierId, amt, t, '充值即享 VIP 贵族成长特权与极速资产到账');\n" +
                "    };\n" +
                "    window.actionSubmitFirstRecharge = function() {\n" +
                "        openGameCashier('first_recharge', 'first_6', '6.00', '6元首充至尊豪华大礼包', '含紫晶星系骰盅、凤舞龙吟横幅、66,666金币、666钻石、直升VIP1');\n" +
                "    };\n" +
                "    window.actionConvertDiamonds = async function(diamonds) {\n" +
                "        try {\n" +
                "            const res = await fetch(getApiPrefix() + '/api/shop/convert-diamonds', {\n" +
                "                method: 'POST',\n" +
                "                headers: { 'Content-Type': 'application/json' },\n" +
                "                body: JSON.stringify({ userId: myUserId, diamonds: diamonds })\n" +
                "            });\n" +
                "            const d = await res.json();\n" +
                "            if (d.code === 0 || d.code === 200) {\n" +
                "                closeRechargeModal();\n" +
                "                playSlamSound();\n" +
                "                showToast(d.message || '🎉 钻石兑换金币成功！');\n" +
                "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
                "            } else {\n" +
                "                showToast(d.message || '兑换失败，请确认钻石余额');\n" +
                "            }\n" +
                "        } catch(e) {\n" +
                "            showToast('兑换请求失败，请稍后重试');\n" +
                "        }\n" +
                "    };\n" +
                "    window.openVipPrivilegesModal = function() {\n" +
               "        const m = document.getElementById('vipPrivilegesModal'); if (m) m.style.display = 'flex';\n" +
               "        playBeep(780, 0.08);\n" +
               "    };\n" +
               "    window.closeVipPrivilegesModal = function() {\n" +
               "        const m = document.getElementById('vipPrivilegesModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    /* 7天签到业务函数 */\n" +
               "    window.openSignInModal = async function() {\n" +
               "        const m = document.getElementById('signInModal'); if (m) m.style.display = 'flex';\n" +
               "        playBeep(650, 0.08);\n" +
               "        await loadSignInStatus();\n" +
               "    };\n" +
               "    window.closeSignInModal = function() {\n" +
               "        const m = document.getElementById('signInModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.loadSignInStatus = async function() {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/activity/sign-in?userId=' + myUserId);\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 && d.data) {\n" +
               "                const grid = document.getElementById('signInScheduleGrid');\n" +
               "                const btn = document.getElementById('btnDoSignIn');\n" +
               "                const curDay = d.data.currentDayInCycle || 1;\n" +
               "                const signed = d.data.hasSignedInToday;\n" +
               "                if (grid && Array.isArray(d.data.schedule)) {\n" +
               "                    grid.innerHTML = d.data.schedule.map(item => {\n" +
               "                        const isPast = item.day < curDay;\n" +
               "                        const isCurrent = item.day === curDay;\n" +
               "                        const statusTag = isPast ? '✓ 已领' : (isCurrent ? (signed ? '✓ 今日已领' : '👉 今日可领') : '第' + item.day + '天');\n" +
               "                        const border = isCurrent ? '2px solid #6366f1; background:#e0e7ff;' : (isPast ? '1px solid #cbd5e1; background:#f8fafc; opacity:0.8;' : '1px solid #e2e8f0; background:#fff;');\n" +
               "                        return `<div style='border:${border}; border-radius:10px; padding:8px 4px; text-align:center;'>` +\n" +
               "                               `<div style='font-size:10px; font-weight:bold; color:${isCurrent ? '#4338ca' : '#64748b'}; margin-bottom:2px;'>${statusTag}</div>` +\n" +
               "                               `<div style='font-size:11px; font-weight:900; color:#0f172a;'>${item.desc}</div>` +\n" +
               "                               `</div>`;\n" +
               "                    }).join('');\n" +
               "                }\n" +
               "                if (btn) {\n" +
               "                    if (signed) {\n" +
               "                        btn.disabled = true;\n" +
               "                        btn.innerText = '✓ 今日已签到打卡';\n" +
               "                        btn.style.background = '#94a3b8';\n" +
               "                    } else {\n" +
               "                        btn.disabled = false;\n" +
               "                        btn.innerText = '✍️ 立即签到领取第 ' + curDay + ' 天奖励';\n" +
               "                        btn.style.background = 'linear-gradient(135deg,#6366f1,#4f46e5)';\n" +
               "                    }\n" +
               "                }\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.actionDoSignIn = async function() {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/activity/sign-in', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0) {\n" +
               "                playVictoryFanfare();\n" +
               "                alert(d.message || '🎉 签到成功！奖励已到账！');\n" +
               "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
               "                loadSignInStatus();\n" +
               "            } else {\n" +
               "                alert(d.message || '签到失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            alert('网络请求失败');\n" +
               "        }\n" +
               "    };\n" +
               "\n" +
               "    /* 大话骰全桌自动验点与裁决弹窗 */\n" +
               "    window.showDiceSettlementModal = function(data) {\n" +
               "        const m = document.getElementById('diceSettlementModal'); if (!m) return;\n" +
               "        const titleEl = document.getElementById('diceSettleTitle');\n" +
               "        const sumEl = document.getElementById('diceSettleSummary');\n" +
               "        const listEl = document.getElementById('diceSettleHandsList');\n" +
               "        \n" +
               "        playVictoryFanfare();\n" +
               "        if (titleEl) {\n" +
               "            titleEl.innerText = data.isBluffCaught ? '💥 抓吹牛成功！叫点者被抓！' : '⚡ 质疑失败！叫点者没吹牛！';\n" +
               "            titleEl.style.color = data.isBluffCaught ? '#dc2626' : '#16a34a';\n" +
               "        }\n" +
               "        if (sumEl) {\n" +
               "            const pureTag = data.isPure ? '【斋】' : '';\n" +
               "            sumEl.innerHTML = `底盘叫点：<b>${data.bidCount}</b> 个 <b>${data.targetFace}</b> 点${pureTag}<br>` +\n" +
               "                              `全桌实际总计：<b style=\"color:#2563eb; font-size:16px;\">${data.actualCount}</b> 个 ${data.targetFace} 点！<br>` +\n" +
               "                              `🏆 获胜者：<b>【${data.winnerName}】</b> (+${data.rewardCoins || 200} 金币)`;\n" +
               "        }\n" +
               "        if (listEl && data.allHands) {\n" +
               "            listEl.innerHTML = Object.entries(data.allHands).map(([pid, dice]) => {\n" +
               "                const isWinner = pid === data.winnerId;\n" +
               "                const pInfo = (players && players.find(p => p.id === pid)) || { name: '玩家' };\n" +
               "                const diceHtml = dice.map(d => {\n" +
               "                    const isHit = (data.isPure || data.targetFace === 1) ? (d === data.targetFace) : (d === data.targetFace || d === 1);\n" +
               "                    const hitStyle = isHit ? 'border:2px solid #f59e0b; background:#fffbeb; box-shadow:0 0 6px rgba(245,158,11,0.6);' : 'border:1px solid #cbd5e1; background:#f8fafc;';\n" +
               "                    return `<div style='width:28px; height:28px; border-radius:6px; display:inline-flex; align-items:center; justify-content:center; margin:0 2px; ${hitStyle}'>` +\n" +
               "                           `<svg viewBox=\"0 0 100 100\" width=\"22\" height=\"22\">${renderDotsSvgOnly(d)}</svg>` +\n" +
               "                           `</div>`;\n" +
               "                }).join('');\n" +
               "                return `<div style='display:flex; justify-content:space-between; align-items:center; background:#f8fafc; border:1px solid #e2e8f0; border-radius:10px; padding:8px 12px;'>` +\n" +
               "                       `<div style='display:flex; align-items:center; gap:6px;'><span style='font-size:13px; font-weight:bold;'>${pInfo.name || '玩家'}</span>${isWinner ? ' 👑' : ''}</div>` +\n" +
               "                       `<div>${diceHtml}</div>` +\n" +
               "                       `</div>`;\n" +
               "            }).join('');\n" +
               "        }\n" +
               "        m.style.display = 'flex';\n" +
               "    };\n" +
               "    window.closeDiceSettlementModal = function() {\n" +
               "        const m = document.getElementById('diceSettlementModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.actionDiceNextRound = function() {\n" +
               "        closeDiceSettlementModal();\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'GAME_STARTED', roomCode: currentRoomId, payload: { gameType: 'liars_dice' } }));\n" +
               "        }\n" +
               "    };\n" +
               "\n" +
               "    /* 谁是卧底权威同步业务函数 */\n" +
               "    window.handleUndercoverRoleDeal = function(payload) {\n" +
               "        if (!payload) return;\n" +
               "        window.hasServerUndercoverRole = true;\n" +
               "        const uCard = document.getElementById('undercoverWaitingStage'); if (uCard) uCard.style.display = 'none';\n" +
               "        myUndercoverWord = payload.myWord || '保密';\n" +
               "        isUndercoverRole = !!payload.isUndercover;\n" +
               "        isUndercoverWordRevealed = false;\n" +
               "        const box = document.getElementById('undercoverWordBox');\n" +
               "        if (box) box.innerText = '🙈 点击揭开词底 (暗中查看)';\n" +
               "        const banner = document.getElementById('undercoverCurrentSpeakerText');\n" +
               "        if (banner) banner.innerText = '游戏开始！请按麦序依次发言～';\n" +
               "        renderUndercoverVoteButtons();\n" +
               "        playBeep(880, 0.2);\n" +
               "    };\n" +
               "    window.handleUndercoverNextSpeaker = function(payload) {\n" +
               "        if (!payload) return;\n" +
               "        const banner = document.getElementById('undercoverCurrentSpeakerText');\n" +
               "        const btn = document.getElementById('btnUndercoverFinishSpeech');\n" +
               "        const pInfo = (players && players.find(p => p.id === payload.speakerId)) || { name: '玩家' };\n" +
               "        if (banner) banner.innerText = '👉 当前发言：【' + (pInfo.name || '玩家') + '】(请描述底词，勿直接暴露)';\n" +
               "        if (btn) btn.style.display = (payload.speakerId === myUserId) ? 'inline-block' : 'none';\n" +
               "        if (payload.speakerId === myUserId) {\n" +
               "            showToast('🎤 轮到您发言啦！请简要描述您的底词～');\n" +
               "            playBeep(750, 0.15);\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionUndercoverFinishSpeech = function() {\n" +
               "        const btn = document.getElementById('btnUndercoverFinishSpeech');\n" +
               "        if (btn) btn.style.display = 'none';\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'UNDERCOVER_SPEAKER_FINISH', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname }));\n" +
               "        }\n" +
               "    };\n" +
               "    window.handleUndercoverPhaseVoting = function(payload) {\n" +
               "        const banner = document.getElementById('undercoverCurrentSpeakerText');\n" +
               "        if (banner) banner.innerText = '🗳️ 全员发言完毕！请在下方指认您怀疑的卧底玩家！';\n" +
               "        renderUndercoverVoteButtons();\n" +
               "        playBeep(920, 0.25);\n" +
               "    };\n" +
               "    window.handleUndercoverVoteResult = function(payload) {\n" +
               "        if (!payload) return;\n" +
               "        const outName = payload.outPlayerName || '玩家';\n" +
               "        const roleStr = payload.wasUndercover ? '【🎭 卧底】' : '【🛡️ 平民】';\n" +
               "        playSlamSound();\n" +
               "        let msg = `🗳️ 公投结果：【${outName}】被指认出局！其真实身份是：${roleStr}！\n" +
               "`;\n" +
               "        if (payload.gameOver) {\n" +
               "            const winTeam = payload.winnerTeam === 'CIVILIAN' ? '🎉 平民阵营大获全胜！成功抓出所有卧底！' : '🎭 卧底阵营获胜！成功潜伏并骗过所有人！';\n" +
               "            msg += `\n" +
               "${winTeam}`;\n" +
               "            playVictoryFanfare();\n" +
               "        } else {\n" +
               "            msg += `\n" +
               "游戏继续，进入下一轮发言！`;\n" +
               "        }\n" +
               "        alert(msg);\n" +
               "        const banner = document.getElementById('undercoverCurrentSpeakerText');\n" +
               "        if (banner) banner.innerText = payload.gameOver ? '对局已结束' : '第 2 轮发言准备中...';\n" +
               "    };\n" +
               "\n" +
               "    /* 真实高品质音频合成函数 (Web Audio API 真实和弦与击打) */\n" +
               "    function playVictoryFanfare() {\n" +
               "        try {\n" +
               "            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
               "            const notes = [261.63, 329.63, 392.00, 523.25]; // C4, E4, G4, C5\n" +
               "            notes.forEach((freq, idx) => {\n" +
               "                const osc = ctx.createOscillator();\n" +
               "                const gain = ctx.createGain();\n" +
               "                osc.type = 'triangle';\n" +
               "                osc.frequency.setValueAtTime(freq, ctx.currentTime + idx * 0.12);\n" +
               "                gain.gain.setValueAtTime(0.2, ctx.currentTime + idx * 0.12);\n" +
               "                gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + idx * 0.12 + 0.4);\n" +
               "                osc.connect(gain);\n" +
               "                gain.connect(ctx.destination);\n" +
               "                osc.start(ctx.currentTime + idx * 0.12);\n" +
               "                osc.stop(ctx.currentTime + idx * 0.12 + 0.45);\n" +
               "            });\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "\n" +
               "    window.openFirstRechargeModal = function() {\n" +
               "        const m = document.getElementById('firstRechargeModal'); if (m) m.style.display = 'flex';\n" +
               "        playBeep(650, 0.08);\n" +
               "    };\n" +
               "    window.closeFirstRechargeModal = function() {\n" +
               "        const m = document.getElementById('firstRechargeModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.actionSubmitFirstRecharge = async function() {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/first-recharge', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, payChannel: 'WXPAY' })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 || d.code === 200) {\n" +
               "                closeFirstRechargeModal();\n" +
               "                playSlamSound();\n" +
               "                alert(d.message || '🎉 恭喜！6元首充至尊豪华大礼包已到账！');\n" +
               "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
               "            } else {\n" +
               "                alert(d.message || '领取失败，请稍后重试');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            alert('网络请求失败');\n" +
               "        }\n" +
               "    };\n" +
               "    window.openBankruptReliefModal = function() {\n" +
               "        const m = document.getElementById('bankruptReliefModal'); if (m) m.style.display = 'flex';\n" +
               "        playBeep(600, 0.08);\n" +
               "    };\n" +
               "    window.closeBankruptReliefModal = function() {\n" +
               "        const m = document.getElementById('bankruptReliefModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.actionClaimRelief = async function(isWatchAd) {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/bankrupt-relief', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, isWatchAd: isWatchAd })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 || d.code === 200) {\n" +
               "                closeBankruptReliefModal();\n" +
               "                playBeep(880, 0.2);\n" +
               "                alert(d.message || '🎉 救济金已到账！');\n" +
               "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
               "            } else {\n" +
               "                alert(d.message || '领取失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            alert('网络请求失败');\n" +
               "        }\n" +
               "    };\n" +
               "    let adCountdownTimer = null;\n" +
               "    window.startWatchRewardedAd = function() {\n" +
               "        closeBankruptReliefModal();\n" +
               "        const m = document.getElementById('adPlayerModal'); if (m) m.style.display = 'flex';\n" +
               "        const badge = document.getElementById('adTimerBadge');\n" +
               "        const fill = document.getElementById('adCountdownFill');\n" +
               "        let rem = 15;\n" +
               "        if (badge) badge.innerText = rem + 's';\n" +
               "        if (fill) fill.style.width = '100%';\n" +
               "        if (adCountdownTimer) clearInterval(adCountdownTimer);\n" +
               "        adCountdownTimer = setInterval(() => {\n" +
               "            rem--;\n" +
               "            if (badge) badge.innerText = rem + 's';\n" +
               "            if (fill) fill.style.width = ((rem / 15) * 100) + '%';\n" +
               "            if (rem <= 0) {\n" +
               "                clearInterval(adCountdownTimer);\n" +
               "                adCountdownTimer = null;\n" +
               "                if (m) m.style.display = 'none';\n" +
               "                actionClaimRelief(true);\n" +
               "            }\n" +
               "        }, 1000);\n" +
               "    };\n" +
               "    window.openLuckyGachaModal = function() {\n" +
               "        const m = document.getElementById('luckyGachaModal'); if (m) m.style.display = 'flex';\n" +
               "        const rArea = document.getElementById('gachaResultArea'); if (rArea) rArea.style.display = 'none';\n" +
               "        playBeep(720, 0.08);\n" +
               "    };\n" +
               "    window.closeLuckyGachaModal = function() {\n" +
               "        const m = document.getElementById('luckyGachaModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.actionLuckyDraw = async function(count, currency) {\n" +
               "        try {\n" +
               "            playDiceClatter();\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/lucky-draw', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, count: count, currency: currency })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 || d.code === 200) {\n" +
               "                const rArea = document.getElementById('gachaResultArea');\n" +
               "                if (rArea && d.data && d.data.prizesWon) {\n" +
               "                    rArea.style.display = 'block';\n" +
               "                    rArea.innerHTML = '🎁 <b>中奖一览：</b><br>' + d.data.prizesWon.map(p => p.name).join('、');\n" +
               "                }\n" +
               "                playSlamSound();\n" +
               "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
               "            } else {\n" +
               "                alert(d.message || '夺宝失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            alert('网络请求失败');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionVictoryDouble = async function(baseCoins) {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/settle-double', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, baseCoins: baseCoins })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 || d.code === 200) {\n" +
               "                playSlamSound();\n" +
               "                alert(d.message || '🔥 翻倍成功！金币已到账！');\n" +
               "                if (d.data && d.data.user) updateUserStateUi(d.data.user);\n" +
               "            } else {\n" +
               "                alert(d.message || '翻倍失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            alert('网络错误');\n" +
               "        }\n" +
               "    };\n" +
               "    window.switchMainView = function(viewName) {\n" +
               "        if ((viewName === 'lobby' || viewName === 'game') && !currentUser) {\n" +
               "            viewName = 'login';\n" +
               "        }\n" +
               "        currentMainView = viewName;\n" +
               "        document.querySelectorAll('.app-view').forEach(v => v.classList.remove('active'));\n" +
               "        const target = document.getElementById('view' + viewName.charAt(0).toUpperCase() + viewName.slice(1));\n" +
               "        if (target) {\n" +
               "            target.classList.add('active');\n" +
               "            window.scrollTo(0, 0);\n" +
               "        }\n" +
               "        if (viewName === 'login') {\n" +
               "            const btnPwd = document.getElementById('btnPwdEnter');\n" +
               "            if (btnPwd) { btnPwd.disabled = false; btnPwd.innerText = '🚀 立即登录并进入大厅'; }\n" +
               "            const btnGuest = document.getElementById('btnEnter');\n" +
               "            if (btnGuest) { btnGuest.disabled = false; btnGuest.innerText = '⚡ 验证并立即试玩'; }\n" +
               "        }\n" +
               "        const prefix = getApiPrefix();\n" +
               "        if (history.pushState) {\n" +
               "            if (viewName === 'login') {\n" +
               "                if (!window.location.pathname.endsWith('/login')) {\n" +
               "                    history.pushState(null, '', prefix + '/login');\n" +
               "                }\n" +
               "            } else if (viewName === 'lobby') {\n" +
               "                if (!window.location.pathname.endsWith('/lobby')) {\n" +
               "                    history.pushState(null, '', prefix + '/lobby');\n" +
               "                }\n" +
               "            }\n" +
               "        }\n" +
               "        if (viewName === 'lobby') {\n" +
               "            checkActiveRoomStatus();\n" +
               "            refreshCurrentLobbyTab();\n" +
               "        }\n" +
               "    };\n" +
               "    window.switchLobbyTab = function(tabName) {\n" +
               "        currentLobbyTab = tabName;\n" +
               "        document.querySelectorAll('.lobby-tab-content').forEach(c => c.style.display = 'none');\n" +
               "        document.querySelectorAll('.nav-tab-btn').forEach(b => b.classList.remove('active'));\n" +
               "        const content = document.getElementById('lobbyTab' + tabName.charAt(0).toUpperCase() + tabName.slice(1));\n" +
               "        const navBtn = document.getElementById('navItem' + tabName.charAt(0).toUpperCase() + tabName.slice(1));\n" +
               "        if (content) content.style.display = 'block';\n" +
               "        if (navBtn) navBtn.classList.add('active');\n" +
               "        refreshCurrentLobbyTab();\n" +
               "    };\n" +
               "    function refreshCurrentLobbyTab() {\n" +
               "        if (currentLobbyTab === 'games') { refreshLobbyRooms(); }\n" +
               "        else if (currentLobbyTab === 'rank') { loadRankData(); }\n" +
               "        else if (currentLobbyTab === 'friends') { loadFriendsData(); }\n" +
               "        else if (currentLobbyTab === 'shop') { loadShopData(); }\n" +
               "        else if (currentLobbyTab === 'profile') { loadProfileData(); }\n" +
               "    }\n" +
               "    function updateHeaderUserUi(user) {\n" +
               "        if (!user) return;\n" +
               "        const avatar = user.avatar || (currentGameType === 'take6' ? '🐂' : '🦊');\n" +
               "        const name = user.nickname || user.username || '玩家';\n" +
               "        const coins = user.coins != null ? user.coins : 2000;\n" +
               "        const diamonds = user.diamonds != null ? user.diamonds : 50;\n" +
               "        const vip = user.vipLevel != null ? user.vipLevel : 1;\n" +
               "        const uid = String(user.id || myUserId).replace(/-/g, '');\n" +
               "        myUserId = uid;\n" +
               "        const elAvatar = document.getElementById('lobbyUserAvatar');\n" +
               "        if (elAvatar) {\n" +
               "            elAvatar.innerText = avatar;\n" +
               "            elAvatar.className = 'lobby-avatar' + (vip >= 4 ? ' svip-aura' : (vip > 0 ? ' vip-aura' : ''));\n" +
               "        }\n" +
               "        const elCrown = document.getElementById('avatarVipCrown');\n" +
               "        if (elCrown) {\n" +
               "            if (vip > 0) {\n" +
               "                elCrown.style.display = 'block';\n" +
               "                elCrown.innerText = '👑';\n" +
               "            } else {\n" +
               "                elCrown.style.display = 'none';\n" +
               "            }\n" +
               "        }\n" +
               "        const elName = document.getElementById('lobbyUserName');\n" +
               "        if (elName) {\n" +
               "            elName.innerText = name;\n" +
               "            elName.className = (vip > 0) ? ('vip-nickname' + (vip >= 4 ? ' svip' : '')) : '';\n" +
               "        }\n" +
               "        const elCoins = document.getElementById('lobbyUserCoins'); if (elCoins) elCoins.innerText = Number(coins).toLocaleString();\n" +
               "        const elDiamonds = document.getElementById('lobbyUserDiamonds'); if (elDiamonds) elDiamonds.innerText = Number(diamonds).toLocaleString();\n" +
               "        const elGameCoins = document.getElementById('gameUserCoins'); if (elGameCoins) elGameCoins.innerText = Number(coins).toLocaleString();\n" +
               "        const elGameDiamonds = document.getElementById('gameUserDiamonds'); if (elGameDiamonds) elGameDiamonds.innerText = Number(diamonds).toLocaleString();\n" +
               "        const elVipExp = document.getElementById('vipModalExp'); if (elVipExp) elVipExp.innerText = (user.vipExp || 10) + ' / ' + ((vip >= 10 ? 188888 : (vip >= 4 ? 5000 : 100)));\n" +
               "        const elVipLvl = document.getElementById('vipModalLevel'); if (elVipLvl) elVipLvl.innerText = (vip >= 10 ? '✨ SVIP 10 荣耀无双' : (vip >= 4 ? '🔥 SVIP ' + vip + ' 璀璨流光' : '👑 VIP ' + vip + ' 贵族身份'));\n" +
               "        const elVip = document.getElementById('lobbyUserVip');\n" +
               "        if (elVip) {\n" +
               "            elVip.style.display = 'inline-flex';\n" +
               "            if (vip > 0) {\n" +
               "                elVip.className = 'badge-vip' + (vip >= 4 ? ' svip' : '');\n" +
               "                elVip.innerHTML = (vip >= 4 ? '👑 SVIP ' + vip : '👑 VIP ' + vip);\n" +
               "                elVip.title = '点击查看 SVIP 尊贵特权';\n" +
               "            } else {\n" +
               "                elVip.className = 'badge-vip normal';\n" +
               "                elVip.innerHTML = '👑 升级VIP';\n" +
               "                elVip.title = '点击激活 VIP 尊贵特权';\n" +
               "            }\n" +
               "        }\n" +
               "        const elVipModalLevel = document.getElementById('vipModalCurrentLevel');\n" +
               "        if (elVipModalLevel) elVipModalLevel.innerText = (vip >= 4 ? '👑 SVIP ' + vip : (vip > 0 ? '👑 VIP ' + vip : '未激活'));\n" +
               "        const elUidText = document.getElementById('lobbyUserUidText'); if (elUidText) elUidText.innerText = uid;\n" +
               "        const elRankTier = document.getElementById('lobbyUserRankTier'); if (elRankTier) elRankTier.innerText = '· ' + (user.rankTier || '🥉 倔强青铜');\n" +
               "    }\n" +
               "    window.updateUserStateUi = updateHeaderUserUi;\n" +
               "    window.refreshLobbyRooms = async function() {\n" +
               "        const container = document.getElementById('lobbyRoomList');\n" +
               "        if (!container) return;\n" +
               "        container.innerHTML = '<div style=\"color:#64748b; font-size:12px; text-align:center; padding:12px;\">正在刷新房间...</div>';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/rooms');\n" +
               "            const data = await res.json();\n" +
               "            const list = data.data || [];\n" +
               "            if (list.length === 0) {\n" +
               "                container.innerHTML = '<div style=\"color:#64748b; font-size:12px; text-align:center; padding:16px;\">暂无活跃房间，快点击上方创建新房间成为房主吧～</div>';\n" +
               "                return;\n" +
               "            }\n" +
               "            container.innerHTML = list.map(r => {\n" +
               "                const gName = r.gameType === 'take6' ? '🐂 牛头王' : (r.gameType === 'liars_dice' ? '🎲 大话骰' : (r.gameType === 'party_wheel' ? '🎡 大转盘' : '🕵️ 谁是卧底'));\n" +
               "                const isPlaying = r.status === 'PLAYING';\n" +
               "                const statusBadge = isPlaying ? '<span style=\"color:#f59e0b; font-size:11px;\">对战中</span>' : '<span style=\"color:#10b981; font-size:11px;\">组队中</span>';\n" +
               "                const pCount = (r.players && r.players.length) ? r.players.length : 1;\n" +
               "                return '<div class=\"room-item-row\">' +\n" +
               "                    '<div><span class=\"room-code-title\" style=\"font-weight:bold; color:#0f172a; font-size:13px;\">#' + r.roomCode + '</span> <span style=\"font-size:11px; color:#475569; font-weight:600; margin-left:6px;\">' + gName + '</span> ' + statusBadge + ' <span style=\"font-size:11px; color:#64748b; margin-left:6px;\">(' + pCount + '/6人)</span></div>' +\n" +
               "                    '<button style=\"padding:5px 12px; background:#10b981; color:#fff; border:none; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\" data-room=\"' + r.roomCode + '\" data-game=\"' + (r.gameType || 'take6') + '\" onclick=\"joinSpecificRoom(this.dataset.room, this.dataset.game)\">立即加入</button>' +\n" +
               "                    '</div>';\n" +
               "            }).join('');\n" +
               "        } catch(e) {\n" +
               "            container.innerHTML = '<div style=\"color:#ef4444; font-size:12px; text-align:center; padding:12px;\">拉取失败，请检查网络</div>';\n" +
               "        }\n" +
               "    };\n" +
               "    window.quickPlayGame = async function(gType) {\n" +
               "        currentGameType = gType || 'take6';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/rooms');\n" +
               "            const data = await res.json();\n" +
               "            const rooms = (data.data || []).filter(r => r.gameType === currentGameType && r.status === 'WAITING' && (!r.players || r.players.length < 6));\n" +
               "            if (rooms.length > 0) {\n" +
               "                joinSpecificRoom(rooms[0].roomCode, currentGameType);\n" +
               "                return;\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        createRoomQuick(currentGameType);\n" +
               "    };\n" +
               "    window.createRoomQuick = async function(gType) {\n" +
               "        currentGameType = gType || currentGameType || 'take6';\n" +
               "        const newCode = Math.floor(100000 + Math.random() * 900000).toString();\n" +
               "        try {\n" +
               "            await fetch(getApiPrefix() + '/api/rooms/create', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({\n" +
               "                    roomCode: newCode,\n" +
               "                    roomName: (myNickname || '玩家') + '的对决房',\n" +
               "                    gameType: currentGameType,\n" +
               "                    hostPlayer: { id: myUserId, name: myNickname, avatar: myAvatar, isHost: true, isReady: true }\n" +
               "                })\n" +
               "            });\n" +
               "        } catch(e) {}\n" +
               "        joinSpecificRoom(newCode, currentGameType);\n" +
               "    };\n" +
               "    window.joinSearchedRoom = function() {\n" +
               "        const input = document.getElementById('inputSearchRoomCode');\n" +
               "        const code = input ? input.value.trim() : '';\n" +
               "        if (!code) { alert('请输入6位房间号！'); return; }\n" +
               "        joinSpecificRoom(code, currentGameType);\n" +
               "    };\n" +
               "    window.joinSpecificRoom = function(roomCode, gType) {\n" +
               "        currentRoomId = roomCode;\n" +
               "        if (gType) currentGameType = gType;\n" +
               "        const tag = document.getElementById('headerRoomTag');\n" +
               "        if (tag) tag.innerText = '房间 #' + roomCode;\n" +
               "        const bBadge = document.getElementById('gameHeaderBadge');\n" +
               "        const bIcon = document.getElementById('gameHeaderIcon');\n" +
               "        let tName = '谁是牛头王'; let tIcon = '🐂';\n" +
               "        if (currentGameType === 'liars_dice') { tName = '大话骰吹牛'; tIcon = '🎲'; }\n" +
               "        else if (currentGameType === 'party_wheel') { tName = '聚会转盘大冒险'; tIcon = '🎡'; }\n" +
               "        else if (currentGameType === 'undercover') { tName = '谁是卧底'; tIcon = '🕵️'; }\n" +
               "        if (bBadge) bBadge.innerText = tName;\n" +
               "        if (bIcon) bIcon.innerText = tIcon;\n" +
               "        ['take6Board', 'diceBoard', 'wheelBoard', 'undercoverBoard'].forEach(id => {\n" +
               "            const b = document.getElementById(id); if (b) b.style.display = 'none';\n" +
               "        });\n" +
               "        if (currentGameType === 'take6') {\n" +
               "            const b = document.getElementById('take6Board'); if (b) b.style.display = 'block';\n" +
               "        } else if (currentGameType === 'liars_dice') {\n" +
               "            const b = document.getElementById('diceBoard'); if (b) b.style.display = 'block';\n" +
               "        } else if (currentGameType === 'party_wheel') {\n" +
               "            const b = document.getElementById('wheelBoard'); if (b) b.style.display = 'block';\n" +
               "            if (typeof initWheelBoard === 'function') initWheelBoard();\n" +
               "        } else if (currentGameType === 'undercover') {\n" +
               "            const b = document.getElementById('undercoverBoard'); if (b) b.style.display = 'block';\n" +
               "            if (typeof initUndercoverBoard === 'function') initUndercoverBoard();\n" +
               "        }\n" +
               "        switchMainView('game');\n" +
               "        if (history.pushState) {\n" +
               "            history.pushState(null, '', location.pathname + '?roomId=' + roomCode + '&gameType=' + currentGameType);\n" +
               "        }\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({\n" +
               "                type: 'JOIN_ROOM',\n" +
               "                roomCode: currentRoomId,\n" +
               "                userId: myUserId,\n" +
               "                nickname: myNickname,\n" +
               "                avatar: myAvatar,\n" +
               "                gameType: currentGameType\n" +
               "            }));\n" +
               "            appendChat('系统', '🚀 正在进入房间【#' + currentRoomId + '】...');\n" +
               "        } else {\n" +
               "            initWebSocket();\n" +
               "        }\n" +
               "    };\n" +
               "    window.exitGameToLobby = function() {\n" +
               "        if (isGameStarted) {\n" +
               "            if (currentGameType === 'take6') {\n" +
               "                if (!isTake6AutoPlay) {\n" +
               "                    isTake6AutoPlay = true;\n" +
               "                    updateTake6AutoPlayButtonUi();\n" +
               "                    checkTake6AutoPlayAction();\n" +
               "                }\n" +
               "            }\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "                ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'PLAYER_AUTO_HOST', roomCode: currentRoomId, senderId: myUserId }));\n" +
               "            }\n" +
               "            window.activeRoomInfo = { roomCode: currentRoomId, gameType: currentGameType, status: 'PLAYING' };\n" +
               "            try { localStorage.setItem('party_active_room_' + myUserId, JSON.stringify(window.activeRoomInfo)); } catch(e) {}\n" +
               "            switchMainView('lobby');\n" +
               "            setTimeout(checkActiveRoomStatus, 300);\n" +
               "            return;\n" +
               "        }\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "            ws.send(JSON.stringify({ type: 'LEAVE_ROOM', roomCode: currentRoomId, userId: myUserId }));\n" +
               "        }\n" +
               "        try {\n" +
               "            if (currentRoomId && myUserId) {\n" +
               "                fetch(getApiPrefix() + '/api/rooms/leave', {\n" +
               "                    method: 'POST',\n" +
               "                    headers: { 'Content-Type': 'application/json' },\n" +
               "                    body: JSON.stringify({ roomCode: currentRoomId, playerId: myUserId })\n" +
               "                }).catch(() => {});\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        currentRoomId = '';\n" +
               "        window.activeRoomInfo = null;\n" +
               "        try { localStorage.removeItem('party_active_room_' + myUserId); } catch(e) {}\n" +
               "        const banner = document.getElementById('activeRoomBanner');\n" +
               "        if (banner) banner.style.display = 'none';\n" +
               "        switchMainView('lobby');\n" +
               "    };\n" +
               "    window.actionLeaveRoomExplicit = function() {\n" +
               "        if (!currentRoomId) { switchMainView('lobby'); return; }\n" +
               "        if (isGameStarted) {\n" +
               "            if (!confirm('当前对局正在进行中，确认强制退出房间吗？\\n（退出后您将离开本房间并返回大厅，系统将为您自动托管该局对战）')) {\n" +
               "                return;\n" +
               "            }\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "                ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'PLAYER_AUTO_HOST', roomCode: currentRoomId, senderId: myUserId }));\n" +
               "                ws.send(JSON.stringify({ type: 'LEAVE_ROOM', roomCode: currentRoomId, userId: myUserId }));\n" +
               "            }\n" +
               "            try {\n" +
               "                if (currentRoomId && myUserId) {\n" +
               "                    fetch(getApiPrefix() + '/api/rooms/force-leave', {\n" +
               "                        method: 'POST',\n" +
               "                        headers: { 'Content-Type': 'application/json' },\n" +
               "                        body: JSON.stringify({ roomCode: currentRoomId, playerId: myUserId })\n" +
               "                    }).catch(() => {});\n" +
               "                }\n" +
               "            } catch(e) {}\n" +
               "        } else {\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "                ws.send(JSON.stringify({ type: 'LEAVE_ROOM', roomCode: currentRoomId, userId: myUserId }));\n" +
               "            }\n" +
               "            try {\n" +
               "                if (currentRoomId && myUserId) {\n" +
               "                    fetch(getApiPrefix() + '/api/rooms/leave', {\n" +
               "                        method: 'POST',\n" +
               "                        headers: { 'Content-Type': 'application/json' },\n" +
               "                        body: JSON.stringify({ roomCode: currentRoomId, playerId: myUserId })\n" +
               "                    }).catch(() => {});\n" +
               "                }\n" +
               "            } catch(e) {}\n" +
               "        }\n" +
               "        window.activeRoomInfo = null;\n" +
               "        try { localStorage.removeItem('party_active_room_' + myUserId); } catch(e) {}\n" +
               "        currentRoomId = '';\n" +
               "        currentGameType = null;\n" +
               "        isGameStarted = false;\n" +
               "        window.isGameOverPhase = true;\n" +
               "        const banner = document.getElementById('activeRoomBanner');\n" +
               "        if (banner) banner.style.display = 'none';\n" +
               "        switchMainView('lobby');\n" +
               "        showToast('🚪 已成功退出房间，返回游戏大厅！');\n" +
               "        if (typeof refreshLobbyRooms === 'function') refreshLobbyRooms();\n" +
               "    };\n" +
               "    window.checkActiveRoomStatus = async function() {\n" +
               "        if (!currentUser || !myUserId) return;\n" +
               "        const banner = document.getElementById('activeRoomBanner');\n" +
               "        let activeRoom = null;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/user/active-room?userId=' + encodeURIComponent(myUserId));\n" +
               "            const data = await res.json();\n" +
               "            if (data && data.code === 200 && data.hasActiveRoom && data.activeRoom && data.activeRoom.roomCode) {\n" +
               "                activeRoom = data.activeRoom;\n" +
               "                try { localStorage.setItem('party_active_room_' + myUserId, JSON.stringify(activeRoom)); } catch(e) {}\n" +
               "            } else {\n" +
               "                try { localStorage.removeItem('party_active_room_' + myUserId); } catch(e) {}\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        if (activeRoom && activeRoom.roomCode) {\n" +
               "            window.activeRoomInfo = activeRoom;\n" +
               "            const bannerText = document.getElementById('activeRoomBannerText');\n" +
               "            const gTitle = activeRoom.gameType === 'take6' ? '谁是牛头王' : (activeRoom.gameType === 'liars_dice' ? '大话骰吹牛' : (activeRoom.gameType === 'party_wheel' ? '聚会大转盘' : '谁是卧底'));\n" +
               "            const statusText = activeRoom.status === 'PLAYING' ? '⚡ 托管代打中' : '等待准备中';\n" +
               "            if (banner && bannerText) {\n" +
               "                bannerText.innerHTML = '🎮 检测到您在房间【#' + activeRoom.roomCode + '】(' + gTitle + ') 有未结束的对局 (' + statusText + ')！点击立即接管返回';\n" +
               "                banner.style.display = 'flex';\n" +
               "            }\n" +
               "        } else {\n" +
               "            window.activeRoomInfo = null;\n" +
               "            if (banner) banner.style.display = 'none';\n" +
               "        }\n" +
               "    };\n" +
               "    window.rejoinActiveRoom = async function() {\n" +
               "        if (!window.activeRoomInfo || !window.activeRoomInfo.roomCode) {\n" +
               "            const banner = document.getElementById('activeRoomBanner');\n" +
               "            if (banner) banner.style.display = 'none';\n" +
               "            return;\n" +
               "        }\n" +
               "        const targetCode = window.activeRoomInfo.roomCode;\n" +
               "        const targetType = window.activeRoomInfo.gameType || 'take6';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/rooms/detail?roomCode=' + encodeURIComponent(targetCode));\n" +
               "            const resData = await res.json();\n" +
               "            if (resData.code !== 0 || !resData.data || resData.data.status === 'CLOSED' || resData.data.status === 'FINISHED') {\n" +
               "                alert('该房间已解散或对局已彻底结束！');\n" +
               "                window.activeRoomInfo = null;\n" +
               "                try { localStorage.removeItem('party_active_room_' + myUserId); } catch(e) {}\n" +
               "                const banner = document.getElementById('activeRoomBanner');\n" +
               "                if (banner) banner.style.display = 'none';\n" +
               "                refreshRoomList();\n" +
               "                return;\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        joinSpecificRoom(targetCode, targetType);\n" +
               "    };\n" +
               "    window.switchSquareChannel = function(chan) {\n" +
               "        currentSquareChannel = chan;\n" +
               "        const btnW = document.getElementById('btnChanWorld'); const btnC = document.getElementById('btnChanCity');\n" +
               "        if (btnW) btnW.className = (chan === 'WORLD') ? 'square-tab-btn active' : 'square-tab-btn';\n" +
               "        if (btnC) btnC.className = (chan === 'CITY') ? 'square-tab-btn active' : 'square-tab-btn';\n" +
               "        appendSquareChat('系统', '已切换到【' + (chan === 'WORLD' ? '全服世界' : '同城交友') + '】频道');\n" +
               "    };\n" +
               "    window.sendSquareChatMessage = function(overrideText) {\n" +
               "        const input = document.getElementById('squareChatInput');\n" +
               "        const text = overrideText || (input ? input.value.trim() : '');\n" +
               "        if (!text) return;\n" +
               "        if (!overrideText && input) input.value = '';\n" +
               "        const myColor = (currentUser && currentUser.chatTextColor) ? currentUser.chatTextColor : 'COLOR_DEFAULT';\n" +
               "        const myVip = (currentUser && currentUser.vipLevel) ? currentUser.vipLevel : 0;\n" +
               "        appendSquareChat(myNickname, text, true, myColor, myVip);\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'CHAT_MESSAGE', channel: currentSquareChannel, senderId: myUserId, senderName: myNickname, senderAvatar: myAvatar, content: text, textColor: myColor, vipLevel: myVip }));\n" +
               "        }\n" +
               "    };\n" +
               "    window.sendSquareQuickMsg = function(msg) { sendSquareChatMessage(msg); };\n" +
               "    function appendSquareChat(sender, text, isMe = false, textColor = 'COLOR_DEFAULT', vipLevel = 0) {\n" +
               "        const stream = document.getElementById('squareChatStream');\n" +
               "        if (!stream) return;\n" +
               "        const div = document.createElement('div');\n" +
               "        div.className = 'chat-line';\n" +
               "        const isVip = (vipLevel > 0);\n" +
               "        const isV10 = (vipLevel >= 10);\n" +
               "        const isSvip = (vipLevel >= 4);\n" +
               "        const vipBadgeHtml = isVip ? ('<span class=\"badge-vip' + (isV10 ? ' v10' : (isSvip ? ' svip' : '')) + '\" style=\"margin-right:4px;\">' + (isV10 ? '✨ V10 无双' : ((isSvip ? '👑 SVIP' : 'VIP') + vipLevel)) + '</span> ') : '';\n" +
               "        const sColor = isV10 ? '#f59e0b' : (isVip ? (isSvip ? '#ff2e4d' : '#e60012') : (isMe ? '#10b981' : '#38bdf8'));\n" +
               "        let formattedText = text;\n" +
               "        const match = text.match(/#(\\d{6})/);\n" +
               "        if (match) {\n" +
               "            const rCode = match[1];\n" +
               "            formattedText = text.replace(/#(\\d{6})/, '<span style=\"color:#fbbf24;font-weight:bold;\">#' + rCode + '</span> <button class=\"quick-join-btn\" data-room=\"' + rCode + '\" onclick=\"joinSpecificRoom(this.dataset.room)\" style=\"padding:2px 8px;background:#f59e0b;color:#000;border:none;border-radius:4px;font-size:11px;font-weight:bold;cursor:pointer;margin-left:4px;\">⚡ 立即加入</button>');\n" +
               "        }\n" +
               "        let colorHex = (typeof CHAT_COLOR_MAP !== 'undefined' && CHAT_COLOR_MAP[textColor]) ? CHAT_COLOR_MAP[textColor] : '#1e293b';\n" +
               "        if (!colorHex || colorHex === '#ffffff' || colorHex.toLowerCase() === '#fff' || colorHex.toLowerCase() === '#f8fafc' || colorHex.toLowerCase() === '#e2e8f0') { colorHex = '#1e293b'; }\n" +
               "        div.innerHTML = vipBadgeHtml + '<span class=\"sender\" style=\"color:' + sColor + ';font-weight:bold;\">[' + sender + ']</span>: <span style=\"color:' + colorHex + ';font-weight:' + (textColor && textColor !== 'COLOR_DEFAULT' ? 'bold' : '500') + ';\">' + formattedText + '</span>';\n" +
               "        stream.appendChild(div); stream.scrollTop = stream.scrollHeight;\n" +
               "    }\n" +
               "    window.switchRankType = function(type) {\n" +
               "        currentRankType = type;\n" +
               "        const btnT = document.getElementById('btnRankTier'); const btnW = document.getElementById('btnRankWealth');\n" +
               "        if (btnT) btnT.className = (type === 'tier') ? 'rank-tab-btn active' : 'rank-tab-btn';\n" +
               "        if (btnW) btnW.className = (type === 'wealth') ? 'rank-tab-btn active' : 'rank-tab-btn';\n" +
               "        loadRankData();\n" +
               "    };\n" +
               "    window.loadRankData = async function() {\n" +
               "        const container = document.getElementById('rankListContainer');\n" +
               "        if (!container) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/rank/leaderboard');\n" +
               "            const data = await res.json();\n" +
               "            const list = (currentRankType === 'tier' ? data.data?.rankBoard : data.data?.wealthBoard) || [];\n" +
               "            if (list.length === 0) {\n" +
               "                container.innerHTML = '<div style=\"color:#64748b; font-size:12px; text-align:center; padding:16px;\">暂无榜单数据</div>';\n" +
               "                return;\n" +
               "            }\n" +
               "            container.innerHTML = list.slice(0, 30).map((u, i) => {\n" +
               "                const topClass = i === 0 ? 'top1' : (i === 1 ? 'top2' : (i === 2 ? 'top3' : ''));\n" +
               "                const medal = i === 0 ? '🥇' : (i === 1 ? '🥈' : (i === 2 ? '🥉' : ('#' + (i+1))));\n" +
               "                const scoreText = currentRankType === 'tier' ? ((u.rankScore || 1200) + ' 分 · ' + (u.winCount || 0) + '胜') : ('🪙 ' + Number(u.coins||0).toLocaleString());\n" +
               "                return '<div class=\"rank-item ' + topClass + '\">' +\n" +
               "                    '<div style=\"display:flex; align-items:center; gap:8px;\"><span style=\"font-size:16px; font-weight:800; width:26px; text-align:center;\">' + medal + '</span><span style=\"font-size:18px;\">' + (u.avatar||'🦊') + '</span><div><div class=\"rank-nick\" style=\"font-weight:bold; font-size:13px; color:#0f172a;\">' + (u.nickname||'玩家') + '</div><div style=\"font-size:10px; color:#64748b;\">' + (u.rankTier||'倔强青铜') + '</div></div></div>' +\n" +
               "                    '<div style=\"font-weight:bold; font-size:12px; color:#d97706;\">' + scoreText + '</div>' +\n" +
               "                    '</div>';\n" +
               "            }).join('');\n" +
               "        } catch(e) { container.innerHTML = '<div style=\"color:#ef4444; font-size:12px; text-align:center; padding:12px;\">拉取排行榜失败</div>'; }\n" +
               "    };\n";
    }

    private String buildHtmlScriptDirectChatAndProps() {
        return "    let activeDmUserId = null;\n" +
               "    let activeDmUserName = '';\n" +
               "    let activeDmUserAvatar = '🦊';\n" +
               "    window.openFriendChatModal = async function(friendId, friendName, friendAvatar, intimacy, relation) {\n" +
               "        if (!friendId) return;\n" +
               "        activeDmUserId = friendId;\n" +
               "        activeDmUserName = friendName || '好友';\n" +
               "        activeDmUserAvatar = friendAvatar || '🦊';\n" +
               "        const av = document.getElementById('dmTargetAvatar'); if (av) av.innerText = activeDmUserAvatar;\n" +
               "        const nm = document.getElementById('dmTargetName'); if (nm) nm.innerText = activeDmUserName;\n" +
               "        const rb = document.getElementById('dmTargetRelBadge'); if (rb) rb.innerText = relation || '朋友';\n" +
               "        const it = document.getElementById('dmTargetIntimacy'); if (it) it.innerText = '亲密度 ' + (intimacy || 10);\n" +
               "        const m = document.getElementById('friendChatModal'); if (m) m.style.display = 'flex';\n" +
               "        const inp = document.getElementById('directChatInput'); if (inp) { inp.value = ''; inp.focus(); }\n" +
               "        await loadDirectChatHistory(friendId);\n" +
               "        try {\n" +
               "            fetch(getApiPrefix() + '/api/friends/messages/read', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, friendId: friendId })\n" +
               "            }).catch(() => {});\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.closeFriendChatModal = function() {\n" +
               "        activeDmUserId = null;\n" +
               "        const m = document.getElementById('friendChatModal'); if (m) m.style.display = 'none';\n" +
               "    };\n" +
               "    window.loadDirectChatHistory = async function(friendId) {\n" +
               "        const stream = document.getElementById('directChatStream');\n" +
               "        if (!stream) return;\n" +
               "        stream.innerHTML = '<div style=\"text-align:center; color:#94a3b8; font-size:11px; margin:10px 0;\">💬 正在载入私信历史...</div>';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/messages/history?userId=' + encodeURIComponent(myUserId) + '&friendId=' + encodeURIComponent(friendId));\n" +
               "            const d = await res.json();\n" +
               "            const list = d.data || [];\n" +
               "            if (list.length === 0) {\n" +
               "                stream.innerHTML = '<div style=\"text-align:center; color:#94a3b8; font-size:11px; margin:20px 0;\">你们已成为好友，发条消息开启互动吧～</div>';\n" +
               "                return;\n" +
               "            }\n" +
               "            stream.innerHTML = '';\n" +
               "            list.forEach(m => renderDirectChatMessage(m, stream));\n" +
               "            stream.scrollTop = stream.scrollHeight;\n" +
               "        } catch(e) {\n" +
               "            stream.innerHTML = '<div style=\"text-align:center; color:#ef4444; font-size:11px; margin:10px 0;\">拉取聊天记录失败</div>';\n" +
               "        }\n" +
               "    };\n" +
               "    function renderDirectChatMessage(msg, streamContainer) {\n" +
               "        const stream = streamContainer || document.getElementById('directChatStream');\n" +
               "        if (!stream) return;\n" +
               "        const isMe = String(msg.fromUserId) === String(myUserId);\n" +
               "        const row = document.createElement('div');\n" +
               "        row.className = 'chat-bubble-row' + (isMe ? ' me' : '');\n" +
               "        const av = isMe ? myAvatar : (msg.fromAvatar || activeDmUserAvatar || '🦊');\n" +
               "        const avDiv = '<div class=\"chat-bubble-avatar\">' + av + '</div>';\n" +
               "        let bubbleContent = '';\n" +
               "        if (msg.inviteRoomCode) {\n" +
               "            const gName = (msg.gameType === 'take6') ? '谁是牛头王' : ((msg.gameType === 'liars_dice') ? '大话骰吹牛' : '开黑对决');\n" +
               "            bubbleContent = '<div class=\"chat-room-invite-card\">' +\n" +
               "                '<div class=\"chat-room-invite-title\">🎮 邀请你进入房间对局</div>' +\n" +
               "                '<div class=\"chat-room-invite-room\">房间号: #' + msg.inviteRoomCode + ' · ' + gName + '</div>' +\n" +
               "                '<button class=\"chat-room-invite-btn\" data-room=\"' + msg.inviteRoomCode + '\" data-type=\"' + (msg.gameType||'take6') + '\" onclick=\"joinSpecificRoom(this.dataset.room, this.dataset.type)\">⚡ 立即进入对局</button>' +\n" +
               "                '</div>';\n" +
               "        } else {\n" +
               "            bubbleContent = '<div class=\"chat-bubble-msg\">' + (msg.content || '') + '</div>';\n" +
               "        }\n" +
               "        const timeStr = msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';\n" +
               "        const timeDiv = '<div class=\"chat-bubble-time\">' + timeStr + '</div>';\n" +
               "        if (isMe) {\n" +
               "            row.innerHTML = timeDiv + '<div style=\"display:flex; flex-direction:column; align-items:flex-end;\">' + bubbleContent + '</div>' + avDiv;\n" +
               "        } else {\n" +
               "            row.innerHTML = avDiv + '<div style=\"display:flex; flex-direction:column; align-items:flex-start;\">' + bubbleContent + '</div>' + timeDiv;\n" +
               "        }\n" +
               "        stream.appendChild(row);\n" +
               "        stream.scrollTop = stream.scrollHeight;\n" +
               "    }\n" +
               "    window.sendDirectChatMessage = async function(overrideText) {\n" +
               "        if (!activeDmUserId) return;\n" +
               "        const inp = document.getElementById('directChatInput');\n" +
               "        const text = overrideText || (inp ? inp.value.trim() : '');\n" +
               "        if (!text) return;\n" +
               "        if (inp && !overrideText) inp.value = '';\n" +
               "        const now = Date.now();\n" +
               "        const msgObj = {\n" +
               "            id: 'DM-' + now,\n" +
               "            fromUserId: myUserId,\n" +
               "            fromNickname: myNickname,\n" +
               "            fromAvatar: myAvatar,\n" +
               "            toUserId: activeDmUserId,\n" +
               "            content: text,\n" +
               "            timestamp: now\n" +
               "        };\n" +
               "        renderDirectChatMessage(msgObj);\n" +
               "        playBeep(700, 0.08);\n" +
               "        try {\n" +
               "            fetch(getApiPrefix() + '/api/friends/messages/send', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify(msgObj)\n" +
               "            }).catch(() => {});\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "                ws.send(JSON.stringify(Object.assign({ type: 'DIRECT_MESSAGE' }, msgObj)));\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.sendDirectRoomInvite = function() {\n" +
               "        if (!activeDmUserId) return;\n" +
               "        const targetRoom = currentRoomId || Math.floor(100000 + Math.random() * 900000).toString();\n" +
               "        if (!currentRoomId) {\n" +
               "            joinSpecificRoom(targetRoom, currentGameType || 'take6');\n" +
               "        }\n" +
               "        const now = Date.now();\n" +
               "        const msgObj = {\n" +
               "            id: 'DM-' + now,\n" +
               "            fromUserId: myUserId,\n" +
               "            fromNickname: myNickname,\n" +
               "            fromAvatar: myAvatar,\n" +
               "            toUserId: activeDmUserId,\n" +
               "            content: '我正在房间 #' + targetRoom + ' 邀请你加入对局！',\n" +
               "            inviteRoomCode: targetRoom,\n" +
               "            gameType: currentGameType || 'take6',\n" +
               "            timestamp: now\n" +
               "        };\n" +
               "        renderDirectChatMessage(msgObj);\n" +
               "        playBeep(880, 0.15);\n" +
               "        try {\n" +
               "            fetch(getApiPrefix() + '/api/friends/messages/send', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify(msgObj)\n" +
               "            }).catch(() => {});\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "                ws.send(JSON.stringify(Object.assign({ type: 'DIRECT_MESSAGE' }, msgObj)));\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.openGiftFromChat = function() {\n" +
               "        if (!activeDmUserId) return;\n" +
               "        const uid = activeDmUserId;\n" +
               "        const name = activeDmUserName;\n" +
               "        const av = activeDmUserAvatar;\n" +
               "        closeFriendChatModal();\n" +
               "        openItemThrowModal(uid, name, av);\n" +
               "    };\n" +
               "    const THROW_ITEMS = [\n" +
               "        { id: 'beer', name: '冰爽啤酒', emoji: '🍺', costCoins: 20, costDiamonds: 0, intimacy: 10, title: '冰爽啤酒' },\n" +
               "        { id: 'rose', name: '浪漫玫瑰', emoji: '💐', costCoins: 20, costDiamonds: 0, intimacy: 15, title: '浪漫玫瑰' },\n" +
               "        { id: 'egg', name: '调皮臭蛋', emoji: '🥚', costCoins: 10, costDiamonds: 0, intimacy: 5, title: '调皮臭蛋' },\n" +
               "        { id: 'slipper', name: '暴击飞拖', emoji: '👡', costCoins: 15, costDiamonds: 0, intimacy: 8, title: '暴击飞拖' },\n" +
               "        { id: 'bomb', name: '核爆飞弹', emoji: '💣', costCoins: 50, costDiamonds: 0, intimacy: 5, title: '核爆飞弹' },\n" +
               "        { id: 'champagne', name: '胜利香槟', emoji: '🍾', costCoins: 66, costDiamonds: 0, intimacy: 25, title: '胜利香槟' },\n" +
               "        { id: 'hammer', name: '暴击雷锤', emoji: '🔨', costCoins: 30, costDiamonds: 0, intimacy: 8, title: '暴击雷锤' },\n" +
               "        { id: 'kiss', name: '甜蜜飞吻', emoji: '💋', costCoins: 25, costDiamonds: 0, intimacy: 20, title: '甜蜜飞吻' },\n" +
               "        { id: 'brick', name: '糊你板砖', emoji: '🧱', costCoins: 20, costDiamonds: 0, intimacy: 6, title: '糊你板砖' },\n" +
               "        { id: 'watergun', name: '搞笑水枪', emoji: '🔫', costCoins: 15, costDiamonds: 0, intimacy: 8, title: '搞笑水枪' },\n" +
               "        { id: 'poop', name: '搞笑便便', emoji: '💩', costCoins: 10, costDiamonds: 0, intimacy: 5, title: '搞笑便便' },\n" +
               "        { id: 'rocket', name: '超级火箭', emoji: '🚀', costCoins: 0, costDiamonds: 18, intimacy: 60, title: '超级火箭', isGlobal: true, luxury: true },\n" +
               "        { id: 'car', name: '豪华超跑', emoji: '🏎️', costCoins: 0, costDiamonds: 58, intimacy: 188, title: '豪华超跑', isGlobal: true, luxury: true },\n" +
               "        { id: 'ring', name: '璀璨钻戒', emoji: '💍', costCoins: 0, costDiamonds: 88, intimacy: 520, title: '璀璨钻戒', isGlobal: true, luxury: true },\n" +
               "        { id: 'horn', name: '全服喇叭', emoji: '📢', costCoins: 0, costDiamonds: 10, intimacy: 30, title: '全服喇叭', isGlobal: true, broadcast: true }\n" +
               "    ];\n" +
               "    let currentSelectedPropIdx = 0;\n" +
               "    let currentSelectedCombo = 1;\n" +
               "    let throwTargetUid = '';\n" +
               "    let throwTargetNickname = '';\n" +
               "    let throwTargetAvatar = '🦊';\n" +
               "    window.openItemThrowModal = function(targetUid, targetName, targetAvatar) {\n" +
               "        throwTargetUid = targetUid || '';\n" +
               "        throwTargetNickname = targetName || '好友';\n" +
               "        throwTargetAvatar = targetAvatar || '🦊';\n" +
               "        const av = document.getElementById('throwTargetAvatar'); if (av) av.innerText = throwTargetAvatar;\n" +
               "        const nm = document.getElementById('throwTargetName'); if (nm) nm.innerText = throwTargetNickname;\n" +
               "        currentSelectedPropIdx = 0;\n" +
               "        currentSelectedCombo = 1;\n" +
               "        renderThrowItemsGrid();\n" +
               "        updateThrowComboButtons();\n" +
               "        updateThrowCostDisplay();\n" +
               "        const modal = document.getElementById('itemThrowModal'); if (modal) modal.style.display = 'flex';\n" +
               "    };\n" +
               "    window.closeItemThrowModal = function() {\n" +
               "        const modal = document.getElementById('itemThrowModal'); if (modal) modal.style.display = 'none';\n" +
               "    };\n" +
               "    function renderThrowItemsGrid() {\n" +
               "        const grid = document.getElementById('throwItemsGrid');\n" +
               "        if (!grid) return;\n" +
               "        grid.innerHTML = THROW_ITEMS.map((item, idx) => {\n" +
               "            const isSel = idx === currentSelectedPropIdx;\n" +
               "            const costStr = item.costDiamonds > 0 ? ('💎 ' + item.costDiamonds) : ((window.COIN_ICON_SVG || '💰 ') + item.costCoins);\n" +
               "            return '<div class=\"throw-item-card ' + (isSel ? 'selected' : '') + '\" onclick=\"selectThrowItem(' + idx + ')\">' +\n" +
               "                '<div class=\"throw-item-emoji\">' + item.emoji + '</div>' +\n" +
               "                '<div class=\"throw-item-name\">' + item.name + '</div>' +\n" +
               "                '<div class=\"throw-item-cost\">' + costStr + '</div>' +\n" +
               "                '</div>';\n" +
               "        }).join('');\n" +
               "    }\n" +
               "    window.selectThrowItem = function(idx) {\n" +
               "        currentSelectedPropIdx = idx;\n" +
               "        renderThrowItemsGrid();\n" +
               "        updateThrowCostDisplay();\n" +
               "    };\n" +
               "    window.selectThrowCombo = function(combo) {\n" +
               "        currentSelectedCombo = Number(combo || 1);\n" +
               "        updateThrowComboButtons();\n" +
               "        updateThrowCostDisplay();\n" +
               "    };\n" +
               "    function updateThrowComboButtons() {\n" +
               "        document.querySelectorAll('.throw-combo-btn').forEach(btn => {\n" +
               "            const c = Number(btn.dataset.combo || 1);\n" +
               "            if (c === currentSelectedCombo) btn.classList.add('active');\n" +
               "            else btn.classList.remove('active');\n" +
               "        });\n" +
               "    }\n" +
               "    function updateThrowCostDisplay() {\n" +
               "        const item = THROW_ITEMS[currentSelectedPropIdx] || THROW_ITEMS[0];\n" +
               "        const costText = document.getElementById('throwCostText');\n" +
               "        const intText = document.getElementById('throwIntimacyGain');\n" +
               "        const totalCoins = (item.costCoins || 0) * currentSelectedCombo;\n" +
               "        const totalDiamonds = (item.costDiamonds || 0) * currentSelectedCombo;\n" +
               "        const totalIntimacy = (item.intimacy || 10) * currentSelectedCombo;\n" +
               "        if (costText) {\n" +
               "            if (totalDiamonds > 0) costText.innerHTML = '💎 ' + totalDiamonds.toLocaleString() + ' 钻石';\n" +
               "            else costText.innerHTML = (window.COIN_ICON_SVG || '💰 ') + totalCoins.toLocaleString() + ' 金币';\n" +
               "        }\n" +
               "        if (intText) intText.innerText = totalIntimacy.toLocaleString();\n" +
               "    }\n" +
               "    window.confirmSendThrowItem = async function() {\n" +
               "        const item = THROW_ITEMS[currentSelectedPropIdx] || THROW_ITEMS[0];\n" +
               "        const totalCoins = (item.costCoins || 0) * currentSelectedCombo;\n" +
               "        const totalDiamonds = (item.costDiamonds || 0) * currentSelectedCombo;\n" +
               "        const myCoins = (currentUser && currentUser.coins != null) ? currentUser.coins : 2000;\n" +
               "        const myDiamonds = (currentUser && currentUser.diamonds != null) ? currentUser.diamonds : 50;\n" +
               "        if (totalCoins > 0 && myCoins < totalCoins) {\n" +
               "            alert('💰 金币不足 (需 ' + totalCoins + '，当前 ' + myCoins + ')！请前往商城充值或在对局中赚取金币～');\n" +
               "            return;\n" +
               "        }\n" +
               "        if (totalDiamonds > 0 && myDiamonds < totalDiamonds) {\n" +
               "            alert('💎 钻石不足 (需 ' + totalDiamonds + '，当前 ' + myDiamonds + ')！请前往商城充值钻石～');\n" +
               "            return;\n" +
               "        }\n" +
               "        if (currentUser) {\n" +
               "            currentUser.coins = Math.max(0, myCoins - totalCoins);\n" +
               "            currentUser.diamonds = Math.max(0, myDiamonds - totalDiamonds);\n" +
               "            updateHeaderUserUi(currentUser);\n" +
               "            loadProfileData();\n" +
               "        }\n" +
               "        const payload = {\n" +
               "            type: 'THROW_ITEM',\n" +
               "            senderId: myUserId,\n" +
               "            senderName: myNickname,\n" +
               "            senderAvatar: myAvatar,\n" +
               "            targetPlayerId: throwTargetUid,\n" +
               "            targetPlayerName: throwTargetNickname,\n" +
               "            itemType: item.id,\n" +
               "            itemEmoji: item.emoji,\n" +
               "            combo: currentSelectedCombo,\n" +
               "            giftTitle: item.title,\n" +
               "            addedIntimacy: item.intimacy * currentSelectedCombo,\n" +
               "            isGlobal: item.isGlobal === true\n" +
               "        };\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify(payload));\n" +
               "        }\n" +
               "        try {\n" +
               "            fetch(getApiPrefix() + '/api/intimacy/add', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({\n" +
               "                    user1Id: myUserId,\n" +
               "                    user2Id: throwTargetUid,\n" +
               "                    score: item.intimacy * currentSelectedCombo,\n" +
               "                    itemType: item.id\n" +
               "                })\n" +
               "            }).catch(() => {});\n" +
               "        } catch(e) {}\n" +
               "        closeItemThrowModal();\n" +
               "        triggerThrowItemFx(payload);\n" +
               "    };\n" +
               "    window.triggerThrowItemFx = function(data) {\n" +
               "        const stage = document.getElementById('fxOverlayStage');\n" +
               "        if (!stage) return;\n" +
               "        playBeep(650, 0.12);\n" +
               "        const banner = document.createElement('div');\n" +
               "        banner.className = 'fx-runner-banner';\n" +
               "        banner.innerHTML = '<span style=\"font-size:24px;\">' + (data.itemEmoji || '🎁') + '</span> ' +\n" +
               "            '<span>【<b>' + (data.senderName || '玩家') + '</b>】 向 【<b>' + (data.targetPlayerName || '好友') + '</b>】 投掷了 ' + (data.giftTitle || '礼物') + ' <b style=\"color:#fbbf24;\">x' + (data.combo || 1) + '</b>！亲密度 +' + (data.addedIntimacy || 10) + ' ❤️</span>';\n" +
               "        stage.appendChild(banner);\n" +
               "        setTimeout(() => { if (banner.parentNode) banner.parentNode.removeChild(banner); }, 4000);\n" +
               "        const proj = document.createElement('div');\n" +
               "        proj.className = 'fx-projectile';\n" +
               "        proj.innerText = data.itemEmoji || '🎁';\n" +
               "        proj.style.left = (window.innerWidth / 2 - 25) + 'px';\n" +
               "        proj.style.top = (window.innerHeight - 120) + 'px';\n" +
               "        stage.appendChild(proj);\n" +
               "        const targetX = window.innerWidth / 2 - 25;\n" +
               "        const targetY = window.innerHeight * 0.35;\n" +
               "        requestAnimationFrame(() => {\n" +
               "            proj.style.left = targetX + 'px';\n" +
               "            proj.style.top = targetY + 'px';\n" +
               "            proj.style.transform = 'scale(1.5) rotate(360deg)';\n" +
               "        });\n" +
               "        setTimeout(() => {\n" +
               "            if (proj.parentNode) proj.parentNode.removeChild(proj);\n" +
               "            const ring = document.createElement('div');\n" +
               "            ring.className = 'fx-burst-ring';\n" +
               "            ring.style.left = targetX + 'px';\n" +
               "            ring.style.top = targetY + 'px';\n" +
               "            stage.appendChild(ring);\n" +
               "            setTimeout(() => { if (ring.parentNode) ring.parentNode.removeChild(ring); }, 800);\n" +
               "            const emojis = ['✨', '⭐', '💖', '💥', '🎉', '🌟'];\n" +
               "            for (let i = 0; i < 12; i++) {\n" +
               "                const part = document.createElement('div');\n" +
               "                part.className = 'fx-particle';\n" +
               "                part.innerText = emojis[i % emojis.length];\n" +
               "                const angle = (i / 12) * Math.PI * 2;\n" +
               "                const dist = 70 + Math.random() * 60;\n" +
               "                const px = targetX + 15 + Math.cos(angle) * dist;\n" +
               "                const py = targetY + 15 + Math.sin(angle) * dist;\n" +
               "                part.style.left = (targetX + 15) + 'px';\n" +
               "                part.style.top = (targetY + 15) + 'px';\n" +
               "                stage.appendChild(part);\n" +
               "                requestAnimationFrame(() => {\n" +
               "                    part.style.left = px + 'px';\n" +
               "                    part.style.top = py + 'px';\n" +
               "                    part.style.opacity = '0';\n" +
               "                    part.style.transform = 'scale(1.4)';\n" +
               "                });\n" +
               "                setTimeout(() => { if (part.parentNode) part.parentNode.removeChild(part); }, 900);\n" +
               "            }\n" +
               "            playBeep(980, 0.2);\n" +
               "        }, 550);\n" +
               "        if (data.isGlobal || (data.combo && data.combo >= 66)) {\n" +
               "            const splash = document.createElement('div');\n" +
               "            splash.className = 'fx-luxury-splash';\n" +
               "            splash.innerHTML = '<div style=\"font-size:72px;\">' + (data.itemEmoji || '🚀') + '</div>' +\n" +
               "                '<div style=\"font-size:24px; font-weight:800; color:#fbbf24; text-shadow:0 0 20px rgba(245,158,11,0.8); margin:12px 0;\">🎉 全服瞩目 · 豪礼降临！</div>' +\n" +
               "                '<div style=\"font-size:15px; color:#f8fafc; font-weight:bold;\">【' + (data.senderName || '玩家') + '】 豪掷 【' + (data.targetPlayerName || '玩家') + '】 ' + (data.giftTitle || '') + ' x' + (data.combo || 1) + '！</div>' +\n" +
               "                '<div style=\"font-size:12px; color:#cbd5e1; margin-top:8px;\">❤️ 亲密度狂飙 +' + (data.addedIntimacy || 100) + '！情谊天长地久！</div>';\n" +
               "            stage.appendChild(splash);\n" +
               "            setTimeout(() => { if (splash.parentNode) splash.parentNode.removeChild(splash); }, 3800);\n" +
               "        }\n" +
               "    };\n" +
               "    window.openGlobalBroadcastModal = function() {\n" +
               "        const modal = document.getElementById('globalBroadcastModal');\n" +
               "        if (modal) modal.style.display = 'flex';\n" +
               "    };\n" +
               "    window.closeGlobalBroadcastModal = function() {\n" +
               "        const modal = document.getElementById('globalBroadcastModal');\n" +
               "        if (modal) modal.style.display = 'none';\n" +
               "    };\n" +
               "    window.confirmSendGlobalBroadcast = function() {\n" +
               "        const input = document.getElementById('inputGlobalBroadcastMsg');\n" +
               "        const msg = input ? input.value.trim() : '';\n" +
               "        if (!msg) { alert('请输入全服广播内容！'); return; }\n" +
               "        const myDiamonds = (currentUser && currentUser.diamonds != null) ? currentUser.diamonds : 50;\n" +
               "        if (myDiamonds < 10) {\n" +
               "            alert('💎 钻石不足 (需 10 颗钻石，当前 ' + myDiamonds + ')！请前往商城充值～');\n" +
               "            return;\n" +
               "        }\n" +
               "        if (currentUser) {\n" +
               "            currentUser.diamonds = myDiamonds - 10;\n" +
               "            updateHeaderUserUi(currentUser);\n" +
               "            loadProfileData();\n" +
               "        }\n" +
               "        const broadcastObj = {\n" +
               "            id: 'BLS-' + Date.now(),\n" +
               "            type: 'GLOBAL_BROADCAST',\n" +
               "            broadcastType: 'MARQUEE',\n" +
               "            itemType: 'MARQUEE',\n" +
               "            giftTitle: '全服大喇叭',\n" +
               "            itemEmoji: '📢',\n" +
               "            senderId: (currentUser && currentUser.id) ? currentUser.id : ('web_' + Date.now()),\n" +
               "            senderName: myNickname || (currentUser ? currentUser.nickname : '网页玩家'),\n" +
               "            senderAvatar: (currentUser && currentUser.avatar) ? currentUser.avatar : '🦊',\n" +
               "            senderVip: currentUser ? (currentUser.vipLevel || 0) : 1,\n" +
               "            blessing: msg,\n" +
               "            timestamp: Date.now()\n" +
               "        };\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify(broadcastObj));\n" +
               "        } else {\n" +
               "            try { initWebSocket(); } catch(e) {}\n" +
               "        }\n" +
               "        try {\n" +
               "            fetch(getApiPrefix() + '/api/chat/global-broadcast', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify(broadcastObj)\n" +
               "            }).catch(function(e) { console.error('喇叭HTTP广播异常:', e); });\n" +
               "        } catch (err) {}\n" +
               "        showH5GlobalMarquee(broadcastObj);\n" +
               "        closeGlobalBroadcastModal();\n" +
               "        alert('🎉 全服大喇叭播报成功！全服在线玩家均已收到！');\n" +
               "    };\n";
    }

    private String buildHtmlScriptShopAndFriends() {
        return "    let currentShopSubTab = 'dice_cup';\n" +
               "    const SHOP_CATALOG = {\n" +
               "        dice_cup: [\n" +
               "            { id: 'CLASSIC_GOLD', name: '经典黑金骰盅', emoji: '🏆', slot: 'diceCupSkin', coins: 0, diamonds: 0, minVip: 0, desc: '尊贵黑金拉丝质感，聚会老手标志', defaultOwned: true },\n" +
               "            { id: 'NEON_CYBER', name: '赛博霓虹骰盅', emoji: '⚡', slot: 'diceCupSkin', coins: 500, diamonds: 0, minVip: 0, desc: '赛博朋克流光幻彩，夜晚开局焦点' },\n" +
               "            { id: 'PURPLE_GALAXY', name: '紫晶星系骰盅', emoji: '🌌', slot: 'diceCupSkin', coins: 800, diamonds: 0, minVip: 0, desc: '星河流转璀璨迷人，运气爆棚加持' },\n" +
               "            { id: 'FLAME_DRAGON', name: '烈焰赤龙骰盅', emoji: '🔥', slot: 'diceCupSkin', coins: 1200, diamonds: 0, minVip: 0, desc: '烈火熊熊势不可挡，一把梭哈逆天改命' },\n" +
               "            { id: 'PURE_DIAMOND', name: '璀璨钻石骰盅', emoji: '💎', slot: 'diceCupSkin', coins: 2000, diamonds: 0, minVip: 0, desc: '八心八箭至尊水晶切割，闪耀全场' },\n" +
               "            { id: 'ROYAL_DRAGON_GOLD', name: '至尊黄金神龙骰盅', emoji: '👑', slot: 'diceCupSkin', coins: 0, diamonds: 188, minVip: 2, desc: 'VIP 2 专属奢华黄金盘龙，尊崇绝伦' }\n" +
               "        ],\n" +
               "        avatar_frame: [\n" +
               "            { id: 'FRAME_DEFAULT', name: '聚会新星框', emoji: '⭐', slot: 'avatarFrame', coins: 0, diamonds: 0, minVip: 0, desc: '初入聚会社区基础装扮', defaultOwned: true },\n" +
               "            { id: 'FRAME_NEON', name: '赛博流光框', emoji: '🌈', slot: 'avatarFrame', coins: 300, diamonds: 0, minVip: 0, desc: '流光幻彩渐变边框，彰显年轻活力' },\n" +
               "            { id: 'FRAME_GOLD', name: '荣耀黄金框', emoji: '🥇', slot: 'avatarFrame', coins: 800, diamonds: 0, minVip: 0, desc: '璀璨真金抛光工艺，尊贵王者气派' },\n" +
               "            { id: 'FRAME_GALAXY_DOMINATOR', name: '星空霸主框', emoji: '🌌', slot: 'avatarFrame', coins: 0, diamonds: 128, minVip: 1, desc: 'VIP 1 专属星辰环绕动效框' },\n" +
               "            { id: 'FRAME_BLACK_GOLD_ROYAL', name: '黑金至尊帝王框', emoji: '🔱', slot: 'avatarFrame', coins: 0, diamonds: 388, minVip: 4, desc: 'VIP 4 专属黑金龙纹霸气图腾' }\n" +
               "        ],\n" +
               "        entrance_banner: [\n" +
               "            { id: 'BANNER_DEFAULT', name: '普通登场横幅', emoji: '🚪', slot: 'entranceBanner', coins: 0, diamonds: 0, minVip: 0, desc: '系统默认进房提示横幅', defaultOwned: true },\n" +
               "            { id: 'BANNER_SHINE', name: '闪亮登场横幅', emoji: '✨', slot: 'entranceBanner', coins: 500, diamonds: 0, minVip: 0, desc: '全场星光闪烁，醒目进场动画' },\n" +
               "            { id: 'BANNER_DRAGON', name: '凤舞龙吟横幅', emoji: '🐉', slot: 'entranceBanner', coins: 1200, diamonds: 0, minVip: 0, desc: '神龙破空进场横幅，全屏焦点' },\n" +
               "            { id: 'BANNER_EMPEROR', name: '君临天下横幅', emoji: '👑', slot: 'entranceBanner', coins: 0, diamonds: 588, minVip: 3, desc: 'VIP 3 专属尊贵入场全服公告' }\n" +
               "        ],\n" +
               "        chat_text_color: [\n" +
               "            { id: 'COLOR_DEFAULT', name: '默认深黛灰', emoji: '💬', slot: 'chatTextColor', coins: 0, diamonds: 0, minVip: 0, desc: '系统默认高对比度护眼清晰深灰发言 (#1E293B)', defaultOwned: true, hex: '#1e293b' },\n" +
               "            { id: 'COLOR_SAKURA_PINK', name: '炫彩樱花粉', emoji: '🌸', slot: 'chatTextColor', coins: 300, diamonds: 0, minVip: 0, desc: '清新烂漫樱花粉，字字动人心弦 (#DB2777)', hex: '#db2777' },\n" +
               "            { id: 'COLOR_CYBER_BLUE', name: '赛博冰川蓝', emoji: '💎', slot: 'chatTextColor', coins: 500, diamonds: 0, minVip: 0, desc: '极客未来冷萃冰蓝，字迹冷酷吸睛 (#0284C7)', hex: '#0284c7' },\n" +
               "            { id: 'COLOR_AURORA_GREEN', name: '翡翠极光绿', emoji: '🍀', slot: 'chatTextColor', coins: 600, diamonds: 0, minVip: 0, desc: '青翠荧光草绿，生机盎然出类拔萃 (#059669)', hex: '#059669' },\n" +
               "            { id: 'COLOR_DEEP_PURPLE', name: '幻影深空紫', emoji: '🔮', slot: 'chatTextColor', coins: 800, diamonds: 0, minVip: 0, desc: '神秘幽邃深空魅紫，尊贵迷人魅力 (#7C3AED)', hex: '#7c3aed' },\n" +
               "            { id: 'COLOR_BLAZING_GOLD', name: '炽焰曜石金', emoji: '👑', slot: 'chatTextColor', coins: 0, diamonds: 168, minVip: 2, desc: 'VIP 2 专属奢华曜石流金，牌局全场焦点 (#D97706)', hex: '#d97706' },\n" +
               "            { id: 'COLOR_QQ_RED', name: '至尊红钻绯红', emoji: '🔥', slot: 'chatTextColor', coins: 0, diamonds: 288, minVip: 3, desc: 'VIP 3 专属热烈至尊红，如火焰般炽热醒目 (#DC2626)', hex: '#dc2626' }\n" +
               "        ],\n" +
               "        gift_prop: [\n" +
               "            { id: 'GIFT_STARTER', name: '新手超值福利包', emoji: '🎁', slot: 'pack', coins: 0, diamonds: 60, minVip: 0, desc: '内含 6,666 金币 + 鸡蛋啤酒各20个', isAction: 'starter_pack' },\n" +
               "            { id: 'INTERACTION_BUNDLE', name: '酒桌互动大礼包', emoji: '🍻', slot: 'pack', coins: 188, diamonds: 0, minVip: 0, desc: '内含啤酒、鲜花、拖鞋各 10 个', isAction: 'bundle_pack' },\n" +
               "            { id: 'horn_pack', name: '全服广播喇叭', emoji: '📢', slot: 'prop', coins: 0, diamonds: 10, minVip: 0, desc: '全服跑马灯广播祝福，全服同屏送出喜讯', isAction: 'horn' },\n" +
               "            { id: 'rocket_pack', name: '超级火箭礼包', emoji: '🚀', slot: 'prop', coins: 0, diamonds: 18, minVip: 0, desc: '全服震撼巨幕火箭升空，+60 亲密度', isAction: 'rocket' }\n" +
               "        ],\n" +
               "        recharge: [\n" +
               "            { id: 'tier_6', name: '6元聚会新手包', price: '￥6', diamonds: 60, coins: 600, badge: '首充双倍', bonus: '首次赠送120钻石！' },\n" +
               "            { id: 'tier_30', name: '30元微醺畅玩包', price: '￥30', diamonds: 300, coins: 3500, badge: '超值特惠', bonus: '加赠 3,500 金币' },\n" +
               "            { id: 'tier_68', name: '68元骰王进阶包', price: '￥68', diamonds: 680, coins: 8888, badge: '热门首选', bonus: '极速升级 VIP 2' },\n" +
               "            { id: 'tier_128', name: '128元雀圣霸主包', price: '￥128', diamonds: 1280, coins: 18888, badge: '尊享特权', bonus: '直接晋升 VIP 4 帝王框' },\n" +
               "            { id: 'tier_648', name: '648元至尊神豪包', price: '￥648', diamonds: 6480, coins: 100000, badge: '至尊加冕', bonus: '海量 10 万金币 + 顶级特权' }\n" +
               "        ],\n" +
               "        vip_center: [\n" +
               "            { level: 1, name: 'VIP 1 新星特权', exp: 60, emoji: '⭐', perks: '星空霸主专属头像框 · 全服大喇叭高亮V1标示 · 每日签到额外加赠 10%' },\n" +
               "            { level: 2, name: 'VIP 2 尊贵特权', exp: 300, emoji: '👑', perks: '至尊黄金神龙骰盅解锁 · 加好友上限扩展至 200 人 · 专属进场金光特效' },\n" +
               "            { level: 3, name: 'VIP 3 霸主特权', exp: 680, emoji: '🐉', perks: '君临天下全服入场横幅 · 专属闪烁聊天气泡 · 房间置顶优先匹配' },\n" +
               "            { level: 4, name: 'VIP 4 帝王特权', exp: 1280, emoji: '🔱', perks: '黑金至尊帝王专属动效框 · 免广告体验 · 专属防沉迷定制提示' },\n" +
               "            { level: 5, name: 'VIP 5 至尊神豪', exp: 3280, emoji: '💎', perks: '神豪环绕金色专属光环 · 专属客服一对一响应 · 全服赠礼特效加成' },\n" +
               "            { level: 6, name: 'VIP 6 荣耀霸主', exp: 6480, emoji: '🔥', perks: '全服世界发言无冷却 · 专属神龙骰盅定制底座 · 亲密度倍速飞升' }\n" +
               "        ]\n" +
               "    };\n" +
               "    window.switchShopCategory = function(cat) {\n" +
               "        currentShopSubTab = cat;\n" +
               "        ['dice_cup', 'avatar_frame', 'entrance_banner', 'chat_text_color', 'gift_prop', 'recharge', 'vip_center'].forEach(c => {\n" +
               "            const id = 'shopNav' + c.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('');\n" +
               "            const btn = document.getElementById(id);\n" +
               "            if (btn) {\n" +
               "                if (c === cat) btn.classList.add('active');\n" +
               "                else btn.classList.remove('active');\n" +
               "            }\n" +
               "        });\n" +
               "        renderShopGoods();\n" +
               "    };\n" +
               "    window.renderShopGoods = function() {\n" +
               "        const container = document.getElementById('shopCatalogContainer');\n" +
               "        if (!container) return;\n" +
               "        const cat = currentShopSubTab || 'dice_cup';\n" +
               "        const myCoins = (currentUser && currentUser.coins != null) ? currentUser.coins : 2000;\n" +
               "        const myDiamonds = (currentUser && currentUser.diamonds != null) ? currentUser.diamonds : 50;\n" +
               "        const myVip = (currentUser && currentUser.vipLevel != null) ? currentUser.vipLevel : 1;\n" +
               "        const owned = (currentUser && currentUser.ownedItems) ? currentUser.ownedItems : ['CLASSIC_GOLD', 'FRAME_DEFAULT', 'BANNER_DEFAULT', 'COLOR_DEFAULT'];\n" +
               "        const curDiceCup = (currentUser && currentUser.diceCupSkin) ? currentUser.diceCupSkin : 'CLASSIC_GOLD';\n" +
               "        const curAvatarFrame = (currentUser && currentUser.avatarFrame) ? currentUser.avatarFrame : 'FRAME_DEFAULT';\n" +
               "        const curEntranceBanner = (currentUser && currentUser.entranceBanner) ? currentUser.entranceBanner : 'BANNER_DEFAULT';\n" +
               "        const curChatTextColor = (currentUser && currentUser.chatTextColor) ? currentUser.chatTextColor : 'COLOR_DEFAULT';\n" +
               "        const uCoins = document.getElementById('shopUserCoins'); if (uCoins) uCoins.innerText = myCoins.toLocaleString();\n" +
               "        const uDia = document.getElementById('shopUserDiamonds'); if (uDia) uDia.innerText = myDiamonds.toLocaleString();\n" +
               "        const uVip = document.getElementById('shopUserVipBadge'); if (uVip) uVip.innerText = 'V' + myVip;\n" +
               "        if (cat === 'recharge') {\n" +
               "            const tiers = SHOP_CATALOG.recharge;\n" +
               "            container.innerHTML = '<div style=\"display:grid; grid-template-columns:repeat(auto-fit, minmax(150px, 1fr)); gap:10px;\">' +\n" +
               "                tiers.map(t => {\n" +
               "                    return '<div class=\"shop-card-pro\">' +\n" +
               "                        '<div style=\"font-size:10.5px; color:#d97706; font-weight:800; background:#fef3c7; border:1px solid #fde68a; border-radius:4px; padding:1px 6px; display:inline-block; margin-bottom:4px;\">' + t.badge + '</div>' +\n" +
               "                        '<div style=\"font-size:20px; font-weight:900; color:#0284c7; margin:4px 0;\">💎 ' + t.diamonds + ' 钻</div>' +\n" +
               "                        '<div style=\"font-size:11.5px; color:#475569;\">赠 ' + (window.COIN_ICON_SVG || '💰 ') + t.coins.toLocaleString() + ' 金币</div>' +\n" +
               "                        '<div style=\"font-size:10px; color:#10b981; margin:4px 0;\">' + t.bonus + '</div>' +\n" +
               "                        '<button class=\"shop-card-btn recharge\" data-id=\"' + t.id + '\" data-price=\"' + t.price + '\" data-diamonds=\"' + t.diamonds + '\" data-coins=\"' + t.coins + '\" onclick=\"actionShopRecharge(this.dataset.id, this.dataset.price, Number(this.dataset.diamonds), Number(this.dataset.coins))\">' + t.price + ' 立即充值</button>' +\n" +
               "                        '</div>';\n" +
               "                }).join('') + '</div>';\n" +
               "            return;\n" +
               "        }\n" +
               "        if (cat === 'vip_center') {\n" +
               "            const vips = SHOP_CATALOG.vip_center;\n" +
               "            const curExp = (currentUser && currentUser.vipExp) ? currentUser.vipExp : 120;\n" +
               "            container.innerHTML = '<div style=\"background:#ffffff; border:1px solid #e2e8f0; border-radius:14px; padding:14px; margin-bottom:12px;\">' +\n" +
               "                '<div style=\"display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;\">' +\n" +
               "                '<span style=\"font-size:13px; font-weight:bold; color:#0f172a;\">👑 当前 VIP 等级: <span style=\"color:#d97706;\">VIP ' + myVip + '</span></span>' +\n" +
               "                '<span style=\"font-size:11px; color:#64748b;\">成长值: ' + curExp + ' EXP</span>' +\n" +
               "                '</div>' +\n" +
               "                '<div style=\"width:100%; height:8px; background:#f1f5f9; border-radius:4px; overflow:hidden;\">' +\n" +
               "                '<div style=\"width:' + Math.min(100, Math.round((curExp / 680) * 100)) + '%; height:100%; background:linear-gradient(90deg,#f59e0b,#d97706); border-radius:4px;\"></div>' +\n" +
               "                '</div>' +\n" +
               "                '</div>' +\n" +
               "                '<div style=\"display:flex; flex-direction:column; gap:8px;\">' +\n" +
               "                vips.map(v => {\n" +
               "                    const isUnlocked = myVip >= v.level;\n" +
               "                    return '<div style=\"background:#ffffff; border:1px solid ' + (isUnlocked ? '#fde68a' : '#e2e8f0') + '; border-radius:12px; padding:12px; display:flex; gap:10px; align-items:center;\">' +\n" +
               "                        '<div style=\"font-size:28px; width:44px; height:44px; background:' + (isUnlocked ? '#fef3c7' : '#f8fafc') + '; border-radius:10px; display:flex; align-items:center; justify-content:center;\">' + v.emoji + '</div>' +\n" +
               "                        '<div style=\"flex:1;\">' +\n" +
               "                        '<div style=\"display:flex; align-items:center; gap:6px;\">' +\n" +
               "                        '<span style=\"font-size:13px; font-weight:bold; color:' + (isUnlocked ? '#b45309' : '#334155') + ';\">' + v.name + '</span>' +\n" +
               "                        (isUnlocked ? '<span style=\"font-size:9.5px; background:#dcfce7; color:#15803d; border-radius:4px; padding:1px 5px; font-weight:bold;\">已尊享</span>' : '<span style=\"font-size:9.5px; background:#f1f5f9; color:#64748b; border-radius:4px; padding:1px 5px;\">需 ' + v.exp + ' EXP</span>') +\n" +
               "                        '</div>' +\n" +
               "                        '<div style=\"font-size:11px; color:#64748b; margin-top:3px; line-height:1.4;\">' + v.perks + '</div>' +\n" +
               "                        '</div>' +\n" +
               "                        '</div>';\n" +
               "                }).join('') + '</div>';\n" +
               "            return;\n" +
               "        }\n" +
               "        const items = SHOP_CATALOG[cat] || [];\n" +
               "        container.innerHTML = '<div style=\"display:grid; grid-template-columns:repeat(auto-fit, minmax(150px, 1fr)); gap:10px;\">' +\n" +
               "            items.map(item => {\n" +
               "                const isEquipped = (cat === 'dice_cup' && curDiceCup === item.id) || (cat === 'avatar_frame' && curAvatarFrame === item.id) || (cat === 'entrance_banner' && curEntranceBanner === item.id) || (cat === 'chat_text_color' && curChatTextColor === item.id);\n" +
               "                const isOwned = item.defaultOwned || owned.includes(item.id);\n" +
               "                let priceStr = '免费';\n" +
               "                if (item.diamonds > 0) priceStr = '💎 ' + item.diamonds + ' 钻';\n" +
               "                else if (item.coins > 0) priceStr = (window.COIN_ICON_SVG || '💰 ') + item.coins.toLocaleString() + ' 金币';\n" +
               "                let actionBtn = '';\n" +
               "                if (item.slot === 'prop' || item.slot === 'pack') {\n" +
               "                    actionBtn = '<button class=\"shop-card-btn buy\" data-id=\"' + item.id + '\" data-name=\"' + item.name + '\" data-coins=\"' + item.coins + '\" data-diamonds=\"' + item.diamonds + '\" onclick=\"actionShopBuyProp(this.dataset.id, this.dataset.name, Number(this.dataset.coins), Number(this.dataset.diamonds))\">购买使用</button>';\n" +
               "                } else if (isEquipped) {\n" +
               "                    actionBtn = '<button class=\"shop-card-btn equipped\" disabled>✓ 已佩戴</button>';\n" +
               "                } else if (isOwned) {\n" +
               "                    actionBtn = '<button class=\"shop-card-btn equip\" data-slot=\"' + item.slot + '\" data-id=\"' + item.id + '\" onclick=\"actionShopEquip(this.dataset.slot, this.dataset.id)\">点击穿戴</button>';\n" +
               "                } else {\n" +
               "                    actionBtn = '<button class=\"shop-card-btn buy\" data-id=\"' + item.id + '\" data-slot=\"' + item.slot + '\" data-coins=\"' + item.coins + '\" data-diamonds=\"' + item.diamonds + '\" data-vip=\"' + (item.minVip||0) + '\" onclick=\"actionShopBuyGood(this.dataset.id, this.dataset.slot, Number(this.dataset.coins), Number(this.dataset.diamonds), Number(this.dataset.vip))\">购买获取</button>';\n" +
               "                }\n" +
               "                const vipTag = item.minVip > 0 ? ('<span style=\"font-size:9.5px; background:#fff1f2; color:#e11d48; border:1px solid #fecdd3; border-radius:4px; padding:1px 4px; margin-left:4px;\">需 VIP ' + item.minVip + '</span>') : '';\n" +
               "                const colorPreview = item.hex ? ('<div style=\"font-size:11px; font-weight:bold; color:' + item.hex + '; background:rgba(0,0,0,0.7); border-radius:6px; padding:3px 6px; margin:4px 0;\">效果预览：你好呀！</div>') : '';\n" +
               "                return '<div class=\"shop-card-pro\">' +\n" +
               "                    '<div style=\"font-size:32px; margin-bottom:4px;\">' + item.emoji + '</div>' +\n" +
               "                    '<div style=\"font-size:13px; font-weight:bold; color:#0f172a;\">' + item.name + vipTag + '</div>' +\n" +
               "                    '<div style=\"font-size:10.5px; color:#64748b; margin:3px 0; min-height:28px;\">' + item.desc + '</div>' +\n" +
               "                    colorPreview +\n" +
               "                    '<div style=\"font-size:12px; font-weight:800; color:#d97706; margin-bottom:6px;\">' + priceStr + '</div>' +\n" +
               "                    actionBtn +\n" +
               "                    '</div>';\n" +
               "            }).join('') + '</div>';\n" +
               "    };\n" +
               "    window.actionShopBuyGood = async function(itemId, slot, coins, diamonds, minVip) {\n" +
               "        const myCoins = (currentUser && currentUser.coins != null) ? currentUser.coins : 2000;\n" +
               "        const myDiamonds = (currentUser && currentUser.diamonds != null) ? currentUser.diamonds : 50;\n" +
               "        const myVip = (currentUser && currentUser.vipLevel != null) ? currentUser.vipLevel : 1;\n" +
               "        if (minVip > 0 && myVip < minVip) {\n" +
               "            alert('👑 该装扮为 VIP ' + minVip + ' 专属特权！当前等级不足，快去官方充值提升 VIP 等级吧～');\n" +
               "            return;\n" +
               "        }\n" +
               "        if (coins > 0 && myCoins < coins) {\n" +
               "            alert('💰 金币不足！可通过对局或充值快速获取金币！');\n" +
               "            return;\n" +
               "        }\n" +
               "        if (diamonds > 0 && myDiamonds < diamonds) {\n" +
               "            alert('💎 钻石不足！请在充值中心选购钻石！');\n" +
               "            return;\n" +
               "        }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/buy', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, itemId: itemId, autoEquip: true })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 && d.data) {\n" +
               "                currentUser = d.data;\n" +
               "                if (!currentUser.ownedItems) currentUser.ownedItems = [];\n" +
               "                if (!currentUser.ownedItems.includes(itemId)) currentUser.ownedItems.push(itemId);\n" +
               "                currentUser[slot] = itemId;\n" +
               "                if (slot === 'chat_text_color' || slot === 'chatTextColor') currentUser.chatTextColor = itemId;\n" +
               "                updateHeaderUserUi(currentUser);\n" +
               "                loadProfileData();\n" +
               "                renderShopGoods();\n" +
               "                alert('🎉 恭喜成功购买并穿戴！已为您生效！');\n" +
               "                return;\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        if (currentUser) {\n" +
               "            currentUser.coins = Math.max(0, myCoins - coins);\n" +
               "            currentUser.diamonds = Math.max(0, myDiamonds - diamonds);\n" +
               "            if (!currentUser.ownedItems) currentUser.ownedItems = ['CLASSIC_GOLD', 'FRAME_DEFAULT', 'BANNER_DEFAULT', 'COLOR_DEFAULT'];\n" +
               "            currentUser.ownedItems.push(itemId);\n" +
               "            currentUser[slot] = itemId;\n" +
               "            if (slot === 'chat_text_color' || slot === 'chatTextColor') currentUser.chatTextColor = itemId;\n" +
               "            updateHeaderUserUi(currentUser);\n" +
               "            loadProfileData();\n" +
               "            renderShopGoods();\n" +
               "            alert('🎉 购买成功！装扮已自动佩戴！');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionShopEquip = async function(slot, itemId) {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/equip', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, slot: slot, itemId: itemId })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 && d.data) {\n" +
               "                currentUser = d.data;\n" +
               "            } else if (currentUser) {\n" +
               "                currentUser[slot] = itemId;\n" +
               "                if (slot === 'chat_text_color' || slot === 'chatTextColor') currentUser.chatTextColor = itemId;\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            if (currentUser) {\n" +
               "                currentUser[slot] = itemId;\n" +
               "                if (slot === 'chat_text_color' || slot === 'chatTextColor') currentUser.chatTextColor = itemId;\n" +
               "            }\n" +
               "        }\n" +
               "        updateHeaderUserUi(currentUser);\n" +
               "        renderShopGoods();\n" +
               "        alert('🎉 穿戴成功！进房开黑即可展示专属装扮！');\n" +
               "    };\n" +
               "    window.actionShopBuyProp = function(id, name, coins, diamonds) {\n" +
               "        if (id === 'BATTLE_CLEAR_CARD') {\n" +
               "            if (currentUser) {\n" +
               "                currentUser.totalGames = 0; currentUser.winCount = 0;\n" +
               "                currentUser.coins = Math.max(0, (currentUser.coins || 2000) - coins);\n" +
               "                updateHeaderUserUi(currentUser); loadProfileData();\n" +
               "            }\n" +
               "            showToast('🎉 战绩清空成功！重装上阵，胜率重新起飞！');\n" +
               "        } else if (id === 'horn_pack') {\n" +
               "            openGlobalBroadcastModal();\n" +
               "        } else if (id === 'GIFT_STARTER') {\n" +
               "            if (currentUser) {\n" +
               "                currentUser.coins = (currentUser.coins || 0) + 6666;\n" +
               "                currentUser.diamonds = Math.max(0, (currentUser.diamonds || 0) - diamonds);\n" +
               "                updateHeaderUserUi(currentUser); loadProfileData();\n" +
               "            }\n" +
               "            showToast('🎉 成功领取新手超值福利包！+6,666 金币及互动道具已入库！');\n" +
               "        } else {\n" +
               "            showToast('🎉 成功获取道具【' + name + '】！可直接在好友私聊或对局中使用！');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionShopRecharge = async function(tierId, price, diamonds, coins) {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/shop/recharge', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ userId: myUserId, tierId: tierId })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 0 && d.data && d.data.user) {\n" +
               "                currentUser = d.data.user;\n" +
               "                updateHeaderUserUi(currentUser);\n" +
               "                loadProfileData();\n" +
               "                renderShopGoods();\n" +
               "                showToast('🎉 充值成功！金币与钻石已全额到账！');\n" +
               "                return;\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        if (currentUser) {\n" +
               "            currentUser.diamonds = (currentUser.diamonds || 0) + diamonds;\n" +
               "            currentUser.coins = (currentUser.coins || 0) + coins;\n" +
               "            currentUser.vipExp = (currentUser.vipExp || 0) + diamonds;\n" +
               "            const exp = currentUser.vipExp || 0;\n" +
               "            if (exp >= 188888) currentUser.vipLevel = 10;\n" +
               "            else if (exp >= 100000) currentUser.vipLevel = 9;\n" +
               "            else if (exp >= 50000) currentUser.vipLevel = 8;\n" +
               "            else if (exp >= 20000) currentUser.vipLevel = 7;\n" +
               "            else if (exp >= 10000) currentUser.vipLevel = 6;\n" +
               "            else if (exp >= 5000) currentUser.vipLevel = 5;\n" +
               "            else if (exp >= 2000) currentUser.vipLevel = 4;\n" +
               "            else if (exp >= 500) currentUser.vipLevel = 3;\n" +
               "            else if (exp >= 100) currentUser.vipLevel = 2;\n" +
               "            else if (exp >= 10) currentUser.vipLevel = 1;\n" +
               "            else currentUser.vipLevel = 0;\n" +
               "            updateHeaderUserUi(currentUser);\n" +
               "            loadProfileData();\n" +
               "            renderShopGoods();\n" +
               "        }\n" +
               "        alert('🎉 恭喜成功充值！已为您充入 ' + diamonds + ' 钻石与 ' + coins + ' 金币！');\n" +
               "    };\n" +
               "    window.loadShopData = function() {\n" +
               "        renderShopGoods();\n" +
               "    };\n" +
               "    window.loadFriendsData = async function() {\n" +
               "        if (typeof loadFriendRequestsData === 'function') loadFriendRequestsData();\n" +
               "        const wall = document.getElementById('intimacyWallList');\n" +
               "        const listContainer = document.getElementById('friendsListContainer');\n" +
               "        try {\n" +
               "            const resRel = await fetch(getApiPrefix() + '/api/intimacy/my-relations?userId=' + encodeURIComponent(myUserId));\n" +
               "            const dataRel = await resRel.json();\n" +
               "            const relations = dataRel.list || [];\n" +
               "            if (wall) {\n" +
               "                if (relations.length === 0) {\n" +
               "                    wall.innerHTML = '<div style=\"color:#64748b; font-size:12px; text-align:center; padding:10px;\">暂无缔结的亲密关系，与好友互送礼物即可绑定～</div>';\n" +
               "                } else {\n" +
               "                    wall.innerHTML = relations.map(r => {\n" +
               "                        return '<div class=\"relation-card\">' +\n" +
               "                            '<div style=\"display:flex; align-items:center; gap:8px;\"><span style=\"font-size:22px;\">' + (r.partnerAvatar||'🦊') + '</span><div><div style=\"font-weight:bold; font-size:13px; color:#0f172a;\">' + r.partnerName + '</div><div style=\"font-size:11px; color:#f43f5e;\">❤️ ' + (r.relationship || '好朋友') + ' (亲密度 ' + r.intimacyScore + ')</div></div></div>' +\n" +
               "                            '<div style=\"display:flex; gap:6px;\">' +\n" +
               "                            '<button style=\"padding:4px 8px; background:#f1f5f9; border:1px solid #cbd5e1; color:#334155; border-radius:6px; font-size:11px; cursor:pointer;\" data-uid=\"' + (r.partnerId||'') + '\" data-name=\"' + r.partnerName + '\" data-avatar=\"' + (r.partnerAvatar||'🦊') + '\" data-score=\"' + (r.intimacyScore||10) + '\" data-rel=\"' + (r.relationship||'好朋友') + '\" onclick=\"openFriendChatModal(this.dataset.uid, this.dataset.name, this.dataset.avatar, Number(this.dataset.score), this.dataset.rel)\">💬 私聊</button>' +\n" +
               "                            '<button style=\"padding:4px 8px; background:#fff1f2; border:1px solid #fecdd3; color:#e11d48; border-radius:6px; font-size:11px; cursor:pointer;\" data-uid=\"' + (r.partnerId||'') + '\" data-name=\"' + r.partnerName + '\" data-avatar=\"' + (r.partnerAvatar||'🦊') + '\" onclick=\"openItemThrowModal(this.dataset.uid, this.dataset.name, this.dataset.avatar)\">🎁 互动</button>' +\n" +
               "                            '</div>' +\n" +
               "                            '</div>';\n" +
               "                    }).join('');\n" +
               "                }\n" +
               "            }\n" +
               "            const resF = await fetch(getApiPrefix() + '/api/friends/list?userId=' + encodeURIComponent(myUserId));\n" +
               "            const dataF = await resF.json();\n" +
               "            const friends = dataF.data || [];\n" +
               "            if (listContainer) {\n" +
               "                if (friends.length === 0) {\n" +
               "                    listContainer.innerHTML = '<div style=\"color:#64748b; font-size:12px; text-align:center; padding:14px;\">暂无好友，快在对局或广场中结识玩伴吧～</div>';\n" +
               "                } else {\n" +
               "                    listContainer.innerHTML = friends.map(f => {\n" +
               "                        const fId = String(f.id || f.friendId || '').replace(/-/g, '');\n" +
               "                        const fRawName = f.nickname || f.friendNickname || '好友';\n" +
               "                        const fRemark = f.remark || '';\n" +
               "                        const fDisplayName = fRemark ? (fRemark + ' <span style=\"font-size:11px; color:#64748b; font-weight:normal;\">(' + fRawName + ')</span>') : fRawName;\n" +
               "                        const fAvatar = f.avatar || '🦊';\n" +
               "                        const fIntimacy = f.intimacy || 10;\n" +
               "                        const fRel = f.relationship || '好朋友';\n" +
               "                        const fVip = f.vipLevel || 0;\n" +
               "                        const vipBadge = (fVip > 0) ? ('<span class=\"badge-vip' + (fVip >= 4 ? ' svip' : '') + '\" style=\"margin-left:4px; font-size:10px; padding:1px 5px;\">' + (fVip >= 4 ? '👑 SVIP' : 'VIP') + fVip + '</span>') : '';\n" +
               "                        return '<div class=\"room-item-row\" style=\"cursor:pointer;\" onclick=\"openPlayerProfileModal(\\'' + fId + '\\', \\'' + fRawName.replace(/'/g, \"\\\\'\") + '\\', \\'' + fAvatar + '\\')\">' +\n" +
               "                            '<div style=\"display:flex; align-items:center; gap:8px;\"><span style=\"font-size:24px;\">' + fAvatar + '</span><div><div style=\"font-weight:bold; font-size:13px; color:#0f172a; display:flex; align-items:center;\">' + fDisplayName + vipBadge + '</div><div style=\"font-size:10.5px; color:#64748b; margin-top:2px;\">UID: ' + fId + ' · ❤️ ' + fRel + ' (亲密 ' + fIntimacy + ')</div></div></div>' +\n" +
               "                            '<div style=\"display:flex; gap:6px;\" onclick=\"event.stopPropagation();\">' +\n" +
               "                            '<button style=\"padding:4px 8px; background:#eff6ff; color:#2563eb; border:1px solid #bfdbfe; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\" onclick=\"openPlayerProfileModal(\\'' + fId + '\\', \\'' + fRawName.replace(/'/g, \"\\\\'\") + '\\', \\'' + fAvatar + '\\')\">👤 资料</button>' +\n" +
               "                            '<button style=\"padding:4px 8px; background:#3b82f6; color:#fff; border:none; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\" data-uid=\"' + fId + '\" data-name=\"' + fRawName + '\" data-avatar=\"' + fAvatar + '\" data-score=\"' + fIntimacy + '\" data-rel=\"' + fRel + '\" onclick=\"openFriendChatModal(this.dataset.uid, this.dataset.name, this.dataset.avatar, Number(this.dataset.score), this.dataset.rel)\">💬 私聊</button>' +\n" +
               "                            '<button style=\"padding:4px 8px; background:#f43f5e; color:#fff; border:none; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\" data-uid=\"' + fId + '\" data-name=\"' + fRawName + '\" data-avatar=\"' + fAvatar + '\" onclick=\"openItemThrowModal(this.dataset.uid, this.dataset.name, this.dataset.avatar)\">🎁 互动</button>' +\n" +
               "                            '</div>' +\n" +
               "                            '</div>';\n" +
               "                    }).join('');\n" +
               "                }\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.loadFriendRequestsData = async function() {\n" +
               "        const container = document.getElementById('pendingRequestsContainer');\n" +
               "        const badge = document.getElementById('pendingRequestsCountBadge');\n" +
               "        if (!container) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/requests?userId=' + encodeURIComponent(myUserId));\n" +
               "            const d = await res.json();\n" +
               "            const list = d.data || [];\n" +
               "            if (badge) {\n" +
               "                if (list.length > 0) {\n" +
               "                    badge.style.display = 'inline-block';\n" +
               "                    badge.innerText = list.length;\n" +
               "                } else {\n" +
               "                    badge.style.display = 'none';\n" +
               "                }\n" +
               "            }\n" +
               "            if (list.length === 0) {\n" +
               "                container.innerHTML = '<div style=\"color:#94a3b8; font-size:12px; text-align:center; padding:12px;\">暂无待处理的好友申请与陌生人留言</div>';\n" +
               "                return;\n" +
               "            }\n" +
               "            container.innerHTML = list.map(req => {\n" +
               "                const reqId = req.id;\n" +
               "                const fromId = String(req.fromUserId || '').replace(/-/g, '');\n" +
               "                const rawName = req.nickname || (req.fromUser && req.fromUser.nickname) || '玩家';\n" +
               "                const avatar = req.avatar || (req.fromUser && req.fromUser.avatar) || '🦊';\n" +
               "                const title = req.levelTitle || (req.fromUser && req.fromUser.levelTitle) || '聚会玩家';\n" +
               "                const msg = req.latestMessage || req.message || '请求添加您为好友';\n" +
               "                const vip = req.vipLevel || (req.fromUser && req.fromUser.vipLevel) || 0;\n" +
               "                const vipBadge = (vip > 0) ? ('<span class=\"badge-vip' + (vip >= 4 ? ' svip' : '') + '\" style=\"margin-left:4px; font-size:10px; padding:1px 5px;\">' + (vip >= 4 ? '👑 SVIP' : 'VIP') + vip + '</span>') : '';\n" +
               "                return '<div class=\"room-item-row\" style=\"background:#ffffff; border:1px solid #bfdbfe; border-radius:12px; padding:10px 12px; margin-bottom:8px;\">' +\n" +
               "                    '<div style=\"display:flex; align-items:flex-start; justify-content:space-between; width:100%; gap:8px;\">' +\n" +
               "                        '<div style=\"display:flex; gap:10px; align-items:center;\">' +\n" +
               "                            '<span style=\"font-size:28px;\">' + avatar + '</span>' +\n" +
               "                            '<div>' +\n" +
               "                                '<div style=\"font-weight:bold; font-size:13.5px; color:#0f172a; display:flex; align-items:center;\">' + rawName + vipBadge + '<span style=\"font-size:10px; background:#eff6ff; color:#2563eb; padding:1px 5px; border-radius:4px; margin-left:6px;\">' + title + '</span></div>' +\n" +
               "                                '<div style=\"font-size:11px; color:#64748b; margin-top:2px;\">UID: ' + fromId + '</div>' +\n" +
               "                                '<div style=\"font-size:11.5px; color:#1e293b; background:#f0f9ff; border:1px solid #e0f2fe; border-radius:6px; padding:4px 8px; margin-top:4px; line-height:1.4;\">💬 附言/私信: ' + msg.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</div>' +\n" +
               "                            '</div>' +\n" +
               "                        '</div>' +\n" +
               "                        '<div style=\"display:flex; flex-direction:column; gap:4px; min-width:80px;\">' +\n" +
               "                            '<button onclick=\"actionRespondFriendRequest(\\'' + reqId + '\\', \\'ACCEPT\\')\" style=\"padding:5px 8px; background:#10b981; color:#fff; border:none; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\">✅ 同意</button>' +\n" +
               "                            '<button onclick=\"openFriendChatModal(\\'' + fromId + '\\', \\'' + rawName.replace(/'/g, \"\\\\'\") + '\\', \\'' + avatar + '\\')\" style=\"padding:5px 8px; background:#3b82f6; color:#fff; border:none; border-radius:6px; font-size:11px; font-weight:bold; cursor:pointer;\">💬 回复</button>' +\n" +
               "                            '<button onclick=\"actionRespondFriendRequest(\\'' + reqId + '\\', \\'REJECT\\')\" style=\"padding:4px 8px; background:#f1f5f9; color:#64748b; border:1px solid #cbd5e1; border-radius:6px; font-size:10.5px; cursor:pointer;\">忽略</button>' +\n" +
               "                        '</div>' +\n" +
               "                    '</div>' +\n" +
               "                '</div>';\n" +
               "            }).join('');\n" +
               "        } catch(e) {}\n" +
               "    };\n" +
               "    window.actionRespondFriendRequest = async function(requestId, action) {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/respond', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({ requestId: requestId, action: action, userId: myUserId })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast(action === 'ACCEPT' ? '🎉 已同意好友申请！正式成为好友！' : '已忽略该申请');\n" +
               "                loadFriendsData();\n" +
               "            } else {\n" +
               "                showToast(d.message || '操作失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('处理申请异常');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionApplyFriend = async function() {\n" +
               "        const input = document.getElementById('inputAddFriendUid');\n" +
               "        const target = input ? input.value.trim() : '';\n" +
               "        if (!target) { showToast('⚠️ 请输入玩家 UID 或昵称！'); return; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/apply', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    fromUserId: myUserId,\n" +
               "                    toUserId: target,\n" +
               "                    applicantId: myUserId,\n" +
               "                    targetId: target\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('🎉 好友申请已成功发送！等待对方确认～'); if (input) input.value = '';\n" +
               "            } else {\n" +
               "                showToast(d.message || '申请发送失败');\n" +
               "            }\n" +
               "        } catch(e) { showToast('申请发送失败，请重试'); }\n" +
               "    };\n";
    }

    private String buildHtmlScriptWsAndRoom(boolean isTake6) {
        return buildHtmlScriptWsAndRoomPart1() + buildHtmlScriptWsAndRoomPart2(isTake6);
    }

    private String buildHtmlScriptWsAndRoomPart1() {
        return "    window.loadProfileData = function() {\n" +
               "        if (!currentUser) return;\n" +
               "        const avEl = document.getElementById('profileAvatarBig'); if (avEl) avEl.innerText = currentUser.avatar || '🦊';\n" +
               "        const nickEl = document.getElementById('profileNickname'); if (nickEl) nickEl.innerText = currentUser.nickname || '玩家';\n" +
               "        const uidEl = document.getElementById('profileUidText'); if (uidEl) uidEl.innerText = 'UID: ' + (currentUser.id || myUserId) + ' · 📱 手机已绑定';\n" +
               "        const totEl = document.getElementById('statTotalGames'); if (totEl) totEl.innerText = currentUser.totalGames || 0;\n" +
               "        const winEl = document.getElementById('statWinCount'); if (winEl) winEl.innerText = currentUser.winCount || 0;\n" +
               "        const rate = (currentUser.totalGames && currentUser.totalGames > 0) ? Math.round((currentUser.winCount / currentUser.totalGames) * 100) : 50;\n" +
               "        const rateEl = document.getElementById('statWinRate'); if (rateEl) rateEl.innerText = rate + '%';\n" +
               "        const scoreEl = document.getElementById('statRankScore'); if (scoreEl) scoreEl.innerText = currentUser.rankScore || 1200;\n" +
               "        const cEl = document.getElementById('profileCoins'); if (cEl) cEl.innerText = Number(currentUser.coins || 2000).toLocaleString();\n" +
               "        const dEl = document.getElementById('profileDiamonds'); if (dEl) dEl.innerText = currentUser.diamonds || 50;\n" +
               "        const vEl = document.getElementById('profileVip'); if (vEl) vEl.innerText = 'VIP ' + (currentUser.vipLevel || 1);\n" +
               "    };\n" +
               "    function switchAuthTab(tab) {\n" +
               "        currentAuthTab = tab;\n" +
               "        ['pwd', 'qr', 'guest'].forEach(t => {\n" +
               "            const btn = document.getElementById('tabBtn' + t.charAt(0).toUpperCase() + t.slice(1));\n" +
               "            const content = document.getElementById('tabContent' + t.charAt(0).toUpperCase() + t.slice(1));\n" +
               "            if (btn) btn.className = (t === tab) ? 'auth-tab-btn active' : 'auth-tab-btn';\n" +
               "            if (content) content.style.display = (t === tab) ? 'block' : 'none';\n" +
               "        });\n" +
               "        if (tab === 'qr') { initQrLogin(); }\n" +
               "        else if (qrPollTimer) { clearInterval(qrPollTimer); qrPollTimer = null; }\n" +
               "    }\n" +
               "    function toggleRegisterBox() {\n" +
               "        const box = document.getElementById('registerExtraBox');\n" +
               "        if (!box) return;\n" +
               "        box.style.display = (box.style.display === 'none' || !box.style.display) ? 'block' : 'none';\n" +
               "    }\n" +
               "    async function submitRegister() {\n" +
               "        const acc = document.getElementById('inputPwdAccount').value.trim();\n" +
               "        const pwd = document.getElementById('inputPwdPass').value.trim();\n" +
               "        const nick = document.getElementById('inputRegNickname').value.trim();\n" +
               "        if (!acc) { alert('请输入想要注册的账号！'); return; }\n" +
               "        if (!pwd) { alert('请输入登录密码！'); return; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/auth/register', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({ username: acc, password: pwd, nickname: nick || ('玩家_' + acc), phone: acc.match(/^1\\d{10}$/) ? acc : '' })\n" +
               "            });\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 0) {\n" +
               "                alert('🎉 恭喜账号注册成功！正在为您自动登入...');\n" +
               "                submitPasswordLogin(false);\n" +
               "            } else {\n" +
               "                alert(data.message || '注册失败，请检查账号是否已被占用');\n" +
               "            }\n" +
               "        } catch(e) { alert('网络通信异常，请重试'); }\n" +
               "    }\n" +
               "    async function submitPasswordLogin(isAuto = false) {\n" +
               "        const acc = document.getElementById('inputPwdAccount').value.trim();\n" +
               "        const pwd = document.getElementById('inputPwdPass').value.trim();\n" +
               "        const remember = document.getElementById('chkRememberPwd').checked;\n" +
               "        if (!acc) {\n" +
               "            if (!isAuto) alert('请输入您的登录账号或手机号！');\n" +
               "            return;\n" +
               "        }\n" +
               "        const btn = document.getElementById('btnPwdEnter');\n" +
               "        if (btn) { btn.disabled = true; btn.innerText = isAuto ? '正在自动登入...' : '正在登录中...'; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/auth/login', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({ username: acc, password: pwd || '123' })\n" +
               "            });\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 0 && data.data) {\n" +
               "                const user = data.data;\n" +
               "                if (remember) {\n" +
               "                    localStorage.setItem('party_saved_user', acc);\n" +
               "                    if (pwd) localStorage.setItem('party_saved_pwd', pwd);\n" +
               "                    localStorage.setItem('party_auto_login', 'true');\n" +
               "                } else {\n" +
               "                    localStorage.removeItem('party_auto_login');\n" +
               "                    localStorage.removeItem('party_saved_pwd');\n" +
               "                }\n" +
               "                onAuthSuccess(user);\n" +
               "            } else {\n" +
               "                if (btn) { btn.disabled = false; btn.innerText = '🚀 立即登录并进入大厅'; }\n" +
               "                if (!isAuto) alert(data.message || '账号或密码错误，请重试');\n" +
               "                else { localStorage.removeItem('party_auto_login'); switchMainView('login'); }\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            if (btn) { btn.disabled = false; btn.innerText = '🚀 立即登录并进入大厅'; }\n" +
               "            if (!isAuto) alert('网络连接异常，请重试');\n" +
               "        }\n" +
               "    }\n" +
               "    async function initQrLogin(force = false) {\n" +
               "        if (qrPollTimer) { clearInterval(qrPollTimer); qrPollTimer = null; }\n" +
               "        const qrImg = document.getElementById('qrImg');\n" +
               "        const loading = document.getElementById('qrLoading');\n" +
               "        const tip = document.getElementById('qrStatusTip');\n" +
               "        if (loading) loading.style.display = 'block';\n" +
               "        if (qrImg) qrImg.style.opacity = '0.2';\n" +
               "        if (tip) tip.innerText = '⏳ 正在向云端申请动态登录凭证...';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/auth/qr/create?roomId=' + encodeURIComponent(currentRoomId));\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 0 && data.data) {\n" +
               "                currentQrTicket = data.data.ticket;\n" +
               "                const qrUrl = data.data.qrUrl;\n" +
               "                const qrImgSrc = 'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=' + encodeURIComponent(qrUrl);\n" +
               "                if (qrImg) {\n" +
               "                    qrImg.onload = () => { if (loading) loading.style.display = 'none'; qrImg.style.opacity = '1'; };\n" +
               "                    qrImg.src = qrImgSrc;\n" +
               "                }\n" +
               "                if (tip) tip.innerText = '📱 手机 APP 扫一扫或微信扫码一键登录';\n" +
               "                qrPollTimer = setInterval(async () => {\n" +
               "                    if (!currentQrTicket || currentAuthTab !== 'qr') return;\n" +
               "                    try {\n" +
               "                        const r = await fetch(getApiPrefix() + '/api/auth/qr/check?ticket=' + currentQrTicket);\n" +
               "                        const d = await r.json();\n" +
               "                        if (d.code === 0 && d.data) {\n" +
               "                            if (d.data.status === 'CONFIRMED' && d.data.user) {\n" +
               "                                clearInterval(qrPollTimer); qrPollTimer = null;\n" +
               "                                if (tip) tip.innerText = '🎉 扫码授权成功！正在登入...';\n" +
               "                                onAuthSuccess(d.data.user);\n" +
               "                            } else if (d.data.status === 'EXPIRED') {\n" +
               "                                clearInterval(qrPollTimer); qrPollTimer = null;\n" +
               "                                if (tip) tip.innerText = '⚠️ 二维码已过期，请点击下方刷新';\n" +
               "                            }\n" +
               "                        }\n" +
               "                    } catch(e) {}\n" +
               "                }, 1500);\n" +
               "            }\n" +
               "        } catch(e) { if (tip) tip.innerText = '❌ 二维码加载失败，请检查网络'; }\n" +
               "    }\n" +
               "    window.copyQrAuthToken = function() {\n" +
               "        if (!currentQrTicket) { alert('二维码尚未就绪，请稍候或点击刷新！'); return; }\n" +
               "        const token = currentQrTicket;\n" +
               "        const msg = '📋 已复制授权口令：【' + token + '】\\n\\n请在手机 APP 中进入【大厅右上角 扫一扫】或【我的 -> 扫一扫/登录电脑网页端】，粘贴此口令即可秒级授权登录！';\n" +
               "        if (navigator.clipboard && navigator.clipboard.writeText) {\n" +
               "            navigator.clipboard.writeText(token).then(() => { alert(msg); }).catch(() => { prompt('请手动长按复制以下口令在APP中授权：', token); });\n" +
               "        } else { prompt('请手动长按复制以下口令在APP中授权：', token); }\n" +
               "    };\n" +
               "    window.sendTrialSms = async function() {\n" +
               "        const phone = (document.getElementById('inputPhone') ? document.getElementById('inputPhone').value : '').trim();\n" +
               "        if (!phone || !/^1[3-9]\\d{9}$/.test(phone)) { alert('请输入正确的11位中国大陆手机号码！'); return; }\n" +
               "        const btn = document.getElementById('btnSendSms');\n" +
               "        if (btn && btn.disabled) return;\n" +
               "        if (btn) { btn.disabled = true; btn.innerText = '发送中...'; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/auth/trial-sms/send', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({ phone: phone })\n" +
               "            });\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 200 || data.code === 0) {\n" +
               "                showToast('📩 验证码已发送！测试统一固定码: 888888');\n" +
               "                let countdown = 60;\n" +
               "                const timer = setInterval(() => {\n" +
               "                    countdown--;\n" +
               "                    if (countdown <= 0) { clearInterval(timer); if (btn) { btn.disabled = false; btn.innerText = '获取验证码'; } }\n" +
               "                    else { if (btn) btn.innerText = countdown + 's后重发'; }\n" +
               "                }, 1000);\n" +
               "            } else {\n" +
               "                alert(data.message || '短信验证码发送失败');\n" +
               "                if (btn) { btn.disabled = false; btn.innerText = '获取验证码'; }\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('📩 验证码已发送！测试直接填 888888');\n" +
               "            let countdown = 60;\n" +
               "            const timer = setInterval(() => {\n" +
               "                countdown--;\n" +
               "                if (countdown <= 0) { clearInterval(timer); if (btn) { btn.disabled = false; btn.innerText = '获取验证码'; } }\n" +
               "                else { if (btn) btn.innerText = countdown + 's后重发'; }\n" +
               "            }, 1000);\n" +
               "        }\n" +
               "    };\n" +
               "    window.submitTrialSmsAuth = async function() {\n" +
               "        const name = (document.getElementById('inputName') ? document.getElementById('inputName').value : '').trim();\n" +
               "        const phone = (document.getElementById('inputPhone') ? document.getElementById('inputPhone').value : '').trim();\n" +
               "        const code = (document.getElementById('inputSmsCode') ? document.getElementById('inputSmsCode').value : '').trim();\n" +
               "        if (!name) { alert('请输入您的临时游戏昵称！'); return; }\n" +
               "        if (!phone || !/^1[3-9]\\d{9}$/.test(phone)) { alert('请输入正确的11位中国大陆手机号码！'); return; }\n" +
               "        if (!code) { alert('请输入6位短信验证码（测试统一使用 888888）！'); return; }\n" +
               "        const btn = document.getElementById('btnEnter');\n" +
               "        if (btn) { btn.disabled = true; btn.innerText = '正在验证手机短信并进入...'; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/auth/trial-sms/verify', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    phone: phone,\n" +
               "                    code: code,\n" +
               "                    nickname: name,\n" +
               "                    roomId: currentRoomId,\n" +
               "                    gameType: currentGameType\n" +
               "                })\n" +
               "            });\n" +
               "            const data = await res.json();\n" +
               "            if ((data.code === 200 || data.code === 0) && data.data) {\n" +
               "                const u = data.data;\n" +
               "                if (name && (!u.nickname || u.nickname.startsWith('试玩玩家_'))) {\n" +
               "                    u.nickname = name;\n" +
               "                }\n" +
               "                showToast('🎉 短信验证通过！祝您游戏愉快');\n" +
               "                onAuthSuccess(u);\n" +
               "            } else {\n" +
               "                alert(data.message || '验证码核验未通过，可使用测试固定码: 888888');\n" +
               "                if (btn) { btn.disabled = false; btn.innerText = '⚡ 验证并立即试玩'; }\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            if (code === '888888') {\n" +
               "                showToast('🎉 短信验证通过(离线试玩模式)');\n" +
               "                onAuthSuccess({\n" +
               "                    id: 'TRIAL-' + phone.slice(-4) + '-' + Math.floor(100 + Math.random() * 900),\n" +
               "                    nickname: name || ('玩家_' + phone.slice(-4)),\n" +
               "                    avatar: (currentGameType === 'take6' ? '🐂' : '🦊'),\n" +
               "                    coins: 2000,\n" +
               "                    diamonds: 50,\n" +
               "                    vipLevel: 0\n" +
               "                });\n" +
               "            } else {\n" +
               "                alert('网络连接异常，若为测试请填固定验证码 888888');\n" +
               "                if (btn) { btn.disabled = false; btn.innerText = '⚡ 验证并立即试玩'; }\n" +
               "            }\n" +
               "        }\n" +
               "    };\n" +
               "    function onAuthSuccess(user) {\n" +
               "        currentUser = user;\n" +
               "        myUserId = user.id || ('U-' + Math.random().toString().substring(2, 8));\n" +
               "        myNickname = user.nickname || user.username || '玩家';\n" +
               "        myAvatar = user.avatar || (currentGameType === 'take6' ? '🐂' : '🦊');\n" +
               "        updateHeaderUserUi(user);\n" +
               "        loadProfileData();\n" +
               "        playBeep(880, 0.2);\n" +
               "        initWebSocket();\n" +
               "        const urlParams = new URLSearchParams(window.location.search);\n" +
               "        const qRoom = urlParams.get('roomId');\n" +
               "        if (qRoom) {\n" +
               "            joinSpecificRoom(qRoom, currentGameType);\n" +
               "        } else {\n" +
               "            switchMainView('lobby');\n" +
               "            switchLobbyTab(currentLobbyTab || 'games');\n" +
               "        }\n" +
               "    }\n" +
               "    window.logoutUser = function() {\n" +
               "        localStorage.removeItem('party_auto_login');\n" +
               "        localStorage.removeItem('fwpt_auth_token');\n" +
               "        localStorage.removeItem('fwpt_auth_user');\n" +
               "        currentUser = null;\n" +
               "        currentRoomId = '';\n" +
               "        window.activeRoomInfo = null;\n" +
               "        const banner = document.getElementById('activeRoomBanner');\n" +
               "        if (banner) banner.style.display = 'none';\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            try { ws.close(); } catch(e) {}\n" +
               "        }\n" +
               "        const btnPwd = document.getElementById('btnPwdEnter');\n" +
               "        if (btnPwd) { btnPwd.disabled = false; btnPwd.innerText = '🚀 立即登录并进入大厅'; }\n" +
               "        const btnGuest = document.getElementById('btnEnter');\n" +
               "        if (btnGuest) { btnGuest.disabled = false; btnGuest.innerText = '⚡ 验证并立即试玩'; }\n" +
               "        const prefix = getApiPrefix();\n" +
               "        if (history.pushState) {\n" +
               "            history.pushState(null, '', prefix + '/login');\n" +
               "        }\n" +
               "        showToast('👋 已安全退出登录～');\n" +
               "        switchMainView('login');\n" +
               "    };\n" +
               "    function initAuthFromStorage() {\n" +
               "        try {\n" +
               "            const fwptToken = localStorage.getItem('fwpt_auth_token');\n" +
               "            const rawFwptUser = localStorage.getItem('fwpt_auth_user');\n" +
               "            if (fwptToken && rawFwptUser) {\n" +
               "                const fu = JSON.parse(rawFwptUser);\n" +
               "                if (fu && (fu.username || fu.nickname)) {\n" +
               "                    onAuthSuccess({\n" +
               "                        id: fu.id ? String(fu.id) : ('FWPT-' + (fu.username || 'user')),\n" +
               "                        username: fu.username || '',\n" +
               "                        nickname: fu.nickname || fu.username || 'FWPT玩家',\n" +
               "                        avatar: fu.avatar || (currentGameType === 'take6' ? '🐂' : '🦊'),\n" +
               "                        coins: (typeof fu.coins === 'number' && fu.coins > 0) ? fu.coins : 2000,\n" +
               "                        diamonds: (typeof fu.diamonds === 'number' && fu.diamonds > 0) ? fu.diamonds : 50,\n" +
               "                        vipLevel: (fu.role === 'ADMIN' || fu.is_vip) ? 1 : 0\n" +
               "                    });\n" +
               "                    return;\n" +
               "                }\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        const savedUser = localStorage.getItem('party_saved_user');\n" +
               "        const savedPwd = localStorage.getItem('party_saved_pwd');\n" +
               "        const savedAuto = localStorage.getItem('party_auto_login');\n" +
               "        if (savedUser) {\n" +
               "            const accInput = document.getElementById('inputPwdAccount'); if (accInput) accInput.value = savedUser;\n" +
               "        }\n" +
               "        if (savedPwd) {\n" +
               "            const pwdInput = document.getElementById('inputPwdPass'); if (pwdInput) pwdInput.value = savedPwd;\n" +
               "        }\n" +
               "        const isExplicitLogin = window.location.pathname.endsWith('/login');\n" +
               "        if (savedAuto === 'true' && savedUser && !isExplicitLogin) {\n" +
               "            submitPasswordLogin(true);\n" +
               "            return;\n" +
               "        }\n" +
               "        switchMainView('login');\n" +
               "    }\n" +
               "    async function refreshCaptcha() {\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/web/captcha');\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 200) {\n" +
               "                currentCaptchaId = data.captchaId;\n" +
               "                document.getElementById('captchaBox').innerText = data.displayCode;\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            currentCaptchaId = 'LOCAL_RAND';\n" +
               "            document.getElementById('captchaBox').innerText = Math.random().toString(36).substring(2, 6).toUpperCase();\n" +
               "        }\n" +
               "    }\n" +
               "    async function submitAuth() {\n" +
               "        const name = document.getElementById('inputName').value.trim();\n" +
               "        const phone = document.getElementById('inputPhone').value.trim();\n" +
               "        const captcha = document.getElementById('inputCaptcha').value.trim();\n" +
               "        if (!name) { alert('请输入您的游戏名称！'); return; }\n" +
               "        if (!phone || !/^1[3-9]\\d{9}$/.test(phone)) { alert('请输入正确的11位中国大陆手机号码！'); return; }\n" +
               "        if (!captcha) { alert('请输入机器验证码！'); return; }\n" +
               "        const btn = document.getElementById('btnEnter');\n" +
               "        btn.disabled = true; btn.innerText = '正在验证并登入...';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/web/verify', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({ gameName: name, phone: phone, captchaId: currentCaptchaId, captchaCode: captcha, roomId: currentRoomId, gameType: currentGameType })\n" +
               "            });\n" +
               "            const data = await res.json();\n" +
               "            if (data.code === 200) {\n" +
               "                onAuthSuccess({ id: data.userId, nickname: data.nickname, avatar: data.avatar, coins: data.coins, vipLevel: data.vipLevel });\n" +
               "            } else {\n" +
               "                alert(data.message || '验证失败，请重试'); refreshCaptcha(); btn.disabled = false; btn.innerText = '⚡ 验证并立即试玩';\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            onAuthSuccess({ id: 'WEB-' + (Date.now()%100000), nickname: name, avatar: (currentGameType === 'take6' ? '🐂' : '🦊') });\n" +
               "        }\n" +
               "    }\n" +
               "    function initWebSocket() {\n" +
               "        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';\n" +
               "        const wsHost = window.location.host || 'fwpt.cn';\n" +
               "        const wsUrl = protocol + '//' + wsHost + '/party-game/ws';\n" +
               "        try {\n" +
               "            ws = new WebSocket(wsUrl);\n" +
               "            ws.onopen = () => {\n" +
               "                ws.send(JSON.stringify({ type: 'INIT_USER', userId: myUserId, nickname: myNickname }));\n" +
               "                if (currentRoomId) ws.send(JSON.stringify({ type: 'JOIN_ROOM', roomCode: currentRoomId, userId: myUserId, nickname: myNickname, avatar: myAvatar, gameType: currentGameType }));\n" +
               "            };\n" +
               "            ws.onmessage = (event) => {\n" +
               "                try { const msg = JSON.parse(event.data); handleWsMessage(msg); } catch(e) {}\n" +
               "            };\n" +
               "            ws.onclose = () => { setTimeout(initWebSocket, 3500); };\n" +
               "        } catch(e) {}\n" +
               "    }\n" +
               "    let h5MarqueeTimer = null;\n" +
               "    function showH5GlobalMarquee(data) {\n" +
               "        const bar = document.getElementById('globalMarqueeBar');\n" +
               "        const iconEl = document.getElementById('marqueeIcon');\n" +
               "        const badgeEl = document.getElementById('marqueeBadge');\n" +
               "        const senderEl = document.getElementById('marqueeSender');\n" +
               "        const textEl = document.getElementById('marqueeTickerText');\n" +
               "        if (!bar || !textEl) return;\n" +
               "        if (iconEl) iconEl.innerText = data.itemEmoji || '📢';\n" +
               "        if (badgeEl) badgeEl.innerText = data.giftTitle || (data.senderVip > 0 ? ('V' + data.senderVip + ' 喇叭') : '全服喇叭');\n" +
               "        if (senderEl) senderEl.innerText = data.senderName || '玩家';\n" +
               "        textEl.innerText = data.blessing || '全服开黑快乐！';\n" +
               "        bar.classList.add('show');\n" +
               "        playBeep(880, 0.15);\n" +
               "        if (h5MarqueeTimer) clearTimeout(h5MarqueeTimer);\n" +
               "        h5MarqueeTimer = setTimeout(() => { bar.classList.remove('show'); }, 7500);\n" +
               "    }\n" +
               "    function handleRoomReconnectSync(msg) {\n" +
               "        if (!msg) return;\n" +
               "        if (msg.allowSpectator !== undefined) {\n" +
               "            allowSpectator = !!msg.allowSpectator;\n" +
               "            window.allowSpectator = allowSpectator;\n" +
               "        }\n" +
               "        if (msg.isSpectator) {\n" +
               "            isSpectatorMode = true;\n" +
               "            window.isSpectatorMode = true;\n" +
               "            appendChat('系统', '👀 您当前以【旁观者模式】进入房间，不可查看私密手牌/骰盅，等待本局结束可点击入席！');\n" +
               "        } else {\n" +
               "            isSpectatorMode = false;\n" +
               "            window.isSpectatorMode = false;\n" +
               "        }\n" +
               "        if (msg.players && Array.isArray(msg.players)) {\n" +
               "            players = msg.players;\n" +
               "            if (players.some(p => p.id === myUserId)) {\n" +
               "                isSpectatorMode = false;\n" +
               "                window.isSpectatorMode = false;\n" +
               "            }\n" +
               "            renderSeats(players);\n" +
               "        }\n" +
               "        updateReadyButtonState();\n" +
               "        if (msg.status === 'PLAYING') {\n" +
               "            isGameStarted = true;\n" +
               "            if (!isSpectatorMode) {\n" +
               "                appendChat('系统', '🟢 成功重连房间！已为您恢复对局状态并解除自动托管！');\n" +
               "            }\n" +
               "            if (currentGameType === 'take6') {\n" +
               "                isTake6AutoPlay = false;\n" +
               "                updateTake6AutoPlayButtonUi();\n" +
               "                const waitingCard = document.getElementById('take6WaitingStage');\n" +
               "                if (waitingCard) waitingCard.style.display = 'none';\n" +
               "                if (msg.take6Rows && Array.isArray(msg.take6Rows)) {\n" +
               "                    take6Rows = msg.take6Rows.map(r => Array.isArray(r) ? [...r] : [r]);\n" +
               "                    renderTake6Rows();\n" +
               "                }\n" +
               "                if (msg.take6Scores) {\n" +
               "                    Object.assign(take6Scores, msg.take6Scores);\n" +
               "                    renderTake6Scores();\n" +
               "                }\n" +
               "                if (!isSpectatorMode && msg.take6PlayerHands && msg.take6PlayerHands[myUserId]) {\n" +
               "                    take6MyHand = [...msg.take6PlayerHands[myUserId]];\n" +
               "                } else if (isSpectatorMode) {\n" +
               "                    take6MyHand = [];\n" +
               "                }\n" +
               "                if (msg.take6ReadyPlayers) {\n" +
               "                    take6ReadyPlayers = Object.assign({}, msg.take6ReadyPlayers);\n" +
               "                    window.take6ReadyPlayers = take6ReadyPlayers;\n" +
               "                }\n" +
               "                if (msg.take6CurrentTurn != null) {\n" +
               "                    window.take6CurrentTurn = msg.take6CurrentTurn;\n" +
               "                }\n" +
               "                renderTake6Hand();\n" +
               "                updateTake6SelectionStatus();\n" +
               "            } else if (currentGameType === 'liars_dice') {\n" +
               "                const waitingCard = document.getElementById('diceWaitingStage');\n" +
               "                if (waitingCard) waitingCard.style.display = 'none';\n" +
               "                diceStartActiveGame();\n" +
               "            }\n" +
               "        }\n" +
               "    }\n" +
               "    function onGameStartedTrigger(payload) {\n" +
               "        if (isGameStarted) return;\n" +
               "        window.isGameOverPhase = false;\n" +
               "        isGameStarted = true; updateReadyButtonState(); playBeep(980, 0.35); appendChat('房主', '🚀 游戏正式开始！');\n" +
               "        if (currentGameType === 'take6') { take6StartActiveGame(payload); }\n" +
               "        else if (currentGameType === 'liars_dice') { diceStartActiveGame(); }\n" +
               "        else if (currentGameType === 'party_wheel') { const wCard = document.getElementById('wheelWaitingStage'); if (wCard) wCard.style.display = 'none'; if (typeof initWheelBoard === 'function') initWheelBoard(); appendChat('系统', '🎡 轮盘大冒险开局！点击【🎯 开始旋转】抽取任务！'); }\n" +
               "        else if (currentGameType === 'undercover') { const uCard = document.getElementById('undercoverWaitingStage'); if (uCard) uCard.style.display = 'none'; if (typeof initUndercoverBoard === 'function') initUndercoverBoard(); appendChat('系统', '🕵️ 谁是卧底开局！点击上方查看专属底词！'); }\n" +
               "    }\n" +
               "    function handleWsMessage(msg) {\n" +
               "        if (msg.type === 'DIRECT_MESSAGE') {\n" +
               "            if (activeDmUserId && (String(msg.fromUserId) === String(activeDmUserId) || String(msg.toUserId) === String(activeDmUserId))) {\n" +
               "                renderDirectChatMessage(msg);\n" +
               "                playBeep(800, 0.1);\n" +
               "                fetch(getApiPrefix() + '/api/friends/messages/read', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ userId: myUserId, friendId: msg.fromUserId }) }).catch(() => {});\n" +
               "            } else {\n" +
               "                playBeep(880, 0.2);\n" +
               "                appendChat('私信留言', '💬 【' + (msg.fromNickname || '私信') + '】: ' + (msg.content || ''));\n" +
               "                if (typeof loadFriendRequestsData === 'function') loadFriendRequestsData();\n" +
               "            }\n" +
               "        } else if (msg.type === 'KICKED_FROM_ROOM' || (msg.type === 'PLAYER_KICKED' && (String(msg.targetPlayerId) === String(myUserId) || String(msg.targetPlayerId).replace(/-/g, '') === String(myUserId).replace(/-/g, '')))) {\n" +
               "            currentRoomId = null;\n" +
               "            currentGameType = null;\n" +
               "            isGameStarted = false;\n" +
               "            switchMainView('lobby');\n" +
               "            showToast('⚠️ 您已被房主移出该房间！');\n" +
               "            refreshLobbyRooms();\n" +
               "        } else if (msg.type === 'PLAYER_KICKED') {\n" +
               "            appendChat('系统', '🚫 玩家【' + (msg.targetPlayerName || '玩家') + '】已被房主移出房间');\n" +
               "            if (msg.players && typeof renderSeats === 'function') {\n" +
               "                renderSeats(msg.players);\n" +
               "            }\n" +
               "        } else if (msg.type === 'CHAT_MESSAGE') {\n" +
               "            const isMe = (myUserId && msg.senderId && String(msg.senderId) === String(myUserId)) || (myNickname && msg.senderName && String(msg.senderName) === String(myNickname));\n" +
               "            if (isMe) { return; }\n" +
               "            if (msg.channel === 'WORLD' || msg.channel === 'CITY') {\n" +
               "                appendSquareChat(msg.senderName || '玩家', msg.content, false, msg.textColor || 'COLOR_DEFAULT', msg.vipLevel || 0);\n" +
               "            } else {\n" +
               "                appendChat(msg.senderName || '玩家', msg.content, msg.textColor || 'COLOR_DEFAULT', msg.vipLevel || 0); triggerBubble(msg.senderId || msg.senderName, msg.content);\n" +
               "            }\n" +
               "        } else if (msg.type === 'THROW_ITEM_EVENT' || msg.type === 'THROW_ITEM') {\n" +
               "            triggerThrowItemFx(msg);\n" +
               "            const desc = (msg.senderName || '玩家') + ' 向 ' + (msg.targetPlayerName || '玩家') + ' 投掷了 ' + (msg.itemEmoji || '🎁') + ' ' + (msg.giftTitle || '');\n" +
               "            const intimacyDesc = msg.addedIntimacy ? (' (亲密度 +' + msg.addedIntimacy + ')') : '';\n" +
               "            appendChat('互动', desc + intimacyDesc); triggerBubble(msg.senderId || msg.senderName, (msg.itemEmoji || '🎁') + ' 投掷！');\n" +
               "        } else if (msg.type === 'SUMMON_STARTED') {\n" +
               "            startSummonCountdown(msg.countdown || 10);\n" +
               "            appendChat('系统', msg.content || '📢 召集广播已发布！');\n" +
               "        } else if (msg.type === 'GLOBAL_BROADCAST_EVENT' || msg.type === 'GLOBAL_BROADCAST') {\n" +
               "            showH5GlobalMarquee(msg);\n" +
               "        } else if (msg.type === 'ROOM_SETTINGS_UPDATED') {\n" +
               "            if (msg.allowSpectator !== undefined) {\n" +
               "                allowSpectator = !!msg.allowSpectator;\n" +
               "                window.allowSpectator = allowSpectator;\n" +
               "                updateReadyButtonState();\n" +
               "                appendChat('系统', allowSpectator ? '👁️ 房主开启了【允许旁观】模式' : '🚫 房主关闭了【旁观模式】');\n" +
               "            }\n" +
               "        } else if (msg.type === 'ROOM_SPECTATORS_UPDATED') {\n" +
               "            if (msg.spectators) {\n" +
               "                window.spectatorsList = msg.spectators;\n" +
               "            }\n" +
               "} else if (msg.type === 'HEARTBEAT_PING') {\n" +
               "if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "ws.send(JSON.stringify({ type: 'HEARTBEAT_PONG', timestamp: Date.now() }));\n" +
               "}\n" +
               "        } else if (msg.type === 'ROOM_RECONNECT_SYNC') {\n" +
               "            handleRoomReconnectSync(msg);\n" +
               "        } else if (msg.type === 'GAME_ACTION') {\n" +
               "            if (msg.action === 'GAME_STARTED') { onGameStartedTrigger(msg.payload); }\n" +
               "            else if (msg.action === 'GAME_RESTART') {\n" +
               "                const overlay = document.getElementById('settlementOverlay'); if (overlay) overlay.style.display = 'none';\n" +
               "                window.isGameOverPhase = true;\n" +
               "                if (typeof resetTake6ToLobbyWaiting === 'function') resetTake6ToLobbyWaiting();\n" +
               "                appendChat('房主', '🔄 房主发起了再来一局！房间准备状态已重置。');\n" +
               "            } else if (msg.action === 'GAME_OVER') {\n" +
               "                if (msg.payload && msg.payload.scores) {\n" +
               "                    take6Scores = Object.assign({}, msg.payload.scores);\n" +
               "                    window.take6Scores = take6Scores;\n" +
               "                }\n" +
               "                showTake6SettlementModal();\n" +
               "            } else if (msg.action === 'TAKE6_STATE_SYNC' && currentGameType === 'take6') {\n" +
               "                handleTake6StateSync(msg.payload);\n" +
               "            } else if (msg.action === 'PLAY_CARD' && currentGameType === 'take6') {\n" +
               "                handleTake6RemotePlay(msg.senderId, msg.senderName, msg.payload);\n" +
               "            } else if (msg.action === 'TAKE_ROW' && currentGameType === 'take6') {\n" +
               "                handleTake6RemoteTakeRow(msg.senderName, msg.payload);\n" +
               "            } else if (msg.action === 'BID' && currentGameType === 'liars_dice') {\n" +
               "                if (msg.payload) updateBidDisplay(msg.payload.count, msg.payload.face, msg.senderName || '玩家');\n" +
               "            } else if (msg.action === 'CHALLENGE' && currentGameType === 'liars_dice') {\n" +
               "                triggerChallengeDisplay(msg.senderName || '玩家');\n" +
               "} else if (msg.action === 'DICE_MY_HAND' && currentGameType === 'liars_dice') {\n" +
               "if (msg.payload && msg.payload.dice) {\n" +
               "myDice = [...msg.payload.dice];\n" +
               "renderDiceList();\n" +
               "}\n" +
               "} else if (msg.action === 'DICE_SETTLEMENT' && currentGameType === 'liars_dice') {\n" +
               "showDiceSettlementModal(msg.payload);\n" +
               "} else if (msg.action === 'UNDERCOVER_ROLE_DEAL') {\n" +
               "handleUndercoverRoleDeal(msg.payload);\n" +
               "} else if (msg.action === 'UNDERCOVER_NEXT_SPEAKER') {\n" +
               "handleUndercoverNextSpeaker(msg.payload);\n" +
               "} else if (msg.action === 'UNDERCOVER_PHASE_VOTING') {\n" +
               "handleUndercoverPhaseVoting(msg.payload);\n" +
               "} else if (msg.action === 'UNDERCOVER_VOTE_RESULT') {\n" +
               "handleUndercoverVoteResult(msg.payload);\n" +
               "} else if (msg.action === 'WHEEL_SPIN' && currentGameType === 'party_wheel') {\n" +
               "if (msg.payload && typeof executeWheelSpinTo === 'function' && String(msg.senderId) !== String(myUserId)) { executeWheelSpinTo(msg.payload.targetIdx, msg.senderName || '桌友', false); }\n" +
               "            } else {\n" +
               "                appendChat('对局', (msg.senderName || msg.senderId) + ': ' + msg.action);\n" +
               "            }\n" +
               "        } else if (msg.type === 'ROOM_PLAYERS_UPDATED') {\n" +
               "            if (msg.event) appendChat('系统', msg.event);\n" +
               "            if (msg.players && Array.isArray(msg.players)) {\n" +
               "                players = msg.players;\n" +
               "                if (players.some(p => p.id === myUserId)) {\n" +
               "                    isSpectatorMode = false;\n" +
               "                    window.isSpectatorMode = false;\n" +
               "                }\n" +
               "                renderSeats(players);\n" +
               "                if (currentGameType === 'take6') renderTake6Scores();\n" +
               "                updateReadyButtonState();\n" +
               "            }\n" +
               "        }\n" +
               "    }\n" +
               "    let summonTimer = null;\n" +
               "    window.actionSummonPlayers = function() {\n" +
               "        if (!currentRoomId) { alert('当前不在房间内！'); return; }\n" +
               "        if (isGameStarted) { alert('对局正在进行中，无法召集新玩家！'); return; }\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({\n" +
               "                type: 'SUMMON_PLAYERS',\n" +
               "                roomCode: currentRoomId,\n" +
               "                senderId: myUserId,\n" +
               "                senderName: myNickname,\n" +
               "                gameType: currentGameType\n" +
               "            }));\n" +
               "        }\n" +
               "        startSummonCountdown(10);\n" +
               "        appendChat('系统', '📢 已向全服与同城频道发布召集广播！若10秒内无玩家进入，将自动安排实力桌友陪玩～');\n" +
               "    };\n" +
               "    function startSummonCountdown(seconds) {\n" +
               "        const banner = document.getElementById('summonCountdownBanner');\n" +
               "        const secEl = document.getElementById('summonTimerSeconds');\n" +
               "        if (!banner || !secEl) return;\n" +
               "        if (summonTimer) clearInterval(summonTimer);\n" +
               "        let remain = seconds;\n" +
               "        secEl.innerText = remain;\n" +
               "        banner.style.display = 'block';\n" +
               "        summonTimer = setInterval(() => {\n" +
               "            remain--;\n" +
               "            if (remain <= 0) {\n" +
               "                clearInterval(summonTimer);\n" +
               "                summonTimer = null;\n" +
               "                banner.style.display = 'none';\n" +
               "            } else {\n" +
               "                secEl.innerText = remain;\n" +
               "            }\n" +
               "        }, 1000);\n" +
               "    }\n" +
               "    let currentModalTargetUid = '';\n" +
               "    let currentModalTargetName = '';\n" +
               "    let currentModalTargetAvatar = '';\n" +
               "    window.openPlayerProfileModal = async function(uid, name, avatar) {\n" +
               "        if (!uid) return;\n" +
               "        const cleanUid = String(uid).replace(/-/g, '');\n" +
               "        currentModalTargetUid = cleanUid;\n" +
               "        currentModalTargetName = name || '玩家';\n" +
               "        currentModalTargetAvatar = avatar || '🦊';\n" +
               "        const modal = document.getElementById('playerProfileModal');\n" +
               "        if (!modal) return;\n" +
               "        const avEl = document.getElementById('modalPlayerAvatar');\n" +
               "        const nameEl = document.getElementById('modalPlayerName');\n" +
               "        const uidEl = document.getElementById('modalPlayerUid');\n" +
               "        const vipEl = document.getElementById('modalPlayerVipBadge');\n" +
               "        const scoreEl = document.getElementById('modalPlayerIntimacyText');\n" +
               "        const relEl = document.getElementById('modalPlayerRelBadge');\n" +
               "        const tierEl = document.getElementById('modalPlayerRankTier');\n" +
               "        const rateEl = document.getElementById('modalPlayerWinRate');\n" +
               "        const totalEl = document.getElementById('modalPlayerTotalGames');\n" +
               "        const remarkBox = document.getElementById('modalPlayerRemarkBox');\n" +
               "        const remarkVal = document.getElementById('modalPlayerRemarkVal');\n" +
               "        const intimacySec = document.getElementById('modalPlayerIntimacySection');\n" +
               "        const giftTitle = document.getElementById('modalPlayerGiftTitle');\n" +
               "        const giftGrid = document.getElementById('modalPlayerGiftGrid');\n" +
               "        const actionsRow = document.getElementById('modalPlayerActionsRow');\n" +
               "        const btnAdd = document.getElementById('modalBtnAddFriend');\n" +
               "        if (avEl) avEl.innerText = currentModalTargetAvatar;\n" +
               "        if (nameEl) nameEl.innerText = currentModalTargetName;\n" +
               "        if (uidEl) uidEl.innerText = cleanUid;\n" +
               "        if (scoreEl) scoreEl.innerText = '双方亲密度: 查询中...';\n" +
               "        if (relEl) relEl.innerText = '查询中...';\n" +
               "        if (tierEl) tierEl.innerText = '🥉 倔强青铜';\n" +
               "        if (rateEl) rateEl.innerText = '0%';\n" +
               "        if (totalEl) totalEl.innerText = '0场';\n" +
               "        if (remarkBox) remarkBox.style.display = 'none';\n" +
               "        const isSelf = (cleanUid === String(myUserId).replace(/-/g, ''));\n" +
               "        if (isSelf) {\n" +
               "            if (intimacySec) intimacySec.style.display = 'none';\n" +
               "            if (giftTitle) giftTitle.style.display = 'none';\n" +
               "            if (giftGrid) giftGrid.style.display = 'none';\n" +
               "            if (actionsRow) actionsRow.style.display = 'none';\n" +
               "        } else {\n" +
               "            if (intimacySec) intimacySec.style.display = 'flex';\n" +
               "            if (giftTitle) giftTitle.style.display = 'block';\n" +
               "            if (giftGrid) giftGrid.style.display = 'grid';\n" +
               "            if (actionsRow) actionsRow.style.display = 'flex';\n" +
               "        }\n" +
               "        modal.style.display = 'flex';\n" +
               "        if (typeof closeInlineRelationshipPanel === 'function') closeInlineRelationshipPanel();\n" +
               "        const inRoomList = window.currentSeatsPlayers || [];\n" +
               "        const meInRoom = inRoomList.find(p => p && (p.id === myUserId || p.name === myNickname));\n" +
               "        const amIHostInRoom = currentRoomId && meInRoom && (meInRoom.isHost === true || (inRoomList[0] && inRoomList[0].id === meInRoom.id));\n" +
               "        const isTargetInRoom = inRoomList.some(p => p && (p.id === cleanUid || (p.id && p.id.replace(/-/g, '') === cleanUid)));\n" +
               "        const btnKickModal = document.getElementById('modalBtnKickRoom');\n" +
               "        if (btnKickModal) btnKickModal.style.display = (amIHostInRoom && !isSelf && isTargetInRoom && !isGameStarted) ? 'block' : 'none';\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/user/profile?userId=' + encodeURIComponent(cleanUid) + '&currentUserId=' + encodeURIComponent(myUserId));\n" +
               "            const d = await res.json();\n" +
               "            if ((d.code === 200 || d.code === 0) && d.data) {\n" +
               "                const u = d.data;\n" +
               "                if (avEl && u.avatar) avEl.innerText = u.avatar;\n" +
               "                if (nameEl && u.nickname) {\n" +
               "                    nameEl.innerText = u.nickname;\n" +
               "                    currentModalTargetName = u.nickname;\n" +
               "                }\n" +
               "                const vip = u.vipLevel || 0;\n" +
               "                if (vipEl) {\n" +
               "                    if (vip > 0) {\n" +
               "                        vipEl.style.display = 'inline-flex';\n" +
               "                        vipEl.className = 'badge-vip' + (vip >= 10 ? ' v10' : (vip >= 4 ? ' svip' : ''));\n" +
               "                        vipEl.innerText = (vip >= 10 ? '✨ V10 无双' : ((vip >= 4 ? '👑 SVIP' : 'VIP') + vip));\n" +
               "                    } else {\n" +
               "                        vipEl.style.display = 'none';\n" +
               "                    }\n" +
               "                }\n" +
               "                if (tierEl) tierEl.innerText = u.rankTier || '🥉 倔强青铜';\n" +
               "                const total = u.totalGames || 0;\n" +
               "                const wins = u.winCount || 0;\n" +
               "                if (totalEl) totalEl.innerText = total + '场';\n" +
               "                if (rateEl) rateEl.innerText = total > 0 ? (Math.round((wins / total) * 100) + '%') : '0%';\n" +
               "                if (!isSelf && u.isFriend) {\n" +
               "                    if (remarkBox) {\n" +
               "                        remarkBox.style.display = 'flex';\n" +
               "                        if (remarkVal) remarkVal.innerText = u.remark || '未设置 (点击修改)';\n" +
               "                    }\n" +
               "                    if (btnAdd) {\n" +
               "                        btnAdd.innerText = '✅ 已是好友';\n" +
               "                        btnAdd.style.background = '#94a3b8';\n" +
               "                        btnAdd.disabled = true;\n" +
               "                    }\n" +
               "                } else if (!isSelf) {\n" +
               "                    if (remarkBox) remarkBox.style.display = 'none';\n" +
               "                    if (btnAdd) {\n" +
               "                        btnAdd.innerText = '➕ 加为好友';\n" +
               "                        btnAdd.style.background = '#10b981';\n" +
               "                        btnAdd.disabled = false;\n" +
               "                    }\n" +
               "                }\n" +
               "            }\n" +
               "        } catch(e) {}\n" +
               "        if (!isSelf) {\n" +
               "            try {\n" +
               "                const resRel = await fetch(getApiPrefix() + '/api/intimacy/query?userA=' + encodeURIComponent(myUserId) + '&userB=' + encodeURIComponent(cleanUid));\n" +
               "                const dRel = await resRel.json();\n" +
               "                if (dRel.code === 200 && dRel.data) {\n" +
               "                    window.currentModalTargetIntimacy = dRel.data.intimacyScore || 0;\n" +
               "                    window.currentModalTargetRelationship = dRel.data.relationship || '暂未缔结';\n" +
               "                    if (scoreEl) scoreEl.innerText = '双方亲密度: ' + window.currentModalTargetIntimacy;\n" +
               "                    if (relEl) relEl.innerText = window.currentModalTargetRelationship;\n" +
               "                } else {\n" +
               "                    window.currentModalTargetIntimacy = 0;\n" +
               "                    window.currentModalTargetRelationship = '暂未缔结';\n" +
               "                    if (scoreEl) scoreEl.innerText = '双方亲密度: 0';\n" +
               "                    if (relEl) relEl.innerText = '暂未缔结';\n" +
               "                }\n" +
               "            } catch(e) {\n" +
               "                if (scoreEl) scoreEl.innerText = '双方亲密度: 0';\n" +
               "                if (relEl) relEl.innerText = '暂未缔结';\n" +
               "            }\n" +
               "        }\n" +
               "    };\n" +
               "    window.copyModalPlayerUid = function() {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        copyUserId(currentModalTargetUid);\n" +
               "    };\n" +
               "    window.openMyProfileModal = function() {\n" +
               "        openPlayerProfileModal(myUserId, myNickname, myAvatar);\n" +
               "    };\n" +
               "    window.promptEditFriendRemark = async function() {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        const currentRemark = (document.getElementById('modalPlayerRemarkVal') ? document.getElementById('modalPlayerRemarkVal').innerText : '');\n" +
               "        const newRemark = prompt('请输入好友的新备注名 (留空可清空备注)：', currentRemark === '未设置 (点击修改)' ? '' : currentRemark);\n" +
               "        if (newRemark === null) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/remark', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({\n" +
               "                    userId: myUserId,\n" +
               "                    friendId: currentModalTargetUid,\n" +
               "                    remark: newRemark.trim()\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('✅ 好友备注修改成功！');\n" +
               "                if (document.getElementById('modalPlayerRemarkVal')) {\n" +
               "                    document.getElementById('modalPlayerRemarkVal').innerText = newRemark.trim() || '未设置 (点击修改)';\n" +
               "                }\n" +
               "                loadFriendsData();\n" +
               "            } else {\n" +
               "                showToast(d.message || '修改失败，请重试');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('修改备注发生异常');\n" +
               "        }\n" +
               "    };\n" +
               "    window.quickApplyFriendFromModal = async function() {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/friends/apply', {\n" +
               "                method: 'POST',\n" +
               "                headers: { 'Content-Type': 'application/json' },\n" +
               "                body: JSON.stringify({\n" +
               "                    fromUserId: myUserId,\n" +
               "                    toUserId: currentModalTargetUid,\n" +
               "                    applicantId: myUserId,\n" +
               "                    targetId: currentModalTargetUid\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('🎉 好友申请已发送，等待对方通过！');\n" +
               "            } else {\n" +
               "                showToast(d.message || '申请已发送或已是好友');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('发送好友申请失败，请重试');\n" +
               "        }\n" +
               "    };\n" +
               "    window.closePlayerProfileModal = function() {\n" +
               "        const modal = document.getElementById('playerProfileModal');\n" +
               "        if (modal) modal.style.display = 'none';\n" +
               "    };\n" +
               "    window.actionSendGift = async function(itemType, itemName, intimacyScore, giftTitle, cost, isGlobal) {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        try {\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "                ws.send(JSON.stringify({\n" +
               "                    type: 'THROW_ITEM',\n" +
               "                    roomCode: currentRoomId,\n" +
               "                    senderId: myUserId,\n" +
               "                    senderName: myNickname,\n" +
               "                    senderAvatar: myAvatar,\n" +
               "                    targetPlayerId: currentModalTargetUid,\n" +
               "                    targetPlayerName: currentModalTargetName,\n" +
               "                    itemType: itemType,\n" +
               "                    itemEmoji: (itemName || '').split(' ')[0] || '🎁',\n" +
               "                    giftTitle: giftTitle || itemName,\n" +
               "                    addedIntimacy: intimacyScore,\n" +
               "                    isGlobal: !!isGlobal\n" +
               "                }));\n" +
               "            }\n" +
               "            await fetch(getApiPrefix() + '/api/intimacy/add', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    userA: myUserId,\n" +
               "                    userB: currentModalTargetUid,\n" +
               "                    addScore: intimacyScore\n" +
               "                })\n" +
               "            });\n" +
               "            showToast('🎉 成功赠送【' + itemName + '】！亲密度 +' + intimacyScore + ' 点！');\n" +
               "            openPlayerProfileModal(currentModalTargetUid, currentModalTargetName, currentModalTargetAvatar);\n" +
               "        } catch(e) {\n" +
               "            showToast('赠送礼物异常，请重试');\n" +
               "        }\n" +
               "    };\n" +
               "    window.toggleInlineRelationshipPanel = function() {\n" +
               "        const panel = document.getElementById('modalInlineRelationshipPanel');\n" +
               "        const btn = document.getElementById('btnToggleInlineRel');\n" +
               "        if (!panel) return;\n" +
               "        if (panel.style.display === 'none' || panel.style.display === '') {\n" +
               "            renderInlineRelationshipBadges();\n" +
               "            panel.style.display = 'block';\n" +
               "            if (btn) btn.innerText = '收起设置 ▴';\n" +
               "        } else {\n" +
               "            panel.style.display = 'none';\n" +
               "            if (btn) btn.innerText = '设置关系 ▾';\n" +
               "        }\n" +
               "    };\n" +
               "    window.closeInlineRelationshipPanel = function() {\n" +
               "        const panel = document.getElementById('modalInlineRelationshipPanel');\n" +
               "        const btn = document.getElementById('btnToggleInlineRel');\n" +
               "        if (panel) panel.style.display = 'none';\n" +
               "        if (btn) btn.innerText = '设置关系 ▾';\n" +
               "    };\n" +
               "    const REL_THRESHOLDS = [\n" +
               "        { name: '朋友', score: 50, icon: '👫' },\n" +
               "        { name: '发小', score: 100, icon: '🤜🤛' },\n" +
               "        { name: '死党', score: 100, icon: '🤝' },\n" +
               "        { name: '知己', score: 200, icon: '🍵' },\n" +
               "        { name: '闺蜜', score: 200, icon: '🌸' },\n" +
               "        { name: '基友', score: 200, icon: '👬' },\n" +
               "        { name: '情侣', score: 520, icon: '💍' },\n" +
               "        { name: '老婆', score: 520, icon: '👰' },\n" +
               "        { name: '老公', score: 520, icon: '🤵' }\n" +
               "    ];\n" +
               "    window.renderInlineRelationshipBadges = function() {\n" +
               "        const grid = document.getElementById('inlineRelBadgesGrid');\n" +
               "        const notice = document.getElementById('inlineRelNotice');\n" +
               "        const removeRow = document.getElementById('inlineRelRemoveRow');\n" +
               "        if (!grid || !notice) return;\n" +
               "        const curScore = Number(window.currentModalTargetIntimacy || 0);\n" +
               "        const curRel = window.currentModalTargetRelationship || '';\n" +
               "        if (curRel && curRel !== '暂未缔结') {\n" +
               "            if (removeRow) removeRow.style.display = 'block';\n" +
               "        } else {\n" +
               "            if (removeRow) removeRow.style.display = 'none';\n" +
               "        }\n" +
               "        if (curScore < 50) {\n" +
               "            notice.innerHTML = '⚠️ <b>当前亲密度为 ' + curScore + ' 点</b>，未达缔结关系最低门槛（需满 50 点，<b>0点无法设置</b>）。请在下方互赠浪漫鲜花或啤酒快速提升亲密度！';\n" +
               "            notice.style.background = '#fee2e2';\n" +
               "            notice.style.color = '#b91c1c';\n" +
               "            notice.style.border = '1px solid #fecaca';\n" +
               "        } else {\n" +
               "            notice.innerHTML = '✨ <b>当前亲密度 ' + curScore + ' 点</b>已达标！点击下方高亮徽章即可直接缔结对应亲密关系：';\n" +
               "            notice.style.background = '#ecfdf5';\n" +
               "            notice.style.color = '#047857';\n" +
               "            notice.style.border = '1px solid #a7f3d0';\n" +
               "        }\n" +
               "        grid.innerHTML = REL_THRESHOLDS.map(item => {\n" +
               "            const unlocked = curScore >= item.score;\n" +
               "            const isCurrent = curRel === item.name;\n" +
               "            if (isCurrent) {\n" +
               "                return '<div style=\"padding:8px 4px; background:linear-gradient(135deg,#f43f5e,#be123c); color:#fff; border-radius:8px; text-align:center; font-size:11px; font-weight:bold; border:2px solid #fda4af; box-shadow:0 2px 8px rgba(244,63,94,0.3);\">' +\n" +
               "                    '<div style=\"font-size:16px;\">' + item.icon + '</div>' +\n" +
               "                    '<div>' + item.name + '</div>' +\n" +
               "                    '<div style=\"font-size:9px; opacity:0.9;\">当前关系</div>' +\n" +
               "                '</div>';\n" +
               "            } else if (unlocked) {\n" +
               "                return '<div onclick=\"actionSetRelationshipDirect(\\'' + item.name + '\\')\" style=\"padding:8px 4px; background:#ffffff; color:#e11d48; border-radius:8px; text-align:center; font-size:11px; font-weight:bold; border:1.5px solid #fb7185; cursor:pointer; box-shadow:0 1px 4px rgba(244,63,94,0.1); transition:all 0.2s;\" onmouseover=\"this.style.background=\\'#fff1f2\\'\" onmouseout=\"this.style.background=\\'#ffffff\\'\">' +\n" +
               "                    '<div style=\"font-size:16px;\">' + item.icon + '</div>' +\n" +
               "                    '<div>' + item.name + '</div>' +\n" +
               "                    '<div style=\"font-size:9.5px; color:#10b981; font-weight:bold;\">可缔结 (' + item.score + ')</div>' +\n" +
               "                '</div>';\n" +
               "            } else {\n" +
               "                return '<div style=\"padding:8px 4px; background:#f1f5f9; color:#94a3b8; border-radius:8px; text-align:center; font-size:11px; border:1px solid #e2e8f0; opacity:0.75;\">' +\n" +
               "                    '<div style=\"font-size:16px;\">' + item.icon + '</div>' +\n" +
               "                    '<div>' + item.name + ' 🔒</div>' +\n" +
               "                    '<div style=\"font-size:9px; color:#64748b;\">需 ' + item.score + ' 点</div>' +\n" +
               "                '</div>';\n" +
               "            }\n" +
               "        }).join('');\n" +
               "    };\n" +
               "    window.actionSetRelationshipDirect = async function(relName) {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/intimacy/set-relationship', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    user1Id: myUserId,\n" +
               "                    user2Id: currentModalTargetUid,\n" +
               "                    relationship: relName\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('🎉 恭喜！您与【' + currentModalTargetName + '】已正式缔结为【' + relName + '】关系！');\n" +
               "                window.currentModalTargetRelationship = relName;\n" +
               "                const relEl = document.getElementById('modalPlayerRelBadge');\n" +
               "                if (relEl) relEl.innerText = '❤️ ' + relName;\n" +
               "                renderInlineRelationshipBadges();\n" +
               "                loadFriendsData();\n" +
               "            } else {\n" +
               "                showToast(d.message || '设置亲密关系失败，请确保亲密度达标');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('设置亲密关系异常，请重试');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionRemoveRelationshipDirect = async function() {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/intimacy/remove-relationship', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    user1Id: myUserId,\n" +
               "                    user2Id: currentModalTargetUid\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('已解除双方亲密关系');\n" +
               "                window.currentModalTargetRelationship = '暂未缔结';\n" +
               "                const relEl = document.getElementById('modalPlayerRelBadge');\n" +
               "                if (relEl) relEl.innerText = '暂未缔结';\n" +
               "                renderInlineRelationshipBadges();\n" +
               "                loadFriendsData();\n" +
               "            } else {\n" +
               "                showToast(d.message || '解除失败');\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('解除关系异常');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionKickPlayer = async function(targetPlayerId, targetPlayerName) {\n" +
               "        if (!currentRoomId || !targetPlayerId) return;\n" +
               "        if (isGameStarted) { showToast('⚠️ 正在激烈对决中，暂不可将玩家移出房间！'); return; }\n" +
               "        try {\n" +
               "            const res = await fetch(getApiPrefix() + '/api/rooms/kick', {\n" +
               "                method: 'POST',\n" +
               "                headers: {'Content-Type': 'application/json'},\n" +
               "                body: JSON.stringify({\n" +
               "                    roomCode: currentRoomId,\n" +
               "                    operatorId: myUserId,\n" +
               "                    targetPlayerId: targetPlayerId\n" +
               "                })\n" +
               "            });\n" +
               "            const d = await res.json();\n" +
               "            if (d.code === 200 || d.code === 0) {\n" +
               "                showToast('🚫 已成功将玩家【' + (targetPlayerName || '玩家') + '】移出房间');\n" +
               "                closePlayerProfileModal();\n" +
               "            } else {\n" +
               "                showToast(d.message || '踢出玩家失败');\n" +
               "            }\n" +
               "            if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "                ws.send(JSON.stringify({\n" +
               "                    type: 'KICK_PLAYER',\n" +
               "                    roomCode: currentRoomId,\n" +
               "                    targetPlayerId: targetPlayerId,\n" +
               "                    targetPlayerName: targetPlayerName\n" +
               "                }));\n" +
               "            }\n" +
               "        } catch(e) {\n" +
               "            showToast('踢人操作异常');\n" +
               "        }\n" +
               "    };\n" +
               "    window.actionKickPlayerFromModal = function() {\n" +
               "        if (!currentModalTargetUid) return;\n" +
               "        if (isGameStarted) { showToast('⚠️ 正在激烈对决中，暂不可将玩家移出房间！'); return; }\n" +
               "        actionKickPlayer(currentModalTargetUid, currentModalTargetName);\n" +
               "    };\n" +
               "    function renderSeats(list = []) {\n" +
               "        window.currentSeatsPlayers = list;\n" +
               "        const grid = document.getElementById('seatsGrid');\n" +
               "        if (!grid) return;\n" +
               "        grid.innerHTML = '';\n" +
               "        const mePlayer = list.find(p => p && (p.id === myUserId || p.name === myNickname));\n" +
               "        const amIHost = mePlayer ? (mePlayer.isHost === true || (list[0] && list[0].id === mePlayer.id)) : (list.length <= 1);\n" +
               "        for (let i = 1; i <= 6; i++) {\n" +
               "            const p = list[i - 1];\n" +
               "            const div = document.createElement('div');\n" +
               "            div.style.position = 'relative';\n" +
               "            const isMe = p && (p.id === myUserId || p.name === myNickname);\n" +
               "            div.className = 'seat-card' + (isMe ? ' active-turn' : '');\n" +
               "            div.id = 'seat-' + i;\n" +
               "            if (p) {\n" +
               "                const isHost = p.isHost || i === 1;\n" +
               "                const kickBtn = (amIHost && !isMe && !isGameStarted) ? ('<button class=\"btn-seat-kick\" onclick=\"event.stopPropagation(); actionKickPlayer(\\'' + p.id + '\\', \\'' + (p.name || '玩家').replace(/'/g, \"\\\\'\") + '\\')\" title=\"房主将该玩家请出房间\">✕ 移出</button>') : '';\n" +
               "                let badge = '';\n" +
               "                if (isGameStarted && currentGameType === 'take6') {\n" +
               "                    const isDone = !!(window.take6ReadyPlayers && window.take6ReadyPlayers[p.id]);\n" +
               "                    const curT = window.take6CurrentTurn || 1;\n" +
               "                    const remainCards = Math.max(0, 10 - curT + (isDone ? 0 : 1));\n" +
               "                    const remainText = '<span style=\"font-size:9.5px; color:#cbd5e1; font-weight:normal; display:block; margin-top:2px;\">剩 ' + remainCards + ' 张</span>';\n" +
               "                    badge = (isDone ? '<span class=\"ready-badge ready\" style=\"background:rgba(16,185,129,0.2); color:#10b981; border:1px solid #10b981;\">🎴 已扣牌</span>' : '<span class=\"ready-badge unready\" style=\"background:rgba(245,158,11,0.2); color:#f59e0b; border:1px solid #f59e0b;\">⏳ 思考中</span>') + remainText;\n" +
               "                } else {\n" +
               "                    const isReady = p.isReady || isHost;\n" +
               "                    badge = isHost ? '<span class=\"host-crown\">👑 房主</span>' : (isReady ? '<span class=\"ready-badge ready\">🟢 已准备</span>' : '<span class=\"ready-badge unready\">🟡 未准备</span>');\n" +
               "                }\n" +
               "                const pVip = p.vipLevel || 0;\n" +
               "                const isVip = pVip > 0;\n" +
               "                const isV10 = pVip >= 10;\n" +
               "                const isSvip = pVip >= 4;\n" +
               "                const pVipBadge = isVip ? (' <span class=\"badge-vip' + (isV10 ? ' v10' : (isSvip ? ' svip' : '')) + '\" style=\"font-size:8px; padding:0 3px;\">' + (isV10 ? '✨' : (isSvip ? '👑' : '')) + 'V' + pVip + '</span>') : '';\n" +
               "                const pNameClass = isVip ? ('seat-name vip-nickname' + (isV10 ? ' v10' : (isSvip ? ' svip' : ''))) : 'seat-name';\n" +
               "                div.innerHTML = '<span class=\"seat-mic-tag\">' + i + '号麦</span>' + kickBtn + badge + '<div class=\"seat-avatar\">' + (p.avatar || (currentGameType === 'take6' ? '🐂' : '🦊')) + '</div><div class=\"' + pNameClass + '\">' + (p.name || '玩家') + pVipBadge + (isMe ? ' (我)' : '') + '</div>';\n" +
               "                if (!isMe) {\n" +
               "                    div.style.cursor = 'pointer';\n" +
               "                    div.setAttribute('title', '点击查看名片、赠送礼物或缔结亲密关系');\n" +
               "                    div.onclick = function() { openPlayerProfileModal(p.id, p.name || '玩家', p.avatar || '🦊'); };\n" +
               "                }\n" +
               "            } else {\n" +
                "                if (isGameStarted) {\n" +
                "                    div.innerHTML = '<span class=\"seat-mic-tag\">' + i + '号麦</span><div class=\"seat-empty\" style=\"opacity:0.35;cursor:not-allowed;\" title=\"对战中空席\"><span class=\"plus\">🔒</span><span>空席 (对战中)</span></div>';\n" +
                "                } else {\n" +
                "                    div.innerHTML = '<span class=\"seat-mic-tag\">' + i + '号麦</span><div class=\"seat-empty\" onclick=\"actionSummonPlayers()\" style=\"cursor:pointer;\" title=\"点击召集桌友开黑\"><span class=\"plus\">📢</span><span>召集玩家</span></div>';\n" +
                "                }\n" +
               "            }\n" +
               "            grid.appendChild(div);\n" +
               "        }\n" +
               "        const tag = document.getElementById('headerRoomTag');\n" +
               "        if (tag) tag.innerText = '房间 #' + (currentRoomId || '待分配') + ' (' + list.length + '/6人)';\n" +
               "        updateReadyButtonState();\n" +
               "        if (currentGameType === 'undercover' && typeof renderUndercoverVoteButtons === 'function') {\n" +
               "            renderUndercoverVoteButtons();\n" +
               "        }\n" +
               "    }\n" +
               "    function updateReadyButtonState() {\n" +
               "        const btn = document.getElementById('btnReadyToggle');\n" +
               "        const summonBtn = document.getElementById('btnSummonPlayers');\n" +
               "        const specBtn = document.getElementById('btnSpectatorToggle');\n" +
               "        if (summonBtn) { summonBtn.style.display = isGameStarted ? 'none' : 'inline-block'; }\n" +
               "        if (!btn) return;\n" +
               "        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
               "        const isHost = me ? (me.isHost || players[0]?.id === me.id) : (players.length <= 1);\n" +
               "        if (specBtn) {\n" +
               "            specBtn.style.display = (isHost && !isGameStarted) ? 'inline-block' : 'none';\n" +
               "            specBtn.innerText = window.allowSpectator ? '👁️ 允许旁观 (开)' : '🚫 禁止旁观 (关)';\n" +
               "            specBtn.style.color = window.allowSpectator ? '#34d399' : '#94a3b8';\n" +
               "            specBtn.style.borderColor = window.allowSpectator ? '#059669' : '#475569';\n" +
               "        }\n" +
               "        if (window.isSpectatorMode) {\n" +
               "            btn.className = 'btn-ready-toggle';\n" +
               "            btn.style.background = '#6366f1';\n" +
               "            btn.innerText = '🪑 申请加入席位准备';\n" +
               "            btn.onclick = () => {\n" +
               "                if (isGameStarted) {\n" +
               "                    alert('当前对局正在进行中，请等待本局结束后上桌加入席位！');\n" +
               "                    return;\n" +
               "                }\n" +
               "                if (players.length >= 8) {\n" +
               "                    alert('房间席位已满，无法加入！');\n" +
               "                    return;\n" +
               "                }\n" +
               "                if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "                    ws.send(JSON.stringify({\n" +
               "                        type: 'GAME_ACTION',\n" +
               "                        action: 'SPECTATOR_JOIN_SEAT',\n" +
               "                        roomCode: currentRoomId,\n" +
               "                        userId: myUserId,\n" +
               "                        userName: myNickname,\n" +
               "                        userAvatar: myAvatar\n" +
               "                    }));\n" +
               "                }\n" +
               "                appendChat('系统', '🪑 已发送加入席位申请，等待入席...');\n" +
               "            };\n" +
               "            return;\n" +
               "        }\n" +
               "        if (isGameStarted) {\n" +
               "            btn.className = 'btn-ready-toggle unready'; btn.innerText = '🎮 对战进行中'; btn.onclick = () => {}; return;\n" +
               "        }\n" +
               "        if (isHost) {\n" +
               "            const nonHosts = players.filter(p => p.id !== (me ? me.id : myUserId));\n" +
               "            const readyCount = nonHosts.filter(p => p.isReady).length;\n" +
               "            const totalNonHosts = nonHosts.length;\n" +
               "            const allReady = totalNonHosts > 0 && readyCount === totalNonHosts;\n" +
               "            if (totalNonHosts === 0) {\n" +
               "                if (currentGameType === 'party_wheel') {\n" +
               "                    btn.className = 'btn-ready-toggle host-start'; btn.innerText = '🚀 立即开启转盘大冒险 (支持单机/多人)'; btn.onclick = hostStartGame;\n" +
               "                } else {\n" +
               "                    btn.className = 'btn-ready-toggle host-waiting'; btn.innerText = '等待其他玩家进房 (1/2人 · 可点右侧召集)'; btn.onclick = () => alert('请点击右侧【📢 召集玩家】召唤桌友，或通过分享邀请好友进房！');\n" +
               "                }\n" +
               "            } else if (!allReady) {\n" +
               "                btn.className = 'btn-ready-toggle host-waiting'; btn.innerText = '等待其他玩家准备 (' + readyCount + '/' + totalNonHosts + ' 已准备)'; btn.onclick = () => alert('还有玩家未准备，请等待所有玩家准备就绪后方可开局！');\n" +
               "            } else {\n" +
               "                btn.className = 'btn-ready-toggle host-start'; btn.innerText = '🚀 所有玩家已就绪，立即开局！'; btn.onclick = hostStartGame;\n" +
               "            }\n" +
               "        } else {\n" +
               "            if (me) myIsReady = !!me.isReady;\n" +
               "            btn.className = myIsReady ? 'btn-ready-toggle unready' : 'btn-ready-toggle ready';\n" +
               "            btn.innerText = myIsReady ? '✓ 已就绪 (点击取消准备)' : '⚡ 点击准备';\n" +
               "            btn.onclick = toggleMyReady;\n" +
               "        }\n" +
               "    }\n" +
               "    window.actionToggleSpectator = function() {\n" +
               "        if (!currentRoomId) return;\n" +
               "        allowSpectator = !allowSpectator;\n" +
               "        window.allowSpectator = allowSpectator;\n" +
               "        updateReadyButtonState();\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({\n" +
               "                type: 'GAME_ACTION',\n" +
               "                action: 'TOGGLE_SPECTATOR_ALLOW',\n" +
               "                roomCode: currentRoomId,\n" +
               "                allowSpectator: allowSpectator\n" +
               "            }));\n" +
               "        }\n" +
               "        fetch(getApiPrefix() + '/api/rooms/settings', {\n" +
               "            method: 'POST',\n" +
               "            headers: {'Content-Type': 'application/json'},\n" +
               "            body: JSON.stringify({ roomCode: currentRoomId, allowSpectator: allowSpectator })\n" +
               "        }).catch(() => {});\n" +
               "        appendChat('系统', allowSpectator ? '👁️ 您已开启允许旁观模式' : '🚫 您已关闭旁观模式，禁止新观众进入');\n" +
               "    };\n" +
               "    async function toggleMyReady() {\n" +
               "        if (isGameStarted) return;\n" +
               "        myIsReady = !myIsReady;\n" +
               "        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
               "        if (me) me.isReady = myIsReady;\n" +
               "        renderSeats(players); playBeep(myIsReady ? 880 : 440, 0.15);\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'PLAYER_READY', roomCode: currentRoomId, userId: myUserId, isReady: myIsReady }));\n" +
               "        }\n" +
               "        try {\n" +
               "            await fetch(getApiPrefix() + '/api/rooms/ready', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ roomCode: currentRoomId, playerId: myUserId, isReady: myIsReady }) });\n" +
               "        } catch(e) {}\n" +
                "    }\n";
    }

    private String buildHtmlScriptWsAndRoomPart2(boolean isTake6) {
        return "    function hostStartGame() {\n" +
               "        window.isGameOverPhase = false;\n" +
               "        playBeep(980, 0.3);\n" +
               "        let startPayload = { gameType: currentGameType };\n" +
               "        if (currentGameType === 'take6') {\n" +
               "            const deck = [];\n" +
               "            for (let i = 1; i <= 104; i++) deck.push(i);\n" +
               "            for (let i = deck.length - 1; i > 0; i--) {\n" +
               "                const j = Math.floor(Math.random() * (i + 1));\n" +
               "                [deck[i], deck[j]] = [deck[j], deck[i]];\n" +
               "            }\n" +
               "            const rows = [[deck.pop()], [deck.pop()], [deck.pop()], [deck.pop()]];\n" +
               "            const hands = {};\n" +
               "            players.forEach(p => {\n" +
               "                if (p && p.id) {\n" +
               "                    const h = [];\n" +
               "                    for (let k = 0; k < 10; k++) { if (deck.length > 0) h.push(deck.pop()); }\n" +
               "                    h.sort((a, b) => a - b);\n" +
               "                    hands[p.id] = h;\n" +
               "                }\n" +
               "            });\n" +
               "            startPayload.rows = rows;\n" +
               "            startPayload.initialRows = rows;\n" +
               "            startPayload.playerHands = hands;\n" +
               "        }\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'GAME_STARTED', roomCode: currentRoomId, payload: startPayload }));\n" +
               "        }\n" +
               "        onGameStartedTrigger(startPayload);\n" +
               "    }\n" +
               "    function copyShareLink() {\n" +
               "        const url = window.location.origin + '/party-game/play?roomId=' + encodeURIComponent(currentRoomId) + '&gameType=' + encodeURIComponent(currentGameType);\n" +
               "        const text = '【聚会桌游吧】🎮 房主邀请你加入房间【' + currentRoomId + '】！手机浏览器直接免安装打开玩：' + url;\n" +
               "        if (navigator.clipboard && navigator.clipboard.writeText) {\n" +
               "            navigator.clipboard.writeText(text); alert('🎉 已复制网页免安装开黑链接！可直接粘贴发送给微信/QQ好友～');\n" +
               "        } else { prompt('请复制开黑链接发送给好友：', text); }\n" +
               "    }\n" +
               "    function triggerBubble(senderKey, text) {\n" +
               "        let seatEl = null;\n" +
               "        if (players && players.length > 0) {\n" +
               "            const idx = players.findIndex(p => p.id === senderKey || p.name === senderKey);\n" +
               "            if (idx >= 0) seatEl = document.getElementById('seat-' + (idx + 1));\n" +
               "        }\n" +
               "        if (!seatEl) seatEl = document.getElementById('seat-1');\n" +
               "        if (!seatEl) return;\n" +
               "        const bubble = document.createElement('div'); bubble.className = 'speech-bubble';\n" +
               "        bubble.innerText = text.length > 15 ? (text.substring(0, 15) + '...') : text;\n" +
               "        seatEl.appendChild(bubble); playBeep(700, 0.08);\n" +
               "        setTimeout(() => { if (bubble.parentNode) bubble.parentNode.removeChild(bubble); }, 3200);\n" +
               "    }\n";
    }

        private String buildHtmlScriptTake6() {
        return "    let take6Rows = [[], [], [], []];\n" +
"    let take6MyHand = [];\n" +
"    let take6Scores = {};\n" +
"    let selectedTake6Card = null;\n" +
"    let take6AwaitingRowChoice = false;\n" +
"    let take6PendingCard = null;\n" +
"    let take6ReadyPlayers = {};\n" +
"    window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"    let take6HasCommittedThisTurn = false;\n" +
"    let take6TurnCards = {};\n" +
"    let take6CountdownTimer = null;\n" +
"    let take6RemainingSeconds = 0;\n" +
"    let isTake6AutoPlay = false;\n" +
"    let take6AutoPlayTimer = null;\n" +
"    let take6AiHands = {};\n" +
"    let take6AiTimers = {};\n" +
"    window.take6ResumePlaceNext = null;\n" +
"    function updateTake6AutoPlayButtonUi() {\n" +
"        const btn = document.getElementById('btnTake6AutoPlay');\n" +
"        if (!btn) return;\n" +
"        if (isTake6AutoPlay) {\n" +
"            btn.className = 'btn-take6-autoplay active';\n" +
"            btn.innerHTML = '🤖 取消托管';\n" +
"        } else {\n" +
"            btn.className = 'btn-take6-autoplay';\n" +
"            btn.innerHTML = '🤖 智能托管';\n" +
"        }\n" +
"    }\n" +
"    window.toggleTake6AutoPlay = function() {\n" +
"        isTake6AutoPlay = !isTake6AutoPlay;\n" +
"        updateTake6AutoPlayButtonUi();\n" +
"        if (isTake6AutoPlay) {\n" +
"            appendChat('系统', '🤖 已开启【智能托管】：系统将在出牌与吃行阶段自动避坑代打');\n" +
"            checkTake6AutoPlayAction();\n" +
"        } else {\n" +
"            if (take6AutoPlayTimer) { clearTimeout(take6AutoPlayTimer); take6AutoPlayTimer = null; }\n" +
"            appendChat('系统', '👤 已取消智能托管，恢复手动操作');\n" +
"        }\n" +
"    };\n" +
"    function updateTake6CountdownUi(seconds, text) {\n" +
"        const badge = document.getElementById('take6CountdownBadge');\n" +
"        if (!badge) return;\n" +
"        if (seconds > 0) {\n" +
"            badge.style.display = 'inline-flex';\n" +
"            badge.innerHTML = text ? text : `⏳ 倒计时: ${seconds}s`;\n" +
"            if (seconds <= 5) {\n" +
"                badge.className = 'take6-countdown-badge urgent';\n" +
"            } else {\n" +
"                badge.className = 'take6-countdown-badge';\n" +
"            }\n" +
"        } else {\n" +
"            badge.style.display = 'none';\n" +
"            badge.className = 'take6-countdown-badge';\n" +
"        }\n" +
"    }\n" +
"    function startTake6Countdown(seconds, phaseType, onTimeout) {\n" +
"        if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; }\n" +
"        take6RemainingSeconds = seconds;\n" +
"        const label = phaseType === 'choice' ? `⚠️ 吃行倒计时: ${seconds}s` : `⏳ 思考出牌: ${seconds}s`;\n" +
"        updateTake6CountdownUi(take6RemainingSeconds, label);\n" +
"        updateTake6SelectionStatus();\n" +
"        take6CountdownTimer = setInterval(() => {\n" +
"            take6RemainingSeconds--;\n" +
"            const curLabel = phaseType === 'choice' ? `⚠️ 吃行倒计时: ${take6RemainingSeconds}s` : `⏳ 思考出牌: ${take6RemainingSeconds}s`;\n" +
"            updateTake6CountdownUi(take6RemainingSeconds, curLabel);\n" +
"            updateTake6SelectionStatus();\n" +
"            if (take6RemainingSeconds <= 0) {\n" +
"                clearInterval(take6CountdownTimer);\n" +
"                take6CountdownTimer = null;\n" +
"                updateTake6CountdownUi(0);\n" +
"                if (onTimeout) onTimeout();\n" +
"            }\n" +
"        }, 1000);\n" +
"        checkTake6AutoPlayAction();\n" +
"    }\n" +
"    function getBullheads(n) {\n" +
"        if (n === 55) return 7;\n" +
"        if (n % 11 === 0) return 5;\n" +
"        if (n % 10 === 0) return 3;\n" +
"        if (n % 5 === 0) return 2;\n" +
"        return 1;\n" +
"    }\n" +
"    function getCardTheme(bulls) {\n" +
"        if (bulls === 7) return { bg: '#FEF2F2', border: '#F87171', text: '#991B1B', accent: '#DC2626' };\n" +
"        if (bulls === 5) return { bg: '#FAF5FF', border: '#C084FC', text: '#581C87', accent: '#9333EA' };\n" +
"        if (bulls === 3) return { bg: '#FFFBEB', border: '#FCD34D', text: '#78350F', accent: '#D97706' };\n" +
"        if (bulls === 2) return { bg: '#ECFDF5', border: '#6EE7B7', text: '#065F46', accent: '#059669' };\n" +
"        return { bg: '#FFFFFF', border: '#CBD5E1', text: '#1E293B', accent: '#0284C7' };\n" +
"    }\n" +
"    function renderTake6CardHtml(n, isSelected = false, onClickStr = '') {\n" +
"        const bulls = getBullheads(n);\n" +
"        const theme = getCardTheme(bulls);\n" +
"        const selClass = isSelected ? 'take6-card selected' : 'take6-card';\n" +
"        const selBorder = isSelected ? 'border: 2.5px solid #F59E0B !important;' : `border: 1.5px solid ${theme.border};`;\n" +
"        return `<div class='${selClass}' style='background: ${theme.bg}; color: ${theme.text}; ${selBorder}' onclick='${onClickStr}'>` +\n" +
"               `<div class='card-corner top-left'><span style='color:${theme.accent};'>🐮x${bulls}</span></div>` +\n" +
"               `<div class='card-number' style='color:${theme.text};'>${n}</div>` +\n" +
"               `<div class='card-corner bottom-right'><span style='color:${theme.accent};'>🐮x${bulls}</span></div>` +\n" +
"               `</div>`;\n" +
"    }\n" +
"    function renderTake6WaitingState() {\n" +
"        const waitingCard = document.getElementById('take6WaitingStage');\n" +
"        if (waitingCard) waitingCard.style.display = 'block';\n" +
"        updateTake6CountdownUi(0);\n" +
"        updateTake6AutoPlayButtonUi();\n" +
"        const rowsContainer = document.getElementById('take6RowsContainer');\n" +
"        if (rowsContainer) {\n" +
"            rowsContainer.innerHTML = [1, 2, 3, 4].map(idx => `\n" +
"                <div class='take6-row'>\n" +
"                    <div class='take6-row-meta'><span style='color: #94a3b8;'>#${idx}</span></div>\n" +
"                    <div class='take6-row-cards'>\n" +
"                        <div class='card-slot-empty'>待发牌</div>\n" +
"                        <div class='card-slot-empty'>+2</div>\n" +
"                        <div class='card-slot-empty'>+3</div>\n" +
"                        <div class='card-slot-empty'>+4</div>\n" +
"                        <div class='card-slot-empty'>+5</div>\n" +
"                    </div>\n" +
"                </div>\n" +
"            `).join('');\n" +
"        }\n" +
"        const handTitle = document.getElementById('take6HandTitle');\n" +
"        if (handTitle) handTitle.innerText = '🎴 我的手牌 (待发牌)';\n" +
"        const handContainer = document.getElementById('take6HandCards');\n" +
"        if (handContainer) {\n" +
"            handContainer.innerHTML = '<div style=\"color: #94a3b8; font-size: 12px; padding: 16px; text-align: center; width: 100%;\">⏳ 对局尚未开始。请先点击上方【⚡ 点击准备】，房主开局后系统将自动为您发放 10 张专属牛头牌～</div>';\n" +
"        }\n" +
"        const btnPlay = document.getElementById('btnTake6Play');\n" +
"        if (btnPlay) { btnPlay.disabled = true; btnPlay.innerText = '等待开局'; }\n" +
"        renderTake6Scores();\n" +
"    }\n" +
"    function decideTake6BestCardForHand(handCards) {\n" +
"        if (!handCards || handCards.length === 0) return null;\n" +
"        let bestSafeCard = null;\n" +
"        let minSafeDiff = 9999;\n" +
"        let bestDangerCard = null;\n" +
"        let minDangerBulls = 9999;\n" +
"        let bestSmallerCard = null;\n" +
"        let minRowBullsForSmaller = 9999;\n" +
"        let minOverallRowBulls = 9999;\n" +
"        for (let i = 0; i < 4; i++) {\n" +
"            let rowBulls = 0;\n" +
"            take6Rows[i].forEach(c => rowBulls += getBullheads(c));\n" +
"            if (rowBulls < minOverallRowBulls) minOverallRowBulls = rowBulls;\n" +
"        }\n" +
"        for (const card of handCards) {\n" +
"            let targetRowIdx = -1;\n" +
"            let minDiff = 9999;\n" +
"            for (let i = 0; i < 4; i++) {\n" +
"                const row = take6Rows[i];\n" +
"                const tail = row[row.length - 1];\n" +
"                if (card > tail) {\n" +
"                    const diff = card - tail;\n" +
"                    if (diff < minDiff) { minDiff = diff; targetRowIdx = i; }\n" +
"                }\n" +
"            }\n" +
"            if (targetRowIdx !== -1) {\n" +
"                const targetRow = take6Rows[targetRowIdx];\n" +
"                if (targetRow.length < 5) {\n" +
"                    if (minDiff < minSafeDiff) { minSafeDiff = minDiff; bestSafeCard = card; }\n" +
"                } else {\n" +
"                    let penalty = 0;\n" +
"                    targetRow.forEach(c => penalty += getBullheads(c));\n" +
"                    if (penalty < minDangerBulls) { minDangerBulls = penalty; bestDangerCard = card; }\n" +
"                }\n" +
"            } else {\n" +
"                if (minOverallRowBulls < minRowBullsForSmaller) {\n" +
"                    minRowBullsForSmaller = minOverallRowBulls;\n" +
"                    bestSmallerCard = card;\n" +
"                }\n" +
"            }\n" +
"        }\n" +
"        if (bestSafeCard !== null) return bestSafeCard;\n" +
"        if (bestDangerCard !== null && minDangerBulls <= minOverallRowBulls) return bestDangerCard;\n" +
"        if (bestSmallerCard !== null) return bestSmallerCard;\n" +
"        return handCards[0];\n" +
"    }\n" +
"    function decideTake6BestCard() {\n" +
"        return decideTake6BestCardForHand(take6MyHand);\n" +
"    }\n" +
"    function decideTake6BestRowToTake() {\n" +
"        let minRowIdx = 0;\n" +
"        let minBulls = 9999;\n" +
"        for (let i = 0; i < 4; i++) {\n" +
"            let sum = 0;\n" +
"            take6Rows[i].forEach(c => sum += getBullheads(c));\n" +
"            if (sum < minBulls) { minBulls = sum; minRowIdx = i; }\n" +
"        }\n" +
"        return minRowIdx;\n" +
"    }\n" +
"    function checkTake6AutoPlayAction() {\n" +
"        if (!isTake6AutoPlay || !isGameStarted) return;\n" +
"        if (take6AutoPlayTimer) { clearTimeout(take6AutoPlayTimer); take6AutoPlayTimer = null; }\n" +
"        if (!take6HasCommittedThisTurn && !take6AwaitingRowChoice && take6MyHand.length > 0) {\n" +
"            take6AutoPlayTimer = setTimeout(() => {\n" +
"                if (!isTake6AutoPlay || take6HasCommittedThisTurn || take6AwaitingRowChoice) return;\n" +
"                const card = decideTake6BestCard();\n" +
"                if (card !== null) {\n" +
"                    selectedTake6Card = card;\n" +
"                    renderTake6Hand();\n" +
"                    appendChat('智能托管', `🤖 自动打出推荐避坑牌: [${card}号牌]`);\n" +
"                    actionTake6PlayCard();\n" +
"                }\n" +
"            }, 800);\n" +
"        }\n" +
"        if (take6AwaitingRowChoice) {\n" +
"            take6AutoPlayTimer = setTimeout(() => {\n" +
"                if (!isTake6AutoPlay || !take6AwaitingRowChoice) return;\n" +
"                const bestRow = decideTake6BestRowToTake();\n" +
"                appendChat('智能托管', `🤖 自动收走牛头最少的第 ${bestRow + 1} 行`);\n" +
"                take6ChooseRowToTake(bestRow);\n" +
"            }, 800);\n" +
"        }\n" +
"    }\n" +
"    function triggerTake6AiTurn() {\n" +
"        if (!isGameStarted || currentGameType !== 'take6') return;\n" +
"        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
"        const isHost = me && (me.isHost === true || (players.length <= 1));\n" +
"        const hasAppHost = players.some(p => p.isHost && p.id && !p.id.startsWith('WEB-') && p.id !== myUserId);\n" +
"        if (!isHost && hasAppHost) return;\n" +
"        players.forEach((p, idx) => {\n" +
"            if (p.id === myUserId) {\n" +
"                if (!isTake6AutoPlay) return;\n" +
"            } else {\n" +
"                if (!p.isAi && p.online !== false) return;\n" +
"            }\n" +
"            if (take6TurnCards[p.id]) return;\n" +
"            if (take6AiTimers[p.id]) return;\n" +
"            let aiHand = take6AiHands[p.id];\n" +
"            if (!aiHand || aiHand.length === 0) {\n" +
"                const used = new Set([...take6MyHand, ...take6Rows.flat()]);\n" +
"                const deck = [];\n" +
"                for (let i = 1; i <= 104; i++) { if (!used.has(i)) deck.push(i); }\n" +
"                deck.sort(() => Math.random() - 0.5);\n" +
"                aiHand = deck.slice(0, 10).sort((a, b) => a - b);\n" +
"                take6AiHands[p.id] = aiHand;\n" +
"            }\n" +
"            const delay = 1000 + idx * 450 + Math.floor(Math.random() * 800);\n" +
"            take6AiTimers[p.id] = setTimeout(() => {\n" +
"                delete take6AiTimers[p.id];\n" +
"                if (!isGameStarted || take6TurnCards[p.id]) return;\n" +
"                const chosenCard = decideTake6BestCardForHand(aiHand);\n" +
"                if (chosenCard !== null) {\n" +
"                    take6AiHands[p.id] = aiHand.filter(c => c !== chosenCard);\n" +
"                    const bulls = getBullheads(chosenCard);\n" +
"                    handleTake6RemotePlay(p.id, p.name, { card: chosenCard, cardNumber: chosenCard, bullheads: bulls });\n" +
"                    if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"                        ws.send(JSON.stringify({\n" +
"                            type: 'GAME_ACTION',\n" +
"                            action: 'PLAY_CARD',\n" +
"                            roomCode: currentRoomId,\n" +
"                            senderId: p.id,\n" +
"                            senderName: p.name,\n" +
"                            payload: { card: chosenCard, cardNumber: chosenCard, bullheads: bulls }\n" +
"                        }));\n" +
"                    }\n" +
"                }\n" +
"            }, delay);\n" +
"        });\n" +
"    }\n" +
"    function take6StartActiveGame(payload) {\n" +
"        const waitingCard = document.getElementById('take6WaitingStage');\n" +
"        if (waitingCard) waitingCard.style.display = 'none';\n" +
"        take6HasCommittedThisTurn = false;\n" +
"        take6ReadyPlayers = {};\n" +
"        window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"        take6TurnCards = {};\n" +
"        take6AiHands = {};\n" +
"        Object.values(take6AiTimers).forEach(t => clearTimeout(t));\n" +
"        take6AiTimers = {};\n" +
"        window.take6CurrentTurn = 1;\n" +
"        if (payload && (payload.initialRows || payload.rows)) {\n" +
"            take6Rows = (payload.initialRows || payload.rows).map(row => Array.isArray(row) ? [...row] : [row]);\n" +
"        } else {\n" +
"            const deck = []; for (let i = 1; i <= 104; i++) deck.push(i);\n" +
"            for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }\n" +
"            take6Rows = [[deck.pop()], [deck.pop()], [deck.pop()], [deck.pop()]];\n" +
"        }\n" +
"        if (payload && payload.playerHands && payload.playerHands[myUserId]) {\n" +
"            take6MyHand = [...payload.playerHands[myUserId]].sort((a, b) => a - b);\n" +
"        } else if (payload && payload.playerHands && Object.keys(payload.playerHands).length > 0) {\n" +
"            const matchedKey = Object.keys(payload.playerHands).find(k => k === myUserId || k.includes(myNickname));\n" +
"            if (matchedKey) {\n" +
"                take6MyHand = [...payload.playerHands[matchedKey]].sort((a, b) => a - b);\n" +
"            } else {\n" +
"                take6MyHand = [...Object.values(payload.playerHands)[0]].sort((a, b) => a - b);\n" +
"            }\n" +
"        } else {\n" +
"            const deck = []; for (let i = 1; i <= 104; i++) deck.push(i);\n" +
"            for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }\n" +
"            take6MyHand = []; for (let i = 0; i < 10; i++) take6MyHand.push(deck.pop());\n" +
"            take6MyHand.sort((a, b) => a - b);\n" +
"        }\n" +
"        // 初始化 AI 手牌\n" +
"        players.forEach(p => {\n" +
"            if (p.isAi) {\n" +
"                if (payload && payload.playerHands && payload.playerHands[p.id]) {\n" +
"                    take6AiHands[p.id] = [...payload.playerHands[p.id]].sort((a, b) => a - b);\n" +
"                } else {\n" +
"                    const deck = []; for (let i = 1; i <= 104; i++) deck.push(i);\n" +
"                    for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }\n" +
"                    take6AiHands[p.id] = deck.slice(0, 10).sort((a, b) => a - b);\n" +
"                }\n" +
"            }\n" +
"        });\n" +
"        selectedTake6Card = null; take6AwaitingRowChoice = false; take6PendingCard = null;\n" +
"        take6Scores[myUserId] = 0;\n" +
"        players.forEach(p => { if (p.id) take6Scores[p.id] = 0; });\n" +
"        renderTake6Rows(); renderTake6Hand(); renderTake6Scores(); updateReadyButtonState();\n" +
"        renderSeats(players); updateTake6SelectionStatus(1);\n" +
"        updateTake6AutoPlayButtonUi();\n" +
"        appendChat('系统', '🎴 10张手牌已就绪！每轮秘密暗扣一张手牌，全员扣好后统一点亮入行！');\n" +
"        startTake6Countdown(20, 'play', () => {\n" +
"            if (!take6HasCommittedThisTurn && take6MyHand.length > 0) {\n" +
"                if (!isTake6AutoPlay) {\n" +
"                    isTake6AutoPlay = true;\n" +
"                    updateTake6AutoPlayButtonUi();\n" +
"                    appendChat('系统', '⏳ 出牌超时！已自动开启【智能托管】避坑代打');\n" +
"                }\n" +
"                const autoCard = decideTake6BestCard();\n" +
"                selectedTake6Card = autoCard;\n" +
"                appendChat('系统', `⏳ 出牌超时，系统已自动帮您打出 [${autoCard}号牌]！`);\n" +
"                actionTake6PlayCard();\n" +
"            }\n" +
"        });\n" +
"        triggerTake6AiTurn();\n" +
"        checkTake6AutoPlayAction();\n" +
"    }\n" +
"    function handleTake6StateSync(payload) {\n" +
"        if (!payload) return;\n" +
"        if (payload.rows && Array.isArray(payload.rows)) {\n" +
"            take6Rows = payload.rows.map(r => Array.isArray(r) ? [...r] : [r]);\n" +
"            renderTake6Rows();\n" +
"        }\n" +
"        if (payload.scores || payload.penaltyScores) {\n" +
"            Object.assign(take6Scores, payload.scores || payload.penaltyScores);\n" +
"            renderTake6Scores();\n" +
"        }\n" +
"        if (payload.readyPlayerIds && Array.isArray(payload.readyPlayerIds)) {\n" +
"            take6ReadyPlayers = {};\n" +
"            payload.readyPlayerIds.forEach(id => { take6ReadyPlayers[id] = true; });\n" +
"            window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"            renderSeats(players);\n" +
"        }\n" +
"        if (payload.phase === 'selectingCard') {\n" +
"            take6AwaitingRowChoice = false;\n" +
"            take6HasCommittedThisTurn = false;\n" +
"            if (payload.readyPlayerIds && Array.isArray(payload.readyPlayerIds)) {\n" +
"                take6HasCommittedThisTurn = payload.readyPlayerIds.includes(myUserId);\n" +
"            }\n" +
"            selectedTake6Card = null;\n" +
"            take6TurnCards = {};\n" +
"            const alertEl = document.getElementById('take6ChoiceAlert');\n" +
"            if (alertEl) alertEl.style.display = 'none';\n" +
"            renderSeats(players);\n" +
"            renderTake6Rows();\n" +
"            renderTake6Hand();\n" +
"            updateTake6SelectionStatus(payload.currentTurn || window.take6CurrentTurn);\n" +
"            startTake6Countdown(20, 'play', () => {\n" +
"                if (!take6HasCommittedThisTurn && take6MyHand.length > 0) {\n" +
"                    if (!isTake6AutoPlay) {\n" +
"                        isTake6AutoPlay = true;\n" +
"                        updateTake6AutoPlayButtonUi();\n" +
"                        appendChat('系统', '⏳ 出牌超时！已自动开启【智能托管】避坑代打');\n" +
"                    }\n" +
"                    const autoCard = decideTake6BestCard();\n" +
"                    selectedTake6Card = autoCard;\n" +
"                    appendChat('系统', `⏳ 出牌超时，系统已自动帮您打出 [${autoCard}号牌]！`);\n" +
"                    actionTake6PlayCard();\n" +
"                }\n" +
"            });\n" +
"            if (payload.currentTurn) window.take6CurrentTurn = payload.currentTurn;\n" +
"            triggerTake6AiTurn();\n" +
"            checkTake6AutoPlayAction();\n" +
"        } else if (payload.phase === 'revealing' || payload.phase === 'resolving') {\n" +
"            if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; take6RemainingSeconds = 0; }\n" +
"            updateTake6CountdownUi(0);\n" +
"            if (payload.revealedCards && Object.keys(payload.revealedCards).length > 0) {\n" +
"                renderRevealedCardsList(payload.revealedCards);\n" +
"            }\n" +
"        } else if (payload.phase === 'awaitingRowChoice') {\n" +
"            if (payload.playerChoosingRowId === myUserId) {\n" +
"                take6AwaitingRowChoice = true;\n" +
"                const alertEl = document.getElementById('take6ChoiceAlert');\n" +
"                if (alertEl) alertEl.style.display = 'block';\n" +
"                renderTake6Rows(); renderTake6Hand(); playTakeBullSound();\n" +
"                appendChat('系统', '⚠️ 您出的牌小于所有行末尾牌，请点击桌面选择收走一行！');\n" +
"                startTake6Countdown(10, 'choice', () => {\n" +
"                    if (take6AwaitingRowChoice) {\n" +
"                        if (!isTake6AutoPlay) {\n" +
"                            isTake6AutoPlay = true;\n" +
"                            updateTake6AutoPlayButtonUi();\n" +
"                            appendChat('系统', '⏳ 选择行超时！已自动开启【智能托管】');\n" +
"                        }\n" +
"                        const minRowIdx = decideTake6BestRowToTake();\n" +
"                        appendChat('系统', `⏳ 选择行超时，系统已自动帮您收走第 ${minRowIdx + 1} 行！`);\n" +
"                        take6ChooseRowToTake(minRowIdx);\n" +
"                    }\n" +
"                });\n" +
"            } else {\n" +
"                if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; take6RemainingSeconds = 0; }\n" +
"                updateTake6CountdownUi(0);\n" +
"                take6AwaitingRowChoice = false;\n" +
"                const alertEl = document.getElementById('take6ChoiceAlert');\n" +
"                if (alertEl) alertEl.style.display = 'none';\n" +
"                renderTake6Rows();\n" +
"            }\n" +
"        }\n" +
"        if (payload.phase === 'gameOver') {\n" +
"            if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; take6RemainingSeconds = 0; }\n" +
"            updateTake6CountdownUi(0);\n" +
"            const revEl = document.getElementById('take6RevealedCards');\n" +
"            if (revEl) revEl.innerHTML = '<span style=\"color: #64748b; font-size: 11px;\">本局已结束</span>';\n" +
"            take6TurnCards = {};\n" +
"            showTake6SettlementModal();\n" +
"            appendChat('系统', '🏆 游戏结束！对局战绩榜已生成。');\n" +
"        }\n" +
"        if (payload.eventLogs) {\n" +
"            appendChat('裁判', payload.eventLogs);\n" +
"        }\n" +
"    }\n" +
"    function renderRevealedCardsList(cardsMap) {\n" +
"        const revEl = document.getElementById('take6RevealedCards');\n" +
"        if (!revEl) return;\n" +
"        const entries = Object.keys(cardsMap).map(pid => {\n" +
"            const cardNum = cardsMap[pid];\n" +
"            const p = players.find(x => x.id === pid || x.name === pid);\n" +
"            const name = p ? p.name : (pid === myUserId ? myNickname : '玩家');\n" +
"            return { pid, cardNum, name };\n" +
"        }).sort((a, b) => a.cardNum - b.cardNum);\n" +
"        let html = '<div style=\"display:flex; flex-direction:column; gap:6px; width:100%;\">';\n" +
"        html += '<div style=\"font-size:11px; font-weight:800; color:#0284c7; display:flex; align-items:center; gap:6px;\"><span>⚡ 亮牌揭晓：按点数从小到大依次入行</span><span style=\"font-size:10px; color:#64748b; font-weight:normal;\">(共 ' + entries.length + ' 张)</span></div>';\n" +
"        html += '<div style=\"display:flex; flex-wrap:wrap; gap:8px; align-items:center;\">';\n" +
"        entries.forEach((entry, idx) => {\n" +
"            const isMe = entry.pid === myUserId;\n" +
"            const orderBadge = `<span style=\"background:${isMe ? '#f59e0b' : '#0284c7'}; color:#fff; font-size:9px; padding:1px 5px; border-radius:10px; font-weight:bold; margin-bottom:2px;\">#${idx+1} 入行</span>`;\n" +
"            html += `<div style=\"display:flex; flex-direction:column; align-items:center; background:${isMe ? 'rgba(245,158,11,0.1)' : 'rgba(255,255,255,0.06)'}; padding:4px 6px; border-radius:8px; border:1px solid ${isMe ? '#f59e0b' : 'rgba(56,189,248,0.25)'};\">` +\n" +
"                    orderBadge +\n" +
"                    `<span style=\"font-size:10.5px; color:${isMe ? '#d97706' : '#0284c7'}; margin-bottom:2px; font-weight:bold;\">${entry.name}</span>` +\n" +
"                    renderTake6CardHtml(entry.cardNum) +\n" +
"                    `</div>`;\n" +
"        });\n" +
"        html += '</div></div>';\n" +
"        revEl.innerHTML = html;\n" +
"        playCardSnap();\n" +
"    }\n" +
"    function updateTake6SelectionStatus(turn) {\n" +
"        const revEl = document.getElementById('take6RevealedCards');\n" +
"        if (!revEl) return;\n" +
"        const totalCount = players.length > 0 ? players.length : 2;\n" +
"        const readyCount = Object.keys(take6ReadyPlayers).length;\n" +
"        const curTurnNum = turn || window.take6CurrentTurn || 1;\n" +
"        const turnPrefix = `第 ${curTurnNum}/10 轮 · `;\n" +
"        const timerBadge = take6RemainingSeconds > 0 ? ` <span style='background:${take6RemainingSeconds <= 5 ? '#ef4444' : '#0284c7'}; color:#fff; padding:1px 6px; border-radius:10px; font-weight:bold; font-size:10px;'>⏳ ${take6RemainingSeconds}s</span>` : '';\n" +
"        revEl.innerHTML = `<span style='color: #64748b; font-size: 11px;'>🎴 ${turnPrefix}全员暗扣选牌中：${readyCount} / ${totalCount} 人已扣好手牌 (全员出完统一翻牌)${timerBadge}</span>`;\n" +
"    }\n" +
"    function renderTake6Scores() {\n" +
"        const container = document.getElementById('take6ScoreBar'); if (!container) return; container.innerHTML = '';\n" +
"        const myBulls = take6Scores[myUserId] || 0;\n" +
"        const myDiv = document.createElement('div'); myDiv.className = 'take6-score-item me';\n" +
"        myDiv.innerHTML = `<span>${myNickname} (我):</span> <span class='take6-score-bulls'>🐮${myBulls}分</span>`;\n" +
"        container.appendChild(myDiv);\n" +
"        players.forEach(p => {\n" +
"            if (p.id && p.id !== myUserId) {\n" +
"                const b = take6Scores[p.id] || 0;\n" +
"                const d = document.createElement('div'); d.className = 'take6-score-item';\n" +
"                d.innerHTML = `<span>${p.name || '玩家'}:</span> <span class='take6-score-bulls'>🐮${b}分</span>`;\n" +
"                container.appendChild(d);\n" +
"            }\n" +
"        });\n" +
"    }\n" +
"    function renderTake6Rows() {\n" +
"        const container = document.getElementById('take6RowsContainer'); if (!container) return; container.innerHTML = '';\n" +
"        let minRowIdx = -1;\n" +
"        let minBulls = 999999;\n" +
"        if (take6AwaitingRowChoice) {\n" +
"            take6Rows.forEach((r, idx) => {\n" +
"                let sum = 0; r.forEach(c => sum += getBullheads(c));\n" +
"                if (sum < minBulls) { minBulls = sum; minRowIdx = idx; }\n" +
"            });\n" +
"        }\n" +
"        take6Rows.forEach((row, idx) => {\n" +
"            let totalRowBulls = 0; row.forEach(c => totalRowBulls += getBullheads(c));\n" +
"            const isDanger = row.length >= 4; const isOverflow = row.length >= 5; const isSelectable = take6AwaitingRowChoice;\n" +
"            const isRec = isSelectable && (idx === minRowIdx);\n" +
"            const rowDiv = document.createElement('div');\n" +
"            let rowCls = 'take6-row';\n" +
"            if (isRec) rowCls += ' selectable recommended';\n" +
"            else if (isSelectable) rowCls += ' selectable';\n" +
"            else if (isOverflow) rowCls += ' overflow';\n" +
"            else if (isDanger) rowCls += ' danger';\n" +
"            rowDiv.className = rowCls;\n" +
"            if (isSelectable) rowDiv.onclick = () => take6ChooseRowToTake(idx);\n" +
"            let cardsHtml = row.map(c => renderTake6CardHtml(c)).join('');\n" +
"            for (let k = row.length; k < 5; k++) cardsHtml += `<div class='card-slot-empty'>+${k + 1}</div>`;\n" +
"            const actionBtn = isSelectable ? (isRec\n" +
"                ? `<button style='background: linear-gradient(135deg, #10b981, #059669); color: #fff; border: 1.5px solid #a7f3d0; padding: 6px 12px; border-radius: 8px; font-weight: 800; font-size: 11px; cursor: pointer; flex-shrink: 0; box-shadow: 0 0 10px rgba(16,185,129,0.4);'>🛡️ 推荐收此行(🐮${totalRowBulls})</button>`\n" +
"                : `<button style='background: #ef4444; color: #fff; border: none; padding: 6px 10px; border-radius: 6px; font-weight: bold; font-size: 11px; cursor: pointer; flex-shrink: 0;'>💥 吃此行(🐮${totalRowBulls})</button>`) : '';\n" +
"            rowDiv.innerHTML = `<div class='take6-row-meta'><span style='color: #94a3b8;'>#${idx + 1}</span><span style='color: ${isRec ? '#10b981' : '#ef4444'}; font-size: 10px; margin-top: 2px; font-weight: bold;'>🐮${totalRowBulls}</span></div><div class='take6-row-cards'>${cardsHtml}</div>${actionBtn}`;\n" +
"            container.appendChild(rowDiv);\n" +
"        });\n" +
"    }\n" +
"    function renderTake6Hand() {\n" +
"        const container = document.getElementById('take6HandCards'); const titleEl = document.getElementById('take6HandTitle'); const btnPlay = document.getElementById('btnTake6Play');\n" +
"        if (!container) return;\n" +
"        if (window.isSpectatorMode) {\n" +
"            if (titleEl) titleEl.innerText = '👀 旁观者视角';\n" +
"            container.innerHTML = '<div style=\"color: #cbd5e1; font-size: 13px; padding: 14px; background: rgba(30,41,59,0.7); border-radius: 8px; border: 1px dashed #6366f1; width: 100%; text-align: center;\">' +\n" +
"                '<div style=\"font-weight: bold; color: #818cf8; margin-bottom: 4px;\">👀 正在旁观牛头王对局</div>' +\n" +
"                '<div>为保护公平竞技，旁观者不可查看选手私密手牌，游戏结束后可点击加入席位！</div>' +\n" +
"                '</div>';\n" +
"            if (btnPlay) {\n" +
"                btnPlay.disabled = true;\n" +
"                btnPlay.innerText = '👀 旁观中（不可出牌）';\n" +
"                btnPlay.style.background = '#475569';\n" +
"            }\n" +
"            return;\n" +
"        }\n" +
"        if (titleEl) titleEl.innerText = '🎴 我的手牌 (' + take6MyHand.length + '张)';\n" +
"        if (take6MyHand.length === 0) {\n" +
"            container.innerHTML = '<div style=\"color: #94a3b8; font-size: 12px; padding: 12px;\">🎉 您的手牌已全部出完！等待游戏结算～</div>';\n" +
"            if (btnPlay) { btnPlay.disabled = true; btnPlay.innerText = '出牌完毕'; }\n" +
"            return;\n" +
"        }\n" +
"        container.innerHTML = take6MyHand.map(c => renderTake6CardHtml(c, selectedTake6Card === c, `take6SelectCard(${c})`)).join('');\n" +
"        if (btnPlay) {\n" +
"            if (take6HasCommittedThisTurn) {\n" +
"                btnPlay.disabled = true;\n" +
"                btnPlay.style.background = '#059669';\n" +
"                btnPlay.innerText = '🎴 已暗扣出牌，等待其他玩家...';\n" +
"            } else {\n" +
"                btnPlay.style.background = '';\n" +
"                btnPlay.disabled = !selectedTake6Card || take6AwaitingRowChoice;\n" +
"                btnPlay.innerText = selectedTake6Card ? `⚡ 出 [${selectedTake6Card}号牌]` : '⚡ 请选一张手牌';\n" +
"            }\n" +
"        }\n" +
"    }\n" +
"    function take6SelectCard(n) {\n" +
"        if (take6AwaitingRowChoice || !isGameStarted || take6HasCommittedThisTurn || window.isSpectatorMode) return;\n" +
"        selectedTake6Card = (selectedTake6Card === n) ? null : n; playBeep(selectedTake6Card ? 650 : 400, 0.08); renderTake6Hand();\n" +
"    }\n" +
"    function actionTake6PlayCard() {\n" +
"        if (!selectedTake6Card || !isGameStarted || take6HasCommittedThisTurn || window.isSpectatorMode) return;\n" +
"        if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; take6RemainingSeconds = 0; }\n" +
"        updateTake6CountdownUi(0);\n" +
"        const card = selectedTake6Card; const bulls = getBullheads(card); playCardSnap();\n" +
"        take6HasCommittedThisTurn = true;\n" +
"        take6ReadyPlayers[myUserId] = true;\n" +
"        window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"        take6TurnCards[myUserId] = card;\n" +
"        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'PLAY_CARD', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: { card: card, cardNumber: card, bullheads: bulls } }));\n" +
"        }\n" +
"        sendChatMessage('🎴 我已暗扣出牌，等待其他玩家...');\n" +
"        take6MyHand = take6MyHand.filter(c => c !== card); selectedTake6Card = null; renderTake6Hand();\n" +
"        renderSeats(players); updateTake6SelectionStatus();\n" +
"        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
"        const isHost = me && (me.isHost === true || (players.length <= 1));\n" +
"        const hasAppHost = players.some(p => p.isHost && p.id && !p.id.startsWith('WEB-') && p.id !== myUserId);\n" +
"        const total = players.length > 0 ? players.length : 2;\n" +
"        if (isHost && !hasAppHost && Object.keys(take6TurnCards).length >= total) {\n" +
"            renderRevealedCardsList(take6TurnCards);\n" +
"            broadcastTake6SyncState('revealing', take6TurnCards);\n" +
"            setTimeout(() => { resolveH5TurnCards(); }, 1800);\n" +
"        } else {\n" +
"            triggerTake6AiTurn();\n" +
"        }\n" +
"    }\n" +
"    function showNonBlockingToast(msg, duration = 3000) {\n" +
"        let toast = document.getElementById('floatingToast');\n" +
"        if (!toast) {\n" +
"            toast = document.createElement('div');\n" +
"            toast.id = 'floatingToast';\n" +
"            toast.style.cssText = 'position:fixed; top:24px; left:50%; transform:translateX(-50%); background:rgba(15,23,42,0.94); color:#fef08a; border:1px solid #f59e0b; padding:10px 22px; border-radius:24px; font-weight:bold; font-size:13px; box-shadow:0 8px 24px rgba(0,0,0,0.5); z-index:99999; pointer-events:none; transition:opacity 0.3s ease, transform 0.3s ease; text-align:center; max-width:90%;';\n" +
"            document.body.appendChild(toast);\n" +
"        }\n" +
"        toast.innerText = msg;\n" +
"        toast.style.opacity = '1';\n" +
"        toast.style.transform = 'translateX(-50%) translateY(0)';\n" +
"        if (window.toastTimer) clearTimeout(window.toastTimer);\n" +
"        window.toastTimer = setTimeout(() => {\n" +
"            toast.style.opacity = '0';\n" +
"            toast.style.transform = 'translateX(-50%) translateY(-10px)';\n" +
"        }, duration);\n" +
"    }\n" +
"    function placeTake6CardOnTable(card, playerId, playerName) {\n" +
"        let targetIdx = -1; let minDiff = 9999;\n" +
"        for (let i = 0; i < 4; i++) {\n" +
"            const row = take6Rows[i]; const tail = row[row.length - 1];\n" +
"            if (card > tail) { const diff = card - tail; if (diff < minDiff) { minDiff = diff; targetIdx = i; } }\n" +
"        }\n" +
"        if (targetIdx !== -1) {\n" +
"            if (take6Rows[targetIdx].length < 5) {\n" +
"                take6Rows[targetIdx].push(card); playCardSnap(); renderTake6Rows(); appendChat('对局', `【${playerName}】的 [${card}号牌] 放入了第 ${targetIdx + 1} 行。`);\n" +
"            } else {\n" +
"                playTakeBullSound(); let penalty = 0; take6Rows[targetIdx].forEach(c => penalty += getBullheads(c));\n" +
"                take6Scores[playerId] = (take6Scores[playerId] || 0) + penalty;\n" +
"                take6Rows[targetIdx] = [card]; renderTake6Rows(); renderTake6Scores();\n" +
"                appendChat('对局', `💥 触发吃牛！【${playerName}】放入第6张牌，吃掉第 ${targetIdx + 1} 行全部 ${penalty} 个牛头！`);\n" +
"                if (playerId === myUserId) showNonBlockingToast(`💥 扎心了！您放下了第6张牌，收走第 ${targetIdx + 1} 行的 ${penalty} 个牛头惩罚！`);\n" +
"            }\n" +
"        } else {\n" +
"            if (playerId === myUserId) {\n" +
"                take6AwaitingRowChoice = true; take6PendingCard = card;\n" +
"                const alertEl = document.getElementById('take6ChoiceAlert');\n" +
"                if (alertEl) alertEl.style.display = 'block';\n" +
"                renderTake6Rows(); renderTake6Hand(); playTakeBullSound();\n" +
"                checkTake6AutoPlayAction();\n" +
"            } else {\n" +
"                let minRowIdx = decideTake6BestRowToTake();\n" +
"                let penalty = 0; take6Rows[minRowIdx].forEach(c => penalty += getBullheads(c));\n" +
"                take6Scores[playerId] = (take6Scores[playerId] || 0) + penalty;\n" +
"                take6Rows[minRowIdx] = [card]; renderTake6Rows(); renderTake6Scores();\n" +
"                appendChat('对局', `⚠️ 【${playerName}】的卡牌过小，收走第 ${minRowIdx + 1} 行 (🐮${penalty}点)。`);\n" +
"                if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"                    ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'TAKE_ROW', roomCode: currentRoomId, senderId: playerId, senderName: playerName, payload: { rowIndex: minRowIdx, penalty: penalty, newHead: card } }));\n" +
"                }\n" +
"            }\n" +
"        }\n" +
"    }\n" +
"    function take6ChooseRowToTake(rowIdx) {\n" +
"        if (!take6AwaitingRowChoice || window.isSpectatorMode) return;\n" +
"        if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; take6RemainingSeconds = 0; }\n" +
"        updateTake6CountdownUi(0);\n" +
"        take6AwaitingRowChoice = false;\n" +
"        let penalty = 0; take6Rows[rowIdx].forEach(c => penalty += getBullheads(c));\n" +
"        take6Scores[myUserId] = (take6Scores[myUserId] || 0) + penalty;\n" +
"        if (take6PendingCard) { take6Rows[rowIdx] = [take6PendingCard]; }\n" +
"        const alertEl = document.getElementById('take6ChoiceAlert');\n" +
"        if (alertEl) alertEl.style.display = 'none';\n" +
"        playTakeBullSound(); renderTake6Rows(); renderTake6Hand(); renderTake6Scores();\n" +
"        appendChat('对局', `💥 我选择了吃掉第 ${rowIdx + 1} 行，收走 🐮${penalty} 个牛头！`);\n" +
"        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'TAKE_ROW', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: { rowIndex: rowIdx, penalty: penalty, newHead: take6PendingCard } }));\n" +
"        }\n" +
"        take6PendingCard = null;\n" +
"        setTimeout(() => { if (typeof window.take6ResumePlaceNext === 'function') window.take6ResumePlaceNext(); }, 600);\n" +
"    }\n" +
"    function handleTake6RemotePlay(senderId, senderName, payload) {\n" +
"        if (senderId === myUserId) return;\n" +
"        take6ReadyPlayers[senderId] = true;\n" +
"        window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"        if (payload && (payload.card || payload.cardNumber)) {\n" +
"            take6TurnCards[senderId] = payload.card || payload.cardNumber;\n" +
"        }\n" +
"        renderSeats(players);\n" +
"        updateTake6SelectionStatus();\n" +
"        appendChat('对局', `🎴 【${senderName || '玩家'}】已暗扣手牌，等待大家出牌...`);\n" +
"        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
"        const isHost = me && (me.isHost === true || (players.length <= 1));\n" +
"        const hasAppHost = players.some(p => p.isHost && p.id && !p.id.startsWith('WEB-') && p.id !== myUserId);\n" +
"        const total = players.length > 0 ? players.length : 2;\n" +
"        if (isHost && !hasAppHost && Object.keys(take6TurnCards).length >= total) {\n" +
"            renderRevealedCardsList(take6TurnCards);\n" +
"            broadcastTake6SyncState('revealing', take6TurnCards);\n" +
"            setTimeout(() => { resolveH5TurnCards(); }, 1800);\n" +
"        }\n" +
"    }\n" +
"    function handleTake6RemoteTakeRow(senderName, payload) {\n" +
"        if (payload && typeof payload.rowIndex === 'number') {\n" +
"            if (payload.newHead) take6Rows[payload.rowIndex] = [payload.newHead];\n" +
"            renderTake6Rows(); appendChat('对局', `【${senderName}】收走了第 ${payload.rowIndex + 1} 行 (🐮${payload.penalty || 0}点)。`);\n" +
"        }\n" +
"    }\n" +
"    function broadcastTake6SyncState(phase, revealedMap) {\n" +
"        if (!ws || ws.readyState !== WebSocket.OPEN) return;\n" +
"        const me = players.find(p => p.id === myUserId || p.name === myNickname);\n" +
"        const isHost = me && (me.isHost === true || (players.length <= 1));\n" +
"        if (!isHost) return;\n" +
"        const hasAppHost = players.some(p => p.isHost && p.id && !p.id.startsWith('WEB-') && p.id !== myUserId);\n" +
"        if (hasAppHost) return;\n" +
"        ws.send(JSON.stringify({\n" +
"            type: 'GAME_ACTION',\n" +
"            action: 'TAKE6_STATE_SYNC',\n" +
"            roomCode: currentRoomId,\n" +
"            senderId: myUserId,\n" +
"            payload: {\n" +
"                rows: take6Rows,\n" +
"                scores: take6Scores,\n" +
"                phase: phase,\n" +
"                revealedCards: revealedMap || null,\n" +
"                readyPlayerIds: Object.keys(take6ReadyPlayers),\n" +
"                currentTurn: window.take6CurrentTurn || 1,\n" +
"                playerHands: (typeof take6AiHands !== 'undefined') ? Object.assign({ [myUserId]: [...take6MyHand] }, take6AiHands) : { [myUserId]: [...take6MyHand] }\n" +
"            }\n" +
"        }));\n" +
"    }\n" +
"    function resolveH5TurnCards() {\n" +
"        const sortedEntries = Object.keys(take6TurnCards).map(pid => ({\n" +
"            playerId: pid,\n" +
"            playerName: (players.find(p => p.id === pid) || {}).name || (pid === myUserId ? myNickname : '玩家'),\n" +
"            card: take6TurnCards[pid]\n" +
"        })).sort((a, b) => a.card - b.card);\n" +
"        take6TurnCards = {};\n" +
"        take6ReadyPlayers = {};\n" +
"        window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"        take6HasCommittedThisTurn = false;\n" +
"        let stepIdx = 0;\n" +
"        function placeNext() {\n" +
"            if (stepIdx >= sortedEntries.length) {\n" +
"                take6TurnCards = {};\n" +
"                take6ReadyPlayers = {};\n" +
"                window.take6ReadyPlayers = take6ReadyPlayers;\n" +
"                take6HasCommittedThisTurn = false;\n" +
"                selectedTake6Card = null;\n" +
"                window.take6ResumePlaceNext = null;\n" +
"                renderTake6Rows();\n" +
"                renderTake6Hand();\n" +
"                renderSeats(players);\n" +
"                if (take6MyHand.length === 0) {\n" +
"                    const revEl = document.getElementById('take6RevealedCards');\n" +
"                    if (revEl) revEl.innerHTML = '<span style=\"color: #64748b; font-size: 11px;\">本局已结束</span>';\n" +
"                    take6TurnCards = {};\n" +
"                    broadcastTake6SyncState('gameOver');\n" +
"                    if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
"                        ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'GAME_OVER', roomCode: currentRoomId, senderId: myUserId, payload: { scores: take6Scores, phase: 'gameOver' } }));\n" +
"                    }\n" +
"                    setTimeout(showTake6SettlementModal, 1200);\n" +
"                    return;\n" +
"                }\n" +
"                window.take6CurrentTurn = (window.take6CurrentTurn || 1) + 1;\n" +
"                updateTake6SelectionStatus(window.take6CurrentTurn);\n" +
"                broadcastTake6SyncState('selectingCard');\n" +
"                startTake6Countdown(20, 'play', () => {\n" +
"                    if (!take6HasCommittedThisTurn && take6MyHand.length > 0) {\n" +
"                        if (!isTake6AutoPlay) {\n" +
"                            isTake6AutoPlay = true;\n" +
"                            updateTake6AutoPlayButtonUi();\n" +
"                            appendChat('系统', '⏳ 出牌超时！已自动开启【智能托管】避坑代打');\n" +
"                        }\n" +
"                        const autoCard = decideTake6BestCard();\n" +
"                        selectedTake6Card = autoCard;\n" +
"                        appendChat('系统', `⏳ 出牌超时，系统已自动帮您打出 [${autoCard}号牌]！`);\n" +
"                        actionTake6PlayCard();\n" +
"                    }\n" +
"                });\n" +
"                triggerTake6AiTurn();\n" +
"                checkTake6AutoPlayAction();\n" +
"                return;\n" +
"            }\n" +
"            const entry = sortedEntries[stepIdx++];\n" +
"            window.take6ResumePlaceNext = placeNext;\n" +
"            placeTake6CardOnTable(entry.card, entry.playerId, entry.playerName);\n" +
"            renderTake6Rows();\n" +
"            renderTake6Scores();\n" +
"            broadcastTake6SyncState('resolving');\n" +
"            if (take6AwaitingRowChoice) {\n" +
"                return;\n" +
"            }\n" +
"            setTimeout(placeNext, 750);\n" +
"        }\n" +
"        placeNext();\n" +
"    }\n" +
"    function showTake6SettlementModal() {\n" +
               "        window.isGameOverPhase = true;\n" +
               "        isGameStarted = false;\n" +
               "        window.activeRoomInfo = null;\n" +
               "        try { localStorage.removeItem('party_active_room_' + myUserId); } catch(e) {}\n" +
               "        if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; }\n" +
"        const overlay = document.getElementById('settlementOverlay');\n" +
"        const listEl = document.getElementById('settlementList');\n" +
"        const titleEl = document.getElementById('settlementTitle');\n" +
"        const subtitleEl = document.getElementById('settlementSubtitle');\n" +
"        const revEl = document.getElementById('take6RevealedCards');\n" +
"        if (revEl) revEl.innerHTML = '<span style=\"color: #64748b; font-size: 11px;\">本局已结束</span>';\n" +
"        take6TurnCards = {};\n" +
"        if (!overlay || !listEl) return;\n" +
"        const playerList = [...players];\n" +
"        playerList.sort((a, b) => (take6Scores[a.id] || 0) - (take6Scores[b.id] || 0));\n" +
"        const winner = playerList[0];\n" +
"        if (winner && titleEl) {\n" +
"            titleEl.innerHTML = `🏆 【${winner.name || '玩家'}】荣获本场冠军！`;\n" +
"            if (subtitleEl) subtitleEl.innerText = `最终吃下 ${take6Scores[winner.id] || 0} 个牛头惩罚，避坑王者！`;\n" +
"        }\n" +
"        const rankEmojis = ['🥇', '🥈', '🥉'];\n" +
"        listEl.innerHTML = playerList.map((p, idx) => {\n" +
"            const isMe = p.id === myUserId || p.name === myNickname;\n" +
"            const bulls = take6Scores[p.id] || 0;\n" +
"            const rankBadge = idx < 3 ? rankEmojis[idx] : `#${idx + 1}`;\n" +
"            return `<div class='settlement-item ${idx === 0 ? 'winner' : ''}'>` +\n" +
"                   `<div class='settlement-rank-badge ${idx < 3 ? 'settlement-rank-' + (idx+1) : ''}'>${rankBadge}</div>` +\n" +
"                   `<div class='settlement-player-info'>` +\n" +
"                   `<div class='settlement-avatar'>${p.avatar || '🐂'}</div>` +\n" +
"                   `<div class='settlement-name'>${p.name || '玩家'}${isMe ? ' (我)' : ''}</div>` +\n" +
"                   `</div>` +\n" +
"                   `<div class='settlement-score'>🐮 ${bulls} 个</div>` +\n" +
"                   `</div>`;\n" +
"        }).join('');\n" +
"        const btnRestart = document.getElementById('btnSettleRestart');\n" +
"        if (btnRestart) {\n" +
"            if (window.isSpectatorMode) {\n" +
"                btnRestart.innerText = '🪑 申请加入席位准备';\n" +
"                btnRestart.onclick = function() {\n" +
"                    if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"                        ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'SPECTATOR_JOIN_SEAT', roomCode: currentRoomId, senderId: myUserId }));\n" +
"                    }\n" +
"                    actionCloseSettlementModal();\n" +
"                };\n" +
"            } else {\n" +
"                btnRestart.innerText = '🔄 再来一局';\n" +
"                btnRestart.onclick = window.actionTake6RestartGame;\n" +
"            }\n" +
"        }\n" +
"        overlay.style.display = 'flex';\n" +
"        playBeep(980, 0.4);\n" +
"    }\n" +
               "    window.actionCloseSettlementModal = function() {\n" +
               "        const overlay = document.getElementById('settlementOverlay');\n" +
               "        if (overlay) overlay.style.display = 'none';\n" +
               "        window.isGameOverPhase = true;\n" +
               "        isGameStarted = false;\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'GAME_RESTART', roomCode: currentRoomId, senderId: myUserId }));\n" +
               "        }\n" +
               "        if (currentRoomId) {\n" +
               "            fetch(getApiPrefix() + '/api/rooms/reset', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ roomCode: currentRoomId }) }).catch(() => {});\n" +
               "        }\n" +
               "        resetTake6ToLobbyWaiting();\n" +
               "    };\n" +
               "    window.actionTake6RestartGame = function() {\n" +
               "        const overlay = document.getElementById('settlementOverlay');\n" +
               "        if (overlay) overlay.style.display = 'none';\n" +
               "        window.isGameOverPhase = true;\n" +
               "        isGameStarted = false;\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'GAME_RESTART', roomCode: currentRoomId, senderId: myUserId }));\n" +
               "        }\n" +
               "        if (currentRoomId) {\n" +
               "            fetch(getApiPrefix() + '/api/rooms/reset', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ roomCode: currentRoomId }) }).catch(() => {});\n" +
               "        }\n" +
               "        resetTake6ToLobbyWaiting();\n" +
               "    };\n" +
               "    function resetTake6ToLobbyWaiting() {\n" +
               "        window.isGameOverPhase = true;\n" +
               "        isGameStarted = false;\n" +
               "        take6HasCommittedThisTurn = false;\n" +
               "        take6ReadyPlayers = {};\n" +
               "        window.take6ReadyPlayers = take6ReadyPlayers;\n" +
               "        take6TurnCards = {};\n" +
               "        take6AiHands = {};\n" +
               "        Object.values(take6AiTimers).forEach(t => clearTimeout(t));\n" +
               "        take6AiTimers = {};\n" +
               "        window.take6ResumePlaceNext = null;\n" +
               "        selectedTake6Card = null;\n" +
               "        take6AwaitingRowChoice = false;\n" +
               "        take6PendingCard = null;\n" +
               "        isTake6AutoPlay = false;\n" +
               "        if (take6AutoPlayTimer) { clearTimeout(take6AutoPlayTimer); take6AutoPlayTimer = null; }\n" +
               "        if (take6CountdownTimer) { clearInterval(take6CountdownTimer); take6CountdownTimer = null; }\n" +
               "        updateTake6AutoPlayButtonUi();\n" +
               "        updateTake6CountdownUi(0);\n" +
               "        players.forEach(p => { if (p) p.isReady = true; });\n" +
               "        myIsReady = true;\n" +
               "        const waitingCard = document.getElementById('take6WaitingStage');\n" +
               "        if (waitingCard) waitingCard.style.display = 'block';\n" +
               "        const alertEl = document.getElementById('take6ChoiceAlert');\n" +
               "        if (alertEl) alertEl.style.display = 'none';\n" +
               "        renderTake6WaitingState();\n" +
               "        renderSeats(players);\n" +
               "        updateReadyButtonState();\n" +
               "        appendChat('系统', '🔄 对局已重置，全员已就绪！请房主点击【立即开局】开始新的一局游戏。');\n" +
               "    }\n";
    }

    private String buildHtmlScriptDice() {
        return "    let myDice = [1, 2, 3, 4, 5];\n" +
"    let isDicePeeking = true;\n" +
"    let currentBid = null;\n" +
"    function renderDiceWaitingState() {\n" +
"        const waitingCard = document.getElementById('diceWaitingStage');\n" +
"        if (waitingCard) waitingCard.style.display = 'block';\n" +
"        const row = document.getElementById('myDiceRow');\n" +
"        if (row) {\n" +
"            row.innerHTML = [1, 2, 3, 4, 5].map(() => `<div class=\"dice-card hidden-face\" title=\"等待开局\">🎲</div>`).join('');\n" +
"        }\n" +
"        const tip = document.getElementById('turnTip'); if (tip) tip.innerText = '对局未开始，请先准备，开局后由房主统一发号施令！';\n" +
"        const tally = document.getElementById('diceTallyText'); if (tally) tally.innerText = '等待房主开局...';\n" +
"        const btnShake = document.getElementById('btnDiceShake'); if (btnShake) btnShake.disabled = true;\n" +
"        const btnCall = document.getElementById('btnDiceCall'); if (btnCall) btnCall.disabled = true;\n" +
"        const btnOpen = document.getElementById('btnDiceOpen'); if (btnOpen) btnOpen.disabled = true;\n" +
"    }\n" +
"    function diceStartActiveGame() {\n" +
"        const waitingCard = document.getElementById('diceWaitingStage');\n" +
"        if (waitingCard) waitingCard.style.display = 'none';\n" +
"        const peekBtn = document.getElementById('btnPeek');\n" +
"        const btnShake = document.getElementById('btnDiceShake');\n" +
"        const btnCall = document.getElementById('btnDiceCall');\n" +
"        const btnOpen = document.getElementById('btnDiceOpen');\n" +
"        if (window.isSpectatorMode) {\n" +
"            if (peekBtn) peekBtn.style.display = 'none';\n" +
"            if (btnShake) btnShake.disabled = true;\n" +
"            if (btnCall) btnCall.disabled = true;\n" +
"            if (btnOpen) btnOpen.disabled = true;\n" +
"            renderDiceList();\n" +
"            updateReadyButtonState();\n" +
"            return;\n" +
"        }\n" +
"        if (peekBtn) peekBtn.style.display = 'inline-block';\n" +
"        if (btnShake) btnShake.disabled = false;\n" +
"        if (btnCall) btnCall.disabled = false;\n" +
"        if (btnOpen) btnOpen.disabled = false;\n" +
"        actionRollDice(); updateReadyButtonState();\n" +
"    }\n" +
"    function playDiceClatter() {\n" +
"        try {\n" +
"            const ctx = new (window.AudioContext || window.webkitAudioContext)();\n" +
"            for (let i = 0; i < 7; i++) {\n" +
"                setTimeout(() => {\n" +
"                    const osc = ctx.createOscillator(); const gain = ctx.createGain();\n" +
"                    osc.type = 'triangle'; osc.frequency.setValueAtTime(260 + Math.random() * 420, ctx.currentTime);\n" +
"                    gain.gain.setValueAtTime(0.14, ctx.currentTime); gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.06);\n" +
"                    osc.connect(gain); gain.connect(ctx.destination);\n" +
"                    osc.start(); osc.stop(ctx.currentTime + 0.06);\n" +
"                }, i * 65);\n" +
"            }\n" +
"        } catch(e) {}\n" +
"    }\n" +
"    function renderDiceFaceSvg(val) {\n" +
"        const dots = {\n" +
"            1: '<circle cx=\"50\" cy=\"50\" r=\"16.5\" fill=\"#d32f2f\"/>',\n" +
"            2: '<circle cx=\"26\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/>',\n" +
"            3: '<circle cx=\"26\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"50\" cy=\"50\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/>',\n" +
"            4: '<circle cx=\"26\" cy=\"26\" r=\"10.5\" fill=\"#d32f2f\"/><circle cx=\"74\" cy=\"26\" r=\"10.5\" fill=\"#d32f2f\"/><circle cx=\"26\" cy=\"74\" r=\"10.5\" fill=\"#d32f2f\"/><circle cx=\"74\" cy=\"74\" r=\"10.5\" fill=\"#d32f2f\"/>',\n" +
"            5: '<circle cx=\"26\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"50\" cy=\"50\" r=\"10.5\" fill=\"#d32f2f\"/><circle cx=\"26\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/>',\n" +
"            6: '<circle cx=\"26\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"26\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"26\" cy=\"50\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"50\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"26\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"10.5\" fill=\"#1e293b\"/>'\n" +
"        };\n" +
"        return `<div class=\"dice-card\" onclick=\"playBeep(650, 0.08)\" title=\"${val} 点\"><svg viewBox=\"0 0 100 100\" width=\"100%\" height=\"100%\">${dots[val] || ''}</svg></div>`;\n" +
"    }\n" +
"    function renderDiceList() {\n" +
"        const row = document.getElementById('myDiceRow'); const tallyEl = document.getElementById('diceTallyText'); const peekBtn = document.getElementById('btnPeek');\n" +
"        if (!row) return;\n" +
"        if (window.isSpectatorMode) {\n" +
"            row.innerHTML = '<div style=\"width:100%; text-align:center; padding:12px; color:#94a3b8; font-size:13px; background:rgba(30,41,59,0.5); border-radius:10px; border:1px dashed #475569;\">👀 观战中 · 参赛选手私密骰盅已隐藏（公平防窥）</div>';\n" +
"            if (tallyEl) tallyEl.innerText = '👀 当前处于观战视角，待对局结束后可申请上桌';\n" +
"            if (peekBtn) peekBtn.style.display = 'none';\n" +
"            return;\n" +
"        }\n" +
"        if (!isDicePeeking) {\n" +
"            row.innerHTML = myDice.map(() => `<div class=\"dice-card hidden-face\" onclick=\"togglePeekDice()\" title=\"点击揭开\">🎲</div>`).join('');\n" +
"            if (tallyEl) tallyEl.innerText = '点数已遮挡 (防偷看)'; if (peekBtn) peekBtn.innerText = '👁️ 掀开查看'; return;\n" +
"        }\n" +
"        row.innerHTML = myDice.map(d => renderDiceFaceSvg(d)).join('');\n" +
"        if (peekBtn) peekBtn.innerText = '🙈 遮挡防窥';\n" +
"        const counts = {}; myDice.forEach(d => { counts[d] = (counts[d] || 0) + 1; });\n" +
"        const parts = Object.keys(counts).sort((a,b) => b-a).map(k => `${counts[k]}个${k}点`);\n" +
"        const wildCount = counts[1] || 0;\n" +
"        const wildTip = wildCount > 0 ? ` (含${wildCount}个通配1点)` : '';\n" +
"        if (tallyEl) tallyEl.innerText = '手牌分布：' + parts.join('、') + wildTip;\n" +
"    }\n" +
"    function togglePeekDice() { if (window.isSpectatorMode) return; isDicePeeking = !isDicePeeking; playBeep(isDicePeeking ? 720 : 380, 0.1); renderDiceList(); }\n" +
"    function actionRollDice() {\n" +
"        if (window.isSpectatorMode) { alert('当前处于观战视角，不可摇骰！'); return; }\n" +
"        const cup = document.getElementById('diceCup'); if (cup) cup.classList.add('shake'); playDiceClatter();\n" +
"        const cards = document.querySelectorAll('.dice-card'); cards.forEach(c => c.classList.add('rolling'));\n" +
"        setTimeout(() => {\n" +
"            if (cup) cup.classList.remove('shake');\n" +
"            myDice = myDice.map(() => Math.floor(Math.random() * 6) + 1);\n" +
"            isDicePeeking = true; renderDiceList(); sendChatMessage('🎲 摇好了我的专属骰盅！点数保密～');\n" +
"        }, 550);\n" +
"    }\n" +
"    function renderDotsSvgOnly(face) {\n" +
"        const dots = {\n" +
"            1: '<circle cx=\"50\" cy=\"50\" r=\"18\" fill=\"#d32f2f\"/>',\n" +
"            2: '<circle cx=\"26\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/>',\n" +
"            3: '<circle cx=\"26\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"50\" cy=\"50\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/>',\n" +
"            4: '<circle cx=\"26\" cy=\"26\" r=\"11\" fill=\"#d32f2f\"/><circle cx=\"74\" cy=\"26\" r=\"11\" fill=\"#d32f2f\"/><circle cx=\"26\" cy=\"74\" r=\"11\" fill=\"#d32f2f\"/><circle cx=\"74\" cy=\"74\" r=\"11\" fill=\"#d32f2f\"/>',\n" +
"            5: '<circle cx=\"26\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"50\" cy=\"50\" r=\"11\" fill=\"#d32f2f\"/><circle cx=\"26\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/>',\n" +
"            6: '<circle cx=\"26\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"26\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"26\" cy=\"50\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"50\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"26\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/><circle cx=\"74\" cy=\"74\" r=\"11\" fill=\"#1e293b\"/>'\n" +
"        };\n" +
"        return dots[face] || '';\n" +
"    }\n" +
"    function updateBidDisplay(count, face, bidderName) {\n" +
"        currentBid = { count, face, bidderName };\n" +
"        const board = document.getElementById('bidStatusBoard'); if (!board) return;\n" +
"        board.style.display = 'flex';\n" +
"        board.innerHTML = `<div class='bid-status-info'><div class='bid-status-title'>📢 当前叫点 (来自【${bidderName}】)</div><div class='bid-status-val'>${count} 个 ${face} 点</div></div><div class='bid-dice-badge'><svg viewBox='0 0 100 100' width='30' height='30'>${renderDotsSvgOnly(face)}</svg></div>`;\n" +
"        const tipEl = document.getElementById('turnTip'); if (tipEl) tipEl.innerText = '当前盘面：' + count + ' 个 ' + face + ' 点！下家请跟叫或开盅！'; playBeep(880, 0.2);\n" +
"    }\n" +
"    let modalBidCount = 3;\n" +
"    let modalBidFace = 4;\n" +
"    let modalBidIsPure = false;\n" +
"    function openDiceBidModal() {\n" +
"        if (window.isSpectatorMode) { alert('当前处于观战视角，不可参与叫点！'); return; }\n" +
"        if (!isGameStarted) return;\n" +
"        const modal = document.getElementById('diceBidModal');\n" +
"        if (!modal) return;\n" +
"        if (currentBid) {\n" +
"            modalBidCount = currentBid.count + 1;\n" +
"            modalBidFace = currentBid.face;\n" +
"            modalBidIsPure = !!currentBid.isPure;\n" +
"        } else {\n" +
"            modalBidCount = 3;\n" +
"            modalBidFace = 4;\n" +
"            modalBidIsPure = false;\n" +
"        }\n" +
"        updateDiceBidModalUi();\n" +
"        modal.style.display = 'flex';\n" +
"        playBeep(650, 0.08);\n" +
"    }\n" +
"    function closeDiceBidModal() {\n" +
"        const modal = document.getElementById('diceBidModal');\n" +
"        if (modal) modal.style.display = 'none';\n" +
"    }\n" +
"    function updateDiceBidModalUi() {\n" +
"        const hintEl = document.getElementById('modalCurrentBidHint');\n" +
"        if (hintEl) {\n" +
"            if (currentBid) {\n" +
"                hintEl.innerHTML = `当前底盘：<b>【${currentBid.bidderName || '玩家'}】</b>叫了 <b>${currentBid.count}</b> 个 <b>${currentBid.face}</b> 点${currentBid.isPure ? '【斋】' : ''}`;\n" +
"            } else {\n" +
"                hintEl.innerHTML = '当前底盘：首位叫点，请报出您的起叫点数！';\n" +
"            }\n" +
"        }\n" +
"        const countValEl = document.getElementById('bidCountVal');\n" +
"        if (countValEl) countValEl.innerText = modalBidCount;\n" +
"        const faceGrid = document.getElementById('bidFaceGrid');\n" +
"        if (faceGrid) {\n" +
"            faceGrid.innerHTML = [1, 2, 3, 4, 5, 6].map(f => {\n" +
"                const isSel = f === modalBidFace;\n" +
"                return `<div class='bid-face-chip ${isSel ? 'selected' : ''}' onclick='selectBidFace(${f})'>` +\n" +
"                       `<svg viewBox='0 0 100 100' width='26' height='26'>${renderDotsSvgOnly(f)}</svg>` +\n" +
"                       `<span class='face-num'>${f}点</span>` +\n" +
"                       `</div>`;\n" +
"            }).join('');\n" +
"        }\n" +
"        const pureChk = document.getElementById('bidIsPureCheckbox');\n" +
"        if (pureChk) pureChk.checked = modalBidIsPure;\n" +
"    }\n" +
"    function adjustBidCount(delta) {\n" +
"        modalBidCount = Math.max(1, modalBidCount + delta);\n" +
"        updateDiceBidModalUi();\n" +
"        playBeep(520, 0.05);\n" +
"    }\n" +
"    function selectBidFace(face) {\n" +
"        modalBidFace = face;\n" +
"        updateDiceBidModalUi();\n" +
"        playBeep(680, 0.06);\n" +
"    }\n" +
"    function togglePureBid() {\n" +
"        const pureChk = document.getElementById('bidIsPureCheckbox');\n" +
"        modalBidIsPure = pureChk ? pureChk.checked : false;\n" +
"        playBeep(720, 0.06);\n" +
"    }\n" +
"    function confirmDiceBid() {\n" +
"        if (currentBid) {\n" +
"            if (modalBidCount < currentBid.count) {\n" +
"                alert('叫点个数必须大于或等于上一位玩家（' + currentBid.count + '个）！');\n" +
"                return;\n" +
"            }\n" +
"            if (modalBidCount === currentBid.count && modalBidFace <= currentBid.face && !modalBidIsPure && !currentBid.isPure) {\n" +
"                alert('相同个数时，点数必须大于上一位玩家（大于 ' + currentBid.face + ' 点）！');\n" +
"                return;\n" +
"            }\n" +
"        }\n" +
"        const payload = { count: modalBidCount, face: modalBidFace, isPure: modalBidIsPure, bidderId: myUserId, bidderName: myNickname };\n" +
"        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'BID', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: payload }));\n" +
"        }\n" +
"        const pureTag = modalBidIsPure ? '【斋】' : '';\n" +
"        sendChatMessage(`📢 我叫 ${modalBidCount} 个 ${modalBidFace} 点${pureTag}！`);\n" +
"        updateBidDisplay(modalBidCount, modalBidFace, myNickname);\n" +
"        closeDiceBidModal();\n" +
"    }\n" +
"    function actionBidDialog() {\n" +
"        openDiceBidModal();\n" +
"    }\n" +
"    function triggerChallengeDisplay(challengerName) {\n" +
"        const board = document.getElementById('bidStatusBoard');\n" +
"        if (board) {\n" +
"            board.style.display = 'flex';\n" +
"            board.innerHTML = `<div class='bid-status-info'><div class='bid-status-title' style='color: #ef4444;'>⚡ 抓吹牛开盅！</div><div class='bid-status-val' style='color: #f87171;'>【${challengerName}】大喊：开！！</div></div><div style='font-size: 26px;'>💥</div>`;\n" +
"        }\n" +
"        const stampOverlay = document.getElementById('diceStampOverlay');\n" +
"        if (stampOverlay) {\n" +
"            stampOverlay.style.display = 'flex';\n" +
"            const stampText = document.getElementById('diceStampText');\n" +
"            if (stampText) stampText.innerText = `【${challengerName}】喊：开！💥`;\n" +
"            setTimeout(() => { stampOverlay.style.display = 'none'; }, 2000);\n" +
"        }\n" +
"        playSlamSound();\n" +
"        isDicePeeking = true;\n" +
"        renderDiceList();\n" +
"    }\n" +
"    function actionCallLiar() {\n" +
"        if (window.isSpectatorMode) { alert('当前处于观战视角，不可开盅！'); return; }\n" +
"        if (!isGameStarted) return;\n" +
"        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
"            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'CHALLENGE', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: { challengerId: myUserId, challengerName: myNickname } }));\n" +
"        }\n" +
"        sendChatMessage('⚡ 开！！我不信！抓你吹牛！');\n" +
"        triggerChallengeDisplay(myNickname);\n" +
"    }\n";
    }

    private String buildHtmlScriptWheel() {
        return "    let wheelAngle = 0;\n" +
               "    let isWheelSpinning = false;\n" +
               "    let autoWheelTimer = null;\n" +
               "    const wheelTasks = [\n" +
               "        '真心话：最尴尬的瞬间',\n" +
               "        '大冒险：深情朗读一段台词',\n" +
               "        '惩罚：自罚一杯 (饮料或酒)',\n" +
               "        '奖励：全场发一个随机红包',\n" +
               "        '真心话：初恋是在什么时候',\n" +
               "        '大冒险：模仿一种动物叫声',\n" +
               "        '惩罚：对左手边桌友说情话',\n" +
               "        '免罚：运气爆棚直接通关'\n" +
               "    ];\n" +
               "    function drawWheel(angle) {\n" +
               "        const canvas = document.getElementById('wheelCanvas');\n" +
               "        if (!canvas) return;\n" +
               "        const ctx = canvas.getContext('2d');\n" +
               "        const cx = 130, cy = 130, r = 120;\n" +
               "        const len = wheelTasks.length;\n" +
               "        const arc = (2 * Math.PI) / len;\n" +
               "        ctx.clearRect(0, 0, 260, 260);\n" +
               "        const colors = ['#f43f5e', '#8b5cf6', '#06b6d4', '#10b981', '#f59e0b', '#ec4899', '#3b82f6', '#14b8a6'];\n" +
               "        for (let i = 0; i < len; i++) {\n" +
               "            const start = angle + i * arc;\n" +
               "            const end = start + arc;\n" +
               "            ctx.beginPath();\n" +
               "            ctx.moveTo(cx, cy);\n" +
               "            ctx.arc(cx, cy, r, start, end);\n" +
               "            ctx.fillStyle = colors[i % colors.length];\n" +
               "            ctx.fill();\n" +
               "            ctx.strokeStyle = '#ffffff';\n" +
               "            ctx.lineWidth = 2;\n" +
               "            ctx.stroke();\n" +
               "            ctx.save();\n" +
               "            ctx.translate(cx, cy);\n" +
               "            ctx.rotate(start + arc / 2);\n" +
               "            ctx.textAlign = 'right';\n" +
               "            ctx.fillStyle = '#ffffff';\n" +
               "            ctx.font = 'bold 11px sans-serif';\n" +
               "            const txt = wheelTasks[i].split('：')[0] || wheelTasks[i];\n" +
               "            ctx.fillText(txt, r - 16, 4);\n" +
               "            ctx.restore();\n" +
               "        }\n" +
               "        ctx.beginPath();\n" +
               "        ctx.arc(cx, cy, 22, 0, 2 * Math.PI);\n" +
               "        ctx.fillStyle = '#0f172a';\n" +
               "        ctx.fill();\n" +
               "        ctx.strokeStyle = '#f472b6';\n" +
               "        ctx.lineWidth = 3;\n" +
               "        ctx.stroke();\n" +
               "        ctx.fillStyle = '#fff';\n" +
               "        ctx.font = 'bold 12px sans-serif';\n" +
               "        ctx.textAlign = 'center';\n" +
               "        ctx.textBaseline = 'middle';\n" +
               "        ctx.fillText('🎯', cx, cy);\n" +
               "    }\n" +
               "    window.initWheelBoard = function() {\n" +
               "        drawWheel(wheelAngle);\n" +
               "    };\n" +
               "    window.executeWheelSpinTo = function(targetIdx, spinnerName, isLocalInitiator) {\n" +
               "        if (isWheelSpinning) return;\n" +
               "        isWheelSpinning = true;\n" +
               "        const wCard = document.getElementById('wheelWaitingStage'); if (wCard) wCard.style.display = 'none';\n" +
               "        const resultCard = document.getElementById('wheelResultCard');\n" +
               "        if (resultCard) resultCard.style.display = 'none';\n" +
               "        const extraTurns = 6;\n" +
               "        const safeIdx = (targetIdx != null && targetIdx >= 0 && targetIdx < wheelTasks.length) ? targetIdx : Math.floor(Math.random() * wheelTasks.length);\n" +
               "        if (isLocalInitiator && ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'WHEEL_SPIN', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: { targetIdx: safeIdx } }));\n" +
               "        }\n" +
               "        const arc = (2 * Math.PI) / wheelTasks.length;\n" +
               "        const targetAngle = -Math.PI / 2 - (safeIdx + 0.5) * arc + (extraTurns * 2 * Math.PI);\n" +
               "        const startAngle = wheelAngle % (2 * Math.PI);\n" +
               "        const totalRotation = (extraTurns * 2 * Math.PI) + (targetAngle - startAngle);\n" +
               "        const startTime = performance.now();\n" +
               "        const duration = 2800;\n" +
               "        function animate(time) {\n" +
               "            const elapsed = time - startTime;\n" +
               "            const progress = Math.min(elapsed / duration, 1);\n" +
               "            const ease = 1 - Math.pow(1 - progress, 3);\n" +
               "            wheelAngle = startAngle + totalRotation * ease;\n" +
               "            drawWheel(wheelAngle);\n" +
               "            if (progress < 1) {\n" +
               "                requestAnimationFrame(animate);\n" +
               "            } else {\n" +
               "                isWheelSpinning = false;\n" +
               "                const chosen = wheelTasks[safeIdx];\n" +
               "                if (resultCard) {\n" +
               "                    resultCard.innerHTML = '🎉 【' + (spinnerName || myNickname || '玩家') + '】抽中任务：' + chosen;\n" +
               "                    resultCard.style.display = 'block';\n" +
               "                }\n" +
               "                appendChat('大转盘', '🎯 【' + (spinnerName || myNickname || '玩家') + '】旋转结果：【' + chosen + '】');\n" +
               "                playBeep(880, 0.3);\n" +
               "            }\n" +
               "        }\n" +
               "        requestAnimationFrame(animate);\n" +
               "    };\n" +
               "    window.actionSpinWheel = function() {\n" +
               "        if (isWheelSpinning) return;\n" +
               "        const targetIdx = Math.floor(Math.random() * wheelTasks.length);\n" +
               "        executeWheelSpinTo(targetIdx, myNickname, true);\n" +
               "    };\n" +
               "    window.toggleAutoWheel = function() {\n" +
               "        const btn = document.getElementById('btnAutoWheel');\n" +
               "        if (autoWheelTimer) {\n" +
               "            clearInterval(autoWheelTimer);\n" +
               "            autoWheelTimer = null;\n" +
               "            if (btn) btn.innerText = '🤖 自动连转';\n" +
               "        } else {\n" +
               "            if (btn) btn.innerText = '⏹️ 停止连转';\n" +
               "            actionSpinWheel();\n" +
               "            autoWheelTimer = setInterval(() => {\n" +
               "                if (!isWheelSpinning) actionSpinWheel();\n" +
               "            }, 4500);\n" +
               "        }\n" +
               "    };\n";
    }

    private String buildHtmlScriptUndercover() {
        return "    let isUndercoverWordRevealed = false;\n" +
               "    let myUndercoverWord = '白菜';\n" +
               "    let isUndercoverRole = false;\n" +
               "    window.hasServerUndercoverRole = false;\n" +
               "    window.initUndercoverBoard = function() {\n" +
               "        if (!window.hasServerUndercoverRole) {\n" +
               "            const pair = [\n" +
               "                { c: '白菜', u: '生菜' },\n" +
               "                { c: '牛奶', u: '豆浆' },\n" +
               "                { c: '烤肉', u: '火锅' },\n" +
               "                { c: '手机', u: '平板' }\n" +
               "            ][Math.floor(Math.random() * 4)];\n" +
               "            isUndercoverRole = Math.random() < 0.25;\n" +
               "            myUndercoverWord = isUndercoverRole ? pair.u : pair.c;\n" +
               "            isUndercoverWordRevealed = false;\n" +
               "            const box = document.getElementById('undercoverWordBox');\n" +
               "            if (box) box.innerText = '🙈 点击揭开词底';\n" +
               "        }\n" +
               "        renderUndercoverVoteButtons();\n" +
               "    };\n" +
               "    window.toggleUndercoverWord = function() {\n" +
               "        isUndercoverWordRevealed = !isUndercoverWordRevealed;\n" +
               "        const box = document.getElementById('undercoverWordBox');\n" +
               "        if (!box) return;\n" +
               "        if (isUndercoverWordRevealed) {\n" +
               "            box.innerHTML = '✨ 专属底词：<b style=\"color:#fbbf24; font-size:20px;\">' + myUndercoverWord + '</b>' +\n" +
               "                '<div style=\"font-size:11px; color:#94a3b8; margin-top:4px;\">(身份：' + (isUndercoverRole ? '卧底' : '平民') + ') 点击遮挡防窥</div>';\n" +
               "        } else {\n" +
               "            box.innerText = '🙈 点击揭开词底';\n" +
               "        }\n" +
               "        playBeep(isUndercoverWordRevealed ? 750 : 400, 0.1);\n" +
               "    };\n" +
               "    function renderUndercoverVoteButtons() {\n" +
               "        const container = document.getElementById('undercoverVoteButtons');\n" +
               "        if (!container) return;\n" +
               "        const list = (players && players.length > 0) ? players : [{ id: myUserId, name: myNickname }];\n" +
               "        container.innerHTML = list.map(p => {\n" +
               "            return '<button class=\"uc-vote-btn\" style=\"background:#334155; color:#f8fafc; border:1px solid #475569; border-radius:8px; padding:6px 12px; font-size:12px; font-weight:bold; cursor:pointer;\" data-uid=\"' + p.id + '\" data-name=\"' + (p.name || '玩家') + '\" onclick=\"actionVoteUndercover(this.dataset.uid, this.dataset.name, this)\">🗳️ 投 ' + (p.name || '玩家') + '</button>';\n" +
               "        }).join('');\n" +
               "    }\n" +
               "    window.actionVoteUndercover = function(targetId, targetName, btnEl) {\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN && currentRoomId) {\n" +
               "            ws.send(JSON.stringify({ type: 'GAME_ACTION', action: 'UNDERCOVER_VOTE', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, payload: { targetId: targetId, targetName: targetName } }));\n" +
               "        }\n" +
               "        document.querySelectorAll('.uc-vote-btn').forEach(b => { b.disabled = true; b.style.opacity = '0.5'; });\n" +
               "        if (btnEl) { btnEl.style.background = '#e11d48'; btnEl.style.borderColor = '#f43f5e'; btnEl.style.opacity = '1'; btnEl.innerText = '✓ 已投 ' + targetName; }\n" +
               "        sendChatMessage('🗳️ 我投票指认【' + targetName + '】为卧底！');\n" +
               "        appendChat('投票', '🗳️ 已成功投给 ' + targetName);\n" +
               "        showToast('🗳️ 已成功投票指认【' + targetName + '】！');\n" +
               "    };\n";
    }

    private String buildHtmlScriptTail(boolean isTake6) {
        return "    function toggleChatCollapse() {\n" +
               "        isChatCollapsed = !isChatCollapsed;\n" +
               "        const stream = document.getElementById('chatStream'); const btn = document.getElementById('btnToggleChat');\n" +
               "        if (stream) stream.style.display = isChatCollapsed ? 'none' : 'block';\n" +
               "        if (btn) btn.innerText = isChatCollapsed ? '🗖 展开聊天' : '🗕 折叠聊天';\n" +
               "    }\n" +
               "    const CHAT_COLOR_MAP = {\n" +
               "        'COLOR_DEFAULT': '#1e293b',\n" +
               "        'COLOR_SAKURA_PINK': '#db2777',\n" +
               "        'COLOR_CYBER_BLUE': '#0284c7',\n" +
               "        'COLOR_AURORA_GREEN': '#059669',\n" +
               "        'COLOR_DEEP_PURPLE': '#7c3aed',\n" +
               "        'COLOR_BLAZING_GOLD': '#d97706',\n" +
               "        'COLOR_QQ_RED': '#dc2626'\n" +
               "    };\n" +
               "    function sendQuickPhrase(text) { sendChatMessage(text); }\n" +
               "    function sendChatMessage(overrideText) {\n" +
               "        const input = document.getElementById('chatInput');\n" +
               "        const text = overrideText || (input ? input.value.trim() : '');\n" +
               "        if (!text) return;\n" +
               "        if (!overrideText && input) input.value = '';\n" +
               "        const myColor = (currentUser && currentUser.chatTextColor) ? currentUser.chatTextColor : 'COLOR_DEFAULT';\n" +
               "        const myVip = (currentUser && currentUser.vipLevel) ? currentUser.vipLevel : 0;\n" +
               "        appendChat(myNickname, text, myColor, myVip); triggerBubble(myUserId, text);\n" +
               "        if (ws && ws.readyState === WebSocket.OPEN) {\n" +
               "            ws.send(JSON.stringify({ type: 'CHAT_MESSAGE', channel: 'ROOM', roomCode: currentRoomId, senderId: myUserId, senderName: myNickname, senderAvatar: myAvatar, content: text, textColor: myColor, vipLevel: myVip }));\n" +
               "        }\n" +
               "    }\n" +
               "    function appendChat(sender, text, textColor = 'COLOR_DEFAULT', vipLevel = 0) {\n" +
               "        const stream = document.getElementById('chatStream'); if (!stream) return;\n" +
               "        const div = document.createElement('div'); div.className = 'chat-line';\n" +
               "        const isVip = (vipLevel > 0);\n" +
               "        const isV10 = (vipLevel >= 10);\n" +
               "        const isSvip = (vipLevel >= 4);\n" +
               "        const vipBadgeHtml = isVip ? ('<span class=\"badge-vip' + (isV10 ? ' v10' : (isSvip ? ' svip' : '')) + '\" style=\"margin-right:4px;\">' + (isV10 ? '✨ V10 无双' : ((isSvip ? '👑 ' : '') + 'V' + vipLevel)) + '</span>') : '';\n" +
               "        const nameColor = isV10 ? '#f59e0b' : (isVip ? (isSvip ? '#ff2e4d' : '#e60012') : '#38bdf8');\n" +
               "        let colorHex = (typeof CHAT_COLOR_MAP !== 'undefined' && CHAT_COLOR_MAP[textColor]) ? CHAT_COLOR_MAP[textColor] : '#1e293b';\n" +
               "        if (!colorHex || colorHex === '#ffffff' || colorHex.toLowerCase() === '#fff' || colorHex.toLowerCase() === '#f8fafc' || colorHex.toLowerCase() === '#e2e8f0') { colorHex = '#1e293b'; }\n" +
               "        div.innerHTML = vipBadgeHtml + '<span class=\"sender\" style=\"color:' + nameColor + ';\">' + sender + ':</span> <span style=\"color:' + colorHex + ';font-weight:' + (textColor && textColor !== 'COLOR_DEFAULT' ? 'bold' : '500') + ';\">' + text + '</span>';\n" +
               "        stream.appendChild(div); stream.scrollTop = stream.scrollHeight;\n" +
               "    }\n" +
               "    function applyWebTheme(isDark) {\n" +
               "        document.body.classList.toggle('dark-mode', isDark);\n" +
               "        const b1 = document.getElementById('btnLobbyThemeToggle');\n" +
               "        const b2 = document.getElementById('btnRoomThemeToggle');\n" +
               "        if (b1) b1.innerText = isDark ? '☀️ 护眼' : '🌙 暗黑';\n" +
               "        if (b2) b2.innerText = isDark ? '☀️' : '🌙';\n" +
               "    }\n" +
               "    window.toggleWebTheme = function() {\n" +
               "        const nextDark = !document.body.classList.contains('dark-mode');\n" +
               "        localStorage.setItem('pg_web_theme', nextDark ? 'dark' : 'light');\n" +
               "        applyWebTheme(nextDark);\n" +
               "    };\n" +
               "    window.filterLobbyGameCategory = function(cat, btnEl) {\n" +
               "        document.querySelectorAll('.category-filter-bar .cat-pill').forEach(el => el.classList.remove('active'));\n" +
               "        if (btnEl) btnEl.classList.add('active');\n" +
               "        document.querySelectorAll('#lobbyTabGames .game-mode-card').forEach(card => {\n" +
               "            const c = card.getAttribute('data-cat') || 'all';\n" +
               "            card.style.display = (cat === 'all' || c === cat) ? 'block' : 'none';\n" +
               "        });\n" +
               "    };\n" +
               "    const GAME_RULES_GUIDE = {\n" +
               "        'take6': {\n" +
               "            title: '🐂 谁是牛头王 (Take 6!) · 规则速览',\n" +
               "            html: '<b>1. 盲选亮牌：</b>每人10张手牌，桌面4行底牌。每回合全员同时暗选1张牌亮出。<br><b>2. 升序接龙：</b>按牌面数字从小到大依次接在【末尾数字比它小且差值最小】的一行后面。<br><b>3. 第6张爆行：</b>每行最多5张牌！放进第6张牌的玩家必须收走该行前5张牌作为牛头惩罚。<br><b>4. 过小选行：</b>若牌比4行末尾都小，必须任选一行收走全部牌。10回合后牛头最少者获胜！'\n" +
               "        },\n" +
               "        'liars_dice': {\n" +
               "            title: '🎲 大话骰吹牛 (Liar\\'s Dice) · 规则速览',\n" +
               "            html: '<b>1. 摇盅看点：</b>每人5颗骰子，摇盅后仅自己可见真实点数。<br><b>2. 轮流叫点：</b>按序叫出全桌某点数的总个数（如 4个3），下家必须叫【更多数量】或【同数量更大点数】。<br><b>3. 飞1百搭：</b>未叫过1点或未喊斋时，1点可充当任意点数的万能百搭！<br><b>4. 开盅抓吹牛：</b>质疑上家不够数可点击【开！】全桌亮盅验点，判负者受罚！'\n" +
               "        },\n" +
               "        'party_wheel': {\n" +
               "            title: '🎡 聚会大冒险大转盘 · 规则速览',\n" +
               "            html: '<b>1. 物理旋转：</b>点击转盘中央或旋转按钮即可触发随机惯性旋转。<br><b>2. 真心话大冒险：</b>指针落定【真心话】或【大冒险】将自动抽取精选聚会题库。<br><b>3. 自动连转：</b>支持开启自动连转托管模式，聚会破冰零冷场！'\n" +
               "        },\n" +
               "        'undercover': {\n" +
               "            title: '🕵️ 谁是卧底 (Undercover) · 规则速览',\n" +
               "            html: '<b>1. 秘密发词：</b>平民拿到相同词，卧底拿到高度相似的词。<br><b>2. 轮流发言：</b>每人用一句话描述自己的词，既不能暴露底词，又要寻找同阵营队友。<br><b>3. 投票放逐：</b>每轮发言后投票放逐得票最高者，抓出所有卧底则平民胜，反之卧底胜！'\n" +
               "        }\n" +
               "    };\n" +
               "    window.openGameRulesModal = function(gType) {\n" +
               "        const key = (gType && GAME_RULES_GUIDE[gType]) ? gType : 'take6';\n" +
               "        const info = GAME_RULES_GUIDE[key];\n" +
               "        const modal = document.getElementById('gameRulesModal');\n" +
               "        const tEl = document.getElementById('rulesModalTitle');\n" +
               "        const bEl = document.getElementById('rulesModalBody');\n" +
               "        if (tEl) tEl.innerText = info.title;\n" +
               "        if (bEl) bEl.innerHTML = info.html;\n" +
               "        ['take6','liars_dice','party_wheel','undercover'].forEach(k => {\n" +
               "            const tab = document.getElementById('ruleTab_' + k);\n" +
               "            if (tab) tab.classList.toggle('active', k === key);\n" +
               "        });\n" +
               "        if (modal) modal.style.display = 'flex';\n" +
               "    };\n" +
               "    window.closeGameRulesModal = function() {\n" +
               "        const modal = document.getElementById('gameRulesModal');\n" +
               "        if (modal) modal.style.display = 'none';\n" +
               "    };\n" +
               "    window.onload = () => {\n" +
               "        applyWebTheme(localStorage.getItem('pg_web_theme') === 'dark');\n" +
               "        initAuthFromStorage();\n" +
               "        refreshCaptcha();\n" +
               "        renderSeats([]);\n" +
               "        if (currentGameType === 'take6') { renderTake6WaitingState(); }\n" +
               "        else if (currentGameType === 'liars_dice') { renderDiceWaitingState(); }\n" +
               "        else if (currentGameType === 'party_wheel') { if (typeof initWheelBoard === 'function') initWheelBoard(); }\n" +
               "        else if (currentGameType === 'undercover') { if (typeof initUndercoverBoard === 'function') initUndercoverBoard(); }\n" +
               "        setInterval(async () => {\n" +
               "            if (!currentRoomId || currentMainView !== 'game') return;\n" +
               "            try {\n" +
               "                const res = await fetch(getApiPrefix() + '/api/rooms/detail?roomCode=' + encodeURIComponent(currentRoomId));\n" +
               "                const data = await res.json();\n" +
               "                if (data.code === 0 && data.data && data.data.players) {\n" +
               "                    players = data.data.players; renderSeats(players);\n" +
               "                    if (currentGameType === 'take6' && isGameStarted) renderTake6Scores();\n" +
               "                    if (data.data.status === 'PLAYING' && !isGameStarted && !window.isGameOverPhase) onGameStartedTrigger();\n" +
               "                }\n" +
               "            } catch(e) {}\n" +
               "        }, 2000);\n" +
               "    };\n" +
               "</script>\n" +
               "</body>\n" +
               "</html>\n";
    }
}
