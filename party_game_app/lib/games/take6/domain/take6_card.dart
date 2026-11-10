/// 谁是牛头王 - 纸牌领域实体 (1~104 号牌及牛头惩罚数算法)
class Take6Card implements Comparable<Take6Card> {
  final int number;
  final int bullheads;

  const Take6Card({
    required this.number,
    required this.bullheads,
  });

  /// 依据官方经典规则纯数学计算牛头惩罚数
  /// - 55 号牌: 7 个牛头 (特例，既是 11 的倍数又是尾数 5)
  /// - 11 的倍数 (11, 22, 33, 44, 66, 77, 88, 99): 5 个牛头
  /// - 10 的倍数 (10, 20, 30, 40, 50, 60, 70, 80, 90, 100): 3 个牛头
  /// - 尾数为 5 (5, 15, 25, 35, 45, 65, 75, 85, 95): 2 个牛头
  /// - 其余牌: 1 个牛头
  factory Take6Card.fromNumber(int number) {
    assert(number >= 1 && number <= 104, '牌号必须在 1~104 之间');
    int bulls = 1;
    if (number == 55) {
      bulls = 7;
    } else if (number % 11 == 0) {
      bulls = 5;
    } else if (number % 10 == 0) {
      bulls = 3;
    } else if (number % 5 == 0) {
      bulls = 2;
    }
    return Take6Card(number: number, bullheads: bulls);
  }

  /// 生成完整 104 张正规牌库
  static List<Take6Card> generateDeck() {
    return List.generate(104, (i) => Take6Card.fromNumber(i + 1));
  }

  @override
  int compareTo(Take6Card other) => number.compareTo(other.number);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Take6Card && runtimeType == other.runtimeType && number == other.number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'Card($number, 🐮x$bullheads)';

  Map<String, dynamic> toJson() => {
    'number': number,
    'bullheads': bullheads,
  };

  factory Take6Card.fromJson(Map<String, dynamic> json) => Take6Card(
    number: json['number'] as int,
    bullheads: json['bullheads'] as int,
  );
}
