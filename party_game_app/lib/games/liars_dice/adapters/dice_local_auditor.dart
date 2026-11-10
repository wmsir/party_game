import '../../core/contracts/game_auditor.dart';
import '../../core/models/game_action.dart';
import '../domain/dice_rules_engine.dart';
import '../domain/dice_state.dart';

/// 本地裁决仲裁器 (Local Dice Auditor Adapter)
/// 负责校验玩家操作合法性、判断胜负归属与规则裁决
class DiceLocalAuditor implements IGameAuditor<DiceState> {
  final DiceRulesEngine engine;

  DiceLocalAuditor({required this.engine});

  @override
  bool validateAction(DiceState currentState, GameAction action) {
    if (action.actionType == 'BID') {
      if (currentState.phase != DicePhase.bidding) return false;
      if (currentState.currentPlayer.id != action.playerId) return false;

      final count = action.payload['count'] as int?;
      final face = action.payload['face'] as int?;
      if (count == null || face == null || face < 1 || face > 6) return false;
      return true;
    } else if (action.actionType == 'CHALLENGE') {
      if (currentState.phase != DicePhase.bidding) return false;
      if (currentState.currentPlayer.id != action.playerId) return false;
      if (currentState.currentBid == null) return false;
      return true;
    }
    return false;
  }

  @override
  dynamic auditResolution(DiceState currentState, GameAction action) {
    return {
      'game': 'liars_dice',
      'isGameOver': currentState.phase == DicePhase.roundOver,
      'lastResult': currentState.lastResult?.toJson(),
      'chipsScore': currentState.chipsScore,
    };
  }

  /// 供界面或信道直接执行动作并获取结果
  GameActionResult executeAction(GameAction action) {
    if (!validateAction(engine.state, action)) {
      return GameActionResult.fail('尚未轮到您操作或当前不在叫点阶段');
    }

    if (action.actionType == 'BID') {
      final count = action.payload['count'] as int;
      final face = action.payload['face'] as int;
      final isPure = action.payload['isPure'] as bool? ?? false;

      final success = engine.playerBid(
        playerId: action.playerId,
        count: count,
        face: face,
        isPure: isPure,
      );

      if (success) {
        return GameActionResult.success;
      } else {
        return GameActionResult.fail('叫点必须严格高于前一位玩家（点数或数量更大）');
      }
    } else if (action.actionType == 'CHALLENGE') {
      final success = engine.playerChallenge(action.playerId);
      if (success) {
        return GameActionResult.success;
      } else {
        return GameActionResult.fail('开盅失败');
      }
    }

    return GameActionResult.fail('不支持的操作类型');
  }
}
