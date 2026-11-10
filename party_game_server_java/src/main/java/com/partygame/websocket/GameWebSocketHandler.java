package com.partygame.websocket;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.partygame.entity.DirectMessageRecord;
import com.partygame.entity.UserIntimacy;
import com.partygame.repository.DirectMessageRepository;
import com.partygame.repository.UserIntimacyRepository;
import com.partygame.controller.IntimacyController;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.partygame.controller.RoomAndMomentController;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;

@Slf4j
@Component
@RequiredArgsConstructor
public class GameWebSocketHandler extends TextWebSocketHandler {

    private final DirectMessageRepository directMessageRepository;
    private final UserIntimacyRepository intimacyRepository;
    private final com.partygame.service.FriendService friendService;
    private final com.partygame.repository.UserRepository userRepository;

    private static final ScheduledExecutorService SCHEDULER = Executors.newScheduledThreadPool(4);

    public static final List<String> REALISTIC_AI_NAMES = List.of(
            "落落清欢", "微风拂过星河", "打牌从不看牌", "大眼萌妹", "今天也想暴富",
            "江南皮革厂销冠", "爱喝暴打柠檬茶", "甜妹不吃香菜", "秋刀鱼会过期", "炸串第一名",
            "夜市小霸王", "半支烟的距离", "西湖断桥客", "向日葵的守望", "一壶浊酒醉江南",
            "骑猪看日出", "火锅狂热爱好者", "深海潜水员", "清晨第一缕阳光", "快乐小肥宅"
    );

    public static final List<String> REALISTIC_AI_AVATARS = List.of(
            "🦊", "🐼", "🦁", "🐯", "🐰", "🦄", "🐨", "🐺", "🐱", "🐶", "🐻", "🐬", "🌸", "🌟"
    );

    public static final List<String> AI_GREETINGS = List.of(
            "来了来了！刚好看到召集就进来了~",
            "冲冲冲，人齐了吗？这把看我操作！",
            "哈喽大家好呀，随时准备着！",
            "刚刷到召集广播，带我一个~",
            "来啦！今晚手感火热，直接开！"
    );

    public static final List<String> AI_GIFT_THANKS = List.of(
            "哇！谢谢老板的礼物❤️，太破费啦！",
            "收到礼物啦~ 笔芯笔芯！这把稳赢！",
            "老板大气！这局看我怎么带飞~",
            "谢谢小伙伴，亲密度蹭蹭涨！🥰"
    );

    // 谁是卧底经典丰富词库（权威题库）
    public static final List<List<String>> UNDERCOVER_WORDS = List.of(
            List.of("微信", "QQ"),
            List.of("可口可乐", "百事可乐"),
            List.of("汉堡包", "肉夹馍"),
            List.of("小龙虾", "大闸蟹"),
            List.of("秋裤", "毛裤"),
            List.of("自行车", "电动车"),
            List.of("玫瑰", "月季"),
            List.of("鸭脖", "鸡爪"),
            List.of("雨伞", "雨衣"),
            List.of("口红", "唇膏"),
            List.of("牛奶", "豆浆"),
            List.of("烤肉", "火锅"),
            List.of("手机", "平板"),
            List.of("吉他", "尤克里里"),
            List.of("咖啡", "奶茶"),
            List.of("枕头", "抱枕"),
            List.of("毛巾", "浴巾"),
            List.of("眉毛", "睫毛"),
            List.of("包子", "饺子"),
            List.of("橙子", "橘子"),
            List.of("西瓜", "哈密瓜"),
            List.of("拖鞋", "凉鞋"),
            List.of("镜子", "玻璃"),
            List.of("风扇", "空调"),
            List.of("辣椒", "芥末"),
            List.of("面条", "米线"),
            List.of("跳绳", "拔河"),
            List.of("象棋", "围棋"),
            List.of("铅笔", "钢笔"),
            List.of("森林", "树林")
    );

    private static class ClientMeta {
        String userId;
        String nickname;
        String roomCode;
        boolean isSpectator = false;
        volatile long lastActiveTime = System.currentTimeMillis();
        Set<String> channels = ConcurrentHashMap.newKeySet();

        ClientMeta() {
            channels.add("WORLD");
        }
    }

    @jakarta.annotation.PostConstruct
    public void initHeartbeatReaper() {
        SCHEDULER.scheduleWithFixedDelay(() -> {
            try {
                long now = System.currentTimeMillis();
                for (Map.Entry<WebSocketSession, ClientMeta> entry : clients.entrySet()) {
                    WebSocketSession session = entry.getKey();
                    ClientMeta meta = entry.getValue();
                    if (!session.isOpen()) {
                        clients.remove(session);
                        continue;
                    }
                    if (now - meta.lastActiveTime > 75000) {
                        log.info("[WS Reaper] 自动剔除超时僵尸连接: uid={}, room={}", meta.userId, meta.roomCode);
                        try {
                            session.close(CloseStatus.SESSION_NOT_RELIABLE);
                        } catch (Exception ignored) {}
                    } else {
                        try {
                            session.sendMessage(new TextMessage(JSON.toJSONString(Map.of("type", "HEARTBEAT_PING", "timestamp", now))));
                        } catch (Exception ignored) {}
                    }
                }
            } catch (Exception e) {
                log.warn("[WS Reaper] 心跳巡检异常: {}", e.getMessage());
            }
        }, 15, 25, TimeUnit.SECONDS);
    }

    private static final Map<WebSocketSession, ClientMeta> clients = new ConcurrentHashMap<>();
    private final Map<String, List<Map<String, Object>>> OFFLINE_MESSAGES = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        ClientMeta meta = new ClientMeta();
        clients.put(session, meta);

        Map<String, Object> welcome = new HashMap<>();
        welcome.put("type", "CONNECTED");
        welcome.put("serverTime", System.currentTimeMillis());
        welcome.put("port", 9001);
        welcome.put("message", "🎉 成功连接到 9001 聚会桌游即时同步中枢 (Java 原生引擎)");
        session.sendMessage(new TextMessage(JSON.toJSONString(welcome)));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        String payload = message.getPayload();
        try {
            JSONObject msg = JSON.parseObject(payload);
            String type = msg.getString("type");
            ClientMeta meta = clients.get(session);
            if (meta == null || type == null) return;
            meta.lastActiveTime = System.currentTimeMillis();
            if ("PONG".equals(type) || "HEARTBEAT_PONG".equals(type)) {
                return;
            }

            switch (type) {
                case "INIT_USER":
                    meta.userId = msg.getString("userId") != null ? msg.getString("userId").trim() : null;
                    meta.nickname = msg.getString("nickname") != null ? msg.getString("nickname").trim() : "玩家";
                    log.info("[WS] INIT_USER registered: userId={}, nickname={}", meta.userId, meta.nickname);
                    // 用户上线时自动补发离线期间收到的好友私信（从数据库可靠读取）
                    if (meta.userId != null) {
                        try {
                            List<DirectMessageRecord> unread = directMessageRepository.findByToUserIdAndIsReadFalseOrderByTimestampAsc(meta.userId);
                            if (unread != null && !unread.isEmpty()) {
                                for (DirectMessageRecord r : unread) {
                                    Map<String, Object> dm = new HashMap<>();
                                    dm.put("type", "DIRECT_MESSAGE");
                                    dm.put("id", r.getId());
                                    dm.put("toUserId", r.getToUserId());
                                    dm.put("fromUserId", r.getFromUserId());
                                    dm.put("fromNickname", r.getFromNickname());
                                    dm.put("fromAvatar", r.getFromAvatar());
                                    dm.put("content", r.getContent());
                                    dm.put("inviteRoomCode", r.getInviteRoomCode());
                                    dm.put("timestamp", r.getTimestamp());
                                    try {
                                        session.sendMessage(new TextMessage(JSON.toJSONString(dm)));
                                        r.setDelivered(true);
                                    } catch (IOException ignored) {}
                                }
                                directMessageRepository.saveAll(unread);
                                log.info("[WS] Dispatched {} unread messages to user {}", unread.size(), meta.userId);
                            }
                        } catch (Exception e) {
                            log.error("[WS] Error reading offline messages from DB: {}", e.getMessage());
                        }

                        // 内存缓冲清理
                        List<Map<String, Object>> pending = OFFLINE_MESSAGES.remove(meta.userId);
                        if (pending != null && !pending.isEmpty()) {
                            for (Map<String, Object> m : pending) {
                                try {
                                    session.sendMessage(new TextMessage(JSON.toJSONString(m)));
                                } catch (IOException ignored) {}
                            }
                        }

                        // 自动同步补发最近 3 分钟内活跃的全服跑马灯大喇叭广播（确保后上线或重连的客户端即刻展示）
                        long threeMinAgo = System.currentTimeMillis() - 3 * 60 * 1000;
                        for (Map<String, Object> rBcast : RoomAndMomentController.RECENT_GLOBAL_BROADCASTS) {
                            Object tsObj = rBcast.get("timestamp");
                            long ts = (tsObj instanceof Number) ? ((Number) tsObj).longValue() : 0L;
                            if (ts >= threeMinAgo) {
                                try {
                                    session.sendMessage(new TextMessage(JSON.toJSONString(rBcast)));
                                } catch (IOException ignored) {}
                            }
                        }
                    }
                    break;

                case "JOIN_ROOM":
                    meta.roomCode = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : null;
                    String joinUid = msg.getString("userId") != null ? msg.getString("userId").trim() : meta.userId;
                    String joinNick = msg.getString("nickname") != null ? msg.getString("nickname").trim() : meta.nickname;
                    String joinAvatar = msg.getString("avatar") != null ? msg.getString("avatar").trim() : "🦊";
                    String joinGameType = msg.getString("gameType");

                    if (meta.roomCode != null) {
                        Map<String, Object> room = RoomAndMomentController.ROOMS.get(meta.roomCode);
                        if (room == null) {
                            room = new HashMap<>();
                            room.put("roomCode", meta.roomCode);
                            room.put("roomName", "开黑房间 " + meta.roomCode);
                            room.put("gameType", (joinGameType != null && !joinGameType.trim().isEmpty()) ? joinGameType.trim() : "liars_dice");
                            room.put("createdAt", System.currentTimeMillis());
                            room.put("status", "WAITING");
                            room.put("players", new ArrayList<Map<String, Object>>());
                            RoomAndMomentController.ROOMS.put(meta.roomCode, room);
                        } else if (joinGameType != null && !joinGameType.trim().isEmpty() && (room.get("gameType") == null || "liars_dice".equals(room.get("gameType")))) {
                            room.put("gameType", joinGameType.trim());
                        }
                        List<Map<String, Object>> players = (List<Map<String, Object>>) room.computeIfAbsent("players", k -> new ArrayList<>());
                        boolean isReconnect = false;
                        if (joinUid != null) {
                            // 单账号单房间互斥：进入当前新房间时，自动清理并退出用户之前所在的旧房间
                            RoomAndMomentController.enforceSingleRoomPerUser(joinUid, meta.roomCode);

                            Map<String, Object> existingPlayer = null;
                            for (Map<String, Object> p : players) {
                                if (Objects.equals(p.get("id"), joinUid)) {
                                    existingPlayer = p;
                                    break;
                                }
                            }
                            if (existingPlayer != null) {
                                isReconnect = true;
                                meta.isSpectator = false;
                                existingPlayer.put("online", true);
                                existingPlayer.put("isAutoPlay", false);
                                existingPlayer.remove("offlineAt");
                                if (joinNick != null) existingPlayer.put("name", joinNick);
                                if (joinAvatar != null) existingPlayer.put("avatar", joinAvatar);
                            } else {
                                // 若房间正在游戏中，且新玩家无席位：触发观战检测
                                if ("PLAYING".equals(room.get("status"))) {
                                    boolean allowSpectator = !Boolean.FALSE.equals(room.get("allowSpectator"));
                                    if (!allowSpectator) {
                                        Map<String, Object> err = new HashMap<>();
                                        err.put("type", "ERROR");
                                        err.put("code", 403);
                                        err.put("message", "当前对局正在进行中，且该房间未开启观战功能");
                                        try {
                                            session.sendMessage(new TextMessage(JSON.toJSONString(err)));
                                        } catch (IOException ignored) {}
                                        meta.roomCode = null;
                                        break;
                                    }

                                    // 加入旁观者列表
                                    meta.isSpectator = true;
                                    List<Map<String, Object>> spectators = (List<Map<String, Object>>) room.computeIfAbsent("spectators", k -> new ArrayList<>());
                                    Map<String, Object> spec = new HashMap<>();
                                    spec.put("id", joinUid);
                                    spec.put("name", joinNick != null ? joinNick : "观众");
                                    spec.put("avatar", joinAvatar != null ? joinAvatar : "👀");
                                    spec.put("isSpectator", true);
                                    if (spectators.stream().noneMatch(s -> Objects.equals(s.get("id"), joinUid))) {
                                        spectators.add(spec);
                                    }

                                    // 单独向观战者下发权威观战快照：【严禁展示手牌，手牌对象完全置空，仅展示公共排面与积分！】
                                    Map<String, Object> specSync = new HashMap<>();
                                    specSync.put("type", "ROOM_RECONNECT_SYNC");
                                    specSync.put("roomCode", meta.roomCode);
                                    specSync.put("status", "PLAYING");
                                    specSync.put("gameType", room.get("gameType"));
                                    specSync.put("take6Rows", room.get("take6Rows") != null ? room.get("take6Rows") : room.get("take6InitialRows"));
                                    specSync.put("take6Scores", room.get("take6Scores"));
                                    specSync.put("take6PlayerHands", new HashMap<>()); // 观战手牌严格保密隐藏
                                    specSync.put("playerHands", new HashMap<>());     // 观战手牌严格保密隐藏
                                    specSync.put("take6ReadyPlayers", room.get("take6ReadyPlayers"));
                                    specSync.put("take6CurrentTurn", room.get("take6CurrentTurn"));
                                    specSync.put("take6RevealedCards", room.get("take6RevealedCards"));
                                    specSync.put("revealedCards", room.get("take6RevealedCards"));
                                    specSync.put("phase", room.get("take6Phase"));
                                    specSync.put("players", players);
                                    specSync.put("spectators", spectators);
                                    specSync.put("isSpectator", true);
                                    specSync.put("allowSpectator", true);
                                    try {
                                        session.sendMessage(new TextMessage(JSON.toJSONString(specSync)));
                                    } catch (IOException ignored) {}

                                    Map<String, Object> specEvent = new HashMap<>();
                                    specEvent.put("type", "ROOM_SPECTATORS_UPDATED");
                                    specEvent.put("roomCode", meta.roomCode);
                                    specEvent.put("event", "👀 观众【" + (joinNick != null ? joinNick : "观众") + "】进入房间旁观对局");
                                    specEvent.put("spectators", spectators);
                                    specEvent.put("spectatorCount", spectators.size());
                                    broadcastToRoom(meta.roomCode, specEvent, null);
                                    break;
                                }

                                meta.isSpectator = false;
                                Map<String, Object> p = new HashMap<>();
                                p.put("id", joinUid);
                                p.put("name", joinNick);
                                p.put("avatar", joinAvatar);
                                p.put("isAi", false);
                                p.put("online", true);
                                boolean isHost = players.isEmpty();
                                p.put("isHost", isHost);
                                p.put("isReady", isHost);
                                p.put("seatIndex", players.size());
                                players.add(p);
                            }
                        }

                        // 如果房间处于游戏中，单独向重连回来的在席玩家下发当前游戏权威快照 (包含其实时真实剩余手牌与角色)
                        if ("PLAYING".equals(room.get("status"))) {
                            Map<String, Object> syncMsg = new HashMap<>();
                            syncMsg.put("type", "ROOM_RECONNECT_SYNC");
                            syncMsg.put("roomCode", meta.roomCode);
                            syncMsg.put("status", "PLAYING");
                            String gType = (String) room.get("gameType");
                            syncMsg.put("gameType", gType);
                            syncMsg.put("players", players);
                            syncMsg.put("isSpectator", false);

                            // 1. Take 6 (谁是牛头王) 牌局权威快照
                            Object rowsObj = room.get("take6Rows") != null ? room.get("take6Rows") : room.get("take6InitialRows");
                            syncMsg.put("take6Rows", rowsObj);
                            syncMsg.put("rows", rowsObj);
                            syncMsg.put("take6Scores", room.get("take6Scores"));
                            syncMsg.put("scores", room.get("take6Scores"));
                            syncMsg.put("take6PlayerHands", room.get("take6PlayerHands"));
                            syncMsg.put("playerHands", room.get("take6PlayerHands"));
                            if (room.get("take6PlayerHands") instanceof Map && joinUid != null) {
                                Map<String, Object> handsMap = (Map<String, Object>) room.get("take6PlayerHands");
                                syncMsg.put("myHand", handsMap.get(joinUid));
                            }
                            syncMsg.put("take6ReadyPlayers", room.get("take6ReadyPlayers"));
                            syncMsg.put("take6CurrentTurn", room.get("take6CurrentTurn"));
                            syncMsg.put("currentTurn", room.get("take6CurrentTurn"));

                            // 2. 大话骰 (liars_dice) 真实点数与桌面叫点快照
                            if ("liars_dice".equals(gType)) {
                                if (room.get("diceHands") instanceof Map && joinUid != null) {
                                    Map<String, List<Integer>> diceHands = (Map<String, List<Integer>>) room.get("diceHands");
                                    List<Integer> myDice = diceHands.get(joinUid);
                                    if (myDice != null) {
                                        syncMsg.put("myDice", myDice);
                                        syncMsg.put("dice", myDice);
                                        // 定向推送玩家专属手骰
                                        sendToUser(joinUid, Map.of(
                                                "type", "GAME_ACTION",
                                                "action", "DICE_MY_HAND",
                                                "roomCode", meta.roomCode,
                                                "payload", Map.of("dice", myDice)
                                        ));
                                    }
                                }
                                syncMsg.put("currentBid", room.get("currentDiceBid"));
                                syncMsg.put("lastBid", room.get("currentDiceBid"));
                            }

                            // 3. 谁是卧底 (undercover) 麦序、词汇与存活状态快照
                            if ("undercover".equals(gType)) {
                                syncMsg.put("undercoverPhase", room.get("undercoverPhase"));
                                syncMsg.put("undercoverRound", room.get("undercoverRound"));
                                syncMsg.put("undercoverSpeakerIndex", room.get("undercoverSpeakerIndex"));
                                syncMsg.put("alivePlayerIds", room.get("undercoverAlivePlayerIds"));
                                if (room.get("undercoverRoles") instanceof Map && joinUid != null) {
                                    Map<String, Map<String, Object>> roles = (Map<String, Map<String, Object>>) room.get("undercoverRoles");
                                    Map<String, Object> myRole = roles.get(joinUid);
                                    if (myRole != null) {
                                        syncMsg.put("myWord", myRole.get("word"));
                                        syncMsg.put("isUndercover", myRole.get("isUndercover"));
                                        syncMsg.put("roleName", Boolean.TRUE.equals(myRole.get("isUndercover")) ? "卧底" : "平民");
                                        // 定向私发玩家专属身份与底词
                                        sendToUser(joinUid, Map.of(
                                                "type", "GAME_ACTION",
                                                "action", "UNDERCOVER_ROLE_DEAL",
                                                "roomCode", meta.roomCode,
                                                "payload", Map.of("myWord", myRole.get("word"), "isUndercover", myRole.get("isUndercover"), "roleName", Boolean.TRUE.equals(myRole.get("isUndercover")) ? "卧底" : "平民")
                                        ));
                                    }
                                }
                            }

                            try {
                                session.sendMessage(new TextMessage(JSON.toJSONString(syncMsg)));
                            } catch (IOException ignored) {}
                        }

                        Map<String, Object> joinEvent = new HashMap<>();
                        joinEvent.put("type", "ROOM_PLAYERS_UPDATED");
                        joinEvent.put("roomCode", meta.roomCode);
                        joinEvent.put("event", isReconnect ? ("玩家【" + joinNick + "】重返房间，已解除托管接管对局！") : ("玩家【" + joinNick + "】加入房间"));
                        joinEvent.put("players", players);
                        joinEvent.put("playerCount", players.size());
                        broadcastToRoom(meta.roomCode, joinEvent, null);
                    }
                    break;

                case "ADD_AI_PLAYER":
                    String aiRoom = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : meta.roomCode;
                    if (aiRoom != null) {
                        autoFillRealisticPlayer(aiRoom);
                    }
                    break;

                case "SUMMON_PLAYERS":
                    String sRoom = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : meta.roomCode;
                    String sGameType = msg.getString("gameType") != null ? msg.getString("gameType").trim() : "take6";
                    String sChannel = msg.getString("channel") != null ? msg.getString("channel").trim() : "ALL";
                    String sNick = msg.getString("senderName") != null ? msg.getString("senderName") : (meta.nickname != null ? meta.nickname : "房主");
                    String sAvatar = msg.getString("senderAvatar") != null ? msg.getString("senderAvatar") : "🦊";

                    String gName = "谁是牛头王";
                    if ("liars_dice".equals(sGameType)) gName = "大话骰吹牛";
                    else if ("party_wheel".equals(sGameType)) gName = "聚会转盘大冒险";
                    else if ("undercover".equals(sGameType)) gName = "谁是卧底";

                    String recruitMsg = "🔥 房主【" + sNick + "】正在房间 [#" + sRoom + "] 召集桌友一起开黑《" + gName + "》，缺人速来！点击加入";

                    // 广播到世界频道
                    if ("ALL".equals(sChannel) || "WORLD".equals(sChannel)) {
                        Map<String, Object> wChat = new HashMap<>();
                        wChat.put("type", "CHAT_MESSAGE");
                        wChat.put("id", "RECRUIT-W-" + System.currentTimeMillis());
                        wChat.put("channel", "WORLD");
                        wChat.put("senderId", meta.userId);
                        wChat.put("senderName", sNick);
                        wChat.put("senderAvatar", sAvatar);
                        wChat.put("content", recruitMsg);
                        wChat.put("inviteRoomCode", sRoom);
                        wChat.put("gameType", sGameType);
                        wChat.put("isRecruit", true);
                        wChat.put("timestamp", new Date().toString());
                        broadcastToAll(wChat, null);
                    }
                    // 广播到同城频道
                    if ("ALL".equals(sChannel) || "CITY".equals(sChannel)) {
                        Map<String, Object> cChat = new HashMap<>();
                        cChat.put("type", "CHAT_MESSAGE");
                        cChat.put("id", "RECRUIT-C-" + System.currentTimeMillis());
                        cChat.put("channel", "CITY");
                        cChat.put("senderId", meta.userId);
                        cChat.put("senderName", sNick);
                        cChat.put("senderAvatar", sAvatar);
                        cChat.put("content", recruitMsg);
                        cChat.put("inviteRoomCode", sRoom);
                        cChat.put("gameType", sGameType);
                        cChat.put("isRecruit", true);
                        cChat.put("timestamp", new Date().toString());
                        broadcastToAll(cChat, null);
                    }

                    // 房间内广播 10 秒倒计时事件
                    if (sRoom != null) {
                        Map<String, Object> sEvt = new HashMap<>();
                        sEvt.put("type", "SUMMON_STARTED");
                        sEvt.put("roomCode", sRoom);
                        sEvt.put("countdown", 10);
                        sEvt.put("content", "📢 已向全服与同城频道发布召集广播！正在呼叫桌友 (10s)...");
                        broadcastToRoom(sRoom, sEvt, null);

                        Map<String, Object> currentR = RoomAndMomentController.ROOMS.get(sRoom);
                        int initialCount = (currentR != null && currentR.get("players") != null) ? ((List<?>) currentR.get("players")).size() : 1;

                        // 10 秒后如无新玩家加入且未满员，自动补入拟真玩家
                        SCHEDULER.schedule(() -> {
                            try {
                                Map<String, Object> liveR = RoomAndMomentController.ROOMS.get(sRoom);
                                if (liveR != null && "WAITING".equals(liveR.get("status"))) {
                                    List<?> curP = (List<?>) liveR.get("players");
                                    if (curP != null && curP.size() <= initialCount && curP.size() < 6) {
                                        autoFillRealisticPlayer(sRoom);
                                    }
                                }
                            } catch (Exception e) {
                                log.error("[SUMMON] Error during auto-fill: {}", e.getMessage());
                            }
                        }, 10, TimeUnit.SECONDS);
                    }
                    break;

                case "PLAYER_READY":
                    String rCode = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : meta.roomCode;
                    String rUid = msg.getString("userId") != null ? msg.getString("userId").trim() : meta.userId;
                    Boolean readyVal = msg.getBoolean("isReady");
                    if (rCode != null && rUid != null && readyVal != null) {
                        Map<String, Object> r = RoomAndMomentController.ROOMS.get(rCode);
                        if (r != null) {
                            List<Map<String, Object>> players = (List<Map<String, Object>>) r.get("players");
                            if (players != null) {
                                String rName = "玩家";
                                for (Map<String, Object> p : players) {
                                    if (Objects.equals(String.valueOf(p.get("id")), rUid)) {
                                        p.put("isReady", readyVal);
                                        if (p.get("name") != null) rName = String.valueOf(p.get("name"));
                                        break;
                                    }
                                }
                                Map<String, Object> readyEvt = new HashMap<>();
                                readyEvt.put("type", "ROOM_PLAYERS_UPDATED");
                                readyEvt.put("roomCode", rCode);
                                readyEvt.put("event", "玩家【" + rName + "】" + (readyVal ? "已准备" : "取消了准备"));
                                readyEvt.put("players", players);
                                readyEvt.put("playerCount", players.size());
                                broadcastToRoom(rCode, readyEvt, null);
                            }
                        }
                    }
                    break;

                case "LEAVE_ROOM":
                    String leaveCode = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : meta.roomCode;
                    String leaveUid = msg.getString("userId") != null ? msg.getString("userId").trim() : meta.userId;
                    if (leaveCode != null) {
                        Map<String, Object> r = RoomAndMomentController.ROOMS.get(leaveCode);
                        boolean isPlaying = r != null && "PLAYING".equalsIgnoreCase(String.valueOf(r.get("status")));
                        RoomAndMomentController.removePlayerFromRoom(leaveCode, leaveUid);
                        List<Map<String, Object>> players = r != null ? (List<Map<String, Object>>) r.get("players") : Collections.emptyList();

                        Map<String, Object> leaveEvent = new HashMap<>();
                        leaveEvent.put("type", "ROOM_PLAYERS_UPDATED");
                        leaveEvent.put("roomCode", leaveCode);
                        leaveEvent.put("event", isPlaying ? ("玩家【" + (meta.nickname != null ? meta.nickname : "玩家") + "】暂时退出，已开启AI托管继续对局！") : ("玩家【" + (meta.nickname != null ? meta.nickname : "玩家") + "】离开了房间"));
                        leaveEvent.put("players", players);
                        leaveEvent.put("playerCount", players.size());
                        broadcastToRoom(leaveCode, leaveEvent, null);
                        meta.roomCode = null;
                    }
                    break;

                case "CHAT_MESSAGE":
                    String channel = msg.getString("channel");
                    String roomCode = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : null;
                    if ("ROOM".equalsIgnoreCase(channel) || (roomCode != null && !roomCode.isEmpty())) {
                        channel = "ROOM";
                        if (roomCode == null || roomCode.isEmpty()) {
                            roomCode = meta.roomCode;
                        }
                    } else {
                        channel = ("CITY".equalsIgnoreCase(channel)) ? "CITY" : "WORLD";
                        roomCode = null;
                    }
                    Map<String, Object> chat = new HashMap<>();
                    chat.put("type", "CHAT_MESSAGE");
                    chat.put("id", msg.getString("id") != null ? msg.getString("id") : ("MSG-" + System.currentTimeMillis()));
                    chat.put("channel", channel);
                    chat.put("roomCode", roomCode);
                    chat.put("senderId", msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId);
                    chat.put("senderName", msg.getString("senderName") != null ? msg.getString("senderName") : meta.nickname);
                    chat.put("senderAvatar", msg.getString("senderAvatar") != null ? msg.getString("senderAvatar") : "🦊");
                    chat.put("content", msg.getString("content"));
                    chat.put("textColor", msg.getString("textColor") != null ? msg.getString("textColor") : "COLOR_DEFAULT");
                    chat.put("vipLevel", msg.getInteger("vipLevel") != null ? msg.getInteger("vipLevel") : 0);
                    chat.put("timestamp", new Date().toString());

                    // 发送者本地已乐观追加，广播时排除发送者，杜绝发1条显示2条
                    if ("ROOM".equals(channel) && roomCode != null) {
                        broadcastToRoom(roomCode, chat, session);
                    } else {
                        broadcastToAll(chat, session);
                    }
                    break;

                case "DIRECT_MESSAGE":
                    String toUserId = msg.getString("toUserId") != null ? msg.getString("toUserId").trim() : null;
                    String fromUserId = msg.getString("fromUserId") != null ? msg.getString("fromUserId").trim() : (meta.userId != null ? meta.userId.trim() : null);
                    String msgId = msg.getString("id") != null ? msg.getString("id").trim() : ("DM-" + System.currentTimeMillis());
                    String content = msg.getString("content");
                    String inviteRoomCode = msg.getString("inviteRoomCode");
                    String fromNickname = msg.getString("fromNickname") != null ? msg.getString("fromNickname").trim() : (meta.nickname != null ? meta.nickname.trim() : "玩家");
                    String fromAvatar = msg.getString("fromAvatar") != null ? msg.getString("fromAvatar") : "🦊";
                    long dmTimestamp = System.currentTimeMillis();

                    Map<String, Object> dm = new HashMap<>();
                    dm.put("type", "DIRECT_MESSAGE");
                    dm.put("id", msgId);
                    dm.put("toUserId", toUserId);
                    dm.put("fromUserId", fromUserId);
                    dm.put("fromNickname", fromNickname);
                    dm.put("fromAvatar", fromAvatar);
                    dm.put("content", content);
                    dm.put("inviteRoomCode", inviteRoomCode);
                    dm.put("timestamp", dmTimestamp);

                    // 点对点精准投递
                    boolean delivered = sendToUser(toUserId, dm);
                    if (!delivered && toUserId != null) {
                        OFFLINE_MESSAGES.computeIfAbsent(toUserId, k -> new java.util.concurrent.CopyOnWriteArrayList<>()).add(dm);
                    }

                    // 如果接收方与发送方还不是好友，自动同步创建好友申请与附带留言，确保对方在“好友申请”栏目可清晰查看
                    if (fromUserId != null && toUserId != null && !fromUserId.equalsIgnoreCase(toUserId)) {
                        try {
                            if (!friendService.isFriend(fromUserId, toUserId)) {
                                friendService.applyFriend(fromUserId, toUserId, content != null ? content : "向您发送了私信留言");
                                dm.put("isStranger", true);
                            }
                        } catch (Exception ignored) {}
                    }

                    // 数据库永久保存，离线亦不丢失
                    try {
                        DirectMessageRecord rec = DirectMessageRecord.builder()
                                .id(msgId)
                                .fromUserId(fromUserId)
                                .fromNickname(fromNickname)
                                .fromAvatar(fromAvatar)
                                .toUserId(toUserId)
                                .content(content)
                                .inviteRoomCode(inviteRoomCode)
                                .timestamp(dmTimestamp)
                                .delivered(delivered)
                                .isRead(false)
                                .build();
                        directMessageRepository.save(rec);
                    } catch (Exception e) {
                        log.error("[WS] Failed to persist direct message: {}", e.getMessage());
                    }
                    break;

                case "KICK_PLAYER":
                    String kickRoomCode = msg.getString("roomCode");
                    String kickTargetId = msg.getString("targetPlayerId");
                    String kickTargetName = msg.getString("targetPlayerName");
                    String operatorId = meta.userId;
                    if (kickRoomCode != null && kickTargetId != null) {
                        Map<String, Object> r = RoomAndMomentController.ROOMS.get(kickRoomCode);
                        if (r != null) {
                            String rStatus = (String) r.get("status");
                            if ("PLAYING".equals(rStatus)) {
                                Map<String, Object> errNotice = new HashMap<>();
                                errNotice.put("type", "ERROR_NOTICE");
                                errNotice.put("message", "正在进行激烈游戏对战中，暂不可踢出参赛玩家！");
                                sendToUser(operatorId, errNotice);
                                break;
                            }
                            Map<String, Object> host = (Map<String, Object>) r.get("hostPlayer");
                            String hostId = host != null ? String.valueOf(host.get("id")) : null;
                            String opClean = operatorId != null ? operatorId.replace("-", "").toLowerCase() : "";
                            String hostClean = hostId != null ? hostId.replace("-", "").toLowerCase() : "";
                            boolean isHost = hostClean.equals(opClean) || (hostId != null && hostId.equalsIgnoreCase(operatorId));
                            if (isHost) {
                                RoomAndMomentController.forceRemovePlayerFromRoom(kickRoomCode, kickTargetId);

                                // 专属移出通知投递给被踢玩家
                                Map<String, Object> kickNotice = new HashMap<>();
                                kickNotice.put("type", "KICKED_FROM_ROOM");
                                kickNotice.put("roomCode", kickRoomCode);
                                kickNotice.put("targetPlayerId", kickTargetId);
                                kickNotice.put("message", "您已被房主移出该房间！");
                                sendToUser(kickTargetId, kickNotice);

                                // 广播房间刷新
                                Map<String, Object> kickBcast = new HashMap<>();
                                kickBcast.put("type", "PLAYER_KICKED");
                                kickBcast.put("roomCode", kickRoomCode);
                                kickBcast.put("targetPlayerId", kickTargetId);
                                kickBcast.put("targetPlayerName", kickTargetName != null ? kickTargetName : "玩家");
                                kickBcast.put("players", r.get("players"));
                                broadcastToRoom(kickRoomCode, kickBcast, null);
                                log.info("[WS] Host {} kicked {} from room {}", operatorId, kickTargetId, kickRoomCode);
                            }
                        }
                    }
                    break;

                case "THROW_ITEM":
                    String senderId = msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId;
                    String targetPlayerId = msg.getString("targetPlayerId");
                    String itemType = msg.getString("itemType");
                    int combo = msg.getInteger("combo") != null ? msg.getInteger("combo") : 1;
                    int addedIntimacy = 0;
                    Integer totalIntimacy = null;
                    String intimacyRelationship = null;

                    // 赠送道具 / 投掷礼物自动增加双方亲密度 (支持所有玩家包括拟真人)
                    if (senderId != null && targetPlayerId != null && !senderId.equals(targetPlayerId)) {
                        try {
                            addedIntimacy = IntimacyController.calculateItemScore(itemType, combo);
                            String u1 = senderId.compareTo(targetPlayerId) <= 0 ? senderId : targetPlayerId;
                            String u2 = senderId.compareTo(targetPlayerId) <= 0 ? targetPlayerId : senderId;
                            UserIntimacy intimacy = intimacyRepository.findByUser1IdAndUser2Id(u1, u2)
                                    .orElseGet(() -> UserIntimacy.builder()
                                            .user1Id(u1)
                                            .user2Id(u2)
                                            .intimacyScore(0)
                                            .build());
                            intimacy.setIntimacyScore((intimacy.getIntimacyScore() != null ? intimacy.getIntimacyScore() : 0) + addedIntimacy);
                            intimacyRepository.save(intimacy);
                            totalIntimacy = intimacy.getIntimacyScore();
                            intimacyRelationship = intimacy.getRelationship();
                            log.info("[Intimacy] Added {} points between {} and {}. Total={}", addedIntimacy, u1, u2, totalIntimacy);
                        } catch (Exception e) {
                            log.error("[WS] Error updating intimacy: {}", e.getMessage());
                        }
                    }

                    Map<String, Object> throwEvt = new HashMap<>();
                    throwEvt.put("type", "THROW_ITEM_EVENT");
                    throwEvt.put("senderId", senderId);
                    throwEvt.put("senderName", msg.getString("senderName") != null ? msg.getString("senderName") : meta.nickname);
                    throwEvt.put("senderAvatar", msg.getString("senderAvatar") != null ? msg.getString("senderAvatar") : "🦊");
                    throwEvt.put("targetPlayerId", targetPlayerId);
                    throwEvt.put("targetPlayerName", msg.getString("targetPlayerName"));
                    throwEvt.put("itemType", itemType);
                    throwEvt.put("itemEmoji", msg.getString("itemEmoji"));
                    throwEvt.put("combo", combo);
                    throwEvt.put("giftTitle", msg.getString("giftTitle"));
                    throwEvt.put("content", "向【" + msg.getString("targetPlayerName") + "】投掷了 " + msg.getString("itemEmoji"));
                    throwEvt.put("timestamp", System.currentTimeMillis());
                    throwEvt.put("addedIntimacy", addedIntimacy);
                    throwEvt.put("totalIntimacy", totalIntimacy);
                    throwEvt.put("relationship", intimacyRelationship);

                    boolean isGlobal = Boolean.TRUE.equals(msg.getBoolean("isGlobal"));
                    throwEvt.put("isGlobal", isGlobal);
                    throwEvt.put("roomCode", meta.roomCode);
                    throwEvt.put("blessing", msg.getString("blessing"));

                    // 排除发送者自身，由本地直接驱动动画，避免重复渲染
                    if (isGlobal || meta.roomCode == null) {
                        broadcastToAll(throwEvt, session);
                    } else {
                        broadcastToRoom(meta.roomCode, throwEvt, session);
                    }

                    // 若接收方为拟真AI玩家，800ms后AI在房间聊天区以人类口吻礼貌答谢
                    if (meta.roomCode != null && targetPlayerId != null) {
                        Map<String, Object> r = RoomAndMomentController.ROOMS.get(meta.roomCode);
                        if (r != null) {
                            List<Map<String, Object>> rPlayers = (List<Map<String, Object>>) r.get("players");
                            if (rPlayers != null) {
                                for (Map<String, Object> p : rPlayers) {
                                    if (Objects.equals(p.get("id"), targetPlayerId) && Boolean.TRUE.equals(p.get("isAi"))) {
                                        String giftRoomCode = meta.roomCode;
                                        SCHEDULER.schedule(() -> {
                                            String thank = AI_GIFT_THANKS.get(new Random().nextInt(AI_GIFT_THANKS.size()));
                                            Map<String, Object> replyChat = new HashMap<>();
                                            replyChat.put("type", "CHAT_MESSAGE");
                                            replyChat.put("id", "MSG-" + System.currentTimeMillis());
                                            replyChat.put("channel", "ROOM");
                                            replyChat.put("roomCode", giftRoomCode);
                                            replyChat.put("senderId", targetPlayerId);
                                            replyChat.put("senderName", p.get("name"));
                                            replyChat.put("senderAvatar", p.get("avatar"));
                                            replyChat.put("content", thank);
                                            replyChat.put("timestamp", new Date().toString());
                                            broadcastToRoom(giftRoomCode, replyChat, null);
                                        }, 800, TimeUnit.MILLISECONDS);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    break;

                case "GLOBAL_BROADCAST":
                case "GLOBAL_BROADCAST_EVENT":
                    Map<String, Object> broadcastEvt = new HashMap<>();
                    broadcastEvt.put("type", "GLOBAL_BROADCAST_EVENT");
                    broadcastEvt.put("id", msg.getString("id") != null ? msg.getString("id") : ("BLS-" + System.currentTimeMillis()));
                    broadcastEvt.put("broadcastType", msg.getString("broadcastType") != null ? msg.getString("broadcastType") : "MARQUEE");
                    broadcastEvt.put("senderId", msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId);
                    broadcastEvt.put("senderName", msg.getString("senderName") != null ? msg.getString("senderName") : meta.nickname);
                    broadcastEvt.put("senderAvatar", msg.getString("senderAvatar") != null ? msg.getString("senderAvatar") : "🦊");
                    broadcastEvt.put("senderVip", msg.getInteger("senderVip") != null ? msg.getInteger("senderVip") : 0);
                    String blessing = msg.getString("blessing");
                    if (blessing == null) blessing = msg.getString("content");
                    if (blessing == null) blessing = msg.getString("message");
                    if (blessing == null || blessing.trim().isEmpty()) blessing = "祝大家游戏愉快，天天赢大奖！";
                    broadcastEvt.put("blessing", blessing);
                    broadcastEvt.put("content", blessing);
                    broadcastEvt.put("message", blessing);
                    broadcastEvt.put("itemType", msg.getString("itemType") != null ? msg.getString("itemType") : "MARQUEE");
                    broadcastEvt.put("itemEmoji", msg.getString("itemEmoji") != null ? msg.getString("itemEmoji") : "📢");
                    broadcastEvt.put("giftTitle", msg.getString("giftTitle") != null ? msg.getString("giftTitle") : "全服喇叭");
                    broadcastEvt.put("timestamp", System.currentTimeMillis());

                    RoomAndMomentController.recordRecentGlobalBroadcast(broadcastEvt);

                    log.info("[WS] 全服广播消息: {} - {}", broadcastEvt.get("senderName"), broadcastEvt.get("blessing"));
                    broadcastToAll(broadcastEvt, session);
                    break;

                case "GAME_ACTION":
                    String gameRoom = msg.getString("roomCode") != null ? msg.getString("roomCode").trim() : meta.roomCode;
                    if (gameRoom != null) {
                        String actName = msg.getString("action");
                        Map<String, Object> room = RoomAndMomentController.ROOMS.get(gameRoom);
                        Object payloadObj = msg.get("payload");
                        Map<String, Object> payloadMap;
                        if (payloadObj instanceof Map) {
                            payloadMap = new HashMap<>((Map<String, Object>) payloadObj);
                        } else {
                            payloadMap = new HashMap<>();
                        }

                        if (room != null) {
                            if ("GAME_STARTED".equals(actName)) {
                                room.put("status", "PLAYING");
                                String gType = (String) payloadMap.get("gameType");
                                if (gType == null) {
                                    gType = (String) room.get("gameType");
                                    payloadMap.put("gameType", gType);
                                }
                                if ("take6".equals(gType)) {
                                    if (!payloadMap.containsKey("initialRows") || !payloadMap.containsKey("rows")) {
                                        List<Integer> deck = new ArrayList<>();
                                        for (int i = 1; i <= 104; i++) deck.add(i);
                                        Collections.shuffle(deck);
                                        List<List<Integer>> rows = new ArrayList<>();
                                        for (int i = 0; i < 4; i++) {
                                            rows.add(new ArrayList<>(Collections.singletonList(deck.remove(deck.size() - 1))));
                                        }
                                        Map<String, List<Integer>> hands = new HashMap<>();
                                        List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
                                        if (players != null) {
                                            for (Map<String, Object> p : players) {
                                                String pid = (String) p.get("id");
                                                if (pid != null) {
                                                    List<Integer> hand = new ArrayList<>();
                                                    for (int k = 0; k < 10 && !deck.isEmpty(); k++) {
                                                        hand.add(deck.remove(deck.size() - 1));
                                                    }
                                                    Collections.sort(hand);
                                                    hands.put(pid, hand);
                                                }
                                            }
                                        }
                                        payloadMap.put("initialRows", rows);
                                        payloadMap.put("rows", rows);
                                        payloadMap.put("playerHands", hands);
                                    }
                                    room.put("take6InitialRows", payloadMap.get("initialRows"));
                                    room.put("take6PlayerHands", payloadMap.get("playerHands"));
                                    room.remove("take6Rows");
                                    room.remove("take6Scores");
                                } else if ("liars_dice".equals(gType)) {
                                    // 大话骰：服务端为全桌玩家（真人与AI）生成真实 5 颗骰子
                                    Map<String, List<Integer>> diceHands = new HashMap<>();
                                    List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
                                    Random rand = new Random();
                                    if (players != null) {
                                        for (Map<String, Object> p : players) {
                                            String pid = (String) p.get("id");
                                            if (pid != null) {
                                                List<Integer> hand = new ArrayList<>();
                                                for (int d = 0; d < 5; d++) hand.add(rand.nextInt(6) + 1);
                                                Collections.sort(hand);
                                                diceHands.put(pid, hand);
                                                sendToUser(pid, Map.of(
                                                        "type", "GAME_ACTION",
                                                        "action", "DICE_MY_HAND",
                                                        "roomCode", gameRoom,
                                                        "payload", Map.of("dice", hand)
                                                ));
                                            }
                                        }
                                    }
                                    room.put("diceHands", diceHands);
                                    room.put("currentDiceBid", null);
                                    payloadMap.put("diceHandsInitialized", true);
                                } else if ("undercover".equals(gType)) {
                                    // 谁是卧底：服务端权威抽取词对并安全定向私发身份底词
                                    Random rand = new Random();
                                    List<String> pair = UNDERCOVER_WORDS.get(rand.nextInt(UNDERCOVER_WORDS.size()));
                                    boolean swap = rand.nextBoolean();
                                    String civilianWord = swap ? pair.get(0) : pair.get(1);
                                    String undercoverWord = swap ? pair.get(1) : pair.get(0);

                                    List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
                                    int total = players != null ? players.size() : 0;
                                    int ucCount = total >= 7 ? 2 : 1;
                                    Set<Integer> ucIndices = new HashSet<>();
                                    while (ucIndices.size() < ucCount && total > 0) {
                                        ucIndices.add(rand.nextInt(total));
                                    }

                                    Map<String, Map<String, Object>> roles = new HashMap<>();
                                    List<String> aliveList = new ArrayList<>();
                                    if (players != null) {
                                        for (int i = 0; i < total; i++) {
                                            Map<String, Object> p = players.get(i);
                                            String pid = (String) p.get("id");
                                            if (pid == null) continue;
                                            boolean isUc = ucIndices.contains(i);
                                            String word = isUc ? undercoverWord : civilianWord;
                                            Map<String, Object> rMap = new HashMap<>();
                                            rMap.put("id", pid);
                                            rMap.put("name", p.get("name"));
                                            rMap.put("isUndercover", isUc);
                                            rMap.put("word", word);
                                            rMap.put("isOut", false);
                                            roles.put(pid, rMap);
                                            aliveList.add(pid);

                                            sendToUser(pid, Map.of(
                                                    "type", "GAME_ACTION",
                                                    "action", "UNDERCOVER_ROLE_DEAL",
                                                    "roomCode", gameRoom,
                                                    "payload", Map.of("myWord", word, "isUndercover", isUc, "roleName", isUc ? "卧底" : "平民")
                                            ));
                                        }
                                    }
                                    room.put("undercoverRoles", roles);
                                    room.put("undercoverWords", Map.of("civilian", civilianWord, "undercover", undercoverWord));
                                    room.put("undercoverPhase", "SPEAKING");
                                    room.put("undercoverRound", 1);
                                    room.put("undercoverSpeakerIndex", 0);
                                    room.put("undercoverAlivePlayerIds", aliveList);
                                    payloadMap.put("undercoverPhase", "SPEAKING");
                                    payloadMap.put("alivePlayerIds", aliveList);
                                    if (!aliveList.isEmpty()) {
                                        String firstSpeakerId = aliveList.get(0);
                                        SCHEDULER.schedule(() -> {
                                            Map<String, Object> nextTurn = new HashMap<>();
                                            nextTurn.put("type", "GAME_ACTION");
                                            nextTurn.put("action", "UNDERCOVER_NEXT_SPEAKER");
                                            nextTurn.put("roomCode", gameRoom);
                                            nextTurn.put("payload", Map.of("speakerId", firstSpeakerId, "speakerIndex", 0, "round", 1));
                                            broadcastToRoom(gameRoom, nextTurn, null);
                                            checkAndScheduleUndercoverAiTurn(gameRoom, room);
                                        }, 450, TimeUnit.MILLISECONDS);
                                    }
                                }
                            } else if ("GAME_OVER".equals(actName)) {
                                // 仅广播 GAME_OVER 动作与积分战绩，通知各端展示结算榜，绝不提前触发 GAME_RESTART
                                Map<String, Object> gameOverAction = new HashMap<>();
                                gameOverAction.put("type", "GAME_ACTION");
                                gameOverAction.put("action", "GAME_OVER");
                                gameOverAction.put("roomCode", gameRoom);
                                gameOverAction.put("senderId", meta.userId);
                                gameOverAction.put("payload", payload);
                                broadcastToRoom(gameRoom, gameOverAction, null);
                            } else if ("ROUND_RESTART".equals(actName)) {
                                // 局内小轮重开（吹牛下一回合摇骰），房间保持 PLAYING 状态，广播 ROUND_RESTART 动作让各端洗骰重开，绝不退出大厅！
                                Map<String, Object> roundRestartAction = new HashMap<>();
                                roundRestartAction.put("type", "GAME_ACTION");
                                roundRestartAction.put("action", "ROUND_RESTART");
                                roundRestartAction.put("roomCode", gameRoom);
                                roundRestartAction.put("senderId", meta.userId);
                                broadcastToRoom(gameRoom, roundRestartAction, null);
                            } else if ("GAME_RESTART".equals(actName) || "RESET_ROOM".equals(actName)) {
                                room.put("status", "WAITING");
                                room.remove("take6Rows");
                                room.remove("take6Scores");
                                room.remove("take6InitialRows");
                                room.remove("take6PlayerHands");
                                List<Map<String, Object>> pList = (List<Map<String, Object>>) room.get("players");
                                if (pList != null) {
                                    for (int i = 0; i < pList.size(); i++) {
                                        Map<String, Object> p = pList.get(i);
                                        p.put("isReady", true);
                                    }
                                }
                                Map<String, Object> syncEvent = new HashMap<>();
                                syncEvent.put("type", "ROOM_PLAYERS_UPDATED");
                                syncEvent.put("roomCode", gameRoom);
                                syncEvent.put("event", "对局结束，准备状态已重置");
                                syncEvent.put("players", pList);
                                syncEvent.put("playerCount", pList != null ? pList.size() : 0);
                                broadcastToRoom(gameRoom, syncEvent, null);

                                Map<String, Object> restartAction = new HashMap<>();
                                restartAction.put("type", "GAME_ACTION");
                                restartAction.put("action", "GAME_RESTART");
                                restartAction.put("roomCode", gameRoom);
                                restartAction.put("senderId", meta.userId);
                                broadcastToRoom(gameRoom, restartAction, null);

                                Map<String, Object> statusEvent = new HashMap<>();
                                statusEvent.put("type", "ROOM_STATUS_CHANGED");
                                statusEvent.put("roomCode", gameRoom);
                                statusEvent.put("status", "WAITING");
                                broadcastToRoom(gameRoom, statusEvent, null);
                            } else if ("PLAYER_AUTO_HOST".equals(actName)) {
                                List<Map<String, Object>> pList = (List<Map<String, Object>>) room.get("players");
                                if (pList != null) {
                                    for (Map<String, Object> p : pList) {
                                        if (Objects.equals(p.get("id"), meta.userId)) {
                                            p.put("online", false);
                                            p.put("isAutoPlay", true);
                                            p.put("offlineAt", System.currentTimeMillis());
                                            break;
                                        }
                                    }
                                }
                            } else if ("TAKE6_STATE_SYNC".equals(actName)) {
                                if (payloadMap.containsKey("rows")) room.put("take6Rows", payloadMap.get("rows"));
                                if (payloadMap.containsKey("scores")) room.put("take6Scores", payloadMap.get("scores"));
                                if (payloadMap.containsKey("penaltyScores")) room.put("take6Scores", payloadMap.get("penaltyScores"));
                                if (payloadMap.containsKey("readyPlayers")) room.put("take6ReadyPlayers", payloadMap.get("readyPlayers"));
                                if (payloadMap.containsKey("readyPlayerIds")) room.put("take6ReadyPlayers", payloadMap.get("readyPlayerIds"));
                                if (payloadMap.containsKey("revealedCards")) room.put("take6RevealedCards", payloadMap.get("revealedCards"));
                                if (payloadMap.containsKey("phase")) room.put("take6Phase", payloadMap.get("phase"));
                                if (payloadMap.containsKey("currentTurn")) room.put("take6CurrentTurn", payloadMap.get("currentTurn"));
                                if (payloadMap.containsKey("playerHands")) room.put("take6PlayerHands", payloadMap.get("playerHands"));
                            } else if ("SPECTATOR_JOIN_SEAT".equals(actName)) {
                                if (!"WAITING".equals(room.get("status"))) {
                                    Map<String, Object> failMsg = new HashMap<>();
                                    failMsg.put("type", "ERROR");
                                    failMsg.put("message", "当前对局仍在进行中，请等待本局结束再入席准备！");
                                    session.sendMessage(new TextMessage(JSON.toJSONString(failMsg)));
                                    return;
                                }
                                int maxCapacity = 6;
                                if ("take6".equals(room.get("gameType"))) maxCapacity = 10;
                                else if ("undercover".equals(room.get("gameType"))) maxCapacity = 8;

                                List<Map<String, Object>> pList = (List<Map<String, Object>>) room.computeIfAbsent("players", k -> new ArrayList<>());
                                if (pList.size() >= maxCapacity) {
                                    Map<String, Object> failMsg = new HashMap<>();
                                    failMsg.put("type", "ERROR");
                                    failMsg.put("message", "房间席位已满（" + pList.size() + "/" + maxCapacity + "），请继续观战！");
                                    session.sendMessage(new TextMessage(JSON.toJSONString(failMsg)));
                                    return;
                                }

                                List<Map<String, Object>> specList = (List<Map<String, Object>>) room.computeIfAbsent("spectators", k -> new ArrayList<>());
                                Map<String, Object> foundSpec = null;
                                for (int i = 0; i < specList.size(); i++) {
                                    if (Objects.equals(specList.get(i).get("id"), meta.userId)) {
                                        foundSpec = specList.remove(i);
                                        break;
                                    }
                                }
                                meta.isSpectator = false;
                                Map<String, Object> newPlayer = new HashMap<>();
                                newPlayer.put("id", meta.userId);
                                newPlayer.put("name", foundSpec != null && foundSpec.get("name") != null ? foundSpec.get("name") : meta.nickname);
                                newPlayer.put("avatar", foundSpec != null && foundSpec.get("avatar") != null ? foundSpec.get("avatar") : "🦊");
                                newPlayer.put("isAi", false);
                                newPlayer.put("online", true);
                                newPlayer.put("isHost", pList.isEmpty());
                                newPlayer.put("isReady", pList.isEmpty());
                                newPlayer.put("seatIndex", pList.size());
                                pList.add(newPlayer);

                                Map<String, Object> syncEvent = new HashMap<>();
                                syncEvent.put("type", "ROOM_PLAYERS_UPDATED");
                                syncEvent.put("roomCode", gameRoom);
                                syncEvent.put("event", "🎉 观众【" + newPlayer.get("name") + "】已入席就座准备！");
                                syncEvent.put("players", pList);
                                syncEvent.put("spectators", specList);
                                syncEvent.put("playerCount", pList.size());
                                syncEvent.put("spectatorCount", specList.size());
                                broadcastToRoom(gameRoom, syncEvent, null);
                                return;
                            } else if ("TOGGLE_SPECTATOR_ALLOW".equals(actName)) {
                                boolean allow = !Boolean.FALSE.equals(payloadMap != null ? payloadMap.get("allowSpectator") : null);
                                room.put("allowSpectator", allow);
                                Map<String, Object> cfgEvent = new HashMap<>();
                                cfgEvent.put("type", "ROOM_SETTINGS_UPDATED");
                                cfgEvent.put("roomCode", gameRoom);
                                cfgEvent.put("allowSpectator", allow);
                                cfgEvent.put("event", allow ? "📢 房主已开启房间观战权限" : "🔒 房主已关闭房间观战权限");
                                broadcastToRoom(gameRoom, cfgEvent, null);
                                return;
                            }
                        }

                        // 观战防作弊：观战者不可发送对局出牌或决策动作
                        if (meta.isSpectator && ("PLAY_CARD".equals(actName) || "TAKE_ROW".equals(actName) || "BID".equals(actName) || "CHALLENGE".equals(actName))) {
                            log.warn("[AntiCheat] Spectator {} blocked from game action {}", meta.userId, actName);
                            return;
                        }

                        // 1. 大话骰叫点处理
                        if ("BID".equals(actName) && room != null) {
                            room.put("currentDiceBid", payloadMap);
                            String bidSenderId = msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId;
                            scheduleLiarsDiceAiTurnIfNeeded(gameRoom, room, bidSenderId);
                        }

                        // 2. 大话骰开盅验骰与权威胜负裁决
                        if ("CHALLENGE".equals(actName) && room != null) {
                            resolveLiarsDiceChallenge(gameRoom, room, meta.userId, meta.nickname);
                        }

                        // 3. 谁是卧底麦序推进
                        if ("UNDERCOVER_SPEAKER_FINISH".equals(actName) && room != null) {
                            advanceUndercoverSpeaker(gameRoom, room);
                        }

                        // 4. 谁是卧底公投指认与公决出局
                        if ("UNDERCOVER_VOTE".equals(actName) && room != null) {
                            Map<String, String> votes = (Map<String, String>) room.computeIfAbsent("undercoverVotes", k -> new ConcurrentHashMap<>());
                            String targetId = String.valueOf(payloadMap.get("targetId"));
                            votes.put(meta.userId, targetId);
                            evaluateUndercoverVotesIfComplete(gameRoom, room);
                        }

                        // 牛头王实时真实手牌扣减维护：出牌时同步移除当前出牌，确保断线重连时获取绝对精确的剩余手牌
                        if ("PLAY_CARD".equals(actName)) {
                            String cardSenderId = msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId;
                            Object cardObj = payloadMap != null ? (payloadMap.get("card") != null ? payloadMap.get("card") : payloadMap.get("cardNumber")) : null;
                            if (cardSenderId != null && cardObj != null && room.get("take6PlayerHands") instanceof Map) {
                                Map<String, Object> handsMap = (Map<String, Object>) room.get("take6PlayerHands");
                                Object playerHandObj = handsMap.get(cardSenderId);
                                if (playerHandObj instanceof List) {
                                    List<Object> handList = (List<Object>) playerHandObj;
                                    try {
                                        int cardVal = Integer.parseInt(cardObj.toString());
                                        handList.removeIf(c -> Integer.parseInt(c.toString()) == cardVal);
                                        log.info("[Take6] Hand card played: player={}, card={}, remainingCount={}", cardSenderId, cardVal, handList.size());
                                    } catch (Exception ex) {
                                        log.warn("[Take6] Error updating remaining hand: {}", ex.getMessage());
                                    }
                                }
                            }
                        }

                        Map<String, Object> act = new HashMap<>();
                        act.put("type", "GAME_ACTION");
                        act.put("roomCode", gameRoom);
                        act.put("action", actName);
                        act.put("payload", payloadMap);
                        act.put("senderId", msg.getString("senderId") != null ? msg.getString("senderId") : meta.userId);
                        act.put("senderName", msg.getString("senderName") != null ? msg.getString("senderName") : (meta.nickname != null ? meta.nickname : "玩家"));
                        act.put("timestamp", System.currentTimeMillis());
                        broadcastToRoom(gameRoom, act, null);
                    }
                    break;

                case "PING":
                    session.sendMessage(new TextMessage(JSON.toJSONString(Map.of("type", "PONG", "timestamp", System.currentTimeMillis()))));
                    break;
            }
        } catch (Exception e) {
            log.error("WebSocket 消息解析错误: {}", e.getMessage());
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        ClientMeta meta = clients.remove(session);
        if (meta != null && meta.roomCode != null) {
            Map<String, Object> r = RoomAndMomentController.ROOMS.get(meta.roomCode);
            if (r != null) {
                if (meta.isSpectator) {
                    List<Map<String, Object>> spectators = (List<Map<String, Object>>) r.get("spectators");
                    if (spectators != null) {
                        spectators.removeIf(s -> Objects.equals(s.get("id"), meta.userId));
                    }
                    Map<String, Object> specEvent = new HashMap<>();
                    specEvent.put("type", "ROOM_SPECTATORS_UPDATED");
                    specEvent.put("roomCode", meta.roomCode);
                    specEvent.put("event", "观众【" + (meta.nickname != null ? meta.nickname : "观众") + "】离开了观战");
                    specEvent.put("spectators", spectators != null ? spectators : Collections.emptyList());
                    specEvent.put("spectatorCount", spectators != null ? spectators.size() : 0);
                    broadcastToRoom(meta.roomCode, specEvent, null);
                    return;
                }

                boolean isPlaying = "PLAYING".equalsIgnoreCase(String.valueOf(r.get("status")));
                List<Map<String, Object>> players = (List<Map<String, Object>>) r.get("players");
                if (players != null) {
                    for (Map<String, Object> p : players) {
                        if (Objects.equals(p.get("id"), meta.userId)) {
                            p.put("online", false);
                            if (isPlaying) {
                                p.put("isAutoPlay", true);
                            }
                            p.put("offlineAt", System.currentTimeMillis());
                            break;
                        }
                    }
                }
                Map<String, Object> leaveEvent = new HashMap<>();
                leaveEvent.put("type", "ROOM_PLAYERS_UPDATED");
                leaveEvent.put("roomCode", meta.roomCode);
                leaveEvent.put("event", isPlaying ? ("玩家【" + (meta.nickname != null ? meta.nickname : "玩家") + "】掉线，已自动转为托管代打！") : ("玩家【" + (meta.nickname != null ? meta.nickname : "玩家") + "】暂时断线 (等待重连中)"));
                leaveEvent.put("players", players != null ? players : Collections.emptyList());
                leaveEvent.put("playerCount", players != null ? players.size() : 0);
                broadcastToRoom(meta.roomCode, leaveEvent, null);
            }
        }
    }

    private void resolveLiarsDiceChallenge(String gameRoom, Map<String, Object> room, String challengerId, String challengerName) {
        Map<String, Object> curBid = (Map<String, Object>) room.get("currentDiceBid");
        Map<String, List<Integer>> diceHands = (Map<String, List<Integer>>) room.get("diceHands");
        if (curBid != null && diceHands != null) {
            int targetFace = Integer.parseInt(curBid.get("face").toString());
            int bidCount = Integer.parseInt(curBid.get("count").toString());
            boolean isPure = Boolean.parseBoolean(String.valueOf(curBid.get("isPure")));
            int actualCount = 0;
            for (List<Integer> dList : diceHands.values()) {
                for (Integer val : dList) {
                    if (isPure || targetFace == 1) {
                        if (val == targetFace) actualCount++;
                    } else {
                        if (val == targetFace || val == 1) actualCount++;
                    }
                }
            }
            boolean isBluffCaught = actualCount < bidCount;
            String winnerId = isBluffCaught ? challengerId : String.valueOf(curBid.get("bidderId"));
            String loserId = isBluffCaught ? String.valueOf(curBid.get("bidderId")) : challengerId;
            String winnerName = isBluffCaught ? challengerName : String.valueOf(curBid.get("bidderName"));
            String loserName = isBluffCaught ? String.valueOf(curBid.get("bidderName")) : challengerName;

            updatePlayerCoinsSafely(winnerId, 200);
            updatePlayerCoinsSafely(loserId, -200);
            room.put("currentDiceBid", null);

            Map<String, Object> settlePayload = new HashMap<>();
            settlePayload.put("challengerId", challengerId);
            settlePayload.put("challengerName", challengerName);
            settlePayload.put("bid", curBid);
            settlePayload.put("actualCount", actualCount);
            settlePayload.put("targetFace", targetFace);
            settlePayload.put("bidCount", bidCount);
            settlePayload.put("isPure", isPure);
            settlePayload.put("isBluffCaught", isBluffCaught);
            settlePayload.put("winnerId", winnerId);
            settlePayload.put("winnerName", winnerName);
            settlePayload.put("loserId", loserId);
            settlePayload.put("loserName", loserName);
            settlePayload.put("allHands", diceHands);
            settlePayload.put("rewardCoins", 200);

            Map<String, Object> settleAct = new HashMap<>();
            settleAct.put("type", "GAME_ACTION");
            settleAct.put("action", "DICE_SETTLEMENT");
            settleAct.put("roomCode", gameRoom);
            settleAct.put("payload", settlePayload);
            broadcastToRoom(gameRoom, settleAct, null);
        }
    }

    private void scheduleLiarsDiceAiTurnIfNeeded(String gameRoom, Map<String, Object> room, String lastBidderId) {
        List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
        if (players == null || players.size() < 2) return;
        int idx = -1;
        for (int i = 0; i < players.size(); i++) {
            if (Objects.equals(String.valueOf(players.get(i).get("id")), String.valueOf(lastBidderId))) {
                idx = i;
                break;
            }
        }
        int nextIdx = (idx + 1) % players.size();
        Map<String, Object> nextP = players.get(nextIdx);
        if (!Boolean.TRUE.equals(nextP.get("isAi"))) return;
        String aiId = String.valueOf(nextP.get("id"));
        String aiName = String.valueOf(nextP.getOrDefault("name", "AI桌友"));
        String aiAvatar = String.valueOf(nextP.getOrDefault("avatar", "🦊"));

        SCHEDULER.schedule(() -> {
            Map<String, Object> curBid = (Map<String, Object>) room.get("currentDiceBid");
            if (curBid == null) return;
            int bidCount = Integer.parseInt(curBid.get("count").toString());
            int bidFace = Integer.parseInt(curBid.get("face").toString());
            boolean isPure = Boolean.parseBoolean(String.valueOf(curBid.get("isPure")));
            int threshold = Math.max(4, players.size() * 2);
            Random rnd = new Random();
            if (bidCount >= threshold || (bidCount >= players.size() + 2 && rnd.nextInt(100) < 45)) {
                Map<String, Object> chAct = new HashMap<>();
                chAct.put("type", "GAME_ACTION");
                chAct.put("roomCode", gameRoom);
                chAct.put("action", "CHALLENGE");
                chAct.put("senderId", aiId);
                chAct.put("senderName", aiName);
                chAct.put("payload", Map.of("challengerId", aiId, "challengerName", aiName));
                broadcastToRoom(gameRoom, chAct, null);
                resolveLiarsDiceChallenge(gameRoom, room, aiId, aiName);
            } else {
                int nextCount = bidCount;
                int nextFace = bidFace;
                if (bidFace < 6 && rnd.nextBoolean()) {
                    nextFace = bidFace + 1;
                } else {
                    nextCount = bidCount + 1;
                    nextFace = rnd.nextInt(5) + 2;
                }
                Map<String, Object> newBid = new HashMap<>();
                newBid.put("count", nextCount);
                newBid.put("face", nextFace);
                newBid.put("isPure", isPure);
                newBid.put("bidderId", aiId);
                newBid.put("bidderName", aiName);
                room.put("currentDiceBid", newBid);

                Map<String, Object> bidAct = new HashMap<>();
                bidAct.put("type", "GAME_ACTION");
                bidAct.put("roomCode", gameRoom);
                bidAct.put("action", "BID");
                bidAct.put("senderId", aiId);
                bidAct.put("senderName", aiName);
                bidAct.put("payload", newBid);
                broadcastToRoom(gameRoom, bidAct, null);

                Map<String, Object> chat = new HashMap<>();
                chat.put("type", "CHAT_MESSAGE");
                chat.put("id", "MSG-" + System.currentTimeMillis());
                chat.put("channel", "ROOM");
                chat.put("roomCode", gameRoom);
                chat.put("senderId", aiId);
                chat.put("senderName", aiName);
                chat.put("senderAvatar", aiAvatar);
                chat.put("content", "📢 我跟叫 " + nextCount + " 个 " + nextFace + " 点！");
                broadcastToRoom(gameRoom, chat, null);

                scheduleLiarsDiceAiTurnIfNeeded(gameRoom, room, aiId);
            }
        }, 2000, TimeUnit.MILLISECONDS);
    }

    private void advanceUndercoverSpeaker(String gameRoom, Map<String, Object> room) {
        List<String> alive = (List<String>) room.get("undercoverAlivePlayerIds");
        int curIdx = (int) room.getOrDefault("undercoverSpeakerIndex", 0);
        curIdx++;
        if (alive != null && curIdx >= alive.size()) {
            room.put("undercoverPhase", "VOTING");
            room.put("undercoverVotes", new ConcurrentHashMap<String, String>());
            Map<String, Object> pChange = new HashMap<>();
            pChange.put("type", "GAME_ACTION");
            pChange.put("action", "UNDERCOVER_PHASE_VOTING");
            pChange.put("roomCode", gameRoom);
            pChange.put("payload", Map.of("timeoutSeconds", 25, "alivePlayerIds", alive));
            broadcastToRoom(gameRoom, pChange, null);
            scheduleUndercoverAiVotes(gameRoom, room);
        } else {
            room.put("undercoverSpeakerIndex", curIdx);
            String nextSpeakerId = (alive != null && curIdx < alive.size()) ? alive.get(curIdx) : null;
            Map<String, Object> nextTurn = new HashMap<>();
            nextTurn.put("type", "GAME_ACTION");
            nextTurn.put("action", "UNDERCOVER_NEXT_SPEAKER");
            nextTurn.put("roomCode", gameRoom);
            nextTurn.put("payload", Map.of("speakerId", nextSpeakerId != null ? nextSpeakerId : "", "speakerIndex", curIdx));
            broadcastToRoom(gameRoom, nextTurn, null);
            checkAndScheduleUndercoverAiTurn(gameRoom, room);
        }
    }

    private void checkAndScheduleUndercoverAiTurn(String gameRoom, Map<String, Object> room) {
        List<String> alive = (List<String>) room.get("undercoverAlivePlayerIds");
        int curIdx = (int) room.getOrDefault("undercoverSpeakerIndex", 0);
        if (alive == null || curIdx < 0 || curIdx >= alive.size()) return;
        String speakerId = alive.get(curIdx);
        List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
        if (players == null) return;
        Map<String, Object> speakerPlayer = null;
        for (Map<String, Object> p : players) {
            if (Objects.equals(String.valueOf(p.get("id")), speakerId)) {
                speakerPlayer = p;
                break;
            }
        }
        if (speakerPlayer == null || !Boolean.TRUE.equals(speakerPlayer.get("isAi"))) return;
        String aiName = String.valueOf(speakerPlayer.getOrDefault("name", "AI桌友"));
        String aiAvatar = String.valueOf(speakerPlayer.getOrDefault("avatar", "🦊"));
        String[] clues = {
            "日常生活中经常能见到它，大家应该都很熟悉~",
            "这个东西很有特点，我平时也挺喜欢的！",
            "跟大家的生活息息相关，不用说太白了吧~",
            "感觉前面有人说得有点可疑哦，我的词很常见！"
        };
        String clue = clues[new Random().nextInt(clues.length)];
        SCHEDULER.schedule(() -> {
            if (!"SPEAKING".equals(room.get("undercoverPhase"))) return;
            Map<String, Object> chat = new HashMap<>();
            chat.put("type", "CHAT_MESSAGE");
            chat.put("id", "MSG-" + System.currentTimeMillis());
            chat.put("channel", "ROOM");
            chat.put("roomCode", gameRoom);
            chat.put("senderId", speakerId);
            chat.put("senderName", aiName);
            chat.put("senderAvatar", aiAvatar);
            chat.put("content", "🎤 【麦序发言】" + clue);
            broadcastToRoom(gameRoom, chat, null);
            advanceUndercoverSpeaker(gameRoom, room);
        }, 1800, TimeUnit.MILLISECONDS);
    }

    private void scheduleUndercoverAiVotes(String gameRoom, Map<String, Object> room) {
        List<String> alive = (List<String>) room.get("undercoverAlivePlayerIds");
        List<Map<String, Object>> players = (List<Map<String, Object>>) room.get("players");
        if (alive == null || players == null || alive.size() < 2) return;
        SCHEDULER.schedule(() -> {
            if (!"VOTING".equals(room.get("undercoverPhase"))) return;
            Map<String, String> votes = (Map<String, String>) room.computeIfAbsent("undercoverVotes", k -> new ConcurrentHashMap<>());
            Random rnd = new Random();
            for (Map<String, Object> p : players) {
                String pid = String.valueOf(p.get("id"));
                if (Boolean.TRUE.equals(p.get("isAi")) && alive.contains(pid) && !votes.containsKey(pid)) {
                    List<String> candidates = new ArrayList<>(alive);
                    candidates.remove(pid);
                    if (!candidates.isEmpty()) {
                        votes.put(pid, candidates.get(rnd.nextInt(candidates.size())));
                    }
                }
            }
            evaluateUndercoverVotesIfComplete(gameRoom, room);
        }, 2200, TimeUnit.MILLISECONDS);
    }

    private synchronized void evaluateUndercoverVotesIfComplete(String gameRoom, Map<String, Object> room) {
        if (!"VOTING".equals(room.get("undercoverPhase"))) return;
        Map<String, String> votes = (Map<String, String>) room.get("undercoverVotes");
        List<String> alive = (List<String>) room.get("undercoverAlivePlayerIds");
        if (votes == null || alive == null || votes.size() < alive.size()) return;

        room.put("undercoverPhase", "SETTLING");
        Map<String, Integer> counts = new HashMap<>();
        for (String t : votes.values()) counts.put(t, counts.getOrDefault(t, 0) + 1);
        String outId = Collections.max(counts.entrySet(), Map.Entry.comparingByValue()).getKey();
        Map<String, Map<String, Object>> roles = (Map<String, Map<String, Object>>) room.get("undercoverRoles");
        Map<String, Object> outRole = roles != null ? roles.get(outId) : null;
        boolean wasUndercover = outRole != null && Boolean.TRUE.equals(outRole.get("isUndercover"));
        String outName = outRole != null ? String.valueOf(outRole.get("name")) : "玩家";

        alive.remove(outId);

        int remUc = 0;
        int remCiv = 0;
        for (String pid : alive) {
            if (roles != null && roles.get(pid) != null && Boolean.TRUE.equals(roles.get(pid).get("isUndercover"))) remUc++;
            else remCiv++;
        }

        boolean gameOver = false;
        String winTeam = null;
        if (remUc == 0) {
            gameOver = true;
            winTeam = "CIVILIAN";
        } else if (remCiv <= remUc) {
            gameOver = true;
            winTeam = "UNDERCOVER";
        }

        Map<String, Object> vRes = new HashMap<>();
        vRes.put("outPlayerId", outId);
        vRes.put("outPlayerName", outName);
        vRes.put("wasUndercover", wasUndercover);
        vRes.put("voteCounts", counts);
        vRes.put("gameOver", gameOver);
        vRes.put("winnerTeam", winTeam);
        vRes.put("remainingAlive", alive);

        Map<String, Object> vAct = new HashMap<>();
        vAct.put("type", "GAME_ACTION");
        vAct.put("action", "UNDERCOVER_VOTE_RESULT");
        vAct.put("roomCode", gameRoom);
        vAct.put("payload", vRes);
        broadcastToRoom(gameRoom, vAct, null);

        if (!gameOver) {
            int round = (int) room.getOrDefault("undercoverRound", 1) + 1;
            room.put("undercoverRound", round);
            room.put("undercoverSpeakerIndex", 0);
            room.put("undercoverPhase", "SPEAKING");
            String firstSpeakerId = (!alive.isEmpty()) ? alive.get(0) : "";
            Map<String, Object> nextTurn = new HashMap<>();
            nextTurn.put("type", "GAME_ACTION");
            nextTurn.put("action", "UNDERCOVER_NEXT_SPEAKER");
            nextTurn.put("roomCode", gameRoom);
            nextTurn.put("payload", Map.of("speakerId", firstSpeakerId, "speakerIndex", 0, "round", round));
            broadcastToRoom(gameRoom, nextTurn, null);
            checkAndScheduleUndercoverAiTurn(gameRoom, room);
        }
    }

    private void updatePlayerCoinsSafely(String userId, long delta) {
        if (userId == null || userId.startsWith("U-") || userId.startsWith("AI-")) return;
        try {
            userRepository.findById(userId.trim()).ifPresent(u -> {
                long c = u.getCoins() != null ? u.getCoins() : 0L;
                u.setCoins(Math.max(0, c + delta));
                userRepository.save(u);
            });
        } catch (Exception e) {
            log.warn("[CoinUpdate] 更新金币异常: userId={}, delta={}, error={}", userId, delta, e.getMessage());
        }
    }

    public static boolean sendToUser(String targetUserId, Object message) {
        if (targetUserId == null || targetUserId.trim().isEmpty()) return false;
        String cleanTarget = targetUserId.trim();
        String stripTarget = cleanTarget.replace("-", "").toLowerCase();
        String data = JSON.toJSONString(message);
        TextMessage text = new TextMessage(data);
        boolean sent = false;
        for (Map.Entry<WebSocketSession, ClientMeta> entry : clients.entrySet()) {
            WebSocketSession s = entry.getKey();
            ClientMeta m = entry.getValue();
            if (s.isOpen() && m.userId != null) {
                String stripUser = m.userId.replace("-", "").toLowerCase();
                if (cleanTarget.equalsIgnoreCase(m.userId.trim()) || stripTarget.equals(stripUser)) {
                    try {
                        s.sendMessage(text);
                        sent = true;
                    } catch (IOException ignored) {}
                }
            }
        }
        return sent;
    }

    public static void broadcastToRoom(String roomCode, Object message, WebSocketSession exclude) {
        String data = JSON.toJSONString(message);
        TextMessage text = new TextMessage(data);
        for (Map.Entry<WebSocketSession, ClientMeta> entry : clients.entrySet()) {
            WebSocketSession s = entry.getKey();
            ClientMeta m = entry.getValue();
            if (s.isOpen() && s != exclude && Objects.equals(m.roomCode, roomCode)) {
                try {
                    s.sendMessage(text);
                } catch (IOException ignored) {}
            }
        }
    }

    public static void broadcastToAll(Object message, WebSocketSession exclude) {
        String data = JSON.toJSONString(message);
        TextMessage text = new TextMessage(data);
        for (WebSocketSession s : clients.keySet()) {
            if (s.isOpen() && s != exclude) {
                try {
                    s.sendMessage(text);
                } catch (IOException ignored) {}
            }
        }
    }

    public static void autoFillRealisticPlayer(String roomCode) {
        if (roomCode == null) return;
        Map<String, Object> r = RoomAndMomentController.ROOMS.get(roomCode);
        if (r == null || "PLAYING".equals(r.get("status"))) return;
        List<Map<String, Object>> players = (List<Map<String, Object>>) r.computeIfAbsent("players", k -> new ArrayList<>());
        if (players.size() >= 6) return;

        Set<String> existingNames = new HashSet<>();
        for (Map<String, Object> p : players) {
            existingNames.add(String.valueOf(p.get("name")));
        }
        List<String> pool = new ArrayList<>(REALISTIC_AI_NAMES);
        pool.removeIf(existingNames::contains);
        String name = pool.isEmpty() ? "玩家" + (1000 + new Random().nextInt(9000)) : pool.get(new Random().nextInt(pool.size()));
        String avatar = REALISTIC_AI_AVATARS.get(new Random().nextInt(REALISTIC_AI_AVATARS.size()));
        String uid = "U-" + (100000 + new Random().nextInt(899999));

        Map<String, Object> ai = new HashMap<>();
        ai.put("id", uid);
        ai.put("name", name);
        ai.put("avatar", avatar);
        ai.put("isAi", true);
        ai.put("isReady", true);
        ai.put("online", true);
        ai.put("isHost", false);
        players.add(ai);

        Map<String, Object> aiEvt = new HashMap<>();
        aiEvt.put("type", "ROOM_PLAYERS_UPDATED");
        aiEvt.put("roomCode", roomCode);
        aiEvt.put("event", "玩家【" + name + "】进入了房间");
        aiEvt.put("players", players);
        aiEvt.put("playerCount", players.size());
        broadcastToRoom(roomCode, aiEvt, null);

        // 800ms后拟真AI在房间打招呼
        SCHEDULER.schedule(() -> {
            String greeting = AI_GREETINGS.get(new Random().nextInt(AI_GREETINGS.size()));
            Map<String, Object> chat = new HashMap<>();
            chat.put("type", "CHAT_MESSAGE");
            chat.put("id", "MSG-" + System.currentTimeMillis());
            chat.put("channel", "ROOM");
            chat.put("roomCode", roomCode);
            chat.put("senderId", uid);
            chat.put("senderName", name);
            chat.put("senderAvatar", avatar);
            chat.put("content", greeting);
            chat.put("timestamp", new Date().toString());
            broadcastToRoom(roomCode, chat, null);
        }, 800, TimeUnit.MILLISECONDS);
    }
}
