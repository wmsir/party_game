import '../../core/contracts/game_reward_bridge.dart';
import '../../core/models/game_player.dart';

/// 门店会员奖励与权益结算桥梁 (Store Member Reward Bridge)
/// 将游戏胜利结算对接为商户会员积分、饮品券与茶歇消费折扣
class StoreMemberRewardBridge implements IGameRewardBridge {
  final String currentMemberId;
  final Function(int pointsEarned, String rewardDesc)? onRewardGranted;

  StoreMemberRewardBridge({
    required this.currentMemberId,
    this.onRewardGranted,
  });

  @override
  Future<void> onRoundSettlement({
    required String gameCode,
    required String winnerId,
    required List<GamePlayer> allPlayers,
    required Map<String, dynamic> matchDetails,
  }) async {
    // 若获胜者是当前会员本人，发放门店对局奖励
    if (winnerId == currentMemberId) {
      const points = 20;
      const desc = '赢得小局胜利，获得 20 门店积分';
      if (onRewardGranted != null) {
        onRewardGranted!(points, desc);
      }
    }
  }

  @override
  Future<void> onMatchFinished({
    required String gameCode,
    required List<GamePlayer> rankedPlayers,
    required Map<String, dynamic> summary,
  }) async {
    if (rankedPlayers.isNotEmpty && rankedPlayers.first.id == currentMemberId) {
      const points = 100;
      const desc = '🏆 荣登全场榜首！获得 100 会员积分与【茶水吧台专属赠饮券】一张！';
      if (onRewardGranted != null) {
        onRewardGranted!(points, desc);
      }
    }
  }
}
