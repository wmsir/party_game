class UserModel {
  final String id;
  String username;
  String nickname;
  String phone;
  String avatar;
  String levelTitle;
  int coins;
  int diamonds;
  int vipLevel;
  int vipExp;
  int rankScore;
  String rankTier;
  int stamina;
  int winCount;
  int totalGames;
  bool isGuest;
  String token;
  String diceCupSkin;
  String avatarFrame;
  String entranceBanner;
  String chatTextColor;
  List<String> inventory;
  Map<String, int> itemQuantities;
  String lastSignDate;
  int signInStreak;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    this.phone = '',
    this.avatar = '🦊',
    this.levelTitle = '聚会萌新',
    this.coins = 0,
    this.diamonds = 0,
    this.vipLevel = 0,
    this.vipExp = 0,
    this.rankScore = 0,
    this.rankTier = '暂无段位',
    this.stamina = 100,
    this.winCount = 0,
    this.totalGames = 0,
    this.isGuest = false,
    this.token = '',
    this.diceCupSkin = 'CLASSIC_GOLD',
    this.avatarFrame = 'FRAME_DEFAULT',
    this.entranceBanner = 'BANNER_DEFAULT',
    this.chatTextColor = 'COLOR_DEFAULT',
    List<String>? inventory,
    Map<String, int>? itemQuantities,
    this.lastSignDate = '',
    this.signInStreak = 0,
  })  : inventory = inventory ?? ['CLASSIC_GOLD', 'FRAME_DEFAULT', 'BANNER_DEFAULT'],
        itemQuantities = itemQuantities ?? {};

  String get cleanId => id.replaceAll('-', '');

  double get winRate => totalGames > 0 ? (winCount / totalGames) * 100 : 0.0;

  bool ownsItem(String itemId) => inventory.contains(itemId);

  int getItemCount(String itemId) => itemQuantities[itemId] ?? 0;

  void addItemCount(String itemId, int count) {
    itemQuantities[itemId] = (itemQuantities[itemId] ?? 0) + count;
    if (!inventory.contains(itemId)) {
      inventory.add(itemId);
    }
  }

  bool consumeItem(String itemId, int count) {
    final current = itemQuantities[itemId] ?? 0;
    if (current >= count) {
      itemQuantities[itemId] = current - count;
      return true;
    }
    return false;
  }

  factory UserModel.guest() {
    final randId = DateTime.now().millisecondsSinceEpoch % 10000;
    return UserModel(
      id: 'GUEST$randId',
      username: 'guest_$randId',
      nickname: '聚会客官_$randId',
      phone: '',
      avatar: ['🦊', '🐼', '🦁', '🐯', '🐰', '🦄', '🐨', '🐺'][randId % 8],
      levelTitle: '初入江湖',
      coins: 0,
      diamonds: 0,
      vipLevel: 0,
      vipExp: 0,
      rankScore: 0,
      rankTier: '暂无段位',
      stamina: 100,
      winCount: 0,
      totalGames: 0,
      isGuest: true,
      token: 'guest_token_$randId',
      diceCupSkin: 'CLASSIC_GOLD',
      avatarFrame: 'FRAME_DEFAULT',
      entranceBanner: 'BANNER_DEFAULT',
      chatTextColor: 'COLOR_DEFAULT',
      inventory: ['CLASSIC_GOLD', 'FRAME_DEFAULT', 'BANNER_DEFAULT', 'COLOR_DEFAULT'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
    'phone': phone,
    'avatar': avatar,
    'levelTitle': levelTitle,
    'coins': coins,
    'diamonds': diamonds,
    'vipLevel': vipLevel,
    'vipExp': vipExp,
    'rankScore': rankScore,
    'rankTier': rankTier,
    'stamina': stamina,
    'winCount': winCount,
    'totalGames': totalGames,
    'isGuest': isGuest,
    'token': token,
    'diceCupSkin': diceCupSkin,
    'avatarFrame': avatarFrame,
    'entranceBanner': entranceBanner,
    'chatTextColor': chatTextColor,
    'inventory': inventory,
    'itemQuantities': itemQuantities,
    'lastSignDate': lastSignDate,
    'signInStreak': signInStreak,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> inv = [];
    if (json['inventory'] is List) {
      inv = (json['inventory'] as List).map((e) => e.toString()).toList();
    }
    if (inv.isEmpty) {
      inv = ['CLASSIC_GOLD', 'FRAME_DEFAULT', 'BANNER_DEFAULT', 'COLOR_DEFAULT'];
    }

    Map<String, int> parsedQuantities = {};
    if (json['itemQuantities'] is Map) {
      (json['itemQuantities'] as Map).forEach((k, v) {
        if (v is num) parsedQuantities[k.toString()] = v.toInt();
      });
    }

    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? json['username'] ?? '玩家',
      phone: json['phone'] ?? '',
      avatar: json['avatar'] ?? '🦊',
      levelTitle: json['levelTitle'] ?? '聚会萌新',
      coins: json['coins'] ?? 0,
      diamonds: json['diamonds'] ?? 0,
      vipLevel: json['vipLevel'] ?? 0,
      vipExp: json['vipExp'] ?? 0,
      rankScore: json['rankScore'] ?? 0,
      rankTier: json['rankTier'] ?? '暂无段位',
      stamina: json['stamina'] ?? 100,
      winCount: json['winCount'] ?? 0,
      totalGames: json['totalGames'] ?? 0,
      isGuest: json['isGuest'] ?? false,
      token: json['token'] ?? '',
      diceCupSkin: json['diceCupSkin'] ?? 'CLASSIC_GOLD',
      avatarFrame: json['avatarFrame'] ?? 'FRAME_DEFAULT',
      entranceBanner: json['entranceBanner'] ?? 'BANNER_DEFAULT',
      chatTextColor: json['chatTextColor'] ?? 'COLOR_DEFAULT',
      inventory: inv,
      itemQuantities: parsedQuantities,
      lastSignDate: json['lastSignDate'] ?? '',
      signInStreak: json['signInStreak'] ?? 0,
    );
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? nickname,
    String? phone,
    String? avatar,
    String? levelTitle,
    int? coins,
    int? diamonds,
    int? vipLevel,
    int? vipExp,
    int? rankScore,
    String? rankTier,
    int? stamina,
    int? winCount,
    int? totalGames,
    bool? isGuest,
    String? token,
    String? diceCupSkin,
    String? avatarFrame,
    String? entranceBanner,
    String? chatTextColor,
    List<String>? inventory,
    Map<String, int>? itemQuantities,
    String? lastSignDate,
    int? signInStreak,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      levelTitle: levelTitle ?? this.levelTitle,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      vipLevel: vipLevel ?? this.vipLevel,
      vipExp: vipExp ?? this.vipExp,
      rankScore: rankScore ?? this.rankScore,
      rankTier: rankTier ?? this.rankTier,
      stamina: stamina ?? this.stamina,
      winCount: winCount ?? this.winCount,
      totalGames: totalGames ?? this.totalGames,
      isGuest: isGuest ?? this.isGuest,
      token: token ?? this.token,
      diceCupSkin: diceCupSkin ?? this.diceCupSkin,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      entranceBanner: entranceBanner ?? this.entranceBanner,
      chatTextColor: chatTextColor ?? this.chatTextColor,
      inventory: inventory ?? List.from(this.inventory),
      itemQuantities: itemQuantities ?? Map.from(this.itemQuantities),
      lastSignDate: lastSignDate ?? this.lastSignDate,
      signInStreak: signInStreak ?? this.signInStreak,
    );
  }
}
