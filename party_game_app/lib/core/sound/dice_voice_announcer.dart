import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../storage/local_storage.dart';

/// 大话骰真人语音喊点播报器 (Dice Voice Announcer)
/// 原生轻量级高可靠系统：在对局中真实语音报数：“3个3”、“4个3”、“5个6斋”、“开！”、“劈！”
class DiceVoiceAnnouncer {
  static final DiceVoiceAnnouncer _instance = DiceVoiceAnnouncer._internal();
  factory DiceVoiceAnnouncer() => _instance;
  DiceVoiceAnnouncer._internal();

  static const MethodChannel _channel = MethodChannel('com.fwpt.party_game/tts');

  bool _isInitialized = false;
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  Future<void> init() async {
    if (_isInitialized) return;
    _isEnabled = LocalStorage.getBool('dice_voice_enabled') ?? true;
    _isInitialized = true;
  }

  void toggleVoice(bool enabled) {
    _isEnabled = enabled;
    LocalStorage.setBool('dice_voice_enabled', enabled);
    if (!enabled) {
      try {
        _channel.invokeMethod('stop');
      } catch (_) {}
    }
  }

  /// 叫点语音播报（例如：“3个3”、“4个3”、“5个6斋”）
  Future<void> speakBid({
    required int count,
    required int face,
    bool isPure = false,
    String? bidderName,
    double pitch = 1.0,
  }) async {
    if (!_isEnabled) return;
    if (!_isInitialized) await init();

    try {
      final faceText = _faceToChinese(face);
      final countText = _countToChinese(count);
      final pureText = isPure ? '斋' : '';
      final text = '$countText个$faceText$pureText';

      await _channel.invokeMethod('speak', {
        'text': text,
        'pitch': pitch.clamp(0.8, 1.4),
        'rate': 1.0,
      });
    } catch (e) {
      debugPrint('TTS 喊点提示: $e');
    }
  }

  /// 开 / 劈 语音播报
  Future<void> speakChallenge({
    bool isPi = false,
    String? challengerName,
    double pitch = 1.0,
  }) async {
    if (!_isEnabled) return;
    if (!_isInitialized) await init();

    try {
      final text = isPi ? '劈！' : '开！';
      await _channel.invokeMethod('speak', {
        'text': text,
        'pitch': pitch.clamp(0.8, 1.4),
        'rate': 1.1,
      });
    } catch (e) {
      debugPrint('TTS 开盅提示: $e');
    }
  }

  /// 裁决结果语音提示
  Future<void> speakResult({required bool isChallengerWon}) async {
    if (!_isEnabled) return;
    if (!_isInitialized) await init();

    try {
      final text = isChallengerWon ? '抓中了！' : '抓错啦！';
      await Future.delayed(const Duration(milliseconds: 350));
      await _channel.invokeMethod('speak', {
        'text': text,
        'pitch': 1.0,
        'rate': 1.0,
      });
    } catch (e) {
      debugPrint('TTS 裁决提示: $e');
    }
  }

  String _countToChinese(int count) {
    const list = ['', '一', '两', '三', '四', '五', '六', '七', '八', '九', '十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十'];
    if (count >= 1 && count < list.length) {
      return list[count];
    }
    return count.toString();
  }

  String _faceToChinese(int face) {
    switch (face) {
      case 1:
        return '一';
      case 2:
        return '二';
      case 3:
        return '三';
      case 4:
        return '四';
      case 5:
        return '五';
      case 6:
        return '六';
      default:
        return face.toString();
    }
  }

  void dispose() {
    try {
      _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
