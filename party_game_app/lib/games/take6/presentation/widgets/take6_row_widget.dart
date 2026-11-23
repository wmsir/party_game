import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/take6_row.dart';
import 'take6_card_widget.dart';

/// 谁是牛头王 - 单移行牌台面渲染组件
class Take6RowWidget extends StatelessWidget {
  final Take6Row row;
  final bool isSelectableToTake;
  final bool isRecommendedRow;
  final VoidCallback? onSelectRow;
  final String? previewBadge;
  final Color? previewHighlightColor;

  const Take6RowWidget({
    super.key,
    required this.row,
    this.isSelectableToTake = false,
    this.isRecommendedRow = false,
    this.onSelectRow,
    this.previewBadge,
    this.previewHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = row.count >= 4;
    final isFullOverflowWarning = row.count >= 5;
    final isDark = AppColors.isDarkMode(context);
    final hasPreview = !isSelectableToTake && previewHighlightColor != null;

    return GestureDetector(
      onTap: isSelectableToTake ? () {
        HapticFeedback.mediumImpact();
        onSelectRow?.call();
      } : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelectableToTake
              ? (isRecommendedRow
                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.14)
                  : const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12))
              : (hasPreview
                  ? previewHighlightColor!.withValues(alpha: isDark ? 0.18 : 0.10)
                  : (isFullOverflowWarning
                      ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.20 : 0.12)
                      : AppColors.adaptiveElevated(context).withValues(alpha: 0.55))),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelectableToTake
                ? (isRecommendedRow ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                : (hasPreview
                    ? previewHighlightColor!
                    : (isFullOverflowWarning
                        ? const Color(0xFFEF4444)
                        : (isDanger ? const Color(0xFFF59E0B) : AppColors.adaptiveBorder(context)))),
            width: isSelectableToTake || hasPreview ? 2.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // 行标号与本行牛头累计
            Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelectableToTake
                    ? const Color(0xFFD97706)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${row.rowIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '🐮${row.totalBullheads}',
                    style: const TextStyle(
                      color: Color(0xFFFCD34D),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 行牌 5 格卡槽 (自适应屏幕宽度，小屏不溢出)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 4.0;
                  final cardW = ((constraints.maxWidth - gap * 4) / 5).clamp(30.0, 52.0);
                  final cardH = (cardW * 64 / 46).clamp(44.0, 72.0);
                  return Row(
                    children: List.generate(5, (slotIndex) {
                      final rightPad = slotIndex < 4 ? gap : 0.0;
                      final hasCard = slotIndex < row.cards.length;
                      if (hasCard) {
                        final card = row.cards[slotIndex];
                        return Padding(
                          padding: EdgeInsets.only(right: rightPad),
                          child: Take6CardWidget(
                            key: ValueKey('row-${row.rowIndex}-slot-$slotIndex-${card.number}'),
                            card: card,
                            width: cardW,
                            height: cardH,
                          ),
                        );
                      } else {
                        // 空卡槽 (第 5 格标红预警)
                        final isFifthSlot = slotIndex == 4;
                        return Padding(
                          padding: EdgeInsets.only(right: rightPad),
                          child: Container(
                            width: cardW,
                            height: cardH,
                            decoration: BoxDecoration(
                              color: isFifthSlot
                                  ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.20 : 0.14)
                                  : AppColors.adaptiveCard(context).withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFifthSlot
                                    ? const Color(0xFFFCA5A5)
                                    : AppColors.adaptiveBorder(context),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isFifthSlot ? '⚠️5' : '${slotIndex + 1}',
                                style: TextStyle(
                                  color: isFifthSlot
                                      ? const Color(0xFFEF4444)
                                      : AppColors.adaptiveTextMuted(context),
                                  fontSize: cardW < 38 ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }),
                  );
                },
              ),
            ),

            if (!isSelectableToTake && previewBadge != null && previewHighlightColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: previewHighlightColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  previewBadge!,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),

            if (isSelectableToTake)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isRecommendedRow
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecommendedRow
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withOpacity(0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRecommendedRow) ...[
                      const Icon(Icons.shield_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      isRecommendedRow
                          ? '推荐(🐮${row.totalBullheads})'
                          : '吃此行(🐮${row.totalBullheads})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
