class FriendModel {
  final String id;
  final String nickname;
  String? remark;
  final String avatar;
  final String levelTitle;
  bool isOnline;
  String? currentRoomCode;
  String lastMessage;
  DateTime lastMessageTime;
  int unreadCount;
  int vipLevel;
  String rankTier;
  int rankScore;
  int winCount;
  int totalGames;
  int coins;
  int diamonds;
  String chatTextColor;

  FriendModel({
    required this.id,
    required this.nickname,
    this.remark,
    required this.avatar,
    this.levelTitle = '聚会达人',
    this.isOnline = false,
    this.currentRoomCode,
    this.lastMessage = '',
    DateTime? lastMessageTime,
    this.unreadCount = 0,
    this.vipLevel = 0,
    this.rankTier = '暂无段位',
    this.rankScore = 0,
    this.winCount = 0,
    this.totalGames = 0,
    this.coins = 0,
    this.diamonds = 0,
    this.chatTextColor = 'COLOR_DEFAULT',
  }) : lastMessageTime = lastMessageTime ?? DateTime.now();

  String get cleanId => id.replaceAll('-', '');
  String get displayNickname => (remark != null && remark!.trim().isNotEmpty) ? '$remark ($nickname)' : nickname;
  double get winRate => totalGames > 0 ? (winCount / totalGames) * 100 : 0.0;

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: (json['id'] ?? json['friendId'])?.toString() ?? '',
      nickname: (json['nickname'] ?? json['friendNickname'])?.toString() ?? '好友',
      remark: json['remark']?.toString(),
      avatar: json['avatar']?.toString() ?? '🦊',
      levelTitle: json['levelTitle']?.toString() ?? '聚会达人',
      isOnline: json['isOnline'] == true,
      currentRoomCode: json['currentRoomCode']?.toString(),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: json['lastMessageTimestamp'] is num
          ? DateTime.fromMillisecondsSinceEpoch((json['lastMessageTimestamp'] as num).toInt())
          : (json['lastMessageTime'] != null
              ? DateTime.tryParse(json['lastMessageTime'].toString()) ?? DateTime.now()
              : DateTime.now()),
      unreadCount: json['unreadCount'] is num ? (json['unreadCount'] as num).toInt() : 0,
      vipLevel: (json['vipLevel'] is num) ? (json['vipLevel'] as num).toInt() : 0,
      rankTier: json['rankTier']?.toString() ?? '暂无段位',
      rankScore: (json['rankScore'] is num) ? (json['rankScore'] as num).toInt() : 0,
      winCount: (json['winCount'] is num) ? (json['winCount'] as num).toInt() : 0,
      totalGames: (json['totalGames'] is num) ? (json['totalGames'] as num).toInt() : 0,
      coins: (json['coins'] is num) ? (json['coins'] as num).toInt() : 0,
      diamonds: (json['diamonds'] is num) ? (json['diamonds'] as num).toInt() : 0,
      chatTextColor: json['chatTextColor']?.toString() ?? 'COLOR_DEFAULT',
    );
  }

  static List<FriendModel> getSampleFriends() {
    return [];
  }
}

/// 真实用户搜索结果卡片
class UserSearchResult {
  final String id;
  final String nickname;
  final String username;
  final String avatar;
  final String? phone;
  final String levelTitle;
  final int coins;
  final bool isOnline;

  UserSearchResult({
    required this.id,
    required this.nickname,
    required this.username,
    required this.avatar,
    this.phone,
    this.levelTitle = '聚会新友',
    this.coins = 0,
    this.isOnline = false,
  });

  String get cleanId => id.replaceAll('-', '');

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? json['username']?.toString() ?? '玩家',
      username: json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '🦊',
      phone: json['phone']?.toString(),
      levelTitle: json['levelTitle']?.toString() ?? '聚会新友',
      coins: (json['coins'] is num) ? (json['coins'] as num).toInt() : 0,
      isOnline: json['isOnline'] == true,
    );
  }
}

/// 好友申请记录模型
class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String nickname;
  final String avatar;
  final String levelTitle;
  final String? phone;
  final String status; // 'PENDING' | 'ACCEPTED' | 'REJECTED'
  final DateTime createdAt;

  String get cleanFromUserId => fromUserId.replaceAll('-', '');
  String get cleanToUserId => toUserId.replaceAll('-', '');

  FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.nickname,
    required this.avatar,
    this.levelTitle = '聚会新星',
    this.phone,
    this.status = 'PENDING',
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    final fromUser = json['fromUser'] as Map<String, dynamic>?;
    return FriendRequestModel(
      id: json['id']?.toString() ?? '',
      fromUserId: json['fromUserId']?.toString() ?? '',
      toUserId: json['toUserId']?.toString() ?? '',
      nickname: fromUser?['nickname']?.toString() ?? '聚会玩家',
      avatar: fromUser?['avatar']?.toString() ?? '🤠',
      levelTitle: fromUser?['levelTitle']?.toString() ?? '聚会达人',
      phone: fromUser?['phone']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DirectMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime time;
  final bool isFromMe;
  final String? inviteRoomCode;

  DirectMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.time,
    required this.isFromMe,
    this.inviteRoomCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'time': time.toIso8601String(),
    'isFromMe': isFromMe,
    'inviteRoomCode': inviteRoomCode,
  };

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: json['id']?.toString() ?? '',
    senderId: json['senderId']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    time: json['time'] != null ? (DateTime.tryParse(json['time']) ?? DateTime.now()) : DateTime.now(),
    isFromMe: json['isFromMe'] == true,
    inviteRoomCode: json['inviteRoomCode']?.toString(),
  );
}
