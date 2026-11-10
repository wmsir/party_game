/// 大话骰 / 骰子街 - 叫点出价领域模型 (Bid)
class DiceBid {
  final String bidderId;
  final String bidderName;
  final int count;  // 数量 (如 5 个)
  final int face;   // 点数 (1~6，如 4 点)
  final bool isPure; // 是否为“斋” (斋代表 1 点失去通配能力)

  const DiceBid({
    required this.bidderId,
    required this.bidderName,
    required this.count,
    required this.face,
    this.isPure = false,
  }) : assert(face >= 1 && face <= 6, '点数必须在 1~6 之间'),
       assert(count >= 1, '数量必须大于等于 1');

  /// 校验该叫点相对于前一出价是否严格合法递增
  /// 经典大话骰规则：
  /// 1. 数量增加 (如 5个4 -> 6个2)；
  /// 2. 数量相同，但点数增加 (如 5个4 -> 5个5)；
  /// 3. 若转为“斋” (纯点)，在同等数量或数量加倍规则下合法。
  bool isStrictlyHigherThan(DiceBid? previousBid) {
    if (previousBid == null) return true;

    // 若前一家是“斋”，后一家也必须遵守更高要求
    if (count > previousBid.count) {
      return true;
    } else if (count == previousBid.count) {
      // 数量相同，点数必须更大；或者相同点数但从“飞(通配)”升级为“斋”
      if (face > previousBid.face) {
        return true;
      } else if (face == previousBid.face) {
        return !previousBid.isPure && isPure; // 相同个数和点数，只能由“飞”叫成“斋”
      }
    }
    return false;
  }

  @override
  String toString() => '$count 个 $face ${isPure ? '(斋)' : '(飞)'}';

  Map<String, dynamic> toJson() => {
    'bidderId': bidderId,
    'bidderName': bidderName,
    'count': count,
    'face': face,
    'isPure': isPure,
  };

  factory DiceBid.fromJson(Map<String, dynamic> json) => DiceBid(
    bidderId: json['bidderId'] as String,
    bidderName: json['bidderName'] as String,
    count: json['count'] as int,
    face: json['face'] as int,
    isPure: json['isPure'] as bool? ?? false,
  );
}
