import '../models/game_player.dart';

/// 游戏奖励与权益结算回调桥梁
/// 核心解耦：
/// 1. 在门店会员系统中：赢家赢取会员积分、赠饮券、茶歇买单抵用券；
/// 2. 在独立单机系统中：赢家累积单机本地筹码、成就徽章与连胜记录。
abstract class IGameRewardBridge {
  /// 当某一局结束时结算
  Future<void> onRoundSettlement({
    required String gameCode,
    required String winnerId,
    required List<GamePlayer> allPlayers,
    required Map<String, dynamic> matchDetails,
  });

  /// 当整场对局决出最终胜负时结算
  Future<void> onMatchFinished({
    required String gameCode,
    required List<GamePlayer> rankedPlayers,
    required Map<String, dynamic> summary,
  });
}
