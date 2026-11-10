import 'dart:async';
import 'dart:math';
import '../../core/models/game_player.dart';
import 'take6_card.dart';
import 'take6_row.dart';
import 'take6_state.dart';

/// 谁是牛头王 - 纯领域内核引擎 (Pure Dart Domain Engine)
/// 零 Flutter UI / 零外部信道依赖，负责桌游全部运转规则状态机
class Take6Engine {
  bool isHost;
  late Take6State _state;
  final StreamController<Take6State> _stateController = StreamController<Take6State>.broadcast();
  Timer? _stepTimer;

  Take6Engine({
    this.isHost = true,
  });

  Take6State get state => _state;
  Stream<Take6State> get stateStream => _stateController.stream;

  /// 初始化一整局游戏 (支持注入多端同步的初始底牌与各玩家手牌)
  Take6State startNewMatch({
    required List<GamePlayer> players,
    int handSize = 10,
    List<Take6Row>? initialRows,
    Map<String, List<Take6Card>>? initialHands,
    Map<String, int>? initialScores,
    int? initialTurn,
  }) {
    assert(players.length >= 2 && players.length <= 10, '玩家人数需为 2~10 人');

    List<Take6Row> rows;
    Map<String, List<Take6Card>> playerHands;

    if (initialRows != null && initialRows.isNotEmpty && initialHands != null && initialHands.isNotEmpty) {
      rows = initialRows;
      playerHands = Map<String, List<Take6Card>>.from(initialHands);
      // 补全可能缺失的玩家手牌兜底：先尝试多格式ID匹配，若仍缺失则从剩余牌库发牌，严禁出现空手牌！
      for (final p in players) {
        if (!playerHands.containsKey(p.id) || playerHands[p.id]!.isEmpty) {
          final altKey = initialHands.keys.firstWhere(
            (k) => k == p.id || (k.isNotEmpty && p.id.isNotEmpty && (k.contains(p.id) || p.id.contains(k) || k.replaceAll(RegExp(r'\D'), '') == p.id.replaceAll(RegExp(r'\D'), ''))),
            orElse: () => '',
          );
          if (altKey.isNotEmpty && initialHands[altKey] != null && initialHands[altKey]!.isNotEmpty) {
            playerHands[p.id] = List<Take6Card>.from(initialHands[altKey]!);
          } else {
            final usedNums = <int>{};
            for (final r in rows) {
              for (final c in r.cards) {
                usedNums.add(c.number);
              }
            }
            for (final h in playerHands.values) {
              for (final c in h) {
                usedNums.add(c.number);
              }
            }
            final pool = <Take6Card>[];
            for (int i = 1; i <= 104; i++) {
              if (!usedNums.contains(i)) pool.add(Take6Card.fromNumber(i));
            }
            pool.shuffle();
            final dealt = pool.take(handSize).toList()..sort();
            playerHands[p.id] = dealt;
          }
        }
      }
    } else {
      final deck = Take6Card.generateDeck()..shuffle(Random());

      // 1. 发桌面 4 行底牌
      rows = <Take6Row>[];
      for (int i = 0; i < 4; i++) {
        rows.add(Take6Row(rowIndex: i, cards: [deck.removeLast()]));
      }

      // 2. 发手牌 (默认每人 10 张并排好序)
      playerHands = <String, List<Take6Card>>{};
      for (final p in players) {
        final hand = deck.sublist(0, handSize)..sort();
        deck.removeRange(0, handSize);
        playerHands[p.id] = hand;
      }
    }

    int turn = initialTurn ?? 1;
    if (initialTurn == null && playerHands.isNotEmpty) {
      final minHandCount = playerHands.values.map((h) => h.length).reduce((a, b) => a < b ? a : b);
      if (minHandCount < handSize) {
        turn = handSize - minHandCount + 1;
      }
    }

    _state = Take6State(
      roundId: 'T6-${DateTime.now().millisecondsSinceEpoch}',
      players: players,
      rows: rows,
      playerHands: playerHands,
      selectedCards: {for (var p in players) p.id: null},
      penaltyScores: initialScores != null ? Map<String, int>.from(initialScores) : {for (var p in players) p.id: 0},
      currentTurn: turn,
      phase: Take6Phase.selectingCard,
      eventLogs: ['🐮 谁是牛头王开局！桌面已布设 4 移行牌，每位玩家发放 10 张手牌。'],
    );

    _emit();
    return _state;
  }

  /// 同步远端权威牌局状态 (保证多端桌面 100% 绝对一致)
  void syncFromRemote({
    List<List<int>>? rowNumbers,
    Map<String, int>? penaltyScores,
    Take6Phase? phase,
    int? currentTurn,
    String? playerChoosingRowId,
    Map<String, int>? revealedCards,
    List<String>? readyPlayerIds,
    Map<String, List<int>>? playerHands,
    String? log,
  }) {
    // 1. 桌牌深度比对：判断是否真正发生变化，无变化时不重建行对象，彻底杜绝闪烁震荡
    bool rowsChanged = false;
    if (rowNumbers != null && rowNumbers.isNotEmpty) {
      if (rowNumbers.length != _state.rows.length) {
        rowsChanged = true;
      } else {
        for (int i = 0; i < rowNumbers.length; i++) {
          final nums = rowNumbers[i];
          final currentCards = _state.rows[i].cards;
          if (nums.length != currentCards.length) {
            rowsChanged = true;
            break;
          }
          for (int j = 0; j < nums.length; j++) {
            if (nums[j] != currentCards[j].number) {
              rowsChanged = true;
              break;
            }
          }
          if (rowsChanged) break;
        }
      }
    }

    if (!isHost) {
      _stepTimer?.cancel();
      _stepTimer = null;
    }

    if (rowsChanged && rowNumbers != null) {
      final newRows = <Take6Row>[];
      for (int i = 0; i < rowNumbers.length; i++) {
        final cards = rowNumbers[i].map((n) => Take6Card.fromNumber(n)).toList();
        newRows.add(Take6Row(rowIndex: i, cards: cards));
      }
      _state.rows.clear();
      _state.rows.addAll(newRows);
    }

    bool hasAnyChange = rowsChanged;

    if (currentTurn != null && currentTurn > 0 && _state.currentTurn != currentTurn) {
      _state.currentTurn = currentTurn;
      hasAnyChange = true;
    }

    if (penaltyScores != null) {
      for (final entry in penaltyScores.entries) {
        if (_state.penaltyScores[entry.key] != entry.value) {
          _state.penaltyScores[entry.key] = entry.value;
          hasAnyChange = true;
        }
      }
    }
    if (phase != null && _state.phase != phase) {
      _state.phase = phase;
      hasAnyChange = true;
    }
    if (_state.playerChoosingRowId != playerChoosingRowId) {
      _state.playerChoosingRowId = playerChoosingRowId;
      hasAnyChange = true;
    }

    if (phase == Take6Phase.revealing ||
        phase == Take6Phase.resolving ||
        phase == Take6Phase.awaitingRowChoice ||
        (revealedCards != null && revealedCards.values.any((v) => v > 1))) {
      if (revealedCards != null && revealedCards.isNotEmpty) {
        revealedCards.forEach((pid, numVal) {
          if (numVal > 1) {
            if (_state.selectedCards[pid]?.number != numVal) {
              _state.selectedCards[pid] = Take6Card.fromNumber(numVal);
              hasAnyChange = true;
            }
            final card = Take6Card.fromNumber(numVal);
            if (_state.playerHands[pid]?.contains(card) ?? false) {
              _state.playerHands[pid]!.remove(card);
              hasAnyChange = true;
            }
          }
        });
      }
    } else if (phase == Take6Phase.selectingCard) {
      _stepTimer?.cancel();
      _stepTimer = null;
      _state.currentResolvingEntry = null;
      // 进入新一轮选牌，清空上一轮已亮牌
      if (_state.selectedCards.values.any((c) => c != null && c.number > 1)) {
        _state.selectedCards.updateAll((key, value) => null);
        hasAnyChange = true;
      }
      if (readyPlayerIds != null) {
        for (final p in _state.players) {
          final shouldBeReady = readyPlayerIds.contains(p.id);
          final isCurrentlyReady = _state.selectedCards[p.id] != null;
          if (shouldBeReady != isCurrentlyReady) {
            _state.selectedCards[p.id] = shouldBeReady ? Take6Card.fromNumber(1) : null;
            hasAnyChange = true;
          }
        }
      }
    } else if (phase == Take6Phase.gameOver) {
      _stepTimer?.cancel();
      _stepTimer = null;
      _state.currentResolvingEntry = null;
      _state.selectedCards.updateAll((key, value) => null);
      hasAnyChange = true;
    }

    if (playerHands != null && playerHands.isNotEmpty) {
      playerHands.forEach((pid, handNums) {
        String targetKey = pid;
        if (!_state.playerHands.containsKey(targetKey)) {
          final altKey = _state.playerHands.keys.firstWhere(
            (k) => k == pid || (k.isNotEmpty && pid.isNotEmpty && (k.contains(pid) || pid.contains(k) || k.replaceAll(RegExp(r'\D'), '') == pid.replaceAll(RegExp(r'\D'), ''))),
            orElse: () => '',
          );
          if (altKey.isNotEmpty) targetKey = altKey;
        }

        final existing = _state.playerHands[targetKey];
        bool isIdentical = false;
        if (existing != null && existing.length == handNums.length) {
          final sortedExisting = existing.map((c) => c.number).toList()..sort();
          final sortedNew = List<int>.from(handNums)..sort();
          isIdentical = true;
          for (int i = 0; i < sortedExisting.length; i++) {
            if (sortedExisting[i] != sortedNew[i]) {
              isIdentical = false;
              break;
            }
          }
        }
        if (!isIdentical) {
          _state.playerHands[targetKey] = handNums.map((n) => Take6Card.fromNumber(n)).toList()..sort();
          hasAnyChange = true;
        }
      });
    }

    if (log != null && log.isNotEmpty && (_state.eventLogs.isEmpty || _state.eventLogs.last != log)) {
      _state.eventLogs.add(log);
      hasAnyChange = true;
    }

    if (!hasAnyChange) return; // 状态完全一致，零抖动短路退出，杜绝无效刷新
    _emit();
  }

  /// 动态更新/合并房间内玩家列表 (例如重连或新玩家加入时)
  void updatePlayers(List<GamePlayer> newPlayers) {
    if (newPlayers.isEmpty) return;
    final curIds = _state.players.map((p) => p.id).toList();
    final newIds = newPlayers.map((p) => p.id).toList();
    if (curIds.length == newIds.length && curIds.every((id) => newIds.contains(id))) {
      return; // 席位未发生实际变动，不触发刷新与多端重绘
    }
    _state.players.clear();
    _state.players.addAll(newPlayers);
    for (final p in newPlayers) {
      _state.penaltyScores.putIfAbsent(p.id, () => 0);
      _state.playerHands.putIfAbsent(p.id, () => []);
      _state.selectedCards.putIfAbsent(p.id, () => null);
    }
    _emit();
  }

  /// 玩家 (人类或 AI) 选定出牌
  bool playerPickCard(String playerId, Take6Card card) {
    if (_state.phase != Take6Phase.selectingCard) return false;
    var hand = _state.playerHands[playerId];
    if (hand != null && hand.contains(card)) {
      hand.remove(card);
    }

    _state.selectedCards[playerId] = card;

    // 仅房主权威主机在全员选好后推进至亮牌翻转与入行队列；非房主客户端严格遵循远端同步
    if (isHost) {
      if (_state.isAllCardsSelected) {
        _triggerRevealAndQueue();
      } else {
        _emit();
      }
    } else {
      _emit();
    }
    return true;
  }

  /// 全部选好后翻牌并组装入行队列
  void _triggerRevealAndQueue() {
    _state.phase = Take6Phase.revealing;

    final queue = <PlayedCardEntry>[];
    for (final p in _state.players) {
      final card = _state.selectedCards[p.id]!;
      // 从手牌中扣减
      _state.playerHands[p.id]?.remove(card);
      queue.add(PlayedCardEntry(playerId: p.id, playerName: p.name, card: card));
    }

    // 核心规则：按牌面从小到大排序依次入行
    queue.sort();
    _state.pendingResolveQueue.clear();
    _state.pendingResolveQueue.addAll(queue);

    _state.eventLogs.add(
      '🃏 全员出牌完毕！本回合亮牌：${queue.map((e) => '${e.playerName}[${e.card.number}号 (🐮${e.card.bullheads})]').join('，')}',
    );

    _emit();

    // 关键体验：先保留全员亮牌展示 1.8 秒，让大家看清楚所有人出的牌是多少，然后再依次从小到大入行结算！
    _stepTimer?.cancel();
    _stepTimer = Timer(const Duration(milliseconds: 1800), () {
      _resolveNextCardInQueue();
    });
  }

  /// 顺序解决入行队列中的下一张牌
  void _resolveNextCardInQueue() {
    if (_state.pendingResolveQueue.isEmpty) {
      _finishTurn();
      return;
    }

    final entry = _state.pendingResolveQueue.removeAt(0);
    _state.currentResolvingEntry = entry;
    _state.phase = Take6Phase.resolving;

    final card = entry.card;

    // 寻找所有末尾牌小于 card 的行中，差值最小的那一行
    int bestRowIndex = -1;
    int minDiff = 9999;

    for (int i = 0; i < _state.rows.length; i++) {
      final rowLast = _state.rows[i].lastCard.number;
      if (card.number > rowLast) {
        final diff = card.number - rowLast;
        if (diff < minDiff) {
          minDiff = diff;
          bestRowIndex = i;
        }
      }
    }

    // 情况 A: 牌比当前 4 行所有末尾牌都要小！必须由玩家选择收走任意一行
    if (bestRowIndex == -1) {
      _state.phase = Take6Phase.awaitingRowChoice;
      _state.playerChoosingRowId = entry.playerId;
      _state.eventLogs.add(
        '⚠️ 【${entry.playerName}】打出牌 [${card.number}] 小于所有行末尾牌，必须任选一行收走并计入牛头惩罚！',
      );
      _emit();
      return;
    }

    // 情况 B: 找到了差值最小的目标行
    final targetRow = _state.rows[bestRowIndex];

    // 判断放入后是否爆行 (即将成为第 6 张牌)
    if (targetRow.willOverflowWith(card)) {
      final penaltyCards = targetRow.takeRowAndReset(card);
      final addedBullheads = penaltyCards.fold(0, (sum, c) => sum + c.bullheads);
      _state.penaltyScores[entry.playerId] = (_state.penaltyScores[entry.playerId] ?? 0) + addedBullheads;

      _state.eventLogs.add(
        '💥 爆行！【${entry.playerName}】的牌 [${card.number}] 成为第 6 张牌，收走第 ${bestRowIndex + 1} 行前 5 张牌，吃进 🐮x$addedBullheads！',
      );
    } else {
      // 正常入行，未爆行
      targetRow.append(card);
      _state.eventLogs.add(
        '👉 【${entry.playerName}】的牌 [${card.number}] 顺利入驻第 ${bestRowIndex + 1} 行 (当前 ${targetRow.count}/5)。',
      );
    }

    _emit();
    // 继续解决队列下一张 (延迟 750ms 形成依次入行动画)
    _stepTimer?.cancel();
    _stepTimer = Timer(const Duration(milliseconds: 750), () {
      _resolveNextCardInQueue();
    });
  }

  /// 牌比所有末尾牌都小时，玩家做出吃行选择 (行索引 0~3)
  bool playerChooseRowToTake(String playerId, int rowIndex) {
    if (_state.phase != Take6Phase.awaitingRowChoice) return false;
    if (_state.playerChoosingRowId != playerId) return false;
    if (rowIndex < 0 || rowIndex >= _state.rows.length) return false;

    final entry = _state.currentResolvingEntry;
    if (entry == null) return false;

    final targetRow = _state.rows[rowIndex];
    final penaltyCards = targetRow.takeRowAndReset(entry.card);
    final addedBullheads = penaltyCards.fold(0, (sum, c) => sum + c.bullheads);
    _state.penaltyScores[playerId] = (_state.penaltyScores[playerId] ?? 0) + addedBullheads;

    _state.eventLogs.add(
      '🧹 【${entry.playerName}】主动收走第 ${rowIndex + 1} 行全量纸牌，承受 🐮x$addedBullheads 牛头惩罚，[${entry.card.number}] 成为该行新底牌。',
    );

    _state.playerChoosingRowId = null;
    _emit();

    // 延迟 750ms 解决下一张
    _stepTimer?.cancel();
    _stepTimer = Timer(const Duration(milliseconds: 750), () {
      _resolveNextCardInQueue();
    });
    return true;
  }

  /// 一回合所有牌放完后，检查手牌是否打空
  void _finishTurn() {
    _state.currentResolvingEntry = null;
    _state.selectedCards.updateAll((key, value) => null);

    final isHandEmpty = _state.playerHands.values.every((h) => h.isEmpty);

    if (isHandEmpty || _state.currentTurn >= 10) {
      _state.phase = Take6Phase.gameOver;
      // 结算最终排位 (牛头惩罚数越少越靠前)
      final ranking = List<GamePlayer>.from(_state.players);
      ranking.sort((a, b) => (_state.penaltyScores[a.id] ?? 0).compareTo(_state.penaltyScores[b.id] ?? 0));
      final winner = ranking.first;
      _state.eventLogs.add(
        '🏆 游戏结束！获胜者为【${winner.name}】，牛头惩罚最少 (${_state.penaltyScores[winner.id]} 个牛头)！',
      );
      _emit();
    } else {
      // 延迟 1000ms 开启下一轮暗扣选牌
      _stepTimer?.cancel();
      _stepTimer = Timer(const Duration(milliseconds: 1000), () {
        _state.currentTurn += 1;
        _state.phase = Take6Phase.selectingCard;
        _state.eventLogs.add('🔔 第 ${_state.currentTurn}/10 轮开始，请各位玩家秘密暗扣一张手牌！');
        _emit();
      });
    }
  }

  void _emit() {
    _stateController.add(_state.copy());
  }

  void dispose() {
    _stepTimer?.cancel();
    _stateController.close();
  }
}
