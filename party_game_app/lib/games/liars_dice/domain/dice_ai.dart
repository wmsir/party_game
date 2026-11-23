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

    // 1. 使用二项分布尾概率评估上一家叫点真实性 P(X >= neededFromOthers)
    final face = prevBid.face;
    final isPure = prevBid.isPure || !state.isWild1Active;
    final myMatch = myCup.countFace(face, isWild1: !isPure);
    final neededFromOthers = prevBid.count - myMatch;

    final probSingle = isPure ? (1.0 / 6.0) : (2.0 / 6.0);
    final tailProb = neededFromOthers <= 0 ? 1.0 : _binomialTail(unknownDice, neededFromOthers, probSingle);

    double challengeThreshold = 0.22;
    if (personality == 'CONSERVATIVE') {
      challengeThreshold = 0.30;
    } else if (personality == 'AGGRESSIVE') {
      challengeThreshold = 0.14;
    } else if (personality == 'BLUFF_MASTER') {
      challengeThreshold = 0.18;
    }

    if (neededFromOthers > unknownDice || tailProb < challengeThreshold) {
      return AiDecision.challenge();
    }

    // 如果已经逼近全场骰子总数，果断抓包
    if (prevBid.count >= totalDiceInGame - 1) {
      return AiDecision.challenge();
    }

    // 2. 选择加码出价 (加数量或换更高排名点数)
    return _calculateNextBid(myCup, prevBid, state.isWild1Active, personality, totalPlayers);
  }

  static double _binomialTail(int n, int k, double p) {
    if (k <= 0) return 1.0;
    if (k > n) return 0.0;
    double sum = 0.0;
    for (int i = k; i <= n; i++) {
      sum += _binomialPmf(n, i, p);
    }
    return sum.clamp(0.0, 1.0);
  }

  static double _binomialPmf(int n, int k, double p) {
    double comb = 1.0;
    for (int i = 0; i < k; i++) {
      comb = comb * (n - i) / (i + 1);
    }
    return comb * pow(p, k) * pow(1.0 - p, n - k);
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
    final nextPure = prevBid.isPure || !isWild1Active;
    final faceCounts = <int, int>{};
    for (int f = 1; f <= 6; f++) {
      faceCounts[f] = myCup.countFace(f, isWild1: !nextPure);
    }

    final candidateFaces = nextPure ? [1, 6, 5, 4, 3, 2] : [2, 3, 4, 5, 6];
    candidateFaces.sort((a, b) => (faceCounts[b] ?? 0).compareTo(faceCounts[a] ?? 0));
    final myBestFace = candidateFaces.first;

    final shouldBluff = (personality == 'BLUFF_MASTER' && _rand.nextDouble() < 0.35);
    final targetFace = shouldBluff ? (_rand.nextInt(5) + 2) : myBestFace;

    // 策略 A: 同数量提高点数排名
    final candidateSameCount = DiceBid(
      bidderId: 'ai',
      bidderName: 'ai',
      count: prevBid.count,
      face: targetFace,
      isPure: nextPure || targetFace == 1,
    );
    if (candidateSameCount.isStrictlyHigherThan(prevBid)) {
      return AiDecision.bid(candidateSameCount.count, candidateSameCount.face, isPure: candidateSameCount.isPure);
    }

    // 策略 B: 个数 + 1 (兜底保证严格递增)
    if (prevBid.count < totalPlayers * 5) {
      return AiDecision.bid(
        prevBid.count + 1,
        targetFace,
        isPure: nextPure || targetFace == 1,
      );
    }
    return AiDecision.challenge();
  }
}
