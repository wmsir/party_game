import 'take6_card.dart';

/// 谁是牛头王 - 桌面单一行牌领域模型
class Take6Row {
  final int rowIndex;
  final List<Take6Card> cards;

  Take6Row({
    required this.rowIndex,
    List<Take6Card>? cards,
  }) : cards = cards ?? [];

  /// 获取当前行末尾牌 (即该行当前最大值)
  Take6Card get lastCard => cards.last;

  /// 获取当前行牌数
  int get count => cards.length;

  /// 计算当前行累计所有牌的牛头惩罚数总和
  int get totalBullheads => cards.fold(0, (sum, c) => sum + c.bullheads);

  /// 判断放入一张牌后是否爆行 (达到第 6 张牌)
  bool willOverflowWith(Take6Card newCard) => cards.length >= 5;

  /// 向末尾添加一张牌
  void append(Take6Card card) {
    cards.add(card);
  }

  /// 收走当前行全部牌，并以该新牌重新开启该行
  List<Take6Card> takeRowAndReset(Take6Card newCard) {
    final takenCards = List<Take6Card>.from(cards);
    cards.clear();
    cards.add(newCard);
    return takenCards;
  }

  Take6Row copy() => Take6Row(
    rowIndex: rowIndex,
    cards: List<Take6Card>.from(cards),
  );

  Map<String, dynamic> toJson() => {
    'rowIndex': rowIndex,
    'cards': cards.map((c) => c.toJson()).toList(),
    'totalBullheads': totalBullheads,
  };

  factory Take6Row.fromJson(Map<String, dynamic> json) => Take6Row(
    rowIndex: json['rowIndex'] as int,
    cards: (json['cards'] as List).map((c) => Take6Card.fromJson(c)).toList(),
  );
}
