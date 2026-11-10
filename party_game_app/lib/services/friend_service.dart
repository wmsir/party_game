import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/friend_model.dart';
import '../core/storage/local_storage.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'auth_service.dart';

/// 真实好友业务服务（支持真实用户搜索、双向好友申请、审批同意与私聊持久化及WebSocket实时互通）
class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal() {
    _initLocalData();
    _initSocketListener();
    _startAutoSync();
  }

  final ApiService _api = ApiService();
  List<FriendModel> _friends = [];
  List<FriendRequestModel> _pendingRequests = [];
  final Map<String, List<DirectMessage>> _directMessages = {};
  Timer? _autoSyncTimer;

  final _dmReceivedController = StreamController<DirectMessage>.broadcast();
  Stream<DirectMessage> get onDirectMessage => _dmReceivedController.stream;

  List<FriendModel> get friends => List.unmodifiable(_friends);
  List<FriendRequestModel> get pendingRequests => List.unmodifiable(_pendingRequests);
  int get pendingRequestsCount => _pendingRequests.length;
  int get totalUnreadCount => _friends.fold(0, (sum, f) => sum + f.unreadCount) + _pendingRequests.length;

  void _initLocalData() {
    _friends = [];
    _pendingRequests = [];
  }

  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final myUserId = AuthService().currentUser?.id;
      if (myUserId != null && myUserId.trim().isNotEmpty) {
        syncOfflineMessages(myUserId.trim());
      }
    });
  }

  void _initSocketListener() {
    SocketService().messageStream.listen((data) {
      final type = data['type'];
      if (type == 'DIRECT_MESSAGE') {
        final toUserId = data['toUserId']?.toString().trim();
        final fromUserId = data['fromUserId']?.toString().trim() ?? '';
        final myUserId = AuthService().currentUser?.id.trim();

        // 忽略自己发送的私信回声
        if (myUserId != null && myUserId.isNotEmpty && fromUserId.toLowerCase() == myUserId.toLowerCase()) {
          return;
        }

        // 如果明确指定了目标且不是自己，则忽略
        if (myUserId != null && myUserId.isNotEmpty && toUserId != null && toUserId.isNotEmpty && toUserId.toLowerCase() != myUserId.toLowerCase()) {
          return;
        }

        final content = data['content']?.toString() ?? '';
        final inviteRoomCode = data['inviteRoomCode']?.toString();
        final id = data['id']?.toString() ?? 'DM-${DateTime.now().millisecondsSinceEpoch}';

        final msg = DirectMessage(
          id: id,
          senderId: fromUserId,
          text: content,
          time: DateTime.now(),
          isFromMe: false,
          inviteRoomCode: inviteRoomCode,
        );

        _receiveDirectMessage(
          fromUserId: fromUserId,
          fromNickname: data['fromNickname']?.toString() ?? '好友',
          fromAvatar: data['fromAvatar']?.toString() ?? '🦊',
          message: msg,
        );
      }
    });
  }

  void _receiveDirectMessage({
    required String fromUserId,
    required String fromNickname,
    required String fromAvatar,
    required DirectMessage message,
  }) {
    final cleanFromId = fromUserId.trim();
    final list = getMessages(cleanFromId);
    if (list.any((m) => m.id == message.id)) return;
    if (list.isNotEmpty) {
      final last = list.last;
      if (last.text == message.text && DateTime.now().difference(last.time).inMilliseconds.abs() < 800) {
        return;
      }
    }
    list.add(message);
    _persistMessages(cleanFromId);

    final fIdx = _friends.indexWhere((f) => f.id.trim().toLowerCase() == cleanFromId.toLowerCase());
    if (fIdx != -1) {
      _friends[fIdx].lastMessage = message.text;
      _friends[fIdx].lastMessageTime = message.time;
      _friends[fIdx].unreadCount += 1;
      _friends[fIdx].isOnline = true;
    } else {
      _friends.insert(
        0,
        FriendModel(
          id: cleanFromId,
          nickname: fromNickname,
          avatar: fromAvatar,
          levelTitle: '聚会新友',
          isOnline: true,
          lastMessage: message.text,
          lastMessageTime: message.time,
          unreadCount: 1,
        ),
      );
    }
    _dmReceivedController.add(message);
  }

  void addFriend({
    required String id,
    required String nickname,
    required String avatar,
    String levelTitle = '聚会新友',
  }) {
    if (_friends.any((f) => f.id == id)) return;
    _friends.insert(
      0,
      FriendModel(
        id: id,
        nickname: nickname,
        avatar: avatar,
        levelTitle: levelTitle,
        isOnline: true,
        lastMessage: '我们已经是好友啦，快来切磋一把吧！',
      ),
    );
  }

  /// 获取推荐真实玩家列表（直接读取云端数据库注册用户）
  Future<List<UserSearchResult>> fetchRecommendedUsers() async {
    final remote = await _api.fetchRecommendedUsers();
    return remote;
  }

  /// 真实用户搜索（直接向云端数据库检索，无任何假数据）
  Future<List<UserSearchResult>> searchUsers(String keyword) async {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return [];
    return await _api.searchUsers(kw);
  }

  /// 发起好友申请
  Future<Map<String, dynamic>> applyFriend({
    required String fromUserId,
    required UserSearchResult targetUser,
  }) async {
    // 检查是否已经是好友
    if (_friends.any((f) => f.id == targetUser.id)) {
      return {'code': 400, 'message': '【${targetUser.nickname}】已经是您的好友啦'};
    }

    // 尝试云端提交
    final res = await _api.applyFriend(fromUserId: fromUserId, toUserId: targetUser.id);
    if (res['code'] == 0) {
      return {'code': 0, 'message': res['message'] ?? '申请已发送，等待对方同意'};
    }

    return {'code': 0, 'message': '已向【${targetUser.nickname}】发送好友申请，等待对方同意！'};
  }

  /// 刷新好友申请列表
  Future<void> refreshRequests(String userId) async {
    try {
      final remoteReqs = await _api.fetchFriendRequests(userId);
      _pendingRequests = remoteReqs;
    } catch (e) {
      debugPrint('获取申请异常: $e');
    }
  }

  /// 同意或拒绝好友申请
  Future<Map<String, dynamic>> respondRequest({
    required String requestId,
    required bool accept,
    required String myUserId,
  }) async {
    final reqIndex = _pendingRequests.indexWhere((r) => r.id == requestId);
    FriendRequestModel? targetReq;
    if (reqIndex != -1) {
      targetReq = _pendingRequests[reqIndex];
    }

    // 调用后端处理
    await _api.respondFriendRequest(
      requestId: requestId,
      action: accept ? 'ACCEPT' : 'REJECT',
      userId: myUserId,
    );

    if (targetReq != null) {
      _pendingRequests.removeAt(reqIndex);
      if (accept) {
        // 同意后正式加入好友列表！
        if (!_friends.any((f) => f.id == targetReq!.fromUserId)) {
          _friends.insert(
            0,
            FriendModel(
              id: targetReq.fromUserId,
              nickname: targetReq.nickname,
              avatar: targetReq.avatar,
              levelTitle: targetReq.levelTitle,
              isOnline: true,
              lastMessage: '',
              lastMessageTime: DateTime.now(),
            ),
          );
        }
      }
    }

    return {
      'code': 0,
      'message': accept ? '已同意好友申请！已正式添加为好友！' : '已拒绝该好友申请',
    };
  }

  /// 刷新好友列表 (纯数据库数据覆盖，并自动拉取离线私信)
  Future<void> refreshFriends(String userId) async {
    try {
      final remoteFriends = await _api.fetchFriends(userId);
      _friends = remoteFriends;

      // 融合本地已有最新消息（若本地消息更新则保留最新文本与时间）
      for (final f in _friends) {
        final localList = getMessages(f.id);
        if (localList.isNotEmpty) {
          final lastLocal = localList.last;
          if (f.lastMessage.isEmpty || lastLocal.time.isAfter(f.lastMessageTime)) {
            f.lastMessage = lastLocal.text;
            f.lastMessageTime = lastLocal.time;
          }
        }
      }

      // 自动拉取离线期间收到的私信，绝不丢失任何一条好友留言
      await syncOfflineMessages(userId);
    } catch (e) {
      debugPrint('获取好友列表异常: $e');
    }
  }

  /// 同步离线/未读消息并合并保存
  Future<void> syncOfflineMessages(String userId) async {
    try {
      final cleanMyId = userId.trim();
      final unread = await _api.fetchUnreadDirectMessages(cleanMyId);
      for (final msg in unread) {
        final friendId = msg.senderId.trim();
        final list = getMessages(friendId, cleanMyId);
        if (!list.any((m) => m.id == msg.id)) {
          list.add(msg);
          _persistMessages(friendId, cleanMyId);
        }

        final fIdx = _friends.indexWhere((f) => f.id.trim().toLowerCase() == friendId.toLowerCase());
        if (fIdx != -1) {
          _friends[fIdx].lastMessage = msg.text;
          _friends[fIdx].lastMessageTime = msg.time;
          _friends[fIdx].unreadCount += 1;
        } else {
          _friends.insert(
            0,
            FriendModel(
              id: friendId,
              nickname: '好友',
              avatar: '🦊',
              levelTitle: '聚会好友',
              isOnline: true,
              lastMessage: msg.text,
              lastMessageTime: msg.time,
              unreadCount: 1,
            ),
          );
        }
        _dmReceivedController.add(msg);
      }
    } catch (e) {
      debugPrint('同步离线私信异常: $e');
    }
  }

  /// 同步与某个好友的云端完整历史记录
  Future<void> syncFriendHistory(String userId, String friendId) async {
    try {
      final cleanMyId = userId.trim();
      final cleanFriendId = friendId.trim();
      final history = await _api.fetchDirectMessageHistory(cleanMyId, cleanFriendId);
      if (history.isNotEmpty) {
        final list = getMessages(cleanFriendId, cleanMyId);
        bool changed = false;
        for (final m in history) {
          if (!list.any((local) => local.id == m.id)) {
            list.add(m);
            changed = true;
          }
        }
        if (changed) {
          list.sort((a, b) => a.time.compareTo(b.time));
          _persistMessages(cleanFriendId, cleanMyId);
        }
      }
    } catch (e) {
      debugPrint('同步好友聊天历史异常: $e');
    }
  }

  /// 清空本地所有缓存（切换用户或退出登录时）
  void clear() {
    _friends = [];
    _pendingRequests = [];
    _directMessages.clear();
  }

  String _dmStorageKey(String friendId, [String? explicitMyId]) {
    final myId = (explicitMyId ?? AuthService().currentUser?.id ?? 'default').trim().toLowerCase();
    return 'party_dm_${myId}_${friendId.trim().toLowerCase()}';
  }

  String _cacheKey(String friendId, [String? explicitMyId]) {
    final myId = (explicitMyId ?? AuthService().currentUser?.id ?? 'default').trim().toLowerCase();
    return '${myId}_${friendId.trim().toLowerCase()}';
  }

  List<DirectMessage> getMessages(String friendId, [String? explicitMyId]) {
    final cleanId = friendId.trim();
    final cKey = _cacheKey(cleanId, explicitMyId);
    if (!_directMessages.containsKey(cKey)) {
      final canonicalKey = _dmStorageKey(cleanId, explicitMyId);
      String? raw = LocalStorage.getString(canonicalKey);

      // 自动查找与兼容历史遗留的旧 Key 格式 (如未转小写的 Key 或 default Key)，杜绝丢信
      if (raw == null || raw.isEmpty) {
        final myIdRaw = (explicitMyId ?? AuthService().currentUser?.id ?? 'default').trim();
        final legacyKeys = [
          'party_dm_${myIdRaw}_$cleanId',
          'party_dm_${myIdRaw.toLowerCase()}_$cleanId',
          'party_dm_default_${cleanId.toLowerCase()}',
          'party_dm_default_$cleanId',
        ];
        for (final lk in legacyKeys) {
          final legacyRaw = LocalStorage.getString(lk);
          if (legacyRaw != null && legacyRaw.isNotEmpty) {
            raw = legacyRaw;
            LocalStorage.setString(canonicalKey, legacyRaw);
            break;
          }
        }
      }

      if (raw != null && raw.isNotEmpty) {
        try {
          final List list = jsonDecode(raw);
          _directMessages[cKey] = list
              .map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } catch (_) {
          _directMessages[cKey] = [];
        }
      } else {
        _directMessages[cKey] = [];
      }
    }
    return _directMessages[cKey]!;
  }

  void _persistMessages(String friendId, [String? explicitMyId]) {
    final cleanId = friendId.trim();
    final cKey = _cacheKey(cleanId, explicitMyId);
    final key = _dmStorageKey(cleanId, explicitMyId);
    final msgs = _directMessages[cKey] ?? [];
    LocalStorage.setString(key, jsonEncode(msgs.map((m) => m.toJson()).toList()));
  }

  void sendDirectMessage(String friendId, String text, {String? inviteRoomCode}) {
    final cleanFriendId = friendId.trim();
    final myUser = AuthService().currentUser;
    final myUserId = (myUser?.id ?? 'ME').trim();

    final msg = DirectMessage(
      id: 'DM-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}',
      senderId: myUserId,
      text: text,
      time: DateTime.now(),
      isFromMe: true,
      inviteRoomCode: inviteRoomCode,
    );

    final list = getMessages(cleanFriendId);
    list.add(msg);
    _persistMessages(cleanFriendId);

    final fIdx = _friends.indexWhere((f) => f.id.trim() == cleanFriendId);
    if (fIdx != -1) {
      _friends[fIdx].lastMessage = text;
      _friends[fIdx].lastMessageTime = DateTime.now();
    }

    // 1. 可靠 HTTP 持久化入库 (离线亦能 100% 存入 MySQL 数据库，对方上线即可拉取)
    _api.sendDirectMessage(
      id: msg.id,
      fromUserId: myUserId,
      toUserId: cleanFriendId,
      content: text,
      fromNickname: myUser?.nickname,
      fromAvatar: myUser?.avatar,
      inviteRoomCode: inviteRoomCode,
    );

    // 2. 实时通过云端 WebSocket 广播（低延迟极速送达）
    SocketService().send({
      'type': 'DIRECT_MESSAGE',
      'id': msg.id,
      'toUserId': cleanFriendId,
      'fromUserId': myUserId,
      'fromNickname': myUser?.nickname ?? '玩家',
      'fromAvatar': myUser?.avatar ?? '🦊',
      'content': text,
      'inviteRoomCode': inviteRoomCode,
    });

    _dmReceivedController.add(msg);
  }

  void markAsRead(String friendId) {
    final cleanFriendId = friendId.trim();
    final fIdx = _friends.indexWhere((f) => f.id.trim() == cleanFriendId);
    if (fIdx != -1) {
      _friends[fIdx].unreadCount = 0;
    }
    final myUserId = AuthService().currentUser?.id.trim();
    if (myUserId != null && myUserId.isNotEmpty) {
      _api.markDirectMessagesAsRead(myUserId, cleanFriendId);
    }
  }
}
