import 'dart:async';
import '../../core/contracts/game_channel.dart';
import '../../core/models/game_action.dart';
import '../domain/take6_ai.dart';
import '../domain/take6_state.dart';

/// 谁是牛头王 - 本地 AI 陪玩信道 (实现 IGameChannel)
/// 负责模拟其他 AI 玩家在收到状态变更时的并发异步思考与动作派发
class Take6AiChannel implements IGameChannel {
  final StreamController<GameAction> _actionController = StreamController<GameAction>.broadcast();
  Take6State? _latestState;

  @override
  Stream<GameAction> get actionStream => _actionController.stream;

  @override
  Future<void> initialize() async {}

  @override
  void broadcastState(dynamic gameState) {
    if (gameState is! Take6State) return;
    _latestState = gameState;

    // 当处于选牌阶段时，驱动所有尚未选牌的 AI 玩家执行思考
    if (gameState.phase == Take6Phase.selectingCard) {
      _triggerAiPickCards(gameState);
    } else if (gameState.phase == Take6Phase.awaitingRowChoice) {
      _triggerAiChooseRow(gameState);
    }
  }

  final Set<String> _pendingAiDecisions = {};

  void _triggerAiPickCards(Take6State state) {
    for (int i = 0; i < state.players.length; i++) {
      final p = state.players[i];
      if (!p.isAi) continue;
      // 已经选过或已有计时器在思考中则略过
      if (state.selectedCards[p.id] != null) continue;
      if (_pendingAiDecisions.contains(p.id)) continue;

      final hand = state.playerHands[p.id] ?? [];
      if (hand.isEmpty) continue;

      _pendingAiDecisions.add(p.id);
      // 优雅错开各个 AI 思考时间 (如 700ms, 1200ms, 1700ms)，避免开局并发扎堆冲击
      final delayMs = 600 + i * 450 + (p.id.hashCode.abs() % 250);
      Future.delayed(Duration(milliseconds: delayMs), () {
        _pendingAiDecisions.remove(p.id);
        if (_latestState?.phase != Take6Phase.selectingCard) return;
        final chosen = Take6Ai.decideCardToPlay(
          aiPlayerId: p.id,
          hand: hand,
          rows: state.rows,
          personality: p.aiPersonality,
        );

        dispatchAction(GameAction(
          actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch}-${p.id}',
          playerId: p.id,
          actionType: 'PICK_CARD',
          payload: {'cardNumber': chosen.number},
        ));
      });
    }
  }

  void _triggerAiChooseRow(Take6State state) {
    final aiId = state.playerChoosingRowId;
    if (aiId == null) return;
    final aiPlayer = state.players.firstWhere((p) => p.id == aiId, orElse: () => state.players.first);
    if (!aiPlayer.isAi) return;
    if (_pendingAiDecisions.contains(aiId)) return;

    _pendingAiDecisions.add(aiId);
    Future.delayed(const Duration(milliseconds: 600), () {
      _pendingAiDecisions.remove(aiId);
      if (_latestState?.phase != Take6Phase.awaitingRowChoice) return;
      final bestRow = Take6Ai.decideRowToTake(rows: state.rows);

      dispatchAction(GameAction(
        actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch}-$aiId',
        playerId: aiId,
        actionType: 'CHOOSE_ROW',
        payload: {'rowIndex': bestRow},
      ));
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
