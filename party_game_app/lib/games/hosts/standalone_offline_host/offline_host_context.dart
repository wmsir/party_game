import '../../core/contracts/game_host_context.dart';
import '../../core/services/game_audio_service.dart';

/// 独立单机 / 离线模式宿主上下文 (Standalone Offline Host Context)
/// 支持完全不依赖后端服务器的单机独立运行环境
class OfflineHostContext implements IGameHostContext {
  final String customAppName;
  final Function(String effect)? onPlaySound;
  final Function(bool heavy)? onHaptic;

  OfflineHostContext({
    this.customAppName = '独立单机派对桌游',
    this.onPlaySound,
    this.onHaptic,
  });

  @override
  String get appName => customAppName;

  @override
  String get hostType => 'STANDALONE_OFFLINE';

  @override
  String? get roomOrTableName => '离线本地包厢';

  @override
  String? get roomOrTableNumber => roomOrTableName;

  @override
  void playSound(String soundEffect) {
    if (onPlaySound != null) {
      onPlaySound!(soundEffect);
    } else {
      GameAudioService().playSound(soundEffect);
    }
  }

  @override
  void triggerHapticFeedback({bool heavy = false}) {
    if (onHaptic != null) {
      onHaptic!(heavy);
    }
  }
}
