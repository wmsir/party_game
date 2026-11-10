import 'package:flutter/material.dart';

/// QQ 会员风格统一 VIP 徽章与昵称样式工具
class VipBadgeWidget extends StatelessWidget {
  final int vipLevel;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final bool? isCrown;
  final bool showIfZero;

  const VipBadgeWidget({
    super.key,
    required this.vipLevel,
    this.fontSize = 9.5,
    this.padding,
    this.isCrown,
    this.showIfZero = true,
  });

  @override
  Widget build(BuildContext context) {
    if (vipLevel <= 0 && !showIfZero) return const SizedBox.shrink();
    final bool isV10 = vipLevel >= 10;
    final bool isSvip = isCrown ?? (vipLevel >= 4);
    final bool isVip = vipLevel > 0;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: isV10
            ? const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : (isSvip
                ? const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : (isVip
                    ? const LinearGradient(
                        colors: [Color(0xFFE60012), Color(0xFFC7000B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF374151), Color(0xFF1F2937)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ))),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isV10
              ? const Color(0xFFFDE047)
              : (isVip ? const Color(0xFFFFD700) : const Color(0xFFF59E0B)),
          width: isV10 ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isV10
                    ? const Color(0xFFDB2777)
                    : (isSvip
                        ? const Color(0xFFEF4444)
                        : (isVip ? const Color(0xFFE60012) : const Color(0xFFF59E0B))))
                .withAlpha(isVip ? 140 : 60),
            blurRadius: isV10 ? 6 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(isV10 ? '✨' : '👑', style: const TextStyle(fontSize: 8.5)),
          const SizedBox(width: 2),
          Text(
            isV10
                ? 'V10 无双'
                : (isSvip
                    ? 'SVIP $vipLevel'
                    : (isVip ? 'VIP $vipLevel' : 'VIP 0')),
            style: TextStyle(
              color: isVip ? Colors.white : const Color(0xFFFDE68A),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取会员昵称颜色：V10 无双流金，SVIP 绯红微光，VIP 专属红
  static Color getNicknameColor(int vipLevel, {Color defaultColor = Colors.white}) {
    if (vipLevel >= 10) return const Color(0xFFF59E0B);
    if (vipLevel >= 4) return const Color(0xFFFF2E4D);
    if (vipLevel > 0) return const Color(0xFFE60012);
    return defaultColor;
  }
}
