import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';

class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();

  FriendProvider() {
    _service.onDirectMessage.listen((_) {
      notifyListeners();
    });
  }

  List<FriendModel> get friends => _service.friends;
  List<FriendRequestModel> get pendingRequests => _service.pendingRequests;
  int get pendingRequestsCount => _service.pendingRequestsCount;
  int get totalUnreadCount => _service.totalUnreadCount;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  List<UserSearchResult> _searchResults = [];
  List<UserSearchResult> get searchResults => _searchResults;

  List<UserSearchResult> _recommendedUsers = [];
  List<UserSearchResult> get recommendedUsers => _recommendedUsers;

  Future<void> loadRecommendedUsers() async {
    _recommendedUsers = await _service.fetchRecommendedUsers();
    notifyListeners();
  }

  List<DirectMessage> getMessages(String friendId) {
    return _service.getMessages(friendId);
  }

  void sendDirectMessage(String friendId, String text, {String? inviteRoomCode}) {
    _service.sendDirectMessage(friendId, text, inviteRoomCode: inviteRoomCode);
    notifyListeners();
  }

  void markAsRead(String friendId) {
    _service.markAsRead(friendId);
    notifyListeners();
  }

  Future<void> syncFriendHistory(String userId, String friendId) async {
    await _service.syncFriendHistory(userId, friendId);
    notifyListeners();
  }

  void addFriend({
    required String id,
    required String nickname,
    required String avatar,
    String levelTitle = '聚会新友',
  }) {
    _service.addFriend(id: id, nickname: nickname, avatar: avatar, levelTitle: levelTitle);
    notifyListeners();
  }

  /// 真实用户搜索（按手机号、昵称、游戏ID/用户号）
  Future<List<UserSearchResult>> searchUsers(String keyword) async {
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _service.searchUsers(keyword);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
    return _searchResults;
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// 发起好友申请
  Future<Map<String, dynamic>> applyFriend({
    required String fromUserId,
    required UserSearchResult targetUser,
  }) async {
    final res = await _service.applyFriend(fromUserId: fromUserId, targetUser: targetUser);
    notifyListeners();
    return res;
  }

  /// 同意或拒绝好友申请
  Future<Map<String, dynamic>> respondRequest({
    required String requestId,
    required bool accept,
    required String myUserId,
  }) async {
    final res = await _service.respondRequest(requestId: requestId, accept: accept, myUserId: myUserId);
    notifyListeners();
    return res;
  }

  /// 刷新申请和好友列表
  Future<void> refresh(String userId) async {
    await _service.refreshRequests(userId);
    await _service.refreshFriends(userId);
    notifyListeners();
  }

  /// 清空本地所有数据
  void clear() {
    _service.clear();
    _searchResults = [];
    _recommendedUsers = [];
    notifyListeners();
  }
}
