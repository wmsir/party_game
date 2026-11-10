/// 玩家或系统的游戏动作与事件 (Action Event)
class GameAction {
  final String actionId;
  final String playerId;
  final String actionType; // 如: 'PLAY_CARD', 'PICK_ROW', 'SHAKE_DICE', 'BID_DICE', 'CHALLENGE_DICE'
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  GameAction({
    required this.actionId,
    required this.playerId,
    required this.actionType,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'actionId': actionId,
    'playerId': playerId,
    'actionType': actionType,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GameAction.fromJson(Map<String, dynamic> json) => GameAction(
    actionId: json['actionId'] as String,
    playerId: json['playerId'] as String,
    actionType: json['actionType'] as String,
    payload: json['payload'] as Map<String, dynamic>? ?? {},
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// 动作执行后的反馈结果
class GameActionResult {
  final bool isSuccess;
  final String message;
  final dynamic details;

  const GameActionResult({
    required this.isSuccess,
    this.message = '',
    this.details,
  });

  static const success = GameActionResult(isSuccess: true, message: 'OK');
  static GameActionResult fail(String msg) => GameActionResult(isSuccess: false, message: msg);
}
