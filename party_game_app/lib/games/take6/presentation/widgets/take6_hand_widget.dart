import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/take6_card.dart';
import 'take6_card_widget.dart';

/// 谁是牛头王 - 玩家手牌托盘组件
class Take6HandWidget extends StatelessWidget {
  final List<Take6Card> handCards;
  final Take6Card? selectedCard;
  final bool canPlay;
  final bool hasCommitted;
  final bool isAutoPlay;
  final VoidCallback? onToggleAutoPlay;
  final ValueChanged<Take6Card> onCardSelected;
  final VoidCallback onConfirmPlay;

  const Take6HandWidget({
    super.key,
    required this.handCards,
    required this.selectedCard,
    required this.canPlay,
    this.hasCommitted = false,
    this.isAutoPlay = false,
    this.onToggleAutoPlay,
    required this.onCardSelected,
    required this.onConfirmPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部手牌提示与确认出牌操作栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '🎴 我的手牌',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${handCards.length} 张',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🤖 智能托管与取消托管按钮 (紧邻出牌按钮)
                  if (onToggleAutoPlay != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: onToggleAutoPlay,
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                          decoration: BoxDecoration(
                            color: isAutoPlay ? const Color(0xFFD97706) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAutoPlay ? const Color(0xFFB45309) : const Color(0xFFFCD34D),
                              width: 1.2,
                            ),
                            boxShadow: isAutoPlay
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAutoPlay ? Icons.smart_toy : Icons.smart_toy_outlined,
                                size: 15,
                                color: isAutoPlay ? Colors.white : const Color(0xFF92400E),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAutoPlay ? '取消托管' : '智能托管',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isAutoPlay ? Colors.white : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: canPlay && selectedCard != null ? () {
                      HapticFeedback.lightImpact();
                      onConfirmPlay();
                    } : null,
                    icon: Icon(
                      hasCommitted
                          ? Icons.check_circle_rounded
                          : (selectedCard != null ? Icons.send_rounded : Icons.lock_clock_rounded),
                      size: 16,
                    ),
                    label: Text(
                      hasCommitted
                          ? '已暗扣'
                          : (selectedCard != null ? '出 [${selectedCard!.number}]' : '暗扣出牌'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: hasCommitted
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFCBD5E1),
                      disabledForegroundColor: hasCommitted
                          ? const Color(0xFF065F46)
                          : Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: selectedCard != null && canPlay ? 3 : 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 水平平铺手牌
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: handCards.length,
              itemBuilder: (context, index) {
                final card = handCards[index];
                final isSelected = selectedCard == card;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Take6CardWidget(
                    key: ValueKey('hand-card-${card.number}'),
                    card: card,
                    width: 52,
                    height: 74,
                    isSelected: isSelected,
                    onTap: canPlay ? () {
                      HapticFeedback.selectionClick();
                      onCardSelected(card);
                    } : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
