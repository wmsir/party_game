import '../../core/models/game_player.dart';
import '../../core/state/game_base_state.dart';
import 'dice_bid.dart';
import 'dice_model.dart';

enum DicePhase {
  shaking,     // 摇骰子中
  bidding,     // 轮流叫点博弈中
  challenged,  // 开盅！核验点数与输赢结算
  roundOver,   // 单局结算
  matchOver    // 整场比赛结束
}

/// 开盅核验仲裁结果
class DiceChallengeResult {
  final String challengerId;
  final String challengerName;
  final DiceBid challengedBid;
  final int actualMatchCount;
  final bool isChallengerWon; // 开盅者是否获胜 (若实际点数 < 叫点，则开盅者胜，叫点者输；反之开盅者输)
  final String loserId;
  final String loserName;
  final String details;

  const DiceChallengeResult({
    required this.challengerId,
    required this.challengerName,
    required this.challengedBid,
    required this.actualMatchCount,
    required this.isChallengerWon,
    required this.loserId,
    required this.loserName,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    'challengerId': challengerId,
    'challengerName': challengerName,
    'challengedBid': challengedBid.toJson(),
    'actualMatchCount': actualMatchCount,
    'isChallengerWon': isChallengerWon,
    'loserId': loserId,
    'loserName': loserName,
    'details': details,
  };
}

/// 大话骰 - 完整不可变领域状态
class DiceState extends GameBaseState {
  DicePhase phase;
  final List<GamePlayer> players;
  int currentTurnIndex; // 当前轮到哪位玩家叫点 (0 ~ players.length - 1)
  final Map<String, DiceCupModel> playerCups; // 每位玩家当前骰盅
  DiceBid? currentBid; // 场上当前最新叫点
  final List<DiceBid> bidHistory; // 本局叫点出价履历
  bool isWild1Active; // 1 点当前是否仍然具备通配符能力
  DiceChallengeResult? lastResult; // 最近一次开盅结果
  final Map<String, int> chipsScore; // 玩家筹码/胜负积分
  final List<String> eventLogs;

  DiceState({
    required super.roundId,
    required this.players,
    required this.playerCups,
    this.phase = DicePhase.shaking,
    this.currentTurnIndex = 0,
    this.currentBid,
    List<DiceBid>? bidHistory,
    this.isWild1Active = true,
    this.lastResult,
    Map<String, int>? chipsScore,
    List<String>? eventLogs,
    super.gameCode = 'LIARS_DICE',
  })  : bidHistory = bidHistory ?? [],
        chipsScore = chipsScore ?? {for (var p in players) p.id: 100},
        eventLogs = eventLogs ?? [];

  GamePlayer get currentPlayer => players[currentTurnIndex];

  @override
  DiceState copy() {
    return DiceState(
      roundId: roundId,
      players: players.map((p) => p.copyWith()).toList(),
      playerCups: {
        for (var entry in playerCups.entries)
          entry.key: DiceCupModel(
            playerId: entry.key,
            dice: List<SingleDice>.from(entry.value.dice),
            isSpecialCombo: entry.value.isSpecialCombo,
          ),
      },
      phase: phase,
      currentTurnIndex: currentTurnIndex,
      currentBid: currentBid,
      bidHistory: List<DiceBid>.from(bidHistory),
      isWild1Active: isWild1Active,
      lastResult: lastResult,
      chipsScore: Map<String, int>.from(chipsScore),
      eventLogs: List<String>.from(eventLogs),
      gameCode: gameCode,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'gameCode': gameCode,
    'roundId': roundId,
    'phase': phase.name,
    'currentTurnIndex': currentTurnIndex,
    'players': players.map((p) => p.toJson()).toList(),
    'playerCups': {
      for (var entry in playerCups.entries) entry.key: entry.value.toJson(),
    },
    'currentBid': currentBid?.toJson(),
    'bidHistory': bidHistory.map((b) => b.toJson()).toList(),
    'isWild1Active': isWild1Active,
    'lastResult': lastResult?.toJson(),
    'chipsScore': chipsScore,
    'eventLogs': eventLogs,
  };
}
