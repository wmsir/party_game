import 'dart:async';
import '../../core/contracts/game_channel.dart';
import '../../core/models/game_action.dart';

/// 聚会同屏轮传信道 (Pass & Play Channel)
/// 专为线下聚会多位真人共用一台手机/平板同屏对战设计
class PassAndPlayChannel implements IGameChannel {
  final StreamController<GameAction> _actionController = StreamController<GameAction>.broadcast();
  dynamic _latestState;
  dynamic get latestState => _latestState;

  @override
  Stream<GameAction> get actionStream => _actionController.stream;

  @override
  Future<void> initialize() async {}

  @override
  void broadcastState(dynamic gameState) {
    _latestState = gameState;
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
