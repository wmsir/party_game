import '../models/game_action.dart';

/// 裁决与规则仲裁接口
/// 无论是单机本地运行还是联机运行，规则仲裁均统一通过此端口判定
abstract class IGameAuditor<TState> {
  /// 校验某一动作在当前状态下是否合法
  bool validateAction(TState currentState, GameAction action);

  /// 裁决一次冲突或开牌/开盅结果
  dynamic auditResolution(TState currentState, GameAction action);
}
