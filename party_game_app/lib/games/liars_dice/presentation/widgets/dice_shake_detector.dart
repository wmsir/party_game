import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/services/game_audio_service.dart';

/// 真实摇晃摇骰传感器与交互组件 (Dice Shake Detector)
/// 监听手机加速度物理传感器，感应真实手摇动作并联动物理震颤与骰盅碰撞音效
class DiceShakeDetector extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback onShakeFinished;
  final Widget child;

  const DiceShakeDetector({
    Key? key,
    required this.isEnabled,
    required this.onShakeFinished,
    required this.child,
  }) : super(key: key);

  @override
  State<DiceShakeDetector> createState() => _DiceShakeDetectorState();
}

class _DiceShakeDetectorState extends State<DiceShakeDetector> with SingleTickerProviderStateMixin {
  StreamSubscription<UserAccelerometerEvent>? _sensorSub;
  late AnimationController _shakeAnimCtrl;

  bool _isCurrentlyShaking = false;
  int _shakeCounter = 0;
  DateTime _lastShakeTime = DateTime.now();
  Timer? _stillnessTimer;

  // 灵敏度阈值 (m/s^2)
  static const double _shakeThreshold = 14.0;

  @override
  void initState() {
    super.initState();
    _shakeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    if (widget.isEnabled) {
      _startListeningSensors();
    }
  }

  @override
  void didUpdateWidget(covariant DiceShakeDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnabled != widget.isEnabled) {
      if (widget.isEnabled) {
        _startListeningSensors();
      } else {
        _stopListeningSensors();
      }
    }
  }

  void _startListeningSensors() {
    try {
      _sensorSub = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          if (magnitude > _shakeThreshold) {
            _handleShakeEvent();
          }
        },
        onError: (_) {
          // 模拟器或不支持加速度计的设备上静默容错
        },
      );
    } catch (_) {}
  }

  void _stopListeningSensors() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _stillnessTimer?.cancel();
  }

  void _handleShakeEvent() {
    final now = DateTime.now();
    if (now.difference(_lastShakeTime).inMilliseconds < 180) return; // 防抖
    _lastShakeTime = now;

    if (!mounted) return;

    setState(() {
      _isCurrentlyShaking = true;
      _shakeCounter++;
    });

    // 震颤动画与真实音效
    _shakeAnimCtrl.forward(from: 0.0);
    GameAudioService().playSound('dice_shake');
    HapticFeedback.mediumImpact();

    // 每次剧烈摇晃后，如果静止 850ms，则判定“扣盅停骰”
    _stillnessTimer?.cancel();
    _stillnessTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted && _shakeCounter >= 2) {
        setState(() {
          _isCurrentlyShaking = false;
          _shakeCounter = 0;
        });
        HapticFeedback.heavyImpact();
        GameAudioService().playSound('bid_ding');
        widget.onShakeFinished();
      } else if (mounted) {
        setState(() {
          _isCurrentlyShaking = false;
        });
      }
    });
  }

  /// 允许在桌面端或无传感器环境下手势点击手动模拟摇晃
  void manualSimulateShake() {
    _handleShakeEvent();
    Future.delayed(const Duration(milliseconds: 220), _handleShakeEvent);
    Future.delayed(const Duration(milliseconds: 440), _handleShakeEvent);
  }

  @override
  void dispose() {
    _stopListeningSensors();
    _shakeAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // 当感应到真实手摇时，全屏覆盖半透明 3D 骰盅狂摇特效
        if (_isCurrentlyShaking)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: AnimatedBuilder(
                  animation: _shakeAnimCtrl,
                  builder: (ctx, child) {
                    final offset = sin(_shakeAnimCtrl.value * pi * 4) * 16.0;
                    final angle = sin(_shakeAnimCtrl.value * pi * 4) * 0.12;

                    return Transform.translate(
                      offset: Offset(offset, -offset.abs() * 0.5),
                      child: Transform.rotate(
                        angle: angle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8D6E63), Color(0xFF3E2723)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.6),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                            border: Border.all(color: Colors.amberAccent, width: 2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎲 🎲 🎲', style: TextStyle(fontSize: 34)),
                              const SizedBox(height: 10),
                              const Text(
                                '🌀 用力摇晃手机中...',
                                style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '已感应摇骰: $_shakeCounter 次 (静止后自动扣盅)',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
