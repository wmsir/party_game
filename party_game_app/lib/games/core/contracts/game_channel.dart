import 'dart:async';
import '../models/game_action.dart';

/// 游戏信道抽象端口 (Ports & Adapters)
/// 解耦单机本地 AI、同屏轮流玩 (Pass-and-Play) 与云端联机通信
abstract class IGameChannel {
  /// 初始化信道
  Future<void> initialize();

  /// 玩家动作流 (供引擎消费玩家与机器人的指令)
  Stream<GameAction> get actionStream;

  /// 向信道广播当前最新的游戏状态或事件 (供渲染层或远端接收)
  void broadcastState(dynamic gameState);

  /// 派发玩家动作给信道
  void dispatchAction(GameAction action);

  /// 关闭信道释放资源
  Future<void> dispose();
}
