import '../../core/contracts/game_auditor.dart';
import '../../core/models/game_action.dart';
import '../domain/take6_state.dart';

/// 谁是牛头王 - 本地单机仲裁器 (实现 IGameAuditor)
class Take6LocalAuditor implements IGameAuditor<Take6State> {
  @override
  bool validateAction(Take6State currentState, GameAction action) {
    switch (action.actionType) {
      case 'PICK_CARD':
        if (currentState.phase != Take6Phase.selectingCard) return false;
        final cardNum = action.payload['cardNumber'] as int?;
        if (cardNum == null) return false;
        final hand = currentState.playerHands[action.playerId];
        return hand?.any((c) => c.number == cardNum) ?? false;

      case 'CHOOSE_ROW':
        if (currentState.phase != Take6Phase.awaitingRowChoice) return false;
        if (currentState.playerChoosingRowId != action.playerId) return false;
        final rowIndex = action.payload['rowIndex'] as int?;
        return rowIndex != null && rowIndex >= 0 && rowIndex < currentState.rows.length;

      default:
        return false;
    }
  }

  @override
  dynamic auditResolution(Take6State currentState, GameAction action) {
    // 本地引擎直接裁决，返回合法通过标志
    return {'valid': true};
  }
}
