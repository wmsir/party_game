import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../storage/local_storage.dart';

/// 真实程序化音频合成与音效/BGM服务
/// 支持真实拟真摇骰物理撞击、发牌/开盅/惩罚音效，以及 4 大游戏各具特色的专属背景音乐
class GameSoundService {
  static final GameSoundService _instance = GameSoundService._internal();
  factory GameSoundService() => _instance;
  GameSoundService._internal();

  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;

  AudioPlayer get bgmPlayer => _bgmPlayer ??= AudioPlayer();
  AudioPlayer get sfxPlayer => _sfxPlayer ??= AudioPlayer();

  bool _isSoundEnabled = true;
  bool _isVibrationEnabled = true;
  String? _currentGameBgm;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;
  String? get currentGameBgm => _currentGameBgm;

  // 内存缓存已合成的音频字节流
  final Map<String, Uint8List> _wavCache = {};
  bool _isInitialized = false;

  void init() {
    _isSoundEnabled = LocalStorage.getBool('app_sound_enabled') ?? true;
    _isVibrationEnabled = LocalStorage.getBool('app_vibration_enabled') ?? true;
    _preloadAudio();
  }

  void _preloadAudio() {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      bgmPlayer.setReleaseMode(ReleaseMode.loop);
      bgmPlayer.setVolume(0.45);
      sfxPlayer.setVolume(0.85);

      // 预生成所有音效
      _wavCache['dice_shake'] = _synthesizeDiceShake();
      _wavCache['card_play'] = _synthesizeCardPlay();
      _wavCache['dice_open'] = _synthesizeDiceOpen();
      _wavCache['bull_penalty'] = _synthesizeBullPenalty();
      _wavCache['wheel_tick'] = _synthesizeWheelTick();
      _wavCache['undercover_vote'] = _synthesizeUndercoverVote();
      _wavCache['victory'] = _synthesizeVictory();
      _wavCache['defeat'] = _synthesizeDefeat();
      _wavCache['bomb_hit'] = _synthesizeBombHit();
      _wavCache['beer_cheers'] = _synthesizeBeerCheers();
      _wavCache['flower_magic'] = _synthesizeFlowerMagic();
      _wavCache['slipper_slap'] = _synthesizeSlipperSlap();

      // 预生成 4 款游戏专属不同的背景音乐 (可无缝循环)
      _wavCache['bgm_liars_dice'] = _synthesizeBgmLiarsDice();
      _wavCache['bgm_take6'] = _synthesizeBgmTake6();
      _wavCache['bgm_party_wheel'] = _synthesizeBgmPartyWheel();
      _wavCache['bgm_undercover'] = _synthesizeBgmUndercover();
    } catch (e) {
      // 容错处理
    }
  }

  void toggleSound(bool enabled) {
    _isSoundEnabled = enabled;
    LocalStorage.setBool('app_sound_enabled', enabled);
    if (!enabled) {
      stopBgm();
    } else if (_currentGameBgm != null) {
      playGameBgm(_currentGameBgm!);
    }
  }

  void toggleVibration(bool enabled) {
    _isVibrationEnabled = enabled;
    LocalStorage.setBool('app_vibration_enabled', enabled);
  }

  // ==================== 触感反馈 ====================

  void playHapticLight() {
    if (_isVibrationEnabled) HapticFeedback.lightImpact();
  }

  void playHapticMedium() {
    if (_isVibrationEnabled) HapticFeedback.mediumImpact();
  }

  void playHapticHeavy() {
    if (_isVibrationEnabled) HapticFeedback.heavyImpact();
  }

  // ==================== 独立游戏背景音乐 ====================

  /// 为特定游戏启动其专属背景音乐
  /// gameType: 'liars_dice', 'take6', 'party_wheel', 'undercover'
  Future<void> playGameBgm(String gameType) async {
    _currentGameBgm = gameType;
    if (!_isSoundEnabled) return;
    _preloadAudio();

    final bgmKey = 'bgm_$gameType';
    final bytes = _wavCache[bgmKey];
    if (bytes != null) {
      try {
        await bgmPlayer.stop();
        await bgmPlayer.play(BytesSource(bytes));
      } catch (_) {}
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer?.stop();
    } catch (_) {}
  }

  // ==================== 游戏交互拟真音效 ====================

  Future<void> _playSfx(String key, {VoidCallback? fallbackHaptic}) async {
    if (!_isSoundEnabled) {
      fallbackHaptic?.call();
      return;
    }
    _preloadAudio();

    fallbackHaptic?.call();
    final bytes = _wavCache[key];
    if (bytes != null) {
      try {
        await sfxPlayer.stop();
        await sfxPlayer.play(BytesSource(bytes));
      } catch (_) {}
    }
  }

  /// 真实多颗骰子剧烈摇盅碰撞回响
  void playDiceShake() {
    _playSfx('dice_shake', fallbackHaptic: playHapticMedium);
  }

  /// 真实出牌/翻牌唰声
  void playCardPlay() {
    _playSfx('card_play', fallbackHaptic: playHapticLight);
  }

  /// 开骰/劈骰震撼敲击
  void playDiceOpen() {
    _playSfx('dice_open', fallbackHaptic: playHapticHeavy);
  }

  /// 谁是牛头王惩罚吃牌低沉哀鸣
  void playBullPenalty() {
    _playSfx('bull_penalty', fallbackHaptic: playHapticHeavy);
  }

  /// 聚会大转盘逐格指针清脆咔嗒
  void playWheelTick() {
    _playSfx('wheel_tick', fallbackHaptic: playHapticLight);
  }

  /// 谁是卧底投票法槌敲定
  void playUndercoverVote() {
    _playSfx('undercover_vote', fallbackHaptic: playHapticHeavy);
  }

  /// 胜利欢庆大捷和弦
  void playVictory() {
    _playSfx('victory', fallbackHaptic: playHapticHeavy);
  }

  void playWin() => playVictory();
  void playRoll() => playDiceShake();
  void playClick() => playWheelTick();

  /// 失败/被罚落寞和弦
  void playDefeat() {
    _playSfx('defeat', fallbackHaptic: playHapticHeavy);
  }

  /// 互动道具命中音效
  void playItemHit(String itemType) {
    switch (itemType) {
      case 'BOMB':
        _playSfx('bomb_hit', fallbackHaptic: playHapticHeavy);
        break;
      case 'BEER':
        _playSfx('beer_cheers', fallbackHaptic: playHapticLight);
        break;
      case 'FLOWER':
        _playSfx('flower_magic', fallbackHaptic: playHapticLight);
        break;
      case 'SLIPPER':
        _playSfx('slipper_slap', fallbackHaptic: playHapticMedium);
        break;
      default:
        _playSfx('dice_shake', fallbackHaptic: playHapticMedium);
        break;
    }
  }

  /// 通用音效播放适配方法
  void playSound(String soundKey) {
    switch (soundKey) {
      case 'victory':
        playVictory();
        break;
      case 'defeat':
        playDefeat();
        break;
      case 'dice_shake':
        playDiceShake();
        break;
      case 'card_play':
        playCardPlay();
        break;
      case 'dice_open':
        playDiceOpen();
        break;
      case 'bull_penalty':
        playBullPenalty();
        break;
      case 'wheel_tick':
        playWheelTick();
        break;
      case 'undercover_vote':
        playUndercoverVote();
        break;
      default:
        _playSfx(soundKey, fallbackHaptic: playHapticLight);
        break;
    }
  }

  // ==================== PCM 16-bit 22050Hz WAV 合成器 ====================

  static const int _sampleRate = 22050;

  static Uint8List _createWav(List<int> samples) {
    final int dataSize = samples.length * 2;
    final int fileSize = 36 + dataSize;
    final b = ByteData(44 + dataSize);

    // RIFF
    b.setUint8(0, 0x52); b.setUint8(1, 0x49); b.setUint8(2, 0x46); b.setUint8(3, 0x46);
    b.setUint32(4, fileSize, Endian.little);
    b.setUint8(8, 0x57); b.setUint8(9, 0x41); b.setUint8(10, 0x56); b.setUint8(11, 0x45); // WAVE

    // fmt
    b.setUint8(12, 0x66); b.setUint8(13, 0x6D); b.setUint8(14, 0x74); b.setUint8(15, 0x20);
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // Mono
    b.setUint32(24, _sampleRate, Endian.little);
    b.setUint32(28, _sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);

    // data
    b.setUint8(36, 0x64); b.setUint8(37, 0x61); b.setUint8(38, 0x74); b.setUint8(39, 0x61);
    b.setUint32(40, dataSize, Endian.little);

    int offset = 44;
    for (final s in samples) {
      b.setInt16(offset, s.clamp(-32768, 32767), Endian.little);
      offset += 2;
    }
    return b.buffer.asUint8List();
  }

  /// 1. 真实物理摇骰（模拟 5 颗亚克力骰子在盅内剧烈撞击回弹的 3 幕声浪）
  static Uint8List _synthesizeDiceShake() {
    final int numSamples = (_sampleRate * 0.58).toInt();
    final buffer = Float64List(numSamples);
    final rand = Random(42);

    // 浪潮 1: 初次加速摇荡 (7次撞击)
    for (int i = 0; i < 7; i++) {
      _addDiceImpact(buffer, 0.04 + i * 0.015 + rand.nextDouble() * 0.005, 0.6 + rand.nextDouble() * 0.4, 2900 + rand.nextDouble() * 1500, 460 + rand.nextDouble() * 120, rand);
    }
    // 浪潮 2: 反向剧烈撞击 (10次高密强烈撞击)
    for (int i = 0; i < 10; i++) {
      _addDiceImpact(buffer, 0.18 + i * 0.014 + rand.nextDouble() * 0.006, 0.8 + rand.nextDouble() * 0.2, 3200 + rand.nextDouble() * 1600, 420 + rand.nextDouble() * 140, rand);
    }
    // 浪潮 3: 停落沉底散撞 (8次散漫下落)
    for (int i = 0; i < 8; i++) {
      _addDiceImpact(buffer, 0.36 + i * 0.016 + rand.nextDouble() * 0.008, 0.5 + rand.nextDouble() * 0.4, 2700 + rand.nextDouble() * 1300, 500 + rand.nextDouble() * 160, rand);
    }

    double maxAmp = 0.001;
    for (int i = 0; i < numSamples; i++) {
      if (buffer[i].abs() > maxAmp) maxAmp = buffer[i].abs();
    }
    final scale = 30000.0 / maxAmp;
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      samples.add((buffer[i] * scale).toInt());
    }
    return _createWav(samples);
  }

  static void _addDiceImpact(Float64List buffer, double startTime, double force, double clickPitch, double bodyPitch, Random rand) {
    final int startSample = (startTime * _sampleRate).toInt();
    final int dur = (_sampleRate * 0.032).toInt();
    for (int j = 0; j < dur; j++) {
      final idx = startSample + j;
      if (idx >= buffer.length) break;
      final dt = j / _sampleRate;
      final clickEnv = exp(-360.0 * dt);
      final clickTone = sin(2 * pi * clickPitch * dt) + 0.3 * sin(2 * pi * clickPitch * 1.5 * dt);
      final bodyEnv = exp(-150.0 * dt);
      final bodyTone = sin(2 * pi * bodyPitch * dt);
      final noise = (rand.nextDouble() * 2 - 1) * exp(-400.0 * dt);
      buffer[idx] += force * (clickTone * clickEnv * 0.65 + bodyTone * bodyEnv * 0.25 + noise * 0.1);
    }
  }

  /// 2. 出牌唰声
  static Uint8List _synthesizeCardPlay() {
    final numSamples = (_sampleRate * 0.15).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-16.0 * progress);
      final freq = 900.0 + 1100.0 * (1.0 - progress);
      final noise = (Random().nextDouble() * 2 - 1) * 0.2;
      final wave = sin(2 * pi * freq * t) * 0.8 + noise;
      samples.add((wave * env * 24000).toInt());
    }
    return _createWav(samples);
  }

  /// 3. 开骰/劈骰重击
  static Uint8List _synthesizeDiceOpen() {
    final numSamples = (_sampleRate * 0.55).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-7.0 * progress);
      final strike = sin(2 * pi * 220.0 * (1.0 - progress * 0.4) * t);
      final noise = (Random().nextDouble() * 2 - 1) * exp(-12.0 * progress);
      final wave = strike * 0.6 + noise * 0.4;
      samples.add((wave * env * 29000).toInt());
    }
    return _createWav(samples);
  }

  /// 4. 牛头王吃牌惩罚
  static Uint8List _synthesizeBullPenalty() {
    final numSamples = (_sampleRate * 0.5).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-4.5 * progress);
      final freq = 130.0 + 18.0 * sin(2 * pi * 14 * t);
      final subBass = sin(2 * pi * 65.0 * t);
      final wave = sin(2 * pi * freq * t) * 0.6 + subBass * 0.4;
      samples.add((wave * env * 28000).toInt());
    }
    return _createWav(samples);
  }

  /// 5. 转盘咔哒声
  static Uint8List _synthesizeWheelTick() {
    final numSamples = (_sampleRate * 0.06).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-45.0 * progress);
      final wave = sin(2 * pi * 2400.0 * t);
      samples.add((wave * env * 26000).toInt());
    }
    return _createWav(samples);
  }

  /// 6. 谁是卧底审判敲击
  static Uint8List _synthesizeUndercoverVote() {
    final numSamples = (_sampleRate * 0.4).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-8.0 * progress);
      final thud = sin(2 * pi * 90.0 * t);
      final click = sin(2 * pi * 1200.0 * t) * exp(-50.0 * progress);
      final wave = thud * 0.7 + click * 0.3;
      samples.add((wave * env * 28000).toInt());
    }
    return _createWav(samples);
  }

  /// 7. 炸弹爆炸
  static Uint8List _synthesizeBombHit() {
    final numSamples = (_sampleRate * 0.6).toInt();
    final samples = <int>[];
    final rand = Random(88);
    for (int i = 0; i < numSamples; i++) {
      final progress = i / numSamples;
      final env = exp(-6.0 * progress);
      final noise = (rand.nextDouble() * 2 - 1);
      final sub = sin(2 * pi * 50.0 * (i / _sampleRate));
      final wave = noise * 0.75 + sub * 0.25;
      samples.add((wave * env * 31000).toInt());
    }
    return _createWav(samples);
  }

  /// 8. 碰啤酒
  static Uint8List _synthesizeBeerCheers() {
    final numSamples = (_sampleRate * 0.3).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-12.0 * progress);
      // 玻璃清脆敲碰 (2100Hz & 3500Hz)
      final wave = sin(2 * pi * 2100.0 * t) * 0.6 + sin(2 * pi * 3500.0 * t) * 0.4;
      samples.add((wave * env * 25000).toInt());
    }
    return _createWav(samples);
  }

  /// 9. 送鲜花
  static Uint8List _synthesizeFlowerMagic() {
    final numSamples = (_sampleRate * 0.35).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final progress = i / numSamples;
      final env = exp(-7.0 * progress);
      final freq = 800.0 + 1200.0 * progress;
      final wave = sin(2 * pi * freq * t);
      samples.add((wave * env * 22000).toInt());
    }
    return _createWav(samples);
  }

  /// 10. 甩拖鞋
  static Uint8List _synthesizeSlipperSlap() {
    final numSamples = (_sampleRate * 0.2).toInt();
    final samples = <int>[];
    final rand = Random(7);
    for (int i = 0; i < numSamples; i++) {
      final progress = i / numSamples;
      final env = exp(-20.0 * progress);
      final noise = (rand.nextDouble() * 2 - 1) * 0.6;
      final thud = sin(2 * pi * 160.0 * (i / _sampleRate)) * 0.4;
      samples.add(((noise + thud) * env * 27000).toInt());
    }
    return _createWav(samples);
  }

  /// 11. 胜利乐曲
  static Uint8List _synthesizeVictory() {
    final numSamples = (_sampleRate * 0.85).toInt();
    final samples = <int>[];
    final notes = [523.25, 659.25, 783.99, 1046.5]; // C5, E5, G5, C6
    final noteLen = numSamples ~/ notes.length;
    for (int i = 0; i < numSamples; i++) {
      final noteIdx = min(i ~/ noteLen, 3);
      final freq = notes[noteIdx];
      final t = i / _sampleRate;
      final noteProgress = (i % noteLen) / noteLen;
      final env = exp(-4.0 * noteProgress);
      final wave = sin(2 * pi * freq * t) * 0.7 + sin(2 * pi * freq * 2 * t) * 0.3;
      samples.add((wave * env * 24000).toInt());
    }
    return _createWav(samples);
  }

  /// 12. 失败乐曲
  static Uint8List _synthesizeDefeat() {
    final numSamples = (_sampleRate * 0.75).toInt();
    final samples = <int>[];
    final notes = [440.0, 392.0, 349.23, 293.66]; // A4, G4, F4, D4
    final noteLen = numSamples ~/ notes.length;
    for (int i = 0; i < numSamples; i++) {
      final noteIdx = min(i ~/ noteLen, 3);
      final freq = notes[noteIdx];
      final t = i / _sampleRate;
      final noteProgress = (i % noteLen) / noteLen;
      final env = exp(-4.0 * noteProgress);
      final wave = sin(2 * pi * freq * t);
      samples.add((wave * env * 20000).toInt());
    }
    return _createWav(samples);
  }

  // ==================== 4 大游戏各具特色的专属背景音乐 ====================

  /// 游戏 1: 大话骰专属 BGM —— 悬疑博弈酒吧爵士行走低音与轻快律动 (4.8s 循环)
  static Uint8List _synthesizeBgmLiarsDice() {
    const double dur = 4.8;
    final int numSamples = (_sampleRate * dur).toInt();
    final samples = <int>[];
    // 爵士 Walking Bass + 弱拍钢琴和弦
    final bassNotes = [130.81, 164.81, 196.00, 220.00, 196.00, 164.81, 146.83, 130.81];
    final stepLen = numSamples ~/ bassNotes.length;

    for (int i = 0; i < numSamples; i++) {
      final step = i ~/ stepLen;
      final freq = bassNotes[step % bassNotes.length];
      final t = i / _sampleRate;
      final p = (i % stepLen) / stepLen;
      final env = exp(-4.2 * p);
      final bass = sin(2 * pi * freq * t) * env * 0.55;
      final hihat = ((i % (_sampleRate ~/ 4)) < 200) ? (sin(2 * pi * 5000.0 * t) * 0.08) : 0.0;
      final lead = sin(2 * pi * (freq * 2.5) * t) * exp(-6.0 * p) * 0.25;
      final wave = bass + hihat + lead;
      samples.add((wave * 16000).toInt());
    }
    return _createWav(samples);
  }

  /// 游戏 2: 谁是牛头王专属 BGM —— 轻快活泼乡村木琴卡牌调 (4.8s 循环)
  static Uint8List _synthesizeBgmTake6() {
    const double dur = 4.8;
    final int numSamples = (_sampleRate * dur).toInt();
    final samples = <int>[];
    // 活泼大调小曲 (G, B, D, G, A, C, E, D)
    final melody = [392.00, 493.88, 587.33, 783.99, 440.00, 523.25, 659.25, 587.33];
    final stepLen = numSamples ~/ melody.length;

    for (int i = 0; i < numSamples; i++) {
      final step = i ~/ stepLen;
      final freq = melody[step % melody.length];
      final t = i / _sampleRate;
      final p = (i % stepLen) / stepLen;
      final env = exp(-5.0 * p);
      final xylophone = (sin(2 * pi * freq * t) + 0.3 * sin(2 * pi * freq * 2 * t)) * env * 0.5;
      final bass = sin(2 * pi * (freq / 2) * t) * exp(-3.0 * p) * 0.35;
      final wave = xylophone + bass;
      samples.add((wave * 15000).toInt());
    }
    return _createWav(samples);
  }

  /// 游戏 3: 聚会大冒险转盘专属 BGM —— 紧张刺激派对嘉年华急促摇摆鼓点 (4.0s 循环)
  static Uint8List _synthesizeBgmPartyWheel() {
    const double dur = 4.0;
    final int numSamples = (_sampleRate * dur).toInt();
    final samples = <int>[];
    // 快节奏派对电音驱动 (E, G, A, B, D, B, A, G)
    final melody = [329.63, 392.00, 440.00, 493.88, 587.33, 493.88, 440.00, 392.00];
    final stepLen = numSamples ~/ (melody.length * 2); // 16 步更快节拍

    for (int i = 0; i < numSamples; i++) {
      final step = i ~/ stepLen;
      final freq = melody[step % melody.length];
      final t = i / _sampleRate;
      final p = (i % stepLen) / stepLen;
      final env = exp(-7.0 * p);
      final beat = ((step % 2 == 0) && (p < 0.2)) ? 0.35 * sin(2 * pi * 80.0 * t) : 0.0;
      final synth = sin(2 * pi * freq * t) * env * 0.45;
      final wave = synth + beat;
      samples.add((wave * 17000).toInt());
    }
    return _createWav(samples);
  }

  /// 游戏 4: 谁是卧底专属 BGM —— 悬疑推理沉浸式暗黑心跳神秘律动 (5.2s 循环)
  static Uint8List _synthesizeBgmUndercover() {
    const double dur = 5.2;
    final int numSamples = (_sampleRate * dur).toInt();
    final samples = <int>[];
    // 沉重缓慢的心跳与小调悬疑音 (D, F, A, Bb, A, F, D, C#)
    final melody = [293.66, 349.23, 440.00, 466.16, 440.00, 349.23, 293.66, 277.18];
    final stepLen = numSamples ~/ melody.length;

    for (int i = 0; i < numSamples; i++) {
      final step = i ~/ stepLen;
      final freq = melody[step % melody.length];
      final t = i / _sampleRate;
      final p = (i % stepLen) / stepLen;
      // 扑通心跳 (每小节前 0.15 出现咚咚双声)
      final heart1 = (p < 0.1) ? sin(2 * pi * 55.0 * t) * exp(-12.0 * p) * 0.5 : 0.0;
      final heart2 = (p > 0.12 && p < 0.22) ? sin(2 * pi * 50.0 * t) * exp(-14.0 * (p - 0.12)) * 0.4 : 0.0;
      // 阴暗悬疑长音
      final pad = sin(2 * pi * freq * t) * exp(-2.5 * p) * 0.3;
      final wave = heart1 + heart2 + pad;
      samples.add((wave * 18000).toInt());
    }
    return _createWav(samples);
  }
}
