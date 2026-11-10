import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/sound/game_sound_service.dart';
import '../../main.dart';
import 'avatar_with_frame.dart';

/// 入场横幅视觉风格配置
class EntranceBannerConfig {
  final String bannerId;
  final String title;
  final String subtitle;
  final String defaultPunchline;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color glowColor;
  final String icon;

  const EntranceBannerConfig({
    required this.bannerId,
    required this.title,
    required this.subtitle,
    required this.defaultPunchline,
    required this.gradientColors,
    required this.borderColor,
    required this.glowColor,
    required this.icon,
  });

  static const EntranceBannerConfig dragon = EntranceBannerConfig(
    bannerId: 'BANNER_DRAGON',
    title: '🐉「凤舞龙吟」',
    subtitle: '神龙降世 · 凤舞九天',
    defaultPunchline: '神龙出海，凤舞龙吟！全场瞩目恭迎贵宾尊享入座！',
    gradientColors: [Color(0xFF991B1B), Color(0xFFB45309), Color(0xFF78350F), Color(0xFF451A03)],
    borderColor: Color(0xFFFBBF24),
    glowColor: Color(0xFFF59E0B),
    icon: '🐉',
  );

  static const EntranceBannerConfig emperor = EntranceBannerConfig(
    bannerId: 'BANNER_EMPEROR',
    title: '👑「君临天下」',
    subtitle: '紫气东来 · 万众臣服',
    defaultPunchline: '紫气东来，万众臣服！尊贵领袖君临全场！',
    gradientColors: [Color(0xFF581C87), Color(0xFF701A75), Color(0xFF831843), Color(0xFF3B0764)],
    borderColor: Color(0xFFE879F9),
    glowColor: Color(0xFFC084FC),
    icon: '👑',
  );

  static const EntranceBannerConfig shine = EntranceBannerConfig(
    bannerId: 'BANNER_SHINE',
    title: '✨「闪亮登场」',
    subtitle: '星光璀璨 · 万众聚焦',
    defaultPunchline: '全场星光璀璨，万众瞩目！闪亮登场！',
    gradientColors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF312E81), Color(0xFF0F172A)],
    borderColor: Color(0xFF38BDF8),
    glowColor: Color(0xFF38BDF8),
    icon: '✨',
  );

  static const EntranceBannerConfig def = EntranceBannerConfig(
    bannerId: 'BANNER_DEFAULT',
    title: '🚪「昂首入座」',
    subtitle: '聚会新星 · 气势不凡',
    defaultPunchline: '昂首阔步迈入游戏房间，欢聚一堂！',
    gradientColors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
    borderColor: Color(0xFF94A3B8),
    glowColor: Color(0xFF64748B),
    icon: '🚪',
  );

  static EntranceBannerConfig fromId(String? id) {
    switch (id) {
      case 'BANNER_DRAGON':
        return dragon;
      case 'BANNER_EMPEROR':
        return emperor;
      case 'BANNER_SHINE':
        return shine;
      default:
        return def;
    }
  }
}

/// 全局高质感炫酷入场横幅飘屏浮层
class EntranceBannerOverlay extends StatefulWidget {
  final String playerName;
  final String avatar;
  final String avatarFrame;
  final int vipLevel;
  final String bannerId;
  final String? punchline;
  final VoidCallback? onDismissed;

  const EntranceBannerOverlay({
    super.key,
    required this.playerName,
    required this.avatar,
    this.avatarFrame = 'FRAME_DEFAULT',
    this.vipLevel = 0,
    required this.bannerId,
    this.punchline,
    this.onDismissed,
  });

  // 全局唯一当前正在展示的横幅句柄，确保不堆叠
  static OverlayEntry? _currentEntry;
  static Timer? _activeTimer;

  /// 全局或局部弹窗显示入场横幅
  static void show(
    BuildContext? context, {
    required String playerName,
    required String avatar,
    String avatarFrame = 'FRAME_DEFAULT',
    int vipLevel = 0,
    required String bannerId,
    String? punchline,
  }) {
    // 播放登场高光音效
    GameSoundService().playVictory();

    // 清理先前已存在的横幅
    _dismissCurrent();

    OverlayState? overlay;
    if (context != null) {
      try {
        overlay = Overlay.of(context, rootOverlay: true);
      } catch (_) {}
    }
    overlay ??= PartyGameApp.navigatorKey.currentState?.overlay;

    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => EntranceBannerOverlay(
        playerName: playerName,
        avatar: avatar,
        avatarFrame: avatarFrame,
        vipLevel: vipLevel,
        bannerId: bannerId,
        punchline: punchline,
        onDismissed: () => _dismissCurrent(),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // 3.2秒后自动安全清理
    _activeTimer = Timer(const Duration(milliseconds: 3200), () {
      _dismissCurrent();
    });
  }

  static void _dismissCurrent() {
    _activeTimer?.cancel();
    _activeTimer = null;
    try {
      if (_currentEntry?.mounted == true) {
        _currentEntry?.remove();
      }
    } catch (_) {}
    _currentEntry = null;
  }

  @override
  State<EntranceBannerOverlay> createState() => _EntranceBannerOverlayState();
}

class _EntranceBannerOverlayState extends State<EntranceBannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideInAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<Offset> _slideOutAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 0 ~ 450ms: 强劲滑入弹性落定
    _slideInAnimation = Tween<Offset>(
      begin: const Offset(1.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOutBack),
      ),
    );

    // 0 ~ 300ms: 淡入
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.10, curve: Curves.easeIn),
      ),
    );

    // 450ms ~ 2400ms: 高光闪光带贯穿横扫
    _shimmerAnimation = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.80, curve: Curves.easeInOut),
      ),
    );

    // 2500ms ~ 3000ms: 向上/向左优雅退出并淡出
    _slideOutAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.3, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInBack),
      ),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = EntranceBannerConfig.fromId(widget.bannerId);
    final topPadding = MediaQuery.of(context).padding.top;
    final punchline = widget.punchline ?? cfg.defaultPunchline;

    return Positioned(
      top: topPadding + 12,
      left: 14,
      right: 14,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {
            widget.onDismissed?.call();
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // 综合入场与出场动画
              final isExiting = _controller.value >= 0.85;
              final currentOffset = isExiting ? _slideOutAnimation.value : _slideInAnimation.value;
              final currentOpacity = isExiting ? _fadeOutAnimation.value : _fadeInAnimation.value;

              return Transform.translate(
                offset: Offset(currentOffset.dx * MediaQuery.of(context).size.width, 0),
                child: Opacity(
                  opacity: currentOpacity.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 主横幅外层阴影与发光框
                Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: cfg.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cfg.borderColor, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: cfg.glowColor.withOpacity(0.55),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 1. 头像框与头像
                      AvatarWithFrame(
                        avatar: widget.avatar,
                        avatarFrame: widget.avatarFrame,
                        vipLevel: widget.vipLevel,
                        radius: 23,
                      ),
                      const SizedBox(width: 10),

                      // 2. 玩家名称、入场徽章与华丽欢迎语
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                // 横幅专属标签
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: cfg.borderColor.withOpacity(0.8), width: 0.8),
                                  ),
                                  child: Text(
                                    cfg.title,
                                    style: TextStyle(
                                      color: cfg.borderColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(color: cfg.glowColor, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // 玩家昵称
                                Flexible(
                                  child: Text(
                                    widget.playerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // VIP 角标
                                if (widget.vipLevel > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'VIP ${widget.vipLevel}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),

                            // 欢迎入场金句
                            Text(
                              punchline,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // 3. 右侧巨型动效图标徽章
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                          border: Border.all(color: cfg.borderColor.withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Text(
                            cfg.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 流光扫射效果层
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, _) {
                        return FractionallySizedBox(
                          widthFactor: 0.35,
                          alignment: Alignment(_shimmerAnimation.value, 0.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.28),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
