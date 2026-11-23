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

  bool get isBaozi => isSpecialCombo;

  bool get isStraight {
    if (dice.length != 5) return false;
    final vals = dice.map((d) => d.value).toList()..sort();
    return (vals[0] == 1 && vals[1] == 2 && vals[2] == 3 && vals[3] == 4 && vals[4] == 5) ||
        (vals[0] == 2 && vals[1] == 3 && vals[2] == 4 && vals[3] == 5 && vals[4] == 6);
  }

  /// 5 颗同点数（豹子）匹配目标点数时额外计 +1 个
  int baoziBonus(int targetFace, {bool isWild1 = true}) {
    if (!isSpecialCombo || dice.isEmpty) return 0;
    final face = dice.first.value;
    if (face == targetFace || (isWild1 && targetFace != 1 && face == 1)) {
      return 1;
    }
    return 0;
  }

  /// 统计某一点数的出现频次 (如果 1 点为通配且 targetFace != 1，则同时把 1 点算入；豹子命中时追加 +1)
  int countFace(int targetFace, {bool isWild1 = true, bool includeBaoziBonus = true}) {
    int count = 0;
    for (final d in dice) {
      if (d.value == targetFace) {
        count++;
      } else if (isWild1 && targetFace != 1 && d.value == 1) {
        count++; // 1点作为通配符
      }
    }
    if (includeBaoziBonus) {
      count += baoziBonus(targetFace, isWild1: isWild1);
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
