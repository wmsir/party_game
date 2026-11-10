/// 通用游戏玩家实体 (纯 Dart 模型，零 UI 依赖)
class GamePlayer {
  final String id;
  final String name;
  final String avatar;
  final bool isAi;
  final String aiPersonality; // 'BALANCED', 'AGGRESSIVE', 'CONSERVATIVE', 'BLUFF_MASTER'
  int score; // 积分 / 惩罚分 / 金币
  bool isReady;
  bool isEliminated;
  Map<String, dynamic> extraData;

  GamePlayer({
    required this.id,
    required this.name,
    this.avatar = '',
    this.isAi = false,
    this.aiPersonality = 'BALANCED',
    this.score = 0,
    this.isReady = false,
    this.isEliminated = false,
    Map<String, dynamic>? extraData,
  }) : extraData = extraData ?? {};

  GamePlayer copyWith({
    String? id,
    String? name,
    String? avatar,
    bool? isAi,
    String? aiPersonality,
    int? score,
    bool? isReady,
    bool? isEliminated,
    Map<String, dynamic>? extraData,
  }) {
    return GamePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      isAi: isAi ?? this.isAi,
      aiPersonality: aiPersonality ?? this.aiPersonality,
      score: score ?? this.score,
      isReady: isReady ?? this.isReady,
      isEliminated: isEliminated ?? this.isEliminated,
      extraData: extraData ?? Map<String, dynamic>.from(this.extraData),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'isAi': isAi,
    'aiPersonality': aiPersonality,
    'score': score,
    'isReady': isReady,
    'isEliminated': isEliminated,
    'extraData': extraData,
  };

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
    id: json['id'] as String,
    name: json['name'] as String,
    avatar: json['avatar'] as String? ?? '',
    isAi: json['isAi'] as bool? ?? false,
    aiPersonality: json['aiPersonality'] as String? ?? 'BALANCED',
    score: json['score'] as int? ?? 0,
    isReady: json['isReady'] as bool? ?? ((json['isHost'] == true) || (json['isAi'] == true)),
    isEliminated: json['isEliminated'] as bool? ?? false,
    extraData: json['extraData'] as Map<String, dynamic>? ?? {},
  );
}
