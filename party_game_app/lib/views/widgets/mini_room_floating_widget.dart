import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';

/// 全局常驻最小化房间悬浮挂件 (Mini Room Floating Widget)
/// 当玩家在游戏中点击“最小化”时，无论切换到大厅、广场、潮友圈还是好友页，
/// 均可在屏幕右下侧看到此挂件，轻点一键无缝重返对决！
class MiniRoomFloatingWidget extends StatefulWidget {
  const MiniRoomFloatingWidget({Key? key}) : super(key: key);

  @override
  State<MiniRoomFloatingWidget> createState() => _MiniRoomFloatingWidgetState();
}

class _MiniRoomFloatingWidgetState extends State<MiniRoomFloatingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = Provider.of<RoomProvider>(context);
    final session = roomProv.activeSession;

    if (session == null || !session.isMinimized) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            roomProv.restoreActiveSession();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => session.screenBuilder(ctx)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 动态呼吸指示灯 + 游戏图标
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Text(session.gameIcon, style: const TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          session.gameTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${session.roomCode}',
                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.play_circle_fill, color: Color(0xFF10B981), size: 10),
                        SizedBox(width: 3),
                        Text(
                          '对局进行中 · 点此重返',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // 快速关闭/认输按钮
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.cardSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('退出对局', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        content: const Text('退出房间后将结束当前对局，确定要退出吗？', style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('继续游戏', style: TextStyle(color: AppColors.primary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              final authUser = Provider.of<AuthProvider>(context, listen: false).user;
                              roomProv.leaveRoom(authUser?.id, session.roomCode);
                            },
                            child: const Text('确定退出'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 14),
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
