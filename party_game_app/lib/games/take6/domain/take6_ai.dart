import 'dart:math';
import 'take6_card.dart';
import 'take6_row.dart';

/// 谁是牛头王 - 单机智能 AI 决策算法 (启发式与风险规避模型)
class Take6Ai {
  /// AI 挑选最佳出牌
  static Take6Card decideCardToPlay({
    required String aiPlayerId,
    required List<Take6Card> hand,
    required List<Take6Row> rows,
    required String personality, // 'BALANCED', 'AGGRESSIVE', 'CONSERVATIVE'
  }) {
    if (hand.isEmpty) throw ArgumentError('Hand cannot be empty');
    if (hand.length == 1) return hand.first;

    // 针对不同手牌计算入行安全性打分 (Score 越低代表危险度越低)
    Take6Card? bestCard;
    double bestScore = double.infinity;

    for (final card in hand) {
      final score = _evaluateCardRisk(card, rows, hand.length, personality);
      if (score < bestScore) {
        bestScore = score;
        bestCard = card;
      }
    }

    return bestCard ?? hand.first;
  }

  /// AI 在必须收走一行时，挑选牛头最少的一行收走
  static int decideRowToTake({
    required List<Take6Row> rows,
  }) {
    int minBullheads = 99999;
    int bestRow = 0;

    for (int i = 0; i < rows.length; i++) {
      final bh = rows[i].totalBullheads;
      if (bh < minBullheads) {
        minBullheads = bh;
        bestRow = i;
      }
    }

    return bestRow;
  }

  static double _evaluateCardRisk(
    Take6Card card,
    List<Take6Row> rows,
    int remainingCardsCount,
    String personality,
  ) {
    // 找出该牌若直接入行，会进哪一行
    int bestRowIndex = -1;
    int minDiff = 9999;

    for (int i = 0; i < rows.length; i++) {
      final diff = card.number - rows[i].lastCard.number;
      if (diff > 0 && diff < minDiff) {
        minDiff = diff;
        bestRowIndex = i;
      }
    }

    // 情况 1: 比所有行尾牌都小
    if (bestRowIndex == -1) {
      // 必须吃行！评估桌面上牛头最少的那行
      int minRowBulls = rows.map((r) => r.totalBullheads).reduce(min);
      // 若当前桌面最少行的牛头数非常小 (如仅 1~2 个牛头)，主动送掉小牌并不算太坏
      if (minRowBulls <= 2) {
        return 15.0 + minRowBulls;
      }
      return 60.0 + minRowBulls * 5.0; // 较危险
    }

    final targetRow = rows[bestRowIndex];
    final currentCount = targetRow.count;

    // 情况 2: 直接成为第 6 张牌放爆！
    if (currentCount >= 5) {
      return 100.0 + targetRow.totalBullheads * 10.0;
    }

    // 情况 3: 放入后未爆 (第 2~5 张)
    // 剩余坑位 = 5 - currentCount (例如已有4张，剩1个坑位)
    final remainingSlots = 5 - currentCount;

    // 差值越小越安全 (因为其他人在你前面的空间小)
    double diffRisk = minDiff * 1.2;

    // 坑位越少，被别人抢先挤爆的风险越高
    double slotRisk = (5 - remainingSlots) * 8.0;

    // 保守型加重对爆行的顾忌
    if (personality == 'CONSERVATIVE') {
      slotRisk *= 1.5;
    }

    return diffRisk + slotRisk + card.bullheads * 2.0;
  }
}
