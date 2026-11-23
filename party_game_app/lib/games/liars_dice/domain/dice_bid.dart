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
  /// 2. 数量相同，但点数排名更大 (斋局下 1 点为最大点 rank 7 > 6)；
  /// 3. 一旦进入“斋”，后续禁止退回“飞”。
  static int faceRank(int face, bool isPure) => (isPure && face == 1) ? 7 : face;

  bool isStrictlyHigherThan(DiceBid? previousBid) {
    if (previousBid == null) return true;
    if (previousBid.isPure && !isPure) return false;

    if (count > previousBid.count) {
      return true;
    } else if (count == previousBid.count) {
      final curRank = faceRank(face, isPure);
      final prevRank = faceRank(previousBid.face, previousBid.isPure);
      if (curRank > prevRank) {
        return true;
      } else if (curRank == prevRank) {
        return !previousBid.isPure && isPure; // 同数量同排名仅允许由“飞”升级为“斋”
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
