import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 商业化个性头像框装饰组件
/// 支持：聚会新星框、赛博流光框、荣耀黄金框、星空霸主框、黑金至尊帝王框 + VIP 尊贵小角标
class AvatarWithFrame extends StatelessWidget {
  final String avatar;
  final String avatarFrame;
  final int vipLevel;
  final double radius;
  final VoidCallback? onTap;
  final bool showVipBadge;

  const AvatarWithFrame({
    super.key,
    required this.avatar,
    this.avatarFrame = 'FRAME_DEFAULT',
    this.vipLevel = 0,
    this.radius = 26,
    this.onTap,
    this.showVipBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 边框容器
          _buildFrameContainer(),

          // VIP 尊贵角标 (右下角，仅在明确指定 showVipBadge 为 true 时展示，避免与主标题处 VIP 图标重复)
          if (showVipBadge && vipLevel > 0)
            Positioned(
              right: -3,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  gradient: vipLevel >= 4
                      ? const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE60012), Color(0xFFC7000B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFFFD700), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: (vipLevel >= 4 ? const Color(0xFFEF4444) : const Color(0xFFE60012)).withAlpha(140),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vipLevel >= 4) ...[
                      const Text('👑', style: TextStyle(fontSize: 7)),
                      const SizedBox(width: 1),
                    ],
                    Text(
                      vipLevel >= 4 ? 'SVIP$vipLevel' : 'V$vipLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return child;
  }

  Widget _buildFrameContainer() {
    final size = radius * 2;

    switch (avatarFrame) {
      case 'FRAME_NEON':
        // 赛博流光框：青紫霓虹渐变与光晕
        return Container(
          width: size + 8,
          height: size + 8,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF06B6D4).withAlpha(100), blurRadius: 6, spreadRadius: 1),
            ],
          ),
          child: _buildAvatarCircle(),
        );

      case 'FRAME_GOLD':
        // 荣耀黄金框：金色双环与金芒
        return Container(
          width: size + 8,
          height: size + 8,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFB45309)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF59E0B).withAlpha(120), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: _buildAvatarCircle(),
        );

      case 'FRAME_GALAXY_DOMINATOR':
        // 星空霸主框：深邃蓝紫与星辰光环
        return Container(
          width: size + 10,
          height: size + 10,
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFF38BDF8)],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF818CF8).withAlpha(140), blurRadius: 10, spreadRadius: 1.5),
            ],
          ),
          child: _buildAvatarCircle(),
        );

      case 'FRAME_BLACK_GOLD_ROYAL':
        // 黑金至尊帝王框：霸气黑金龙纹与皇冠尊贵
        return Container(
          width: size + 12,
          height: size + 12,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFFF59E0B), Color(0xFF0F172A), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.amber.withAlpha(160), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: _buildAvatarCircle(),
        );

      case 'FRAME_DEFAULT':
      default:
        // 初始新星框
        return Container(
          width: size + 4,
          height: size + 4,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(60), width: 1.5),
          ),
          child: _buildAvatarCircle(),
        );
    }
  }

  Widget _buildAvatarCircle() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.bgElevated,
      child: Text(avatar, style: TextStyle(fontSize: radius * 1.05)),
    );
  }
}
