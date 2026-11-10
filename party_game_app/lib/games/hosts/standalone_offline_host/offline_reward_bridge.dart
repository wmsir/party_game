import '../../core/contracts/game_reward_bridge.dart';
import '../../core/models/game_player.dart';

/// 独立单机奖励与成就桥梁 (Standalone Offline Reward Bridge)
/// 维护本地连胜次数、金币筹码池、离线徽章成就
class OfflineRewardBridge implements IGameRewardBridge {
  static int localChips = 500;
  static int winStreak = 0;
  static int totalMatchesWon = 0;
  static final Set<String> unlockedAchievements = {};

  final String localPlayerId;
  final Function(String achievementName)? onAchievementUnlocked;

  OfflineRewardBridge({
    required this.localPlayerId,
    this.onAchievementUnlocked,
  });

  @override
  Future<void> onRoundSettlement({
    required String gameCode,
    required String winnerId,
    required List<GamePlayer> allPlayers,
    required Map<String, dynamic> matchDetails,
  }) async {
    if (winnerId == localPlayerId) {
      localChips += 50;
      winStreak++;
      if (winStreak == 3 && !unlockedAchievements.contains('连胜先锋')) {
        _unlock('连胜先锋 (离线 3 连胜)');
      } else if (winStreak == 5 && !unlockedAchievements.contains('不败战神')) {
        _unlock('不败战神 (离线 5 连胜)');
      }
    } else {
      winStreak = 0;
      localChips = (localChips - 20).clamp(0, 999999);
    }
  }

  @override
  Future<void> onMatchFinished({
    required String gameCode,
    required List<GamePlayer> rankedPlayers,
    required Map<String, dynamic> summary,
  }) async {
    if (rankedPlayers.isNotEmpty && rankedPlayers.first.id == localPlayerId) {
      totalMatchesWon++;
      localChips += 200;

      if (gameCode == 'take6' && !unlockedAchievements.contains('避牛大师')) {
        _unlock('避牛大师 (谁是牛头王夺冠)');
      } else if (gameCode == 'liars_dice' && !unlockedAchievements.contains('赌神之眼')) {
        _unlock('赌神之眼 (大话骰夺冠)');
      }
    }
  }

  void _unlock(String badgeName) {
    unlockedAchievements.add(badgeName);
    if (onAchievementUnlocked != null) {
      onAchievementUnlocked!(badgeName);
    }
  }
}
