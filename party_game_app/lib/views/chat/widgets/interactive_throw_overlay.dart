import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/chat_message_model.dart';
import '../../../services/api_service.dart';

/// 仿抖音/TikTok 直播全屏刷礼物顶级华丽特效、物理抛物线飞掷、击中爆破粒子与跑道连击横幅
class InteractiveThrowOverlay extends StatefulWidget {
  final ChatMessageModel? event;
  final VoidCallback onComplete;

  const InteractiveThrowOverlay({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<InteractiveThrowOverlay> createState() => _InteractiveThrowOverlayState();
}

class _InteractiveThrowOverlayState extends State<InteractiveThrowOverlay>
    with TickerProviderStateMixin {
  // 1. 跑道横幅
  late AnimationController _bannerController;
  late Animation<Offset> _bannerSlideAnimation;

  // 2. 飞掷发射阶段 (从底部/发送者抛向屏幕中央目标)
  late AnimationController _flightController;
  late Animation<Offset> _flightOffsetAnimation;
  late Animation<double> _flightScaleAnimation;
  late Animation<double> _flightRotationAnimation;

  // 3. 击中爆发阶段 (冲击波、闪光、粒子炸裂)
  late AnimationController _impactController;
  late Animation<double> _impactScaleAnimation;
  late Animation<double> _impactFlashAnimation;
  late Animation<double> _particleSpreadAnimation;
  late Animation<double> _rayRotationAnimation;

  // 4. 连击数字跳动
  late AnimationController _comboController;
  late Animation<double> _comboScaleAnimation;

  // 屏幕震动微偏移
  double _shakeOffsetX = 0.0;
  double _shakeOffsetY = 0.0;

  Timer? _lingerTimer;
  double _opacity = 1.0;
  int _lingerDurationSeconds = 3;
  bool _isFlying = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();

    // 1. 跑道横幅滑入
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.elasticOut,
    ));

    // 2. 飞掷飞行轨迹 (400ms 高速带弧度抛射)
    _flightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flightOffsetAnimation = Tween<Offset>(
      begin: const Offset(120.0, 320.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeOutCubic,
    ));
    _flightScaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _flightController, curve: Curves.easeOutQuad),
    );
    _flightRotationAnimation = Tween<double>(begin: -0.8, end: 0.0).animate(
      CurvedAnimation(parent: _flightController, curve: Curves.easeOut),
    );

    // 3. 击中爆破冲击波与旋转光芒
    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _impactScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.45, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
    ]).animate(_impactController);

    _impactFlashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _impactController, curve: Curves.easeOut),
    );

    _particleSpreadAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _impactController, curve: Curves.easeOutCubic),
    );

    _rayRotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _impactController, curve: Curves.linear),
    );

    // 4. Combo 连击跳动
    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _comboScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.6).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 60),
    ]).animate(_comboController);

    if (widget.event != null) {
      _startAnimationSequence();
    }
  }

  void _loadConfig() async {
    try {
      final cfg = await ApiService().fetchSystemConfig();
      if (cfg['propDisplayDurationSeconds'] is int) {
        _lingerDurationSeconds = cfg['propDisplayDurationSeconds'];
      }
    } catch (_) {}
  }

  void _startAnimationSequence() {
    _opacity = 1.0;
    _isFlying = true;
    _bannerController.forward(from: 0.0);
    _flightController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() => _isFlying = false);
      _triggerImpact();
    });

    // 延时触发连击跳动
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _comboController.forward(from: 0.0);
    });

    // 停留倒计时
    _lingerTimer?.cancel();
    _lingerTimer = Timer(Duration(seconds: max(3, _lingerDurationSeconds)), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  void _triggerImpact() {
    _impactController.forward(from: 0.0);
    // 触发剧烈震屏
    final isHeavy = widget.event?.itemType == 'BOMB' || widget.event?.itemType == 'SLIPPER' || widget.event?.itemType == 'ROCKET';
    final shakeCount = isHeavy ? 6 : 3;
    final shakeMag = isHeavy ? 10.0 : 5.0;

    for (int i = 0; i < shakeCount; i++) {
      Future.delayed(Duration(milliseconds: i * 40), () {
        if (!mounted) return;
        setState(() {
          _shakeOffsetX = (i % 2 == 0 ? shakeMag : -shakeMag) / (i + 1);
          _shakeOffsetY = (i % 2 == 1 ? shakeMag * 0.5 : -shakeMag * 0.5) / (i + 1);
        });
      });
    }
    Future.delayed(Duration(milliseconds: shakeCount * 40 + 20), () {
      if (mounted) {
        setState(() {
          _shakeOffsetX = 0.0;
          _shakeOffsetY = 0.0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveThrowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.event != null && widget.event != oldWidget.event) {
      _lingerTimer?.cancel();
      _startAnimationSequence();
    }
  }

  @override
  void dispose() {
    _lingerTimer?.cancel();
    _bannerController.dispose();
    _flightController.dispose();
    _impactController.dispose();
    _comboController.dispose();
    super.dispose();
  }

  /// 各类道具专属的爆破飞溅粒子配置
  List<Widget> _buildCustomParticles(String itemType) {
    final spread = _particleSpreadAnimation.value;
    final particles = <Widget>[];

    // 定义每种道具专属的喷射元素与扩散半径
    List<String> emojis;
    Color glowColor;

    switch (itemType) {
      case 'EGG':
        emojis = ['🟡', '🍳', '✨', '💛', '💥', '🟡', '🍳', '✨'];
        glowColor = Colors.amber;
        break;
      case 'SLIPPER':
        emojis = ['⭐', '💫', '👡', '✨', '💥', '⭐', '💫', '⚡'];
        glowColor = Colors.orangeAccent;
        break;
      case 'BEER':
        emojis = ['🫧', '🍺', '🍻', '✨', '🫧', '🥂', '🍾', '🍺'];
        glowColor = Colors.amber;
        break;
      case 'FLOWER':
        emojis = ['🌸', '💐', '💖', '🌹', '✨', '🌷', '💕', '🌸'];
        glowColor = Colors.pinkAccent;
        break;
      case 'BOMB':
        emojis = ['💥', '🔥', '💨', '⚡', '💥', '🔥', '💣', '✨'];
        glowColor = Colors.deepOrange;
        break;
      case 'ROCKET':
        emojis = ['🔥', '💨', '🚀', '✨', '🌟', '💥', '🔥', '💨'];
        glowColor = Colors.cyanAccent;
        break;
      case 'YACHT':
        emojis = ['🏎️', '💨', '⚡', '✨', '🔥', '🏎️', '💨', '⭐'];
        glowColor = Colors.purpleAccent;
        break;
      case 'CASTLE':
        emojis = ['👑', '🏰', '🎆', '✨', '🎉', '🌟', '💎', '🎆'];
        glowColor = Colors.amberAccent;
        break;
      case 'CHAMPAGNE':
        emojis = ['🍾', '🥂', '✨', '🫧', '🎉', '🥂', '🍾', '✨'];
        glowColor = Colors.amber;
        break;
      case 'HAMMER':
        emojis = ['🔨', '⚡', '💥', '⭐', '💫', '⚡', '💥', '🔨'];
        glowColor = Colors.yellowAccent;
        break;
      case 'KISS':
        emojis = ['💋', '💖', '💕', '✨', '🥰', '💘', '💋', '❤️'];
        glowColor = Colors.pink;
        break;
      case 'BRICK':
        emojis = ['🧱', '💥', '💫', '⚡', '🧱', '⭐', '💥', '🧱'];
        glowColor = Colors.redAccent;
        break;
      case 'WATER_GUN':
        emojis = ['🔫', '💦', '💧', '🫧', '🌊', '💦', '💧', '🔫'];
        glowColor = Colors.lightBlueAccent;
        break;
      case 'POOP':
        emojis = ['💩', '💨', '🤢', '🪰', '💩', '💨', '⚡', '💩'];
        glowColor = Colors.brown;
        break;
      case 'DIAMOND_RING':
        emojis = ['💍', '💎', '✨', '💖', '💍', '🌟', '💎', '✨'];
        glowColor = Colors.cyanAccent;
        break;
      case 'CROWN':
        emojis = ['👑', '✨', '🌟', '🥇', '👑', '🎉', '💎', '✨'];
        glowColor = Colors.amberAccent;
        break;
      default:
        emojis = ['✨', '🎉', '🎁', '⭐', '💥', '✨', '🌟', '🎉'];
        glowColor = Colors.amber;
        break;
    }

    // 8 方向环形飞射粒子
    for (int i = 0; i < emojis.length; i++) {
      final angle = (i * 2 * pi) / emojis.length;
      final distance = 110.0 * spread;
      final dx = cos(angle) * distance;
      final dy = sin(angle) * distance;
      final opacity = (1.0 - spread * 0.6).clamp(0.0, 1.0);

      particles.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: opacity,
            child: Text(
              emojis[i],
              style: TextStyle(
                fontSize: 22 + (i % 3) * 4,
                shadows: [Shadow(color: glowColor, blurRadius: 12)],
              ),
            ),
          ),
        ),
      );
    }

    return particles;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event == null) return const SizedBox.shrink();

    final itemEmoji = widget.event!.metadata?['itemEmoji'] ?? '🎁';
    final giftTitle = widget.event!.giftTitle ?? '互动礼物';
    final targetName = widget.event!.targetPlayerName ?? '对手';
    final senderName = widget.event!.senderName;
    final senderAvatar = widget.event!.senderAvatar;
    final combo = widget.event!.combo;
    final itemType = widget.event!.itemType;
    final isGlobal = widget.event!.isGlobal;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 350),
        child: SizedBox.expand(
          child: Transform.translate(
            offset: Offset(_shakeOffsetX, _shakeOffsetY),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. 全屏高能动态聚光背景
                Positioned.fill(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _rayRotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rayRotationAnimation.value,
                          child: Container(
                            width: 340,
                            height: 340,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.32),
                                  Colors.orangeAccent.withOpacity(0.15),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. 击中瞬间全屏光晕爆发冲击波
                if (!_isFlying)
                  Center(
                    child: Container(
                      width: 220 * _impactScaleAnimation.value,
                      height: 220 * _impactScaleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.amber.withOpacity((1.0 - _impactFlashAnimation.value).clamp(0.0, 1.0)),
                          width: 3.5,
                        ),
                      ),
                    ),
                  ),

                // 3. 屏幕中央巨大 3D 飞掷与击中爆发
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 粒子飞溅层
                      if (!_isFlying) ..._buildCustomParticles(itemType ?? ''),

                      // 主体道具 (飞掷中抛物线弧度，击中后弹跳冲击)
                      _isFlying
                          ? Transform.translate(
                              offset: _flightOffsetAnimation.value,
                              child: Transform.rotate(
                                angle: _flightRotationAnimation.value,
                                child: Transform.scale(
                                  scale: _flightScaleAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orangeAccent.withOpacity(0.8),
                                          blurRadius: 30,
                                          spreadRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Text(itemEmoji, style: const TextStyle(fontSize: 76)),
                                  ),
                                ),
                              ),
                            )
                          : ScaleTransition(
                              scale: _impactScaleAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.7),
                                          blurRadius: 42,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      itemEmoji,
                                      style: const TextStyle(fontSize: 96),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // 居中奢华横幅提示
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF9A3412), Color(0xFFD97706), Color(0xFFF59E0B)],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.7),
                                          blurRadius: 18,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(isGlobal ? '👑 ' : '🎯 ', style: const TextStyle(fontSize: 16)),
                                        Text(
                                          isGlobal ? '✨ 全服盛典 · $senderName ✨' : '$senderName 💥 $targetName',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.35),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            giftTitle,
                                            style: const TextStyle(
                                              color: Color(0xFFFEF08A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),

                // 4. 仿抖音左上方礼物连击滑行跑道 (Gift Runway Banner)
                Positioned(
                  top: 96,
                  left: 12,
                  child: SlideTransition(
                    position: _bannerSlideAnimation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 礼物跑马灯底座
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF831843), // 深洋红
                                Color(0xFF312E81), // 赛博靛蓝
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 送礼者头像
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amber, width: 2),
                                  color: Colors.black38,
                                ),
                                child: Center(
                                  child: Text(senderAvatar, style: const TextStyle(fontSize: 20)),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 昵称与礼物详情
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    senderName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        isGlobal ? '献上全服盛典 ' : '向【$targetName】投掷 ',
                                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                                      ),
                                      Text(
                                        giftTitle,
                                        style: const TextStyle(
                                          color: Color(0xFFFDE047),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),

                              // 跑道端头礼物图标
                              Transform.translate(
                                offset: const Offset(4, 0),
                                child: Text(itemEmoji, style: const TextStyle(fontSize: 32)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 5. 抖音标志性 Combo × 连击暴击徽章
                        ScaleTransition(
                          scale: _comboScaleAnimation,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFEF08A), Color(0xFFF97316), Color(0xFFEF4444)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Combo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '×$combo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 28,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
