package com.partygame.controller;

import com.partygame.entity.FriendRequest;
import com.partygame.repository.DirectMessageRepository;
import com.partygame.service.FriendService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class FriendController {

    private final FriendService friendService;
    private final DirectMessageRepository directMessageRepository;

    /**
     * 查询真实好友列表 (纯数据库数据，清空了所有假数据)
     */
    @GetMapping({"/api/friends/list", "/party-game/api/friends/list"})
    public ResponseEntity<?> getFriends(@RequestParam(required = false) String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.ok(createSuccess(Collections.emptyList()));
        }
        List<Map<String, Object>> friends = friendService.getFriendList(userId.trim());
        return ResponseEntity.ok(createSuccess(friends));
    }

    /**
     * 查询真实好友申请列表
     */
    @GetMapping("/api/friends/requests")
    public ResponseEntity<?> getRequests(@RequestParam(required = false) String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.ok(createSuccess(Collections.emptyList()));
        }
        List<Map<String, Object>> requests = friendService.getPendingRequests(userId.trim());
        return ResponseEntity.ok(createSuccess(requests));
    }

    /**
     * 发送好友申请 (支持灵活传参: fromUserId/applicantId, toUserId/targetId, 并支持留言)
     */
    @PostMapping({"/api/friends/apply", "/party-game/api/friends/apply"})
    public ResponseEntity<?> applyFriend(@RequestBody Map<String, String> body) {
        String fromUserId = body.get("fromUserId");
        if (fromUserId == null || fromUserId.trim().isEmpty()) {
            fromUserId = body.get("applicantId");
        }
        if (fromUserId == null || fromUserId.trim().isEmpty()) {
            fromUserId = body.get("userId");
        }

        String toUserId = body.get("toUserId");
        if (toUserId == null || toUserId.trim().isEmpty()) {
            toUserId = body.get("targetId");
        }
        if (toUserId == null || toUserId.trim().isEmpty()) {
            toUserId = body.get("friendId");
        }

        if (fromUserId == null || toUserId == null || fromUserId.trim().isEmpty() || toUserId.trim().isEmpty()) {
            return ResponseEntity.badRequest().body(createError("请提供完整的双方用户编号"));
        }

        String message = body.get("message");
        if (message == null) message = body.get("content");

        try {
            FriendRequest req = friendService.applyFriend(fromUserId.trim(), toUserId.trim(), message);
            Map<String, Object> res = createSuccess(req);
            res.put("message", "好友申请已成功发送，等待对方确认！");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 处理好友申请 (同意/拒绝)
     */
    @PostMapping("/api/friends/respond")
    public ResponseEntity<?> respondRequest(@RequestBody Map<String, String> body) {
        String requestId = body.get("requestId");
        String action = body.get("action");
        String userId = body.get("userId");
        if (requestId == null || action == null || userId == null) {
            return ResponseEntity.badRequest().body(createError("参数不完整"));
        }
        try {
            FriendRequest req = friendService.respondRequest(requestId, action, userId);
            Map<String, Object> res = createSuccess(req);
            res.put("message", "ACCEPT".equalsIgnoreCase(action) ? "已同意好友申请！正式成为好友！" : "已拒绝好友申请");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 设置/修改好友备注名
     */
    @PostMapping({"/api/friends/remark", "/party-game/api/friends/remark"})
    public ResponseEntity<?> setRemark(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String friendId = body.get("friendId");
        String remark = body.get("remark");
        if (userId == null || friendId == null) {
            return ResponseEntity.badRequest().body(createError("参数不完整"));
        }
        try {
            friendService.updateRemark(userId, friendId, remark);
            Map<String, Object> res = createSuccess(null);
            res.put("message", "好友备注修改成功！");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(createError(e.getMessage()));
        }
    }

    /**
     * 发送私信消息（支持数据库持久化 + 在线 WebSocket 毫秒级直推双重保障）
     */
    @PostMapping("/api/friends/messages/send")
    public ResponseEntity<?> sendMessage(@RequestBody Map<String, String> body) {
        String fromUserId = body.get("fromUserId");
        String toUserId = body.get("toUserId");
        String content = body.get("content");
        String fromNickname = body.get("fromNickname");
        String fromAvatar = body.get("fromAvatar");
        String inviteRoomCode = body.get("inviteRoomCode");
        String msgId = body.get("id");

        if (fromUserId == null || toUserId == null || content == null) {
            return ResponseEntity.badRequest().body(createError("消息参数不完整"));
        }

        if (msgId == null || msgId.isEmpty()) {
            msgId = "DM-" + System.currentTimeMillis();
        }
        long timestamp = System.currentTimeMillis();

        Map<String, Object> dm = new HashMap<>();
        dm.put("type", "DIRECT_MESSAGE");
        dm.put("id", msgId);
        dm.put("toUserId", toUserId);
        dm.put("fromUserId", fromUserId);
        dm.put("fromNickname", fromNickname != null ? fromNickname : "好友");
        dm.put("fromAvatar", fromAvatar != null ? fromAvatar : "🦊");
        dm.put("content", content);
        dm.put("inviteRoomCode", inviteRoomCode);
        dm.put("timestamp", timestamp);

        // 如果对方在线，通过 WebSocket 立即投递
        boolean delivered = com.partygame.websocket.GameWebSocketHandler.sendToUser(toUserId, dm);

        com.partygame.entity.DirectMessageRecord rec = com.partygame.entity.DirectMessageRecord.builder()
                .id(msgId)
                .fromUserId(fromUserId)
                .fromNickname(fromNickname)
                .fromAvatar(fromAvatar)
                .toUserId(toUserId)
                .content(content)
                .inviteRoomCode(inviteRoomCode)
                .timestamp(timestamp)
                .delivered(delivered)
                .isRead(false)
                .build();
        directMessageRepository.save(rec);

        log.info("[DM] Sent direct message: id={}, from={}, to={}, delivered={}", msgId, fromUserId, toUserId, delivered);
        return ResponseEntity.ok(createSuccess(rec));
    }

    /**
     * 标记与指定好友的私信为已读
     */
    @PostMapping("/api/friends/messages/read")
    public ResponseEntity<?> markMessagesAsRead(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String friendId = body.get("friendId");
        if (userId == null || friendId == null) {
            return ResponseEntity.badRequest().body(createError("参数不完整"));
        }
        directMessageRepository.markAsReadBetween(userId.trim(), friendId.trim());
        return ResponseEntity.ok(createSuccess(Map.of("status", "ok")));
    }

    /**
     * 查询离线/未读私信（用户登录后主动同步兜底，基于 isRead 状态可靠拉取，杜绝漏信）
     */
    @GetMapping("/api/friends/messages/unread")
    public ResponseEntity<?> getUnreadMessages(@RequestParam String userId) {
        if (userId == null || userId.trim().isEmpty()) {
            return ResponseEntity.ok(createSuccess(Collections.emptyList()));
        }
        List<com.partygame.entity.DirectMessageRecord> list = directMessageRepository.findByToUserIdAndIsReadFalseOrderByTimestampAsc(userId.trim());
        if (!list.isEmpty()) {
            for (com.partygame.entity.DirectMessageRecord r : list) {
                r.setDelivered(true);
            }
            directMessageRepository.saveAll(list);
        }
        return ResponseEntity.ok(createSuccess(list));
    }

    /**
     * 查询与指定好友的聊天历史
     */
    @GetMapping("/api/friends/messages/history")
    public ResponseEntity<?> getChatHistory(@RequestParam String userId, @RequestParam String friendId) {
        if (userId == null || friendId == null) {
            return ResponseEntity.ok(createSuccess(Collections.emptyList()));
        }
        List<com.partygame.entity.DirectMessageRecord> history = directMessageRepository.findChatHistory(userId.trim(), friendId.trim());
        return ResponseEntity.ok(createSuccess(history));
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
