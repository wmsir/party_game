// 聚会桌游平台商业化数据模型集合
// 包含商城全品类道具、充值档位、VIP、签到福利、每日任务与排位天梯榜

class ShopGoodsItem {
  final String id;
  final String category; // 'dice_cup' | 'avatar_frame' | 'entrance_banner' | 'pack'
  final String name;
  final int priceCoins;
  final int priceDiamonds;
  final int minVip;
  final String icon;
  final String desc;
  final bool isDefault;

  const ShopGoodsItem({
    required this.id,
    required this.category,
    required this.name,
    required this.priceCoins,
    required this.priceDiamonds,
    this.minVip = 0,
    required this.icon,
    required this.desc,
    this.isDefault = false,
  });

  bool get isFree => priceCoins == 0 && priceDiamonds == 0;
  bool get isDiamondItem => priceDiamonds > 0;

  factory ShopGoodsItem.fromJson(Map<String, dynamic> json) {
    return ShopGoodsItem(
      id: json['id'] ?? '',
      category: json['category'] ?? 'dice_cup',
      name: json['name'] ?? '',
      priceCoins: json['priceCoins'] ?? 0,
      priceDiamonds: json['priceDiamonds'] ?? 0,
      minVip: json['minVip'] ?? 0,
      icon: json['icon'] ?? '🎁',
      desc: json['desc'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class RechargeTierItem {
  final String id;
  final int priceRmb;
  final int diamonds;
  final int coins;
  final int vipExp;
  final bool isFirstDouble;
  final String title;
  final String badge;

  const RechargeTierItem({
    required this.id,
    required this.priceRmb,
    required this.diamonds,
    required this.coins,
    required this.vipExp,
    this.isFirstDouble = true,
    required this.title,
    required this.badge,
  });

  factory RechargeTierItem.fromJson(Map<String, dynamic> json) {
    return RechargeTierItem(
      id: json['id'] ?? '',
      priceRmb: json['priceRmb'] ?? 6,
      diamonds: json['diamonds'] ?? 60,
      coins: json['coins'] ?? 600,
      vipExp: json['vipExp'] ?? 60,
      isFirstDouble: json['isFirstDouble'] ?? true,
      title: json['title'] ?? '',
      badge: json['badge'] ?? '',
    );
  }
}

class SignInDayReward {
  final int day;
  final int coins;
  final int diamonds;
  final String? prop;
  final String? avatarFrame;
  final String title;
  final String? icon;

  const SignInDayReward({
    required this.day,
    required this.coins,
    required this.diamonds,
    this.prop,
    this.avatarFrame,
    required this.title,
    this.icon,
  });

  String get displayIcon {
    if (icon != null && icon!.isNotEmpty) return icon!;
    if (prop == 'PROP_TRUMPET_10') return '📢';
    if (prop == 'GIFT_ROSE_20') return '💐';
    if (prop == 'GIFT_BOX_LEGENDARY' || day == 7) return '👑';
    if (diamonds > 0) return '💎';
    return '🪙';
  }

  factory SignInDayReward.fromJson(Map<String, dynamic> json) {
    final dayNum = json['day'] ?? 1;
    final propVal = json['prop']?.toString();
    final diamondsVal = json['diamonds'] ?? 0;
    return SignInDayReward(
      day: dayNum,
      coins: json['coins'] ?? 0,
      diamonds: diamondsVal,
      prop: propVal,
      avatarFrame: json['avatarFrame'] ?? (dayNum == 7 ? 'FRAME_GOLD' : null),
      title: json['desc'] ?? json['title'] ?? '',
      icon: json['icon'],
    );
  }
}

class SignInStatus {
  final List<SignInDayReward> calendar;
  final int streak;
  final bool isSignedToday;
  final int currentDay;

  const SignInStatus({
    required this.calendar,
    required this.streak,
    required this.isSignedToday,
    required this.currentDay,
  });

  factory SignInStatus.fromJson(Map<String, dynamic> json) {
    List<SignInDayReward> list = [];
    final rawList = json['schedule'] ?? json['calendar'];
    if (rawList is List) {
      list = rawList.map((c) => SignInDayReward.fromJson(Map<String, dynamic>.from(c as Map))).toList();
    }
    final isSigned = (json['hasSignedInToday'] ?? json['isSignedToday'] ?? false) as bool;
    final streakVal = json['streak'] ?? 0;
    final currentDayVal = json['currentDayInCycle'] ?? json['currentDay'] ?? ((streakVal % 7) + 1);

    return SignInStatus(
      calendar: list,
      streak: streakVal,
      isSignedToday: isSigned,
      currentDay: currentDayVal,
    );
  }
}

class DailyTaskItem {
  final String id;
  final String title;
  final int target;
  final int current;
  final int rewardCoins;
  final int rewardDiamonds;
  final bool isClaimed;

  const DailyTaskItem({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
    required this.rewardCoins,
    required this.rewardDiamonds,
    required this.isClaimed,
  });

  bool get isCompleted => current >= target;
  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

  factory DailyTaskItem.fromJson(Map<String, dynamic> json) {
    return DailyTaskItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      target: json['target'] ?? 1,
      current: json['current'] ?? 0,
      rewardCoins: json['rewardCoins'] ?? 0,
      rewardDiamonds: json['rewardDiamonds'] ?? 0,
      isClaimed: json['isClaimed'] ?? false,
    );
  }
}

class RankSettlementResult {
  final bool isWin;
  final String gameType;
  final int scoreDelta;
  final int currentScore;
  final String oldTier;
  final String currentTier;
  final bool isTierChanged;
  final int coinsReward;

  const RankSettlementResult({
    required this.isWin,
    required this.gameType,
    required this.scoreDelta,
    required this.currentScore,
    required this.oldTier,
    required this.currentTier,
    required this.isTierChanged,
    required this.coinsReward,
  });

  factory RankSettlementResult.fromJson(Map<String, dynamic> json) {
    return RankSettlementResult(
      isWin: json['isWin'] ?? false,
      gameType: json['gameType'] ?? 'liars_dice',
      scoreDelta: json['scoreDelta'] ?? 0,
      currentScore: json['currentScore'] ?? 1200,
      oldTier: json['oldTier'] ?? '黄金II',
      currentTier: json['currentTier'] ?? '黄金II',
      isTierChanged: json['isTierChanged'] ?? false,
      coinsReward: json['coinsReward'] ?? 0,
    );
  }
}

class LeaderboardItem {
  final int rank;
  final String id;
  final String nickname;
  final String avatar;
  final String avatarFrame;
  final int vipLevel;
  final int rankScore;
  final String rankTier;
  final int winCount;
  final int totalGames;
  final int diamonds;
  final int coins;

  const LeaderboardItem({
    required this.rank,
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.avatarFrame,
    required this.vipLevel,
    this.rankScore = 0,
    this.rankTier = '暂无段位',
    this.winCount = 0,
    this.totalGames = 0,
    this.diamonds = 0,
    this.coins = 0,
  });

  double get winRate => totalGames > 0 ? (winCount / totalGames) * 100 : 0.0;

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      rank: json['rank'] ?? 1,
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '玩家',
      avatar: json['avatar'] ?? '🦊',
      avatarFrame: json['avatarFrame'] ?? 'FRAME_DEFAULT',
      vipLevel: json['vipLevel'] ?? 0,
      rankScore: json['rankScore'] ?? 0,
      rankTier: json['rankTier'] ?? '暂无段位',
      winCount: json['winCount'] ?? 0,
      totalGames: json['totalGames'] ?? 0,
      diamonds: json['diamonds'] ?? 0,
      coins: json['coins'] ?? 0,
    );
  }
}
