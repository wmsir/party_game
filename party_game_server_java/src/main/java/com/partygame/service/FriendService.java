package com.partygame.service;

import com.partygame.entity.FriendRelation;
import com.partygame.entity.FriendRequest;
import com.partygame.entity.User;
import com.partygame.entity.DirectMessageRecord;
import com.partygame.repository.FriendRelationRepository;
import com.partygame.repository.FriendRequestRepository;
import com.partygame.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class FriendService {

    private final FriendRelationRepository relationRepository;
    private final FriendRequestRepository requestRepository;
    private final UserRepository userRepository;
    private final com.partygame.repository.DirectMessageRepository directMessageRepository;

    /**
     * 获取用户真实好友列表 (纯数据库数据，不含任何假数据)
     */
    public List<Map<String, Object>> getFriendList(String userId) {
        List<FriendRelation> relations = relationRepository.findByUserId(userId);
        if (relations.isEmpty()) {
            return Collections.emptyList();
        }

        List<Map<String, Object>> list = new ArrayList<>();
        for (FriendRelation rel : relations) {
            Optional<User> fOpt = userRepository.findById(rel.getFriendId());
            if (fOpt.isPresent()) {
                User u = fOpt.get();
                Map<String, Object> map = new HashMap<>();
                map.put("id", u.getId());
                map.put("nickname", u.getNickname());
                map.put("avatar", u.getAvatar());
                map.put("levelTitle", u.getLevelTitle() != null ? u.getLevelTitle() : "聚会好友");
                map.put("phone", u.getPhone());
                map.put("isOnline", true);

                // 从数据库实时统计当前用户与该好友的未读消息数及最新留言
                int unread = directMessageRepository.countUnreadBetween(userId.trim(), u.getId());
                com.partygame.entity.DirectMessageRecord latest = directMessageRepository.findLatestMessageBetween(userId.trim(), u.getId());

                if (latest != null && latest.getContent() != null) {
                    map.put("lastMessage", latest.getContent());
                    map.put("lastMessageTime", java.time.Instant.ofEpochMilli(latest.getTimestamp()).toString());
                    map.put("lastMessageTimestamp", latest.getTimestamp());
                } else {
                    map.put("lastMessage", "");
                    map.put("lastMessageTime", rel.getCreatedAt() != null ? rel.getCreatedAt().toString() : LocalDateTime.now().toString());
                }
                map.put("remark", rel.getRemark() != null ? rel.getRemark() : "");
                map.put("vipLevel", u.getVipLevel() != null ? u.getVipLevel() : 0);
                map.put("avatarFrame", u.getAvatarFrame() != null ? u.getAvatarFrame() : "FRAME_DEFAULT");
                map.put("rankTier", u.getRankTier() != null ? u.getRankTier() : "暂无段位");
                map.put("rankScore", u.getRankScore() != null ? u.getRankScore() : 0);
                map.put("winCount", u.getWinCount() != null ? u.getWinCount() : 0);
                map.put("totalGames", u.getTotalGames() != null ? u.getTotalGames() : 0);
                map.put("coins", u.getCoins() != null ? u.getCoins() : 0);
                map.put("diamonds", u.getDiamonds() != null ? u.getDiamonds() : 0);
                map.put("chatTextColor", u.getChatTextColor() != null ? u.getChatTextColor() : "COLOR_DEFAULT");
                map.put("unreadCount", unread);
                list.add(map);
            }
        }
        return list;
    }

    /**
     * 获取待处理好友申请 (纯数据库数据，初始为空)
     */
    /**
     * 根据用户ID、去中划线ID、手机号、账号名或昵称解析标准用户ID
     */
    public String resolveUserId(String identifier) {
        if (identifier == null || identifier.trim().isEmpty()) {
            return null;
        }
        String id = identifier.trim();
        // 1. 原生ID直接匹配
        if (userRepository.existsById(id)) {
            return id;
        }
        // 2. 去中划线纯ID比对
        String cleanId = id.replace("-", "").toLowerCase();
        List<User> allUsers = userRepository.findAll();
        for (User u : allUsers) {
            if (u.getId() != null && u.getId().replace("-", "").equalsIgnoreCase(cleanId)) {
                return u.getId();
            }
        }
        // 3. 用户名匹配
        Optional<User> byUsername = userRepository.findByUsername(id);
        if (byUsername.isPresent()) {
            return byUsername.get().getId();
        }
        // 4. 手机号匹配
        Optional<User> byPhone = userRepository.findByPhone(id);
        if (byPhone.isPresent()) {
            return byPhone.get().getId();
        }
        // 5. 昵称精确匹配
        for (User u : allUsers) {
            if (u.getNickname() != null && u.getNickname().equalsIgnoreCase(id)) {
                return u.getId();
            }
        }
        // 6. 模糊搜索若唯一匹配
        List<User> found = userRepository.searchUsers(id);
        if (found.size() == 1) {
            return found.get(0).getId();
        }
        return id;
    }

    /**
     * 获取待处理好友申请及陌生人私信留言
     */
    public List<Map<String, Object>> getPendingRequests(String toUserId) {
        String resolvedTo = resolveUserId(toUserId);
        String targetTo = (resolvedTo != null && !resolvedTo.isEmpty()) ? resolvedTo : toUserId;
        String cleanTarget = targetTo.replace("-", "").toLowerCase();

        List<FriendRequest> allPending = requestRepository.findAll();
        List<Map<String, Object>> result = new ArrayList<>();
        Set<String> processedSenderIds = new HashSet<>();

        for (FriendRequest r : allPending) {
            if (!"PENDING".equalsIgnoreCase(r.getStatus())) continue;
            String reqTo = r.getToUserId() != null ? r.getToUserId().replace("-", "").toLowerCase() : "";
            if (reqTo.equals(cleanTarget) || r.getToUserId().equalsIgnoreCase(targetTo)) {
                processedSenderIds.add(r.getFromUserId().replace("-", "").toLowerCase());
                Map<String, Object> map = new HashMap<>();
                map.put("id", r.getId());
                map.put("fromUserId", r.getFromUserId());
                map.put("toUserId", r.getToUserId());
                map.put("status", r.getStatus());
                map.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : "");
                map.put("message", r.getMessage() != null ? r.getMessage() : "");

                // 补充申请发起方信息
                Optional<User> senderOpt = userRepository.findById(r.getFromUserId());
                if (senderOpt.isEmpty()) {
                    String senderClean = r.getFromUserId().replace("-", "").toLowerCase();
                    senderOpt = userRepository.findAll().stream()
                            .filter(u -> u.getId() != null && u.getId().replace("-", "").equalsIgnoreCase(senderClean))
                            .findFirst();
                }

                senderOpt.ifPresent(sender -> {
                    Map<String, Object> fromUser = new HashMap<>();
                    fromUser.put("id", sender.getId());
                    fromUser.put("nickname", sender.getNickname());
                    fromUser.put("avatar", sender.getAvatar());
                    fromUser.put("levelTitle", sender.getLevelTitle());
                    fromUser.put("phone", sender.getPhone());
                    fromUser.put("vipLevel", sender.getVipLevel() != null ? sender.getVipLevel() : 0);
                    map.put("fromUser", fromUser);
                    map.put("nickname", sender.getNickname());
                    map.put("avatar", sender.getAvatar());
                    map.put("levelTitle", sender.getLevelTitle());
                    map.put("vipLevel", sender.getVipLevel() != null ? sender.getVipLevel() : 0);
                });

                // 获取发起方给接收方发送的最新留言/私信内容
                DirectMessageRecord latest = directMessageRepository.findLatestMessageBetween(r.getFromUserId(), targetTo);
                if (latest != null && latest.getContent() != null && !latest.getContent().isEmpty()) {
                    map.put("latestMessage", latest.getContent());
                    map.put("messageTime", latest.getTimestamp());
                } else if (r.getMessage() != null && !r.getMessage().isEmpty()) {
                    map.put("latestMessage", r.getMessage());
                } else {
                    map.put("latestMessage", "请求添加您为好友");
                }

                result.add(map);
            }
        }

        // 进一步扫描非好友发送给当前用户的陌生人留言，自动聚合到申请/留言栏展示
        try {
            List<DirectMessageRecord> incomingMessages = directMessageRepository.findByToUserIdAndIsReadFalseOrderByTimestampAsc(targetTo);
            for (DirectMessageRecord dm : incomingMessages) {
                String senderId = dm.getFromUserId();
                if (senderId == null || senderId.equalsIgnoreCase(targetTo)) continue;
                String cleanSender = senderId.replace("-", "").toLowerCase();
                if (processedSenderIds.contains(cleanSender)) continue;
                if (isFriend(targetTo, senderId)) continue;

                processedSenderIds.add(cleanSender);
                Map<String, Object> map = new HashMap<>();
                String autoReqId = "MSG_REQ_" + dm.getId();
                map.put("id", autoReqId);
                map.put("fromUserId", senderId);
                map.put("toUserId", targetTo);
                map.put("status", "PENDING");
                map.put("createdAt", java.time.Instant.ofEpochMilli(dm.getTimestamp()).toString());
                map.put("message", dm.getContent());
                map.put("latestMessage", dm.getContent());
                map.put("messageTime", dm.getTimestamp());

                Optional<User> sOpt = userRepository.findById(senderId);
                if (sOpt.isPresent()) {
                    User s = sOpt.get();
                    Map<String, Object> fromUser = new HashMap<>();
                    fromUser.put("id", s.getId());
                    fromUser.put("nickname", s.getNickname());
                    fromUser.put("avatar", s.getAvatar());
                    fromUser.put("levelTitle", s.getLevelTitle());
                    fromUser.put("vipLevel", s.getVipLevel() != null ? s.getVipLevel() : 0);
                    map.put("fromUser", fromUser);
                    map.put("nickname", s.getNickname());
                    map.put("avatar", s.getAvatar());
                    map.put("levelTitle", s.getLevelTitle());
                    map.put("vipLevel", s.getVipLevel() != null ? s.getVipLevel() : 0);
                } else {
                    map.put("nickname", dm.getFromNickname() != null ? dm.getFromNickname() : "陌生玩家");
                    map.put("avatar", dm.getFromAvatar() != null ? dm.getFromAvatar() : "🦊");
                }
                result.add(map);
            }
        } catch (Exception e) {
            log.warn("Failed to scan non-friend messages for {}: {}", targetTo, e.getMessage());
        }

        return result;
    }

    /**
     * 发送好友申请 (支持附带留言及全格式编号解析)
     */
    @Transactional
    public FriendRequest applyFriend(String fromUserId, String toUserId, String message) {
        String resolvedFrom = resolveUserId(fromUserId);
        String resolvedTo = resolveUserId(toUserId);

        if (resolvedFrom == null || resolvedTo == null) {
            throw new IllegalArgumentException("未找到指定用户，请核对用户UID或昵称");
        }
        if (resolvedFrom.equalsIgnoreCase(resolvedTo) ||
            resolvedFrom.replace("-", "").equalsIgnoreCase(resolvedTo.replace("-", ""))) {
            throw new IllegalArgumentException("不能添加自己为好友");
        }
        if (isFriend(resolvedFrom, resolvedTo)) {
            throw new IllegalArgumentException("对方已经是您的好友了");
        }

        Optional<FriendRequest> pending = requestRepository.findByFromUserIdAndToUserIdAndStatus(resolvedFrom, resolvedTo, "PENDING");
        if (pending.isPresent()) {
            FriendRequest existing = pending.get();
            if (message != null && !message.trim().isEmpty()) {
                existing.setMessage(message.trim());
                existing.setCreatedAt(LocalDateTime.now());
                return requestRepository.save(existing);
            }
            return existing;
        }

        String reqId = "REQ" + System.currentTimeMillis() + (int)(Math.random() * 1000);
        FriendRequest req = FriendRequest.builder()
                .id(reqId)
                .fromUserId(resolvedFrom)
                .toUserId(resolvedTo)
                .status("PENDING")
                .message(message != null ? message.trim() : "")
                .createdAt(LocalDateTime.now())
                .build();
        return requestRepository.save(req);
    }

    @Transactional
    public FriendRequest applyFriend(String fromUserId, String toUserId) {
        return applyFriend(fromUserId, toUserId, null);
    }

    /**
     * 处理好友申请（同意/拒绝）
     */
    @Transactional
    public FriendRequest respondRequest(String requestId, String action, String currentUserId) {
        String curClean = currentUserId.replace("-", "").toLowerCase();

        // 针对陌生人留言虚拟申请单的处理
        if (requestId != null && requestId.startsWith("MSG_REQ_")) {
            String msgId = requestId.substring("MSG_REQ_".length());
            Optional<DirectMessageRecord> dmOpt = directMessageRepository.findById(msgId);
            String fromUserId = dmOpt.map(DirectMessageRecord::getFromUserId).orElse("");
            if ("ACCEPT".equalsIgnoreCase(action) && !fromUserId.isEmpty()) {
                if (!isFriend(fromUserId, currentUserId)) {
                    relationRepository.save(FriendRelation.builder().userId(fromUserId).friendId(currentUserId).build());
                    relationRepository.save(FriendRelation.builder().userId(currentUserId).friendId(fromUserId).build());
                }
            }
            // 标记消息已读
            directMessageRepository.markAsReadBetween(currentUserId, fromUserId);
            return FriendRequest.builder().id(requestId).fromUserId(fromUserId).toUserId(currentUserId).status("ACCEPT".equalsIgnoreCase(action) ? "ACCEPTED" : "REJECTED").build();
        }

        FriendRequest req = requestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException("申请记录不存在"));

        String reqToClean = req.getToUserId().replace("-", "").toLowerCase();
        if (!req.getToUserId().equalsIgnoreCase(currentUserId) && !reqToClean.equals(curClean)) {
            throw new IllegalArgumentException("无权处理其他人的好友申请");
        }
        if (!"PENDING".equalsIgnoreCase(req.getStatus())) {
            throw new IllegalArgumentException("该申请已被处理");
        }

        req.setRespondedAt(LocalDateTime.now());
        if ("ACCEPT".equalsIgnoreCase(action)) {
            req.setStatus("ACCEPTED");
            // 双向入库建立真实好友关系
            if (!isFriend(req.getFromUserId(), req.getToUserId())) {
                relationRepository.save(FriendRelation.builder().userId(req.getFromUserId()).friendId(req.getToUserId()).build());
            }
            if (!isFriend(req.getToUserId(), req.getFromUserId())) {
                relationRepository.save(FriendRelation.builder().userId(req.getToUserId()).friendId(req.getFromUserId()).build());
            }
            // 同时标记双方未读私信已读
            directMessageRepository.markAsReadBetween(req.getToUserId(), req.getFromUserId());
            log.info("用户 {} 与用户 {} 建立真实好友关系", req.getFromUserId(), req.getToUserId());
        } else {
            req.setStatus("REJECTED");
        }
        return requestRepository.save(req);
    }

    /**
     * 修改好友备注名称
     */
    @Transactional
    public void updateRemark(String userId, String friendId, String remark) {
        String cleanFriend = friendId.replace("-", "").toLowerCase();
        List<FriendRelation> list = relationRepository.findByUserId(userId.trim());
        for (FriendRelation rel : list) {
            if (rel.getFriendId() != null && (rel.getFriendId().equalsIgnoreCase(friendId.trim()) || rel.getFriendId().replace("-", "").equalsIgnoreCase(cleanFriend))) {
                rel.setRemark(remark != null ? remark.trim() : "");
                relationRepository.save(rel);
                log.info("用户 [{}] 修改好友 [{}] 备注为: [{}]", userId, friendId, remark);
                return;
            }
        }
    }

    public boolean isFriend(String userId, String friendId) {
        if (userId == null || friendId == null) return false;
        String u1 = userId.trim();
        String u2 = friendId.trim();
        if (relationRepository.existsByUserIdAndFriendId(u1, u2)) return true;
        String clean1 = u1.replace("-", "").toLowerCase();
        String clean2 = u2.replace("-", "").toLowerCase();
        List<FriendRelation> list = relationRepository.findByUserId(u1);
        for (FriendRelation r : list) {
            if (r.getFriendId() != null && r.getFriendId().replace("-", "").toLowerCase().equals(clean2)) {
                return true;
            }
        }
        return false;
    }

    public String getFriendRemark(String userId, String friendId) {
        String cleanFriend = friendId.replace("-", "").toLowerCase();
        List<FriendRelation> list = relationRepository.findByUserId(userId.trim());
        for (FriendRelation rel : list) {
            if (rel.getFriendId() != null && (rel.getFriendId().equalsIgnoreCase(friendId.trim()) || rel.getFriendId().replace("-", "").toLowerCase().equals(cleanFriend))) {
                return rel.getRemark() != null ? rel.getRemark() : "";
            }
        }
        return "";
    }
}
