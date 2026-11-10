import 'dart:async';
import 'dart:math';
import '../../core/models/game_player.dart';
import 'dice_bid.dart';
import 'dice_model.dart';
import 'dice_state.dart';

/// 大话骰 / 骰子街 - 纯领域规则与状态机引擎 (Pure Dart Domain Engine)
class DiceRulesEngine {
  late DiceState _state;
  final StreamController<DiceState> _stateController = StreamController<DiceState>.broadcast();

  DiceState get state => _state;
  Stream<DiceState> get stateStream => _stateController.stream;

  /// 开新对局
  DiceState startNewRound({
    required List<GamePlayer> players,
    int starterIndex = 0,
    Map<String, int>? initialChips,
  }) {
    assert(players.length >= 2 && players.length <= 8, '大话骰建议 2~8 人对战');

    final cups = <String, DiceCupModel>{};
    for (final p in players) {
      cups[p.id] = DiceCupModel.rollNew(p.id);
    }

    _state = DiceState(
      roundId: 'DICE-${DateTime.now().millisecondsSinceEpoch}',
      players: players,
      playerCups: cups,
      currentTurnIndex: starterIndex % players.length,
      currentBid: null,
      bidHistory: [],
      isWild1Active: true,
      lastResult: null,
      chipsScore: initialChips ?? {for (var p in players) p.id: 100},
      phase: DicePhase.bidding,
      eventLogs: [
        '🎲 摇骰完毕！每位玩家已扣好骰盅。1 点当前默认为【通配/飞】。',
        '👉 首位叫点：【${players[starterIndex % players.length].name}】',
      ],
    );

    _emit();
    return _state;
  }

  /// 权威服务端发牌与重连同步专属手骰
  void syncPlayerDice(String playerId, List<int> diceValues) {
    if (_state.playerCups.containsKey(playerId)) {
      final rolled = diceValues.map((v) => SingleDice(v)).toList()..sort((a, b) => a.value.compareTo(b.value));
      final isBaozi = rolled.isNotEmpty && rolled.every((d) => d.value == rolled.first.value);
      _state.playerCups[playerId] = DiceCupModel(
        playerId: playerId,
        dice: rolled,
        isSpecialCombo: isBaozi,
      );
      _emit();
    }
  }

  /// 玩家叫点出价 (Count 个 Face)
  bool playerBid({
    required String playerId,
    required int count,
    required int face,
    required bool isPure,
  }) {
    if (_state.phase != DicePhase.bidding) return false;
    if (_state.currentPlayer.id != playerId) return false;

    // 默认最低起叫：总人数 + 1 (例如2人至少3个起叫)
    final minCount = max(2, _state.players.length + 1);
    if (_state.currentBid == null && count < minCount) {
      count = minCount;
    }

    // 若当前叫了 1 点，或者主动叫“斋”，则通配符 1 立即永久失效
    bool nextIsPure = isPure;
    if (face == 1) {
      nextIsPure = true;
    }

    final newBid = DiceBid(
      bidderId: playerId,
      bidderName: _state.currentPlayer.name,
      count: count,
      face: face,
      isPure: nextIsPure || !_state.isWild1Active,
    );

    // 校验叫点是否合法递增
    if (!newBid.isStrictlyHigherThan(_state.currentBid)) {
      return false;
    }

    _state.currentBid = newBid;
    _state.bidHistory.add(newBid);

    // 如果叫了斋或点数为1，取消全局1点通配
    if (newBid.isPure) {
      _state.isWild1Active = false;
    }

    _state.eventLogs.add(
      '🗣️ 【${newBid.bidderName}】叫出：${newBid.count} 个 ${newBid.face} ${newBid.isPure ? '【斋/纯】' : '【飞/通配】'}',
    );

    // 轮到下一位玩家
    _state.currentTurnIndex = (_state.currentTurnIndex + 1) % _state.players.length;
    _emit();
    return true;
  }

  /// 玩家发起质疑开盅 (开 / 劈 / 抓)
  bool playerChallenge(String challengerId) {
    if (_state.phase != DicePhase.bidding) return false;
    if (_state.currentPlayer.id != challengerId) return false;
    if (_state.currentBid == null) return false; // 还未叫过点不能开

    final challenger = _state.currentPlayer;
    final bid = _state.currentBid!;
    _state.phase = DicePhase.challenged;

    // 统计全场所有骰盅中符合条件的实际骰子数量
    int totalMatch = 0;
    final detailsMap = <String, List<int>>{};

    for (final p in _state.players) {
      final cup = _state.playerCups[p.id]!;
      detailsMap[p.name] = cup.dice.map((d) => d.value).toList();
      totalMatch += cup.countFace(bid.face, isWild1: _state.isWild1Active && !bid.isPure);
    }

    // 裁决：
    // 若实际总数 >= 叫点数 -> 叫点者获胜，开盅者失利
    // 若实际总数 < 叫点数 -> 开盅者获胜，叫点者吹牛被抓失利
    final bool isChallengerWon = totalMatch < bid.count;
    final String loserId = isChallengerWon ? bid.bidderId : challenger.id;
    final String loserName = isChallengerWon ? bid.bidderName : challenger.name;

    // 输者扣减 10 筹码/积分，赢者获得 10 筹码/积分
    final winnerId = isChallengerWon ? challenger.id : bid.bidderId;
    _state.chipsScore[loserId] = (_state.chipsScore[loserId] ?? 100) - 10;
    _state.chipsScore[winnerId] = (_state.chipsScore[winnerId] ?? 100) + 10;

    final detailDesc = detailsMap.entries.map((e) => '${e.key}: [${e.value.join(',')}]').join(' | ');

    _state.lastResult = DiceChallengeResult(
      challengerId: challenger.id,
      challengerName: challenger.name,
      challengedBid: bid,
      actualMatchCount: totalMatch,
      isChallengerWon: isChallengerWon,
      loserId: loserId,
      loserName: loserName,
      details: detailDesc,
    );

    _state.eventLogs.add(
      '💥 【${challenger.name}】大喊“开/劈”！检验【${bid.bidderName}】叫的 ${bid.count} 个 ${bid.face}！',
    );
    _state.eventLogs.add(
      '🔍 全场揭盅！实际点数共有 $totalMatch 个 ${bid.face} (${_state.isWild1Active && !bid.isPure ? '含1点通配' : '纯点无通配'})。',
    );
    _state.eventLogs.add(
      isChallengerWon
          ? '🎯 抓包成功！实际仅 $totalMatch 个（不足 ${bid.count} 个），【$loserName】吹牛失败受罚！'
          : '🛡️ 守台成功！全场多达 $totalMatch 个（不少于 ${bid.count} 个），【$loserName】质疑失败受罚！',
    );

    _emit();
    return true;
  }

  void _emit() {
    _stateController.add(_state.copy());
  }

  void dispose() {
    _stateController.close();
  }
}
