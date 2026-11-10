import 'dart:async';
import '../../core/contracts/game_channel.dart';
import '../../core/models/game_action.dart';
import '../domain/dice_ai.dart';
import '../domain/dice_state.dart';

/// 大话骰 - 本地 AI 陪玩信道 (实现 IGameChannel)
/// 负责在轮到 AI 玩家出价时触发智能博弈推理，并将决策派发到动作流中
class DiceAiChannel implements IGameChannel {
  final StreamController<GameAction> _actionController = StreamController<GameAction>.broadcast();
  DiceState? _latestState;

  @override
  Stream<GameAction> get actionStream => _actionController.stream;

  @override
  Future<void> initialize() async {}

  @override
  void broadcastState(dynamic gameState) {
    if (gameState is! DiceState) return;
    _latestState = gameState;

    // 当处于叫点阶段且当前出牌者是 AI 时，驱动 AI 思考
    if (gameState.phase == DicePhase.bidding) {
      _triggerCurrentAiIfNeeded(gameState);
    }
  }

  void _triggerCurrentAiIfNeeded(DiceState state) {
    final current = state.currentPlayer;
    if (!current.isAi) return;

    final cup = state.playerCups[current.id];
    if (cup == null) return;

    // 随机 700~1400ms 模拟真人摇骰沉思与博弈心理
    Future.delayed(Duration(milliseconds: 700 + (DateTime.now().millisecond % 600)), () {
      if (_latestState?.phase != DicePhase.bidding) return;
      if (_latestState?.currentPlayer.id != current.id) return;

      final decision = DiceAi.decideNextAction(
        aiPlayerId: current.id,
        myCup: cup,
        state: state,
        personality: current.aiPersonality,
      );

      if (decision.type == AiDecisionType.challenge) {
        dispatchAction(GameAction(
          actionId: 'ACT-CHALLENGE-${DateTime.now().millisecondsSinceEpoch}-${current.id}',
          playerId: current.id,
          actionType: 'CHALLENGE',
          payload: {},
        ));
      } else {
        dispatchAction(GameAction(
          actionId: 'ACT-BID-${DateTime.now().millisecondsSinceEpoch}-${current.id}',
          playerId: current.id,
          actionType: 'BID',
          payload: {
            'count': decision.count,
            'face': decision.face,
            'isPure': decision.isPure,
          },
        ));
      }
    });
  }

  @override
  void dispatchAction(GameAction action) {
    _actionController.add(action);
  }

  @override
  Future<void> dispose() async {
    await _actionController.close();
  }
}
