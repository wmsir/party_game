import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/room_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../views/chat/widgets/interactive_throw_overlay.dart';
import '../../../views/widgets/entrance_banner_overlay.dart';
import '../../../views/widgets/in_game_throw_dialog.dart';
import '../../../views/widgets/game_settlement_dialog.dart';
import '../domain/party_wheel_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/sound/game_sound_service.dart';

class PartyWheelScreen extends StatefulWidget {
  const PartyWheelScreen({Key? key}) : super(key: key);

  @override
  State<PartyWheelScreen> createState() => _PartyWheelScreenState();
}

class _PartyWheelScreenState extends State<PartyWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0;
  bool _isSpinning = false;
  WheelSegment? _selectedSegment;

  final List<WheelSegment> _segments = List.from(PartyWheelModel.defaultSegments);

  // AI 托管自动旋转模式
  bool _isAutoPlay = false;
  Timer? _autoPlayTimer;

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    if (_isAutoPlay) {
      if (!_isSpinning) {
        _spinWheel();
      }
    } else {
      _autoPlayTimer?.cancel();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAutoPlay ? '🤖 已开启【自动连转托管】：大转盘将自动定时为您转动破冰！' : '👤 已取消自动转动'),
        backgroundColor: _isAutoPlay ? const Color(0xFFEC4899) : const Color(0xFF475569),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scheduleNextAutoSpin() {
    if (!_isAutoPlay) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_isAutoPlay) return;
      if (!_isSpinning) {
        _spinWheel();
      }
    });
  }

  void _minimizeRoom() {
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    roomProv.registerActiveSession(
      ActiveRoomSession(
        roomCode: 'WHEEL-1',
        gameType: 'party_wheel',
        gameTitle: '聚会大转盘',
        gameIcon: '🎡',
        isMinimized: true,
        screenBuilder: (_) => const PartyWheelScreen(),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗗 房间已最小化至右侧悬浮窗，可在任意页面随时点击恢复！'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFEC4899),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    GameSoundService().playGameBgm('party_wheel');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        EntranceBannerOverlay.show(
          context,
          playerName: user.nickname,
          avatar: user.avatar,
          avatarFrame: user.avatarFrame,
          vipLevel: user.vipLevel,
          bannerId: user.entranceBanner,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    GameSoundService().stopBgm();
    _controller.dispose();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearThrowEvent();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);
      final roomProv = context.read<RoomProvider>();
      if (!roomProv.hasMinimizedRoom) {
        final user = context.read<AuthProvider>().user;
        roomProv.leaveRoom(user?.id, 'WHEEL-1');
      }
    } catch (_) {}
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _selectedSegment = null;
    });

    GameSoundService().playDiceShake();

    final random = Random();
    // 旋转 5 到 8 圈 + 随机偏移角
    final extraSpins = 5 + random.nextInt(4);
    final targetAngle = _currentAngle + (extraSpins * 2 * pi) + (random.nextDouble() * 2 * pi);

    final startAngle = _currentAngle;
    int lastTickSegment = -1;
    _animation = Tween<double>(
      begin: startAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ))..addListener(() {
      setState(() {
        _currentAngle = _animation.value;
      });
      final currentSeg = (_currentAngle / ((2 * pi) / _segments.length)).floor();
      if (currentSeg != lastTickSegment) {
        lastTickSegment = currentSeg;
        GameSoundService().playWheelTick();
      }
    })..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isSpinning = false;
        GameSoundService().playVictory();
        _calculateResult();
        _scheduleNextAutoSpin();
      }
    });

    _controller.forward(from: 0.0);
  }

  void _calculateResult() {
    // 指针固定在顶部 (3 * pi / 2)
    final normalizedAngle = (3 * pi / 2 - _currentAngle) % (2 * pi);
    final positiveAngle = normalizedAngle < 0 ? normalizedAngle + 2 * pi : normalizedAngle;
    final segmentAngle = (2 * pi) / _segments.length;
    final index = (positiveAngle / segmentAngle).floor() % _segments.length;

    final segment = _segments[index];
    setState(() {
      _selectedSegment = segment;
    });

    GameSoundService().playVictory();

    // 聚会大转盘转动结算排位分与金币
    try {
      context.read<AuthProvider>().settleRankMatch(true, gameType: 'party_wheel');
    } catch (_) {}

    if (segment.type == 'TRUTH') {
      final randIdx = Random().nextInt(PartyWheelModel.truthQuestions.length);
      _showQuestionDialog('真心话考验 💬', PartyWheelModel.truthQuestions[randIdx], segment.color);
    } else if (segment.type == 'DARE') {
      final randIdx = Random().nextInt(PartyWheelModel.dareChallenges.length);
      _showQuestionDialog('大冒险挑战 🎭', PartyWheelModel.dareChallenges[randIdx], segment.color);
    } else {
      _showNormalResultDialog(segment);
    }
  }

  void _showQuestionDialog(String title, String content, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.psychology, color: color),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                content,
                style: const TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            const Text('注：必须如实回答或认真完成，否则自罚一杯！', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.military_tech_outlined, size: 16),
            label: const Text('结算收益'),
            onPressed: () {
              Navigator.pop(ctx);
              GameSettlementDialog.show(
                context,
                isWin: true,
                gameTitle: '聚会大转盘',
                gameIcon: '🎡',
                subtitle: '🎡 勇敢接受大挑战，为全场带来阵阵欢笑！',
                onPlayAgain: () => _spinWheel(),
                onExit: () => Navigator.pop(context),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('已完成挑战！'),
          ),
        ],
      ),
    );
  }

  void _showNormalResultDialog(WheelSegment segment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              segment.type == 'LUCKY' ? '🎉 恭喜！' : '🍺 聚会惩罚',
              style: TextStyle(fontSize: 16, color: segment.color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              segment.text,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.military_tech_outlined, size: 16),
                  label: const Text('收益明细'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    GameSettlementDialog.show(
                      context,
                      isWin: true,
                      gameTitle: '聚会大转盘',
                      gameIcon: '🎡',
                      subtitle: '🎡 转出【${segment.text}】，聚会气氛拉满！',
                      onPlayAgain: () => _spinWheel(),
                      onExit: () => Navigator.pop(context),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: segment.color, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('收到，执行！'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎡 聚会大转盘 · 玩法规则', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1️⃣ 点击中央【开始旋转】或底部按钮，物理惯性转盘将随机落定惩罚或互动指令。', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5)),
            SizedBox(height: 8),
            Text('2️⃣ 转中【真心话】或【大冒险】将自动弹出精选辛辣题库，拒绝回答或挑战失败需按酒桌规矩受罚。', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5)),
            SizedBox(height: 8),
            Text('3️⃣ 点击顶部🤖【自动连转】可开启定时自动旋转，聚会破冰解放双手！', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('明白，开转！'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('离开房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('您可以选择【最小化挂起】对局（可随时点击悬浮窗返回），或【强制退出】彻底离开当前房间。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _minimizeRoom();
            },
            child: const Text('🗗 最小化挂起', style: TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final user = Provider.of<AuthProvider>(context, listen: false).user;
              final roomProv = Provider.of<RoomProvider>(context, listen: false);
              roomProv.leaveRoom(user?.id, 'WHEEL-1');
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('🚪 强制退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wheelDiameter = min(size.width - 48, 340.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF18181B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFF1F5F9), size: 18),
            tooltip: '返回或最小化',
            onPressed: _showExitDialog,
          ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎡 聚会大冒险大转盘', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            if (_isAutoPlay) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFEC4899)),
                ),
                child: const Text(
                  '自动连转中',
                  style: TextStyle(color: Color(0xFFDB2777), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          // 投掷互动道具
          IconButton(
            icon: const Icon(Icons.celebration, color: Color(0xFFF59E0B)),
            tooltip: '投掷互动道具',
            onPressed: () {
              final roomProv = Provider.of<RoomProvider>(context, listen: false);
              final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
              final players = roomProv.currentRoom?.players ?? [];
              final targetPlayers = players.where((p) => p.id != currentUserId).toList();
              if (targetPlayers.isNotEmpty) {
                InGameThrowDialog.show(
                  context,
                  targetPlayerId: targetPlayers.first.id,
                  targetPlayerName: targetPlayers.first.name,
                );
              } else {
                InGameThrowDialog.show(
                  context,
                  targetPlayerId: 'all',
                  targetPlayerName: '全场玩家',
                );
              }
            },
          ),
          // 智能自动连转/托管按钮
          IconButton(
            icon: Icon(
              _isAutoPlay ? Icons.smart_toy : Icons.smart_toy_outlined,
              color: _isAutoPlay ? const Color(0xFFEC4899) : const Color(0xFF94A3B8),
            ),
            tooltip: _isAutoPlay ? '取消自动连转' : '开启自动连转托管',
            onPressed: _toggleAutoPlay,
          ),
          // 房间最小化按钮
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_outlined, color: Color(0xFF94A3B8)),
            tooltip: '最小化房间',
            onPressed: _minimizeRoom,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF94A3B8)),
            tooltip: '玩法规则',
            onPressed: _showRulesDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 自动托管状态高亮横幅
              if (_isAutoPlay)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCE7F3),
                    border: Border(bottom: BorderSide(color: Color(0xFFFBCFE8))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.smart_toy, color: Color(0xFFDB2777), size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'AI 自动连转托管中：每隔几秒自动开启下一轮大冒险',
                        style: TextStyle(color: Color(0xFF9D174D), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _toggleAutoPlay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDB2777),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('取消自动', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                '聚会酒桌神器 · 告别冷场尴尬',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // 转盘区域
              Center(
                child: SizedBox(
                  width: wheelDiameter + 30,
                  height: wheelDiameter + 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 外圈光晕发光装饰底盘
                      Container(
                        width: wheelDiameter + 24,
                        height: wheelDiameter + 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      // 转盘本体
                      Transform.rotate(
                        angle: _currentAngle,
                        child: CustomPaint(
                          size: Size(wheelDiameter, wheelDiameter),
                          painter: _WheelPainter(segments: _segments),
                        ),
                      ),

                      // 顶部固定指针 (朝下指向转盘)
                      Positioned(
                        top: 2,
                        child: CustomPaint(
                          size: const Size(28, 36),
                          painter: _PointerPainter(),
                        ),
                      ),

                      // 中心旋转按钮
                      GestureDetector(
                        onTap: _isSpinning ? null : _spinWheel,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _isSpinning ? '旋转中' : '开始\n旋转',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 当前选中项卡片
              if (_selectedSegment != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _selectedSegment!.color, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars, color: _selectedSegment!.color),
                      const SizedBox(width: 8),
                      Text(
                        '本轮落定：${_selectedSegment!.text}',
                        style: TextStyle(
                          color: _selectedSegment!.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // 底部控制按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpinning ? Colors.grey : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: Text(
                      _isSpinning ? '好运落定中...' : '立即旋转转盘',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSpinning ? null : _spinWheel,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      Consumer<ChatProvider>(
        builder: (context, chat, _) => InteractiveThrowOverlay(
          event: chat.lastThrowEvent,
          onComplete: () => chat.clearThrowEvent(),
        ),
      ),
    ],
  ),
),
);
}
}

class _WheelPainter extends CustomPainter {
  final List<WheelSegment> segments;

  _WheelPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * pi) / segments.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < segments.length; i++) {
      paint.color = segments[i].color;
      final startAngle = i * sweepAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // 绘制文字
      canvas.save();
      final textAngle = startAngle + sweepAngle / 2;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textSpan = TextSpan(
        text: segments[i].text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(radius * 0.45, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);

    // 内部高光小三角
    final highlightPaint = Paint()..color = Colors.white70;
    final highlightPath = Path()
      ..moveTo(size.width * 0.3, 2)
      ..lineTo(size.width * 0.7, 2)
      ..lineTo(size.width / 2, size.height * 0.6)
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
