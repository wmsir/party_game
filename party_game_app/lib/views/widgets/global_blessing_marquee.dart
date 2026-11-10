import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/global_blessing_model.dart';
import '../../providers/chat_provider.dart';
import '../../core/sound/game_sound_service.dart';

/// 奢华全服横向滚动祝福跑马灯 (全局顶层浮层，不阻挡点击交互)
class GlobalBlessingMarquee extends StatefulWidget {
  const GlobalBlessingMarquee({super.key});

  @override
  State<GlobalBlessingMarquee> createState() => _GlobalBlessingMarqueeState();
}

class _GlobalBlessingMarqueeState extends State<GlobalBlessingMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  GlobalBlessingModel? _displayingBlessing;
  bool _isShowing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _triggerShow(GlobalBlessingModel blessing, ChatProvider chatProv) {
    if (!mounted || _isShowing) return;
    _isShowing = true;
    setState(() {
      _displayingBlessing = blessing;
    });

    _slideController.forward(from: 0.0);
    try {
      GameSoundService().playVictory();
    } catch (_) {}

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 6800), () {
      if (!mounted) {
        _isShowing = false;
        chatProv.finishCurrentBlessing();
        return;
      }
      _slideController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _displayingBlessing = null;
          _isShowing = false;
        });
        chatProv.finishCurrentBlessing();
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _displayingBlessing = null;
          _isShowing = false;
        });
        chatProv.finishCurrentBlessing();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 10,
      right: 10,
      child: Consumer<ChatProvider>(
        builder: (context, chatProv, _) {
          final current = chatProv.currentBlessing;

          if (current != null && !_isShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isShowing) {
                _triggerShow(current, chatProv);
              }
            });
          }

          final effectiveBlessing = _displayingBlessing ?? current;
          if (effectiveBlessing == null) {
            return const SizedBox.shrink();
          }

          return Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(
                ignoring: false,
                child: SlideTransition(
                  position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2E1038), // 尊贵深紫
                          Color(0xFF1E102E), // 暗夜紫黑
                          Color(0xFF3B1E08), // 金珀暖棕
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withOpacity(0.55),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 上层：发射图标、VIP标、发送者昵称、横幅标签
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  effectiveBlessing.itemEmoji.isNotEmpty ? effectiveBlessing.itemEmoji : '📢',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (effectiveBlessing.senderVip > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'V${effectiveBlessing.senderVip}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                effectiveBlessing.senderName.isNotEmpty ? effectiveBlessing.senderName : '神秘玩家',
                                style: const TextStyle(
                                  color: Color(0xFFFEF08A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 4),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '播报全服祝福：',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.8),
                              ),
                              child: Text(
                                effectiveBlessing.giftTitle.isNotEmpty ? effectiveBlessing.giftTitle : '全服喇叭',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 下层：水平滚动的跑马灯内容
                        SizedBox(
                          height: 22,
                          child: _MarqueeTextTicker(
                            key: ValueKey('${effectiveBlessing.id}_${effectiveBlessing.blessing}'),
                            text: effectiveBlessing.blessing,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}

/// 匀速平滑自右向左滚动的跑马灯文字组件
class _MarqueeTextTicker extends StatefulWidget {
  final String text;
  const _MarqueeTextTicker({super.key, required this.text});

  @override
  State<_MarqueeTextTicker> createState() => _MarqueeTextTickerState();
}

class _MarqueeTextTickerState extends State<_MarqueeTextTicker> {
  late ScrollController _scrollController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScrolling();
    });
  }

  void _startScrolling() async {
    while (!_isDisposed && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isDisposed || !mounted) break;
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final durationMs = (maxExtent * 45).clamp(2500, 7500).toInt();
        try {
          await _scrollController.animateTo(
            maxExtent,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.linear,
          );
        } catch (_) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 400));
        if (_isDisposed || !mounted || !_scrollController.hasClients) break;
        _scrollController.jumpTo(0.0);
      } else {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0.5, 1.0)),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Text(
            '📢 ${widget.text}',
            style: const TextStyle(
              color: Color(0xFFFEF08A),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0.5, 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
