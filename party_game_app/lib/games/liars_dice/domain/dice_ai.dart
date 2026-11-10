import 'dart:math';
import 'dice_bid.dart';
import 'dice_model.dart';
import 'dice_state.dart';

enum AiDecisionType {
  bid,       // 加价叫点
  challenge  // 开/劈上一家
}

class AiDecision {
  final AiDecisionType type;
  final int count;
  final int face;
  final bool isPure;

  const AiDecision._({
    required this.type,
    this.count = 0,
    this.face = 0,
    this.isPure = false,
  });

  factory AiDecision.bid(int count, int face, {bool isPure = false}) =>
      AiDecision._(type: AiDecisionType.bid, count: count, face: face, isPure: isPure);

  factory AiDecision.challenge() =>
      const AiDecision._(type: AiDecisionType.challenge);
}

/// 大话骰 - 本地智能 AI 策略机 (二项分布期望估计与博弈诈唬模型)
class DiceAi {
  static final Random _rand = Random();

  /// AI 决策核心方法
  static AiDecision decideNextAction({
    required String aiPlayerId,
    required DiceCupModel myCup,
    required DiceState state,
    required String personality, // 'BALANCED', 'AGGRESSIVE', 'CONSERVATIVE', 'BLUFF_MASTER'
  }) {
    final prevBid = state.currentBid;
    final totalPlayers = state.players.length;
    final totalDiceInGame = totalPlayers * 5;
    final unknownDice = (totalPlayers - 1) * 5;

    // 如果还没有人叫点，AI 叫出自己的最佳保底点数
    if (prevBid == null) {
      return _makeFirstBid(myCup, totalPlayers);
    }

    // 1. 评估上一家出价的可信度 (对局置信度判定)
    final face = prevBid.face;
    final isPure = prevBid.isPure || !state.isWild1Active;
    final myMatch = myCup.countFace(face, isWild1: !isPure);
    final neededFromOthers = prevBid.count - myMatch;

    // 单颗未知骰子命中该点数的理论概率
    final probSingle = isPure ? (1.0 / 6.0) : (2.0 / 6.0); // 飞为 1/3，斋为 1/6
    final expectedFromOthers = unknownDice * probSingle;

    // 容差安全上限 (超过此上限通常代表吹牛诈唬)
    double tolerance = 1.8;
    if (personality == 'CONSERVATIVE') {
      tolerance = 1.2; // 保守型极度敏感，容易开别人
    } else if (personality == 'AGGRESSIVE') {
      tolerance = 2.4; // 进攻型更愿意跟叫加码
    }

    // 若上一家叫点已经严重超出数学期望，果断“开/劈”
    if (neededFromOthers > (expectedFromOthers + tolerance)) {
      return AiDecision.challenge();
    }

    // 如果已经逼近全场骰子总数 (例如 2个人叫到8个)，必定抓
    if (prevBid.count >= totalDiceInGame - 1) {
      return AiDecision.challenge();
    }

    // 2. 选择加码出价 (加数量或换点数)
    return _calculateNextBid(myCup, prevBid, state.isWild1Active, personality, totalPlayers);
  }

  static AiDecision _makeFirstBid(DiceCupModel myCup, int totalPlayers) {
    // 寻找自己手中数量最多的点数 (优先 2~6)
    int bestFace = 2;
    int maxCount = 0;
    for (int f = 2; f <= 6; f++) {
      final c = myCup.countFace(f, isWild1: true);
      if (c > maxCount) {
        maxCount = c;
        bestFace = f;
      }
    }

    // 最低起叫数：总人数 + 1
    final baseCount = max(totalPlayers + 1, maxCount);
    return AiDecision.bid(baseCount, bestFace, isPure: false);
  }

  static AiDecision _calculateNextBid(
    DiceCupModel myCup,
    DiceBid prevBid,
    bool isWild1Active,
    String personality,
    int totalPlayers,
  ) {
    // 统计自己对各个点数的持有点数
    final faceCounts = <int, int>{};
    for (int f = 1; f <= 6; f++) {
      faceCounts[f] = myCup.countFace(f, isWild1: isWild1Active && !prevBid.isPure);
    }

    // 找自己持有點数较多的优势点数
    final sortedFaces = [2, 3, 4, 5, 6]..sort((a, b) => (faceCounts[b] ?? 0).compareTo(faceCounts[a] ?? 0));
    final myBestFace = sortedFaces.first;

    // 诈唬概率：欺骗型 AI 有 30% 几率故意叫自己完全没有的点数
    final shouldBluff = (personality == 'BLUFF_MASTER' && _rand.nextDouble() < 0.35);
    final targetFace = shouldBluff ? (_rand.nextInt(5) + 2) : myBestFace;

    // 策略 A: 相同个数，叫更大的点数
    if (targetFace > prevBid.face) {
      return AiDecision.bid(prevBid.count, targetFace, isPure: prevBid.isPure);
    }

    // 策略 B: 个数 + 1
    return AiDecision.bid(prevBid.count + 1, targetFace, isPure: prevBid.isPure);
  }
}
