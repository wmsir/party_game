package com.partygame.controller;

import com.partygame.entity.Moment;
import com.partygame.entity.User;
import com.partygame.repository.MomentRepository;
import com.partygame.security.AdminAuthService;
import com.partygame.security.UserAuthService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@RestController
@RequiredArgsConstructor
public class RoomAndMomentController {

    private final MomentRepository momentRepository;
    private final UserAuthService userAuthService;
    private final AdminAuthService adminAuthService;

    private boolean isRoomHost(Map<String, Object> room, String userId) {
        if (room == null || userId == null) return false;
        Object hostObj = room.get("hostPlayer");
        if (hostObj instanceof Map<?, ?> host) {
            Object idObj = host.get("id");
            if (idObj != null && userAuthService.isSameUserId(userId, String.valueOf(idObj))) {
                return true;
            }
        }
        return false;
    }

    private boolean isRoomParticipant(Map<String, Object> room, String userId) {
        if (isRoomHost(room, userId)) return true;
        if (room == null || userId == null) return false;
        Object playersObj = room.get("players");
        if (playersObj instanceof List<?> players) {
            for (Object item : players) {
                if (item instanceof Map<?, ?> p && p.get("id") != null
                        && userAuthService.isSameUserId(userId, String.valueOf(p.get("id")))) {
                    return true;
                }
            }
        }
        return false;
    }

    // 内存房间映射 (轻量内存对局大厅状态)
    public static final Map<String, Map<String, Object>> ROOMS = new ConcurrentHashMap<>();
    // 全服大喇叭与全服盛典跑马灯最近缓存 (保留最近20条，确保后进入/重连客户端能无缝拉取展现)
    public static final java.util.concurrent.ConcurrentLinkedDeque<Map<String, Object>> RECENT_GLOBAL_BROADCASTS = new java.util.concurrent.ConcurrentLinkedDeque<>();

    @GetMapping({"/api/rooms", "/party-game/api/rooms"})
    public ResponseEntity<?> getRooms() {
        long now = System.currentTimeMillis();
        // 严密时效与活性过滤：只保留10分钟内且包含人类真人玩家的活跃房间，没有人类玩家直接销毁剔除！
        ROOMS.entrySet().removeIf(entry -> {
            Map<String, Object> r = entry.getValue();
            Object createdObj = r.get("createdAt");
            long createdAt = createdObj instanceof Number ? ((Number) createdObj).longValue() : 0L;
            boolean expired = (now - createdAt) > 10 * 60 * 1000;
            List<?> players = (List<?>) r.get("players");
            long humanCount = 0;
            if (players != null) {
                humanCount = players.stream().filter(p -> {
                    if (p instanceof Map) {
                        Object isAi = ((Map<?, ?>) p).get("isAi");
                        return isAi == null || !Boolean.parseBoolean(String.valueOf(isAi));
                    }
                    return false;
                }).count();
            }
            boolean noHumans = humanCount == 0;
            String status = (String) r.get("status");
            boolean closed = "CLOSED".equalsIgnoreCase(status);
            return expired || noHumans || closed;
        });

        List<Map<String, Object>> list = new ArrayList<>(ROOMS.values());
        return ResponseEntity.ok(createSuccess(list));
    }

    @GetMapping({"/api/rooms/detail", "/party-game/api/rooms/detail"})
    public ResponseEntity<?> getRoomDetail(@RequestParam("roomCode") String roomCode) {
        if (roomCode == null || roomCode.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "roomCode 不能为空"));
        }
        String cleanCode = roomCode.trim();
        Map<String, Object> room = ROOMS.get(cleanCode);
        if (room == null) {
            Map<String, Object> notFound = new HashMap<>();
            notFound.put("code", 404);
            notFound.put("message", "房间不存在");
            return ResponseEntity.ok(notFound);
        }
        return ResponseEntity.ok(createSuccess(room));
    }

    @PostMapping({"/api/rooms/create", "/party-game/api/rooms/create"})
    public ResponseEntity<?> createRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        Map<String, Object> hostPlayer = (Map<String, Object>) body.get("hostPlayer");
        String suppliedHostId = (hostPlayer != null && hostPlayer.get("id") != null) ? String.valueOf(hostPlayer.get("id")) : null;
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, suppliedHostId);

        // 优先使用客户端传来的统一 roomCode，避免双重房间号
        String roomCode = (String) body.get("roomCode");
        if (roomCode == null || roomCode.trim().isEmpty()) {
            roomCode = String.valueOf((int)(100000 + Math.random() * 900000));
        }

        // 商业化防重复：同一房主创建新房时，先清理其历史旧房
        if (hostPlayer == null) {
            hostPlayer = new HashMap<>();
            body.put("hostPlayer", hostPlayer);
        }
        String hostId = authed.getId();
        hostPlayer.put("id", hostId);
        hostPlayer.put("name", authed.getNickname() != null ? authed.getNickname() : hostPlayer.getOrDefault("name", "玩家"));
        hostPlayer.put("avatar", authed.getAvatar() != null ? authed.getAvatar() : hostPlayer.getOrDefault("avatar", "🦊"));
        ROOMS.entrySet().removeIf(entry -> {
            Map<String, Object> r = entry.getValue();
            Map<String, Object> h = (Map<String, Object>) r.get("hostPlayer");
            return h != null && userAuthService.isSameUserId(hostId, String.valueOf(h.get("id")));
        });
        hostPlayer.put("isHost", true);
        hostPlayer.put("isReady", true);

        Map<String, Object> room = new HashMap<>(body);
        room.put("roomCode", roomCode);
        room.put("status", "WAITING");
        room.put("createdAt", System.currentTimeMillis());
        room.putIfAbsent("allowSpectator", true);
        room.computeIfAbsent("spectators", k -> new ArrayList<>());

        // 确保 players 列表包含 hostPlayer
        List<Map<String, Object>> players = (List<Map<String, Object>>) room.computeIfAbsent("players", k -> new ArrayList<>());
        if (players.stream().noneMatch(p -> userAuthService.isSameUserId(hostId, String.valueOf(p.get("id"))))) {
            players.add(hostPlayer);
        }

        ROOMS.put(roomCode, room);
        log.info("[Room] Room created: code={}, host={}", roomCode, hostPlayer.get("name"));
        return ResponseEntity.ok(createSuccess(room));
    }

    @PostMapping({"/api/rooms/settings", "/party-game/api/rooms/settings"})
    public ResponseEntity<?> updateRoomSettings(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, null);
        String roomCode = (String) body.get("roomCode");
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            if (!isRoomHost(room, authed.getId())) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("code", 403, "message", "只有房主才能修改房间设置"));
            }
            if (body.containsKey("allowSpectator")) {
                boolean allow = Boolean.TRUE.equals(body.get("allowSpectator"));
                room.put("allowSpectator", allow);
                Map<String, Object> evt = new HashMap<>();
                evt.put("type", "ROOM_SETTINGS_UPDATED");
                evt.put("roomCode", roomCode);
                evt.put("allowSpectator", allow);
                evt.put("event", allow ? "📢 房主已开启房间观战权限" : "🔒 房主已关闭房间观战权限");
                com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(roomCode, evt, null);
            }
            if (body.containsKey("status")) {
                String st = String.valueOf(body.get("status"));
                room.put("status", st);
            }
            return ResponseEntity.ok(createSuccess(room));
        }
        return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "房间不存在"));
    }

    @PostMapping({"/api/rooms/join", "/party-game/api/rooms/join"})
    public ResponseEntity<?> joinRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String roomCode = (String) body.get("roomCode");
        Map<String, Object> player = (Map<String, Object>) body.get("player");
        String suppliedId = (player != null && player.get("id") != null) ? String.valueOf(player.get("id")) : null;
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, suppliedId);
        if (player == null) {
            player = new HashMap<>();
        }
        player.put("id", authed.getId());
        player.put("name", authed.getNickname() != null ? authed.getNickname() : player.getOrDefault("name", "玩家"));
        player.put("avatar", authed.getAvatar() != null ? authed.getAvatar() : player.getOrDefault("avatar", "🦊"));

        if (roomCode == null || !ROOMS.containsKey(roomCode)) {
            Map<String, Object> err = new HashMap<>();
            err.put("code", 404);
            err.put("message", "房间不存在或已被房主解散");
            return ResponseEntity.badRequest().body(err);
        }
        Map<String, Object> room = ROOMS.get(roomCode);
        List<Map<String, Object>> players = (List<Map<String, Object>>) room.computeIfAbsent("players", k -> new ArrayList<>());
        String status = (String) room.get("status");
        String uid = authed.getId();
        boolean isExistingPlayer = players.stream().anyMatch(p -> userAuthService.isSameUserId(uid, String.valueOf(p.get("id"))));

        // 核心观战逻辑：如果房间正在游戏中，且该用户不是本局在席玩家
        if ("PLAYING".equalsIgnoreCase(status) && !isExistingPlayer) {
            boolean allowSpectator = !Boolean.FALSE.equals(room.get("allowSpectator"));
            if (!allowSpectator) {
                Map<String, Object> err = new HashMap<>();
                err.put("code", 403);
                err.put("message", "当前对局正在进行中，且该房间已关闭观战功能");
                return ResponseEntity.status(403).body(err);
            }
            List<Map<String, Object>> spectators = (List<Map<String, Object>>) room.computeIfAbsent("spectators", k -> new ArrayList<>());
            if (spectators.stream().noneMatch(s -> userAuthService.isSameUserId(uid, String.valueOf(s.get("id"))))) {
                player.put("isSpectator", true);
                spectators.add(player);
            }
            Map<String, Object> retRoom = new HashMap<>(room);
            retRoom.put("isSpectator", true);
            return ResponseEntity.ok(createSuccess(retRoom));
        }

        player.put("isHost", players.isEmpty());
        player.put("isReady", players.isEmpty());
        if (players.stream().noneMatch(p -> userAuthService.isSameUserId(uid, String.valueOf(p.get("id"))))) {
            players.add(player);
        }

        // 立即广播房间玩家席位同步
        Map<String, Object> updateEvent = new HashMap<>();
        updateEvent.put("type", "ROOM_PLAYERS_UPDATED");
        updateEvent.put("roomCode", roomCode);
        updateEvent.put("event", "玩家【" + player.get("name") + "】加入房间");
        updateEvent.put("players", players);
        updateEvent.put("playerCount", players.size());
        com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(roomCode, updateEvent, null);

        return ResponseEntity.ok(createSuccess(room));
    }

    @PostMapping({"/api/rooms/add-ai", "/party-game/api/rooms/add-ai"})
    public ResponseEntity<?> addAiPlayer(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, null);
        String roomCode = (String) body.get("roomCode");
        if (roomCode == null || !ROOMS.containsKey(roomCode)) {
            Map<String, Object> err = new HashMap<>();
            err.put("code", 404);
            err.put("message", "房间不存在");
            return ResponseEntity.badRequest().body(err);
        }
        Map<String, Object> room = ROOMS.get(roomCode);
        if (!isRoomParticipant(room, authed.getId())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("code", 403, "message", "仅房间内成员可添加陪玩玩家"));
        }
        com.partygame.websocket.GameWebSocketHandler.autoFillRealisticPlayer(roomCode);
        return ResponseEntity.ok(createSuccess(ROOMS.get(roomCode)));
    }

    @PostMapping({"/api/rooms/ready", "/party-game/api/rooms/ready"})
    public ResponseEntity<?> setPlayerReady(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String roomCode = (String) body.get("roomCode");
        String suppliedPlayerId = (String) body.get("playerId");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, suppliedPlayerId);
        String playerId = authed.getId();
        Boolean isReady = (Boolean) body.get("isReady");
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
            if (players != null) {
                String pName = "玩家";
                for (Map<String, Object> p : players) {
                    if (userAuthService.isSameUserId(playerId, String.valueOf(p.get("id")))) {
                        p.put("isReady", isReady != null && isReady);
                        if (p.get("name") != null) pName = String.valueOf(p.get("name"));
                        break;
                    }
                }
                // 广播玩家准备状态变动
                Map<String, Object> readyEvt = new HashMap<>();
                readyEvt.put("type", "ROOM_PLAYERS_UPDATED");
                readyEvt.put("roomCode", roomCode);
                readyEvt.put("event", "玩家【" + pName + "】" + (isReady != null && isReady ? "已准备" : "取消了准备"));
                readyEvt.put("players", players);
                readyEvt.put("playerCount", players.size());
                com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(roomCode, readyEvt, null);
                log.info("[Room] Player ready updated: room={}, player={}, isReady={}", roomCode, playerId, isReady);
            }
            return ResponseEntity.ok(createSuccess(room));
        }
        return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "房间或玩家不存在"));
    }

    @PostMapping({"/api/rooms/reset", "/party-game/api/rooms/reset"})
    public ResponseEntity<?> resetRoomState(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, null);
        String roomCode = (String) body.get("roomCode");
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            if (!isRoomParticipant(room, authed.getId())) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("code", 403, "message", "仅房间内成员可重置对局状态"));
            }
            room.put("status", "WAITING");
            room.remove("take6Rows");
            room.remove("take6Scores");
            room.remove("take6InitialRows");
            room.remove("take6PlayerHands");
            List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
            if (players != null) {
                for (int i = 0; i < players.size(); i++) {
                    Map<String, Object> p = players.get(i);
                    p.put("isReady", true);
                }
            }
            Map<String, Object> syncEvent = new HashMap<>();
            syncEvent.put("type", "ROOM_PLAYERS_UPDATED");
            syncEvent.put("roomCode", roomCode);
            syncEvent.put("event", "对局结束，准备状态已重置");
            syncEvent.put("players", players);
            syncEvent.put("playerCount", players != null ? players.size() : 0);
            com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(roomCode, syncEvent, null);

            log.info("[Room] Room reset to WAITING: roomCode={}", roomCode);
            return ResponseEntity.ok(createSuccess(room));
        }
        return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "房间不存在"));
    }

    @PostMapping({"/api/rooms/leave", "/party-game/api/rooms/leave"})
    public ResponseEntity<?> leaveRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String roomCode = (String) body.get("roomCode");
        String playerId = (String) body.get("playerId");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, playerId);
        removePlayerFromRoom(roomCode, authed.getId());
        return ResponseEntity.ok(createSuccess(Map.of("message", "已离开房间", "roomCode", roomCode != null ? roomCode : "")));
    }

    @PostMapping({"/api/rooms/force-leave", "/party-game/api/rooms/force-leave"})
    public ResponseEntity<?> forceLeaveRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String roomCode = (String) body.get("roomCode");
        String playerId = (String) body.get("playerId");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, playerId);
        forceRemovePlayerFromRoom(roomCode, authed.getId());
        return ResponseEntity.ok(createSuccess(Map.of("message", "已强制放弃对局并退出房间", "roomCode", roomCode != null ? roomCode : "")));
    }

    /**
     * 房主把玩家踢出房间 (强制校验房主身份)
     */
    @PostMapping({"/api/rooms/kick", "/party-game/api/rooms/kick"})
    public ResponseEntity<?> kickPlayerFromRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        String roomCode = (String) body.get("roomCode");
        String operatorId = (String) body.get("operatorId");
        String targetPlayerId = (String) body.get("targetPlayerId");
        if (roomCode == null || targetPlayerId == null) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "缺少房间号或目标玩家编号"));
        }
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, operatorId);
        Map<String, Object> room = ROOMS.get(roomCode);
        if (room == null) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "房间不存在"));
        }
        String status = (String) room.get("status");
        if ("PLAYING".equals(status)) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "正在进行激烈游戏对战中，暂不可踢出玩家！"));
        }
        if (!isRoomHost(room, authed.getId())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("code", 403, "message", "只有房主才能踢出玩家！"));
        }
        if (userAuthService.isSameUserId(authed.getId(), targetPlayerId)) {
            return ResponseEntity.badRequest().body(Map.of("code", 400, "message", "房主不能踢出自己！"));
        }

        // 执行踢出玩家
        forceRemovePlayerFromRoom(roomCode, targetPlayerId);

        // 通知被踢出的玩家
        Map<String, Object> kickEvent = new HashMap<>();
        kickEvent.put("type", "KICKED_FROM_ROOM");
        kickEvent.put("roomCode", roomCode);
        kickEvent.put("targetPlayerId", targetPlayerId);
        kickEvent.put("message", "您已被房主移出该房间！");
        com.partygame.websocket.GameWebSocketHandler.sendToUser(targetPlayerId, kickEvent);

        // 向全房间广播玩家被踢通知
        Map<String, Object> broadcastEvent = new HashMap<>();
        broadcastEvent.put("type", "PLAYER_KICKED");
        broadcastEvent.put("roomCode", roomCode);
        broadcastEvent.put("targetPlayerId", targetPlayerId);
        broadcastEvent.put("players", room.get("players"));
        com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(roomCode, broadcastEvent, null);

        log.info("[Room] Host {} kicked player {} from room {}", operatorId, targetPlayerId, roomCode);
        return ResponseEntity.ok(createSuccess(Map.of("message", "已成功将玩家移出房间", "roomCode", roomCode)));
    }

    public static void removePlayerFromRoom(String roomCode, String playerId) {
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            String status = String.valueOf(room.get("status"));
            // 清理观战者席位（如果是观战者离开）
            List<Map<String, Object>> spectators = (List<Map<String, Object>>) room.get("spectators");
            if (spectators != null && playerId != null) {
                spectators.removeIf(s -> Objects.equals(String.valueOf(s.get("id")), playerId));
            }

            // 对局进行中退出：不剔除玩家，而是转为自动托管（isAutoPlay=true, online=false），保证房间与游戏持续进行
            if ("PLAYING".equalsIgnoreCase(status)) {
                List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
                if (players != null && playerId != null) {
                    for (Map<String, Object> p : players) {
                        if (Objects.equals(String.valueOf(p.get("id")), playerId)) {
                            p.put("online", false);
                            p.put("isAutoPlay", true);
                            p.put("offlineAt", System.currentTimeMillis());
                            log.info("[Room] Player {} in room {} switched to AutoPlay hosted state", playerId, roomCode);
                            break;
                        }
                    }
                }
                return;
            }

            Map<String, Object> host = (Map<String, Object>) room.get("hostPlayer");
            boolean isHost = host != null && Objects.equals(String.valueOf(host.get("id")), playerId);

            List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
            if (players != null && playerId != null) {
                players.removeIf(p -> Objects.equals(String.valueOf(p.get("id")), playerId));
            }

            // 统计剩余真人人类玩家数
            long humanCount = 0;
            if (players != null) {
                humanCount = players.stream().filter(p -> {
                    if (p instanceof Map) {
                        Object isAi = ((Map<?, ?>) p).get("isAi");
                        return isAi == null || !Boolean.parseBoolean(String.valueOf(isAi));
                    }
                    return false;
                }).count();
            }

            // 房主主动离开时，若还有其他玩家则将房主顺位转移，避免房间被直接打碎；仅当无人类玩家时才彻底销毁
            if (isHost && players != null && !players.isEmpty()) {
                Map<String, Object> newHost = players.get(0);
                newHost.put("isHost", true);
                room.put("hostPlayer", newHost);
                log.info("[Room] Host transferred to {}: code={}", newHost.get("name"), roomCode);
            }
            if (humanCount == 0) {
                ROOMS.remove(roomCode);
                log.info("[Room] Room destroyed upon all humans leave: code={}", roomCode);
            }
        }
    }

    public static void forceRemovePlayerFromRoom(String roomCode, String playerId) {
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            Map<String, Object> host = (Map<String, Object>) room.get("hostPlayer");
            String cleanTarget = playerId != null ? playerId.replace("-", "").toLowerCase() : "";
            boolean isHost = host != null && (Objects.equals(String.valueOf(host.get("id")), playerId) || 
                    String.valueOf(host.get("id")).replace("-", "").toLowerCase().equals(cleanTarget));

            List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
            if (players != null && playerId != null) {
                players.removeIf(p -> {
                    String pid = String.valueOf(p.get("id"));
                    return pid.equalsIgnoreCase(playerId) || pid.replace("-", "").toLowerCase().equals(cleanTarget);
                });
            }

            long humanCount = 0;
            if (players != null) {
                humanCount = players.stream().filter(p -> {
                    if (p instanceof Map) {
                        Object isAi = ((Map<?, ?>) p).get("isAi");
                        return isAi == null || !Boolean.parseBoolean(String.valueOf(isAi));
                    }
                    return false;
                }).count();
            }

            if (isHost && players != null && !players.isEmpty()) {
                Map<String, Object> newHost = players.get(0);
                newHost.put("isHost", true);
                room.put("hostPlayer", newHost);
            }
            if (humanCount == 0) {
                ROOMS.remove(roomCode);
                log.info("[Room] Room force destroyed: code={}", roomCode);
            }
        }
    }

    /**
     * 单账号单房间互斥策略：确保一个用户同时只能在一个房间玩游戏
     */
    public static synchronized void enforceSingleRoomPerUser(String userId, String currentRoomCode) {
        if (userId == null || userId.trim().isEmpty()) return;
        String cleanUid = userId.trim();
        List<String> roomsToEvict = new ArrayList<>();
        for (Map.Entry<String, Map<String, Object>> entry : ROOMS.entrySet()) {
            String rCode = entry.getKey();
            if (Objects.equals(rCode, currentRoomCode)) continue;
            Map<String, Object> room = entry.getValue();
            List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
            if (players != null) {
                boolean inRoom = players.stream().anyMatch(p -> Objects.equals(String.valueOf(p.get("id")), cleanUid));
                if (inRoom) {
                    roomsToEvict.add(rCode);
                }
            }
        }

        for (String oldRoomCode : roomsToEvict) {
            removePlayerFromRoom(oldRoomCode, cleanUid);
            log.info("[SingleRoomPolicy] User {} evicted from old room {} because they entered room {}", cleanUid, oldRoomCode, currentRoomCode);
            Map<String, Object> oldRoom = ROOMS.get(oldRoomCode);
            List<Map<String, Object>> remPlayers = oldRoom != null ? (List<Map<String, Object>>) oldRoom.get("players") : Collections.emptyList();
            Map<String, Object> leaveEvent = new HashMap<>();
            leaveEvent.put("type", "ROOM_PLAYERS_UPDATED");
            leaveEvent.put("roomCode", oldRoomCode);
            leaveEvent.put("event", "玩家在其他设备/房间进入了新游戏，已自动退出当前房间");
            leaveEvent.put("players", remPlayers);
            leaveEvent.put("playerCount", remPlayers.size());
            com.partygame.websocket.GameWebSocketHandler.broadcastToRoom(oldRoomCode, leaveEvent, null);
        }
    }

    /**
     * 获取玩家当前正在进行或等待中的活跃对战房间
     */
    @GetMapping({"/api/user/active-room", "/party-game/api/user/active-room"})
    public ResponseEntity<?> getUserActiveRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestParam(value = "userId", required = false) String userId) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, userId);
        long now = System.currentTimeMillis();
        // 自动清理超过15分钟或已关闭的无效房间
        ROOMS.entrySet().removeIf(entry -> {
            Map<String, Object> r = entry.getValue();
            if (r == null) return true;
            Object createdObj = r.get("createdAt");
            long createdAt = createdObj instanceof Number ? ((Number) createdObj).longValue() : 0L;
            boolean expired = (now - createdAt) > 15 * 60 * 1000;
            String st = String.valueOf(r.get("status"));
            boolean closed = "CLOSED".equalsIgnoreCase(st) || "FINISHED".equalsIgnoreCase(st);
            return expired || closed;
        });

        String cleanUid = authed.getId();
        for (Map.Entry<String, Map<String, Object>> entry : ROOMS.entrySet()) {
            Map<String, Object> r = entry.getValue();
            if (r == null) continue;
            String status = String.valueOf(r.get("status"));
            if ("CLOSED".equalsIgnoreCase(status) || "FINISHED".equalsIgnoreCase(status)) {
                continue;
            }
            List<Map<String, Object>> players = (List<Map<String, Object>>) r.get("players");
            if (players != null && !players.isEmpty()) {
                Map<String, Object> matchedPlayer = null;
                for (Map<String, Object> p : players) {
                    if (Objects.equals(String.valueOf(p.get("id")), cleanUid)) {
                        matchedPlayer = p;
                        break;
                    }
                }
                if (matchedPlayer != null) {
                    Map<String, Object> info = new HashMap<>();
                    info.put("roomCode", r.get("roomCode"));
                    info.put("roomName", r.get("roomName"));
                    info.put("gameType", r.get("gameType"));
                    info.put("status", r.get("status"));
                    info.put("playerCount", players.size());
                    info.put("isAutoPlay", Boolean.TRUE.equals(matchedPlayer.get("isAutoPlay")));
                    info.put("isHost", Boolean.TRUE.equals(matchedPlayer.get("isHost")));
                    return ResponseEntity.ok(Map.of("code", 200, "hasActiveRoom", true, "activeRoom", info));
                }
            }
        }
        Map<String, Object> emptyRes = new HashMap<>();
        emptyRes.put("code", 200);
        emptyRes.put("hasActiveRoom", false);
        emptyRes.put("activeRoom", null);
        return ResponseEntity.ok(emptyRes);
    }

    @PostMapping({"/api/rooms/close", "/party-game/api/rooms/close"})
    public ResponseEntity<?> closeRoom(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, null);
        String roomCode = (String) body.get("roomCode");
        if (roomCode != null && ROOMS.containsKey(roomCode)) {
            Map<String, Object> room = ROOMS.get(roomCode);
            if (!isRoomHost(room, authed.getId())) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("code", 403, "message", "只有房主才能解散房间"));
            }
            ROOMS.remove(roomCode);
            log.info("[Room] Room closed and removed: code={}, host={}", roomCode, authed.getId());
        }
        return ResponseEntity.ok(createSuccess(Map.of("message", "房间已解散", "roomCode", roomCode != null ? roomCode : "")));
    }

    @PostMapping({"/api/rooms/clear", "/party-game/api/rooms/clear"})
    public ResponseEntity<?> clearRooms(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-Admin-Token", required = false) String adminHeader) {
        String token = (authHeader != null && !authHeader.isBlank()) ? authHeader : adminHeader;
        AdminAuthService.AdminSession session = adminAuthService.validateToken(token);
        if (session == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("code", 401, "message", "仅管理员可清空全服房间"));
        }
        ROOMS.clear();
        log.info("[Room] All online rooms cleared by admin: {}", session.getUsername());
        return ResponseEntity.ok(createSuccess(Map.of("message", "所有在线房间已清空", "cleared", true)));
    }

    @GetMapping({"/api/moments", "/party-game/api/moments"})
    public ResponseEntity<?> getMoments() {
        List<Moment> list = momentRepository.findAllByOrderByCreatedAtDesc();
        return ResponseEntity.ok(createSuccess(list));
    }

    @PostMapping({"/api/moments/publish", "/party-game/api/moments/publish"})
    public ResponseEntity<?> publishMoment(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, String> body) {
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, body.get("authorId"));
        String id = "M-" + System.currentTimeMillis();
        Moment m = Moment.builder()
                .id(id)
                .authorId(authed.getId())
                .authorName(authed.getNickname() != null ? authed.getNickname() : body.get("authorName"))
                .authorAvatar(authed.getAvatar() != null ? authed.getAvatar() : body.get("authorAvatar"))
                .content(body.get("content"))
                .gameTag(body.get("gameTag"))
                .recordHighlight(body.get("recordHighlight"))
                .likeCount(0)
                .build();
        Moment saved = momentRepository.save(m);
        return ResponseEntity.ok(createSuccess(saved));
    }

    /**
     * 全服跑马灯与全局盛典特效广播（HTTP 兜底 + 全局 WebSocket 广播双保险）
     */
    @PostMapping({"/api/chat/global-broadcast", "/party-game/api/chat/global-broadcast"})
    public ResponseEntity<?> globalBroadcast(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestHeader(value = "X-User-Token", required = false) String userTokenHeader,
            @RequestBody Map<String, Object> body) {
        Object rawSender = body.get("senderId");
        User authed = userAuthService.requireUser(authHeader, userTokenHeader, rawSender != null ? String.valueOf(rawSender) : null);
        body.put("senderId", authed.getId());
        body.put("senderName", authed.getNickname() != null ? authed.getNickname() : "玩家");
        body.put("senderAvatar", authed.getAvatar() != null ? authed.getAvatar() : "🦊");
        body.put("senderVip", authed.getVipLevel() != null ? authed.getVipLevel() : 0);
        body.put("type", "GLOBAL_BROADCAST_EVENT");
        if (!body.containsKey("timestamp")) {
            body.put("timestamp", System.currentTimeMillis());
        }
        if (!body.containsKey("id")) {
            body.put("id", "BLS-" + System.currentTimeMillis());
        }
        if (!body.containsKey("broadcastType")) {
            body.put("broadcastType", "MARQUEE");
        }
        if (!body.containsKey("itemType")) {
            body.put("itemType", "MARQUEE");
        }
        if (!body.containsKey("itemEmoji")) {
            body.put("itemEmoji", "📢");
        }
        if (!body.containsKey("giftTitle")) {
            body.put("giftTitle", "全服大喇叭");
        }
        Object bVal = body.get("blessing");
        if (bVal == null) bVal = body.get("content");
        if (bVal == null) bVal = body.get("message");
        String bStr = (bVal != null && !bVal.toString().trim().isEmpty()) ? bVal.toString() : "祝大家游戏愉快，天天赢大奖！";
        body.put("blessing", bStr);
        body.put("content", bStr);
        body.put("message", bStr);

        recordRecentGlobalBroadcast(body);

        com.partygame.websocket.GameWebSocketHandler.broadcastToAll(body, null);
        log.info("[HTTP] 全服广播播发成功: {}", body.get("blessing"));
        return ResponseEntity.ok(createSuccess(Map.of("status", "ok")));
    }

    public static synchronized void recordRecentGlobalBroadcast(Map<String, Object> broadcast) {
        if (broadcast == null) return;
        Object id = broadcast.get("id");
        if (id != null) {
            for (Map<String, Object> existing : RECENT_GLOBAL_BROADCASTS) {
                if (Objects.equals(existing.get("id"), id)) {
                    return; // 已经缓存，去重
                }
            }
        }
        RECENT_GLOBAL_BROADCASTS.addFirst(new HashMap<>(broadcast));
        while (RECENT_GLOBAL_BROADCASTS.size() > 20) {
            RECENT_GLOBAL_BROADCASTS.removeLast();
        }
    }

    /**
     * 获取最近 5 分钟内的全服大喇叭历史 (方便后上线的客户端实时补全展示)
     */
    @GetMapping({"/api/chat/global-broadcast/recent", "/party-game/api/chat/global-broadcast/recent"})
    public ResponseEntity<?> getRecentGlobalBroadcasts() {
        long fiveMinAgo = System.currentTimeMillis() - 5 * 60 * 1000;
        List<Map<String, Object>> valid = new ArrayList<>();
        for (Map<String, Object> b : RECENT_GLOBAL_BROADCASTS) {
            Object tsObj = b.get("timestamp");
            long ts = (tsObj instanceof Number) ? ((Number) tsObj).longValue() : 0L;
            if (ts >= fiveMinAgo) {
                valid.add(b);
            }
        }
        return ResponseEntity.ok(createSuccess(valid));
    }

    private Map<String, Object> createSuccess(Object data) {
        Map<String, Object> map = new HashMap<>();
        map.put("code", 0);
        map.put("data", data);
        return map;
    }
}
