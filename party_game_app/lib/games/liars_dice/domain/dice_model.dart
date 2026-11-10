import 'dart:math';

/// 单颗骰子领域实体
class SingleDice {
  final int value; // 1 ~ 6

  const SingleDice(this.value) : assert(value >= 1 && value <= 6, '骰子点数必须在 1~6 之间');

  static SingleDice rollRandom([Random? random]) {
    final r = random ?? Random();
    return SingleDice(r.nextInt(6) + 1);
  }

  Map<String, dynamic> toJson() => {'value': value};
  factory SingleDice.fromJson(Map<String, dynamic> json) => SingleDice(json['value'] as int);

  @override
  String toString() => '[$value]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleDice && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// 某位玩家的骰盅内点数 (标准每盅 5 颗)
class DiceCupModel {
  final String playerId;
  final List<SingleDice> dice;
  final bool isSpecialCombo; // 豹子(顺子/同花)

  DiceCupModel({
    required this.playerId,
    required this.dice,
    this.isSpecialCombo = false,
  });

  /// 摇骰重置
  factory DiceCupModel.rollNew(String playerId, {int diceCount = 5, Random? random}) {
    final r = random ?? Random();
    final rolled = List.generate(diceCount, (_) => SingleDice.rollRandom(r))..sort((a, b) => a.value.compareTo(b.value));
    
    // 判定特殊牌型 (如 5 颗完全相同为豹子，通算加 1 个)
    final isBaozi = rolled.every((d) => d.value == rolled.first.value);
    return DiceCupModel(
      playerId: playerId,
      dice: rolled,
      isSpecialCombo: isBaozi,
    );
  }

  /// 统计某一点数的出现频次 (如果 1 点为通配且 targetFace != 1，则同时把 1 点算入)
  int countFace(int targetFace, {bool isWild1 = true}) {
    int count = 0;
    for (final d in dice) {
      if (d.value == targetFace) {
        count++;
      } else if (isWild1 && targetFace != 1 && d.value == 1) {
        count++; // 1点作为通配符
      }
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'dice': dice.map((d) => d.toJson()).toList(),
    'isSpecialCombo': isSpecialCombo,
  };

  factory DiceCupModel.fromJson(Map<String, dynamic> json) => DiceCupModel(
    playerId: json['playerId'] as String,
    dice: (json['dice'] as List).map((d) => SingleDice.fromJson(d)).toList(),
    isSpecialCombo: json['isSpecialCombo'] as bool? ?? false,
  );
}
