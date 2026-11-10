/// 游戏状态抽象基类
abstract class GameBaseState {
  final String gameCode;
  final String roundId;
  final DateTime createdAt;

  GameBaseState({
    required this.gameCode,
    required this.roundId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 状态深拷贝机制
  GameBaseState copy();

  /// 状态序列化
  Map<String, dynamic> toJson();
}
