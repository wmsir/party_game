import '../../core/models/game_player.dart';
import '../../core/state/game_base_state.dart';
import 'take6_card.dart';
import 'take6_row.dart';

enum Take6Phase {
  selectingCard,       // 等待各玩家出牌
  revealing,           // 亮牌展示动画
  resolving,           // 排序并依次入行
  awaitingRowChoice,   // 某玩家牌比桌面4行尾牌都小，等待该玩家选择吃哪一行
  roundFinished,       // 手牌打完本轮结算
  gameOver             // 整场结束产生胜负排名
}

/// 某张已打出、待结算入行的牌记录
class PlayedCardEntry implements Comparable<PlayedCardEntry> {
  final String playerId;
  final String playerName;
  final Take6Card card;

  const PlayedCardEntry({
    required this.playerId,
    required this.playerName,
    required this.card,
  });

  @override
  int compareTo(PlayedCardEntry other) => card.compareTo(other.card);

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'card': card.toJson(),
  };

  factory PlayedCardEntry.fromJson(Map<String, dynamic> json) => PlayedCardEntry(
    playerId: json['playerId'] as String,
    playerName: json['playerName'] as String,
    card: Take6Card.fromJson(json['card']),
  );
}

/// 谁是牛头王 - 完整领域状态
class Take6State extends GameBaseState {
  Take6Phase phase;
  int currentTurn; // 1~10 轮
  final List<GamePlayer> players;
  final List<Take6Row> rows; // 固定 4 行
  final Map<String, List<Take6Card>> playerHands; // 每人手牌
  final Map<String, Take6Card?> selectedCards;    // 本回合玩家已锁定的出牌
  final List<PlayedCardEntry> pendingResolveQueue; // 翻牌后从小到大排序的入行队列
  PlayedCardEntry? currentResolvingEntry;          // 当前正在入行结算的牌
  String? playerChoosingRowId;                     // 当牌太小必须吃行时，等待决策的玩家ID
  final Map<String, int> penaltyScores;           // 每位玩家累计吃的牛头惩罚分
  final List<String> eventLogs;                   // 实时裁判播报日志

  Take6State({
    required super.roundId,
    required this.players,
    required this.rows,
    required this.playerHands,
    required this.selectedCards,
    this.phase = Take6Phase.selectingCard,
    this.currentTurn = 1,
    List<PlayedCardEntry>? pendingResolveQueue,
    this.currentResolvingEntry,
    this.playerChoosingRowId,
    Map<String, int>? penaltyScores,
    List<String>? eventLogs,
    super.gameCode = 'TAKE_6',
  })  : pendingResolveQueue = pendingResolveQueue ?? [],
        penaltyScores = penaltyScores ?? {for (var p in players) p.id: 0},
        eventLogs = eventLogs ?? [];

  bool get isAllCardsSelected {
    return players.every((p) => selectedCards[p.id] != null);
  }

  @override
  Take6State copy() {
    return Take6State(
      roundId: roundId,
      players: players.map((p) => p.copyWith()).toList(),
      rows: rows.map((r) => r.copy()).toList(),
      playerHands: {
        for (var entry in playerHands.entries)
          entry.key: List<Take6Card>.from(entry.value),
      },
      selectedCards: Map<String, Take6Card?>.from(selectedCards),
      phase: phase,
      currentTurn: currentTurn,
      pendingResolveQueue: List<PlayedCardEntry>.from(pendingResolveQueue),
      currentResolvingEntry: currentResolvingEntry,
      playerChoosingRowId: playerChoosingRowId,
      penaltyScores: Map<String, int>.from(penaltyScores),
      eventLogs: List<String>.from(eventLogs),
      gameCode: gameCode,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'gameCode': gameCode,
    'roundId': roundId,
    'phase': phase.name,
    'currentTurn': currentTurn,
    'players': players.map((p) => p.toJson()).toList(),
    'rows': rows.map((r) => r.toJson()).toList(),
    'playerHands': {
      for (var entry in playerHands.entries)
        entry.key: entry.value.map((c) => c.toJson()).toList(),
    },
    'selectedCards': {
      for (var entry in selectedCards.entries)
        entry.key: entry.value?.toJson(),
    },
    'pendingResolveQueue': pendingResolveQueue.map((e) => e.toJson()).toList(),
    'currentResolvingEntry': currentResolvingEntry?.toJson(),
    'playerChoosingRowId': playerChoosingRowId,
    'penaltyScores': penaltyScores,
    'eventLogs': eventLogs,
  };
}
