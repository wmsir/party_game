import 'package:flutter/material.dart';
import '../../domain/take6_card.dart';

/// 谁是牛头王 - 单张纸牌精致渲染组件
class Take6CardWidget extends StatelessWidget {
  final Take6Card? card;
  final bool isFaceDown;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const Take6CardWidget({
    super.key,
    this.card,
    this.isFaceDown = false,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
    this.width = 54,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) {
    if (isFaceDown || card == null) {
      return _buildFaceDownCard();
    }

    final c = card!;
    final colorScheme = _getCardColorScheme(c.bullheads);

    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(0, isSelected ? -8 : 0),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : (isHighlighted ? const Color(0xFFEF4444) : colorScheme.border),
              width: isSelected || isHighlighted ? 2.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFFF59E0B).withOpacity(0.4)
                    : Colors.black.withOpacity(0.12),
                blurRadius: isSelected ? 8 : 4,
                offset: Offset(0, isSelected ? 4 : 2),
              )
            ],
          ),
        child: Stack(
          children: [
            // 四周点缀牛头小图标
            Positioned(
              top: 3,
              left: 4,
              child: _buildMiniBullhead(c.bullheads, colorScheme.accent),
            ),
            Positioned(
              bottom: 3,
              right: 4,
              child: _buildMiniBullhead(c.bullheads, colorScheme.accent),
            ),

            // 居中大号牌面数字
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.number}',
                    style: TextStyle(
                      fontSize: width * 0.36,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.text,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 牛头徽标数
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: colorScheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🐮x${c.bullheads}',
                      style: TextStyle(
                        fontSize: width * 0.18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFaceDownCard() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.65,
          height: height * 0.65,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text('🐮', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBullhead(int bulls, Color color) {
    return Text(
      '🐮',
      style: TextStyle(fontSize: width * 0.16),
    );
  }

  _CardTheme _getCardColorScheme(int bullheads) {
    switch (bullheads) {
      case 7: // 55 号超级大牛
        return _CardTheme(
          background: const Color(0xFFFEF2F2),
          border: const Color(0xFFF87171),
          text: const Color(0xFF991B1B),
          accent: const Color(0xFFDC2626),
        );
      case 5: // 对子牌 (11, 22, 33...)
        return _CardTheme(
          background: const Color(0xFFFAF5FF),
          border: const Color(0xFFC084FC),
          text: const Color(0xFF581C87),
          accent: const Color(0xFF9333EA),
        );
      case 3: // 10 的倍数
        return _CardTheme(
          background: const Color(0xFFFFFBEB),
          border: const Color(0xFFFCD34D),
          text: const Color(0xFF78350F),
          accent: const Color(0xFFD97706),
        );
      case 2: // 5 的倍数
        return _CardTheme(
          background: const Color(0xFFECFDF5),
          border: const Color(0xFF6EE7B7),
          text: const Color(0xFF065F46),
          accent: const Color(0xFF059669),
        );
      default: // 普通 1 头牌
        return _CardTheme(
          background: const Color(0xFFFFFFFF),
          border: const Color(0xFFCBD5E1),
          text: const Color(0xFF1E293B),
          accent: const Color(0xFF0284C7),
        );
    }
  }
}

class _CardTheme {
  final Color background;
  final Color border;
  final Color text;
  final Color accent;

  _CardTheme({
    required this.background,
    required this.border,
    required this.text,
    required this.accent,
  });
}
