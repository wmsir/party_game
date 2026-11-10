import '../../core/contracts/game_host_context.dart';
import '../../core/services/game_audio_service.dart';

/// 门店会员系统宿主上下文 (Store Member Host Context)
/// 携带当前商户、门店、桌台/包厢编号与会员身份信息
class StoreMemberHostContext implements IGameHostContext {
  final String storeName;
  final String tableNo;
  final String? tenantId;
  final String? memberPhone;
  final Function(String effect)? onPlaySound;
  final Function(bool heavy)? onHaptic;

  StoreMemberHostContext({
    required this.storeName,
    required this.tableNo,
    this.tenantId,
    this.memberPhone,
    this.onPlaySound,
    this.onHaptic,
  });

  @override
  String get appName => '海马智慧门店 · 聚会娱乐空间';

  @override
  String get hostType => 'STORE_MEMBER';

  @override
  String? get roomOrTableName => '$storeName · $tableNo 桌';

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
