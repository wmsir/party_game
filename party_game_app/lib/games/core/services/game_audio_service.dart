import 'dart:async';
import '../../../../core/sound/game_sound_service.dart';

/// 聚会桌游音频与音效中枢服务 (Game Audio & Sound FX Service)
/// 统一转发至全局高保真音效引擎 GameSoundService
class GameAudioService {
  static final GameAudioService _instance = GameAudioService._internal();
  factory GameAudioService() => _instance;
  GameAudioService._internal();

  final GameSoundService _sound = GameSoundService();

  bool get isBgmEnabled => _sound.isSoundEnabled;
  bool get isSfxEnabled => _sound.isSoundEnabled;

  Future<void> initialize() async {}

  Future<void> startBgm({String gameType = 'liars_dice'}) async {
    await _sound.playGameBgm(gameType);
  }

  Future<void> stopBgm() async {
    await _sound.stopBgm();
  }

  void toggleBgm() {
    _sound.toggleSound(!_sound.isSoundEnabled);
  }

  void toggleSfx() {
    _sound.toggleSound(!_sound.isSoundEnabled);
  }

  /// 播放指定名称音效
  Future<void> playSound(String soundKey) async {
    switch (soundKey) {
      case 'dice_shake':
        _sound.playDiceShake();
        break;
      case 'card_play':
        _sound.playCardPlay();
        break;
      case 'dice_open':
      case 'challenge_bang':
        _sound.playDiceOpen();
        break;
      case 'bull_penalty':
        _sound.playBullPenalty();
        break;
      case 'wheel_tick':
        _sound.playWheelTick();
        break;
      case 'victory':
        _sound.playVictory();
        break;
      case 'defeat':
        _sound.playDefeat();
        break;
      default:
        _sound.playHapticLight();
        break;
    }
  }

  Future<void> dispose() async {
    await _sound.stopBgm();
  }
}
