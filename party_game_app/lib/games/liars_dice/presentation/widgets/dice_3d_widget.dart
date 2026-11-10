import 'package:flutter/material.dart';

/// 3D 拟真质感骰子小部件
class Dice3DWidget extends StatelessWidget {
  final int value;
  final double size;
  final bool isHighlighted;
  final bool isDimmed;

  const Dice3DWidget({
    Key? key,
    required this.value,
    this.size = 46.0,
    this.isHighlighted = false,
    this.isDimmed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDimmed ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.amber.withOpacity(0.8)
                : Colors.black.withOpacity(0.25),
            blurRadius: isHighlighted ? 10 : 4,
            spreadRadius: isHighlighted ? 2 : 0,
            offset: const Offset(2, 3),
          ),
          if (!isDimmed)
            const BoxShadow(
              color: Colors.white70,
              blurRadius: 2,
              offset: Offset(-1, -1),
            ),
        ],
        border: Border.all(
          color: isHighlighted ? Colors.amber.shade700 : Colors.grey.shade400,
          width: isHighlighted ? 2.2 : 1.0,
        ),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _DiceFacePainter(value: value, isDimmed: isDimmed),
      ),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int value;
  final bool isDimmed;

  _DiceFacePainter({required this.value, required this.isDimmed});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaintRed = Paint()
      ..color = isDimmed ? Colors.grey : const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final dotPaintDark = Paint()
      ..color = isDimmed ? Colors.grey : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final dotRadius = w * 0.11;
    final bigDotRadius = w * 0.17; // 1 点为大红心

    final center = Offset(w * 0.5, h * 0.5);
    final topLeft = Offset(w * 0.26, h * 0.26);
    final topRight = Offset(w * 0.74, h * 0.26);
    final bottomLeft = Offset(w * 0.26, h * 0.74);
    final bottomRight = Offset(w * 0.74, h * 0.74);
    final midLeft = Offset(w * 0.26, h * 0.5);
    final midRight = Offset(w * 0.74, h * 0.5);

    switch (value) {
      case 1:
        canvas.drawCircle(center, bigDotRadius, dotPaintRed);
        break;
      case 2:
        canvas.drawCircle(topLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(bottomRight, dotRadius, dotPaintDark);
        break;
      case 3:
        canvas.drawCircle(topLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(center, dotRadius, dotPaintDark);
        canvas.drawCircle(bottomRight, dotRadius, dotPaintDark);
        break;
      case 4:
        // 传统中华红四点
        canvas.drawCircle(topLeft, dotRadius, dotPaintRed);
        canvas.drawCircle(topRight, dotRadius, dotPaintRed);
        canvas.drawCircle(bottomLeft, dotRadius, dotPaintRed);
        canvas.drawCircle(bottomRight, dotRadius, dotPaintRed);
        break;
      case 5:
        canvas.drawCircle(topLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(topRight, dotRadius, dotPaintDark);
        canvas.drawCircle(center, dotRadius, dotPaintRed);
        canvas.drawCircle(bottomLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(bottomRight, dotRadius, dotPaintDark);
        break;
      case 6:
        canvas.drawCircle(topLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(topRight, dotRadius, dotPaintDark);
        canvas.drawCircle(midLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(midRight, dotRadius, dotPaintDark);
        canvas.drawCircle(bottomLeft, dotRadius, dotPaintDark);
        canvas.drawCircle(bottomRight, dotRadius, dotPaintDark);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDimmed != isDimmed;
  }
}
