/// 宿主环境上下文接口
/// 允许游戏包向宿主请求声音播放、触觉震动以及读取宿主展示标识
abstract class IGameHostContext {
  /// 宿主应用名称标识 (如: '海马智慧门店', '谁是牛头王独立版', '骰子街单机版')
  String get appName;

  /// 宿主类型标识: 'STORE_MEMBER' (门店会员联机系统) 或 'STANDALONE_OFFLINE' (独立单机模式)
  String get hostType;

  /// 播放音效 (例如: 'dice_shake', 'card_play', 'bull_penalty', 'victory')
  void playSound(String soundEffect);

  /// 触发设备触觉反馈 (轻微震动/中等震动/警告震动)
  void triggerHapticFeedback({bool heavy = false});

  /// 宿主额外展示信息 (如：门店名称、包厢桌号，若无则为空)
  String? get roomOrTableName;
  String? get roomOrTableNumber => roomOrTableName;
}

