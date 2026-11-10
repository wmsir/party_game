import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/contracts/game_channel.dart';
import '../../core/contracts/game_host_context.dart';
import '../../core/contracts/game_reward_bridge.dart';
import '../../core/models/game_action.dart';
import '../../core/models/game_player.dart';
import '../../core/services/game_audio_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/room_provider.dart';
import '../../../services/socket_service.dart';
import '../../../services/api_service.dart';
import '../../../views/widgets/game_settlement_dialog.dart';
import '../../../views/widgets/in_game_throw_dialog.dart';
import '../../../views/chat/widgets/interactive_throw_overlay.dart';
import '../../../views/widgets/in_game_chat_overlay.dart';
import '../../../views/room/game_room_lobby_view.dart';
import '../../../models/game_room_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../main.dart';
import '../../../views/main_frame_view.dart';
import '../domain/take6_ai.dart';
import '../domain/take6_card.dart';
import '../domain/take6_row.dart';
import '../domain/take6_engine.dart';
import '../domain/take6_state.dart';
import '../adapters/take6_ai_channel.dart';
import 'widgets/take6_card_widget.dart';
import 'widgets/take6_hand_widget.dart';
import 'widgets/take6_row_widget.dart';

/// 谁是牛头王 - 完整游戏主屏幕 (整洁架构表现层，完全依赖注入)
class Take6GameScreen extends StatefulWidget {
  final IGameChannel channel;
  final IGameRewardBridge rewardBridge;
  final IGameHostContext hostContext;
  final List<GamePlayer> players;
  final String localPlayerId;
  final String? roomCode;
  final List<List<int>>? initialRowNumbers;
  final Map<String, List<int>>? initialHandNumbers;
  final Map<String, int>? initialScores;
  final int? initialTurn;
  final Take6Engine? existingEngine;
  final bool isSpectator;

  const Take6GameScreen({
    super.key,
    required this.channel,
    required this.rewardBridge,
    required this.hostContext,
    required this.players,
    required this.localPlayerId,
    this.roomCode,
    this.initialRowNumbers,
    this.initialHandNumbers,
    this.initialScores,
    this.initialTurn,
    this.existingEngine,
    this.isSpectator = false,
  });

  /// 快速构建工厂方法（默认单机/离线 AI 对战，支持传入网络同步初始手牌与底牌）
  static Widget createOffline({
    required List<GamePlayer> players,
    required String localPlayerId,
    required IGameRewardBridge rewardBridge,
    required IGameHostContext hostContext,
    String? roomCode,
    List<List<int>>? initialRowNumbers,
    Map<String, List<int>>? initialHandNumbers,
    Map<String, int>? initialScores,
    int? initialTurn,
    Take6Engine? existingEngine,
    bool isSpectator = false,
  }) {
    final channel = Take6AiChannel();
    return Take6GameScreen(
      channel: channel,
      rewardBridge: rewardBridge,
      hostContext: hostContext,
      players: players,
      localPlayerId: localPlayerId,
      roomCode: roomCode,
      initialRowNumbers: initialRowNumbers,
      initialHandNumbers: initialHandNumbers,
      initialScores: initialScores,
      initialTurn: initialTurn,
      existingEngine: existingEngine,
      isSpectator: isSpectator,
    );
  }

  @override
  State<Take6GameScreen> createState() => _Take6GameScreenState();
}

class _Take6GameScreenState extends State<Take6GameScreen> {
  late final Take6Engine _engine;
  StreamSubscription<Take6State>? _stateSub;
  StreamSubscription<GameAction>? _actionSub;
  StreamSubscription? _socketSub;

  Take6Card? _selectedCard;

  // AI 托管代打与状态
  bool _isAutoPlay = false;
  Timer? _autoPlayTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  Take6Phase? _currentCountingPhase;
  int _currentCountingTurn = -1;
  String? _currentCountingChooserId;
  bool _hasSettledGameOver = false;
  int _lastHandledLogCount = 0;

  bool get _isHost {
    try {
      final room = context.read<RoomProvider>().currentRoom;
      if (room != null && room.hostPlayerId.isNotEmpty) {
        return room.hostPlayerId == widget.localPlayerId;
      }
    } catch (_) {}
    return widget.players.isNotEmpty && widget.players.first.id == widget.localPlayerId;
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    if (_isAutoPlay) {
      _checkAutoPlayAction(_engine.state);
    } else {
      _autoPlayTimer?.cancel();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAutoPlay ? '🤖 已开启【AI智能托管】：系统将在轮到您时自动选牌与避坑' : '👤 已取消托管，恢复手动操作'),
        backgroundColor: _isAutoPlay ? const Color(0xFFD97706) : const Color(0xFF475569),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startOrUpdateTurnCountdown(Take6State state) {
    if (state.phase == Take6Phase.selectingCard) {
      if (_currentCountingPhase != Take6Phase.selectingCard || _currentCountingTurn != state.currentTurn) {
        _currentCountingPhase = Take6Phase.selectingCard;
        _currentCountingTurn = state.currentTurn;
        _currentCountingChooserId = null;
        _startTimer(20, onTimeout: () => _handleSelectingCardTimeout(state.currentTurn));
      }
    } else if (state.phase == Take6Phase.awaitingRowChoice) {
      if (_currentCountingPhase != Take6Phase.awaitingRowChoice || _currentCountingChooserId != state.playerChoosingRowId) {
        _currentCountingPhase = Take6Phase.awaitingRowChoice;
        _currentCountingChooserId = state.playerChoosingRowId;
        _startTimer(10, onTimeout: () => _handleRowChoiceTimeout(state.playerChoosingRowId));
      }
    } else {
      _countdownTimer?.cancel();
      _currentCountingPhase = null;
      _currentCountingChooserId = null;
      if (_remainingSeconds != 0) {
        setState(() {
          _remainingSeconds = 0;
        });
      }
    }
  }

  void _startTimer(int seconds, {required VoidCallback onTimeout}) {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        onTimeout();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _handleSelectingCardTimeout(int turnNumber) {
    final cur = _engine.state;
    if (cur.phase != Take6Phase.selectingCard || cur.currentTurn != turnNumber) return;

    // 1. 本地玩家超时未出牌：自动开启托管并代出最佳牌
    if (cur.selectedCards[widget.localPlayerId] == null) {
      if (!_isAutoPlay) {
        setState(() {
          _isAutoPlay = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ 出牌超时！已自动为您开启【智能托管】避坑代打'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 3),
          ),
        );
      }
      final hand = cur.playerHands[widget.localPlayerId] ?? [];
      if (hand.isNotEmpty) {
        final bestCard = Take6Ai.decideCardToPlay(
          aiPlayerId: widget.localPlayerId,
          hand: hand,
          rows: cur.rows,
          personality: 'BALANCED',
        );
        _selectedCard = bestCard;
        _onConfirmPlay();
      }
    }

    // 2. 房主保底机制：联机房间中，延迟 3 秒给远端网络客户端（如 H5/断网重连玩家）充分时机提交其本地手牌
    // 若 3 秒后远端仍未出牌，房主严格从该玩家【真实手牌列表】中代出最佳牌，严禁随机捏造虚假牌！
    if (_isHost) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!mounted) return;
        final latestState = _engine.state;
        if (latestState.phase != Take6Phase.selectingCard || latestState.currentTurn != turnNumber) return;

        for (final p in latestState.players) {
          if (p.id != widget.localPlayerId && latestState.selectedCards[p.id] == null) {
            final pHand = latestState.playerHands[p.id] ?? [];
            if (pHand.isNotEmpty) {
              final cardToPlay = Take6Ai.decideCardToPlay(
                aiPlayerId: p.id,
                hand: pHand,
                rows: latestState.rows,
                personality: 'BALANCED',
              );
              _engine.playerPickCard(p.id, cardToPlay);
              if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
                SocketService().send({
                  'type': 'GAME_ACTION',
                  'action': 'PLAY_CARD',
                  'roomCode': widget.roomCode,
                  'senderId': p.id,
                  'payload': {
                    'card': cardToPlay.number,
                    'cardNumber': cardToPlay.number,
                    'bullheads': cardToPlay.bullheads,
                    'isTimeoutAutoPlay': true,
                  },
                });
              }
            }
          }
        }
      });
    }
  }

  void _handleRowChoiceTimeout(String? chooserId) {
    final cur = _engine.state;
    if (cur.phase != Take6Phase.awaitingRowChoice || cur.playerChoosingRowId != chooserId) return;
    if (chooserId == null) return;

    final bestRow = Take6Ai.decideRowToTake(rows: cur.rows);

    // 1. 本地玩家吃行超时：自动开启托管并选牛头最少的一行
    if (chooserId == widget.localPlayerId) {
      if (!_isAutoPlay) {
        setState(() {
          _isAutoPlay = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ 选择吃行超时！系统已自动为您选择牛头最少的一行'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 3),
          ),
        );
      }
      _onSelectRowToTake(bestRow);
    } else if (_isHost) {
      // 2. 房主保底：远端掉线或超时未选行，给远端 2.5 秒网络缓冲后再代其收走牛头最少行
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        final curLatest = _engine.state;
        if (curLatest.phase == Take6Phase.awaitingRowChoice && curLatest.playerChoosingRowId == chooserId) {
          _engine.playerChooseRowToTake(chooserId, bestRow);
          if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
            SocketService().send({
              'type': 'GAME_ACTION',
              'action': 'TAKE_ROW',
              'roomCode': widget.roomCode,
              'senderId': chooserId,
              'payload': {
                'rowIndex': bestRow,
                'isTimeoutAutoPlay': true,
              },
            });
          }
        }
      });
    }
  }

  void _checkAutoPlayAction(Take6State state) {
    if (!_isAutoPlay) return;

    // 出牌阶段自动选牌并提交
    if (state.phase == Take6Phase.selectingCard && state.selectedCards[widget.localPlayerId] == null) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || !_isAutoPlay) return;
        final cur = _engine.state;
        if (cur.phase != Take6Phase.selectingCard || cur.selectedCards[widget.localPlayerId] != null) return;
        final hand = cur.playerHands[widget.localPlayerId] ?? [];
        if (hand.isEmpty) return;
        final bestCard = Take6Ai.decideCardToPlay(
          aiPlayerId: widget.localPlayerId,
          hand: hand,
          rows: cur.rows,
          personality: 'BALANCED',
        );
        _selectedCard = bestCard;
        _onConfirmPlay();
      });
    }

    // 必须收走一行时自动选择牛头最少的一行
    if (state.phase == Take6Phase.awaitingRowChoice && state.playerChoosingRowId == widget.localPlayerId) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || !_isAutoPlay) return;
        final cur = _engine.state;
        if (cur.phase != Take6Phase.awaitingRowChoice || cur.playerChoosingRowId != widget.localPlayerId) return;
        final bestRow = Take6Ai.decideRowToTake(rows: cur.rows);
        _onSelectRowToTake(bestRow);
      });
    }
  }

  void _minimizeRoom() {
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    roomProv.registerActiveSession(
      ActiveRoomSession(
        roomCode: widget.roomCode ?? '888666',
        gameType: 'take6',
        gameTitle: '谁是牛头王',
        gameIcon: '🐂',
        isMinimized: true,
        screenBuilder: (_) => Take6GameScreen(
          channel: widget.channel,
          rewardBridge: widget.rewardBridge,
          hostContext: widget.hostContext,
          players: _engine.state.players.isNotEmpty ? _engine.state.players : widget.players,
          localPlayerId: widget.localPlayerId,
          roomCode: widget.roomCode,
          initialRowNumbers: widget.initialRowNumbers,
          initialHandNumbers: widget.initialHandNumbers,
          existingEngine: _engine,
          isSpectator: widget.isSpectator,
        ),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗗 房间已最小化至右侧悬浮窗，可在任意页面随时点击恢复！'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFD97706),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingEngine != null) {
      _engine = widget.existingEngine!;
    } else {
      _engine = Take6Engine(isHost: _isHost);
    }
    _engine.isHost = _isHost;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        // 无论是全新进入还是从悬浮窗最小化恢复，均确保与当前房间长连接席位绑定
        if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
          SocketService().send({
            'type': 'JOIN_ROOM',
            'roomCode': widget.roomCode,
            'userId': widget.localPlayerId,
            'nickname': user.nickname,
            'avatar': user.avatar,
          });
        }
      }
    });

    // 监听引擎内部状态流
    _stateSub = _engine.stateStream.listen((state) {
      if (mounted) {
        setState(() {});
        widget.channel.broadcastState(state);
        _handleStateEvents(state);

        // 桌面状态变更时，仅房主(权威主机)向全房间广播同步数据，切断多端互冲死循环
        // 关键：在翻牌(revealing)、入行(resolving)、吃行(awaitingRowChoice)、游戏结束(gameOver)
        // 以及新一回合开始暗扣选牌(isTurnStart，此时全员手牌已更新且待选)时，均需全房间权威同步！
        if (_isHost && widget.roomCode != null && widget.roomCode!.isNotEmpty) {
          final isRevealedPhase = state.phase == Take6Phase.revealing || state.phase == Take6Phase.resolving;
          final isTurnStart = state.phase == Take6Phase.selectingCard && state.selectedCards.values.every((c) => c == null);
          if (isRevealedPhase || state.phase == Take6Phase.awaitingRowChoice || state.phase == Take6Phase.gameOver || isTurnStart) {
            SocketService().send({
              'type': 'GAME_ACTION',
              'action': 'TAKE6_STATE_SYNC',
              'roomCode': widget.roomCode,
              'senderId': widget.localPlayerId,
              'payload': {
                'rows': state.rows.map((r) => r.cards.map((c) => c.number).toList()).toList(),
                'scores': state.penaltyScores,
                'penaltyScores': state.penaltyScores,
                'phase': state.phase.name,
                'currentTurn': state.currentTurn,
                'playerChoosingRowId': state.playerChoosingRowId,
                'revealedCards': {
                  for (var entry in state.selectedCards.entries)
                    if (entry.value != null) entry.key: entry.value!.number
                },
                'readyPlayerIds': state.selectedCards.entries
                    .where((e) => e.value != null)
                    .map((e) => e.key)
                    .toList(),
                'playerHands': {
                  for (var entry in state.playerHands.entries)
                    entry.key: entry.value.map((c) => c.number).toList()
                },
                'eventLogs': state.eventLogs.isNotEmpty ? state.eventLogs.last : null,
              },
            });
          }
        }
      }
    });

    // 监听信道输入的动作指令 (包含本地玩家、本地 AI 或联机远端)
    _actionSub = widget.channel.actionStream.listen((action) {
      if (action.actionType == 'PICK_CARD') {
        final cardNum = action.payload['cardNumber'] as int;
        _engine.playerPickCard(action.playerId, Take6Card.fromNumber(cardNum));
      } else if (action.actionType == 'CHOOSE_ROW') {
        final rowIndex = action.payload['rowIndex'] as int;
        _engine.playerChooseRowToTake(action.playerId, rowIndex);
      }
    });

    // 启动信道并开局 (支持网络同步发牌)
    widget.channel.initialize();

    if (widget.existingEngine == null) {
      List<Take6Row>? initRows;
      if (widget.initialRowNumbers != null && widget.initialRowNumbers!.isNotEmpty) {
        initRows = [];
        for (int i = 0; i < widget.initialRowNumbers!.length; i++) {
          final nums = widget.initialRowNumbers![i];
          initRows.add(Take6Row(rowIndex: i, cards: nums.map((n) => Take6Card.fromNumber(n)).toList()));
        }
      }
      Map<String, List<Take6Card>>? initHands;
      if (widget.initialHandNumbers != null && widget.initialHandNumbers!.isNotEmpty) {
        initHands = {};
        for (final entry in widget.initialHandNumbers!.entries) {
          initHands[entry.key] = entry.value.map((n) => Take6Card.fromNumber(n)).toList();
        }
      }

      _engine.startNewMatch(
        players: widget.players,
        initialRows: initRows,
        initialHands: initHands,
        initialScores: widget.initialScores,
        initialTurn: widget.initialTurn,
      );
    } else {
      widget.channel.broadcastState(_engine.state);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleStateEvents(_engine.state);
        }
      });
    }
    GameAudioService().startBgm(gameType: 'take6');

    // 监听多端网络房间游戏动作 (来自 H5 网页或其他手机玩家)
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      _socketSub = SocketService().messageStream.listen((data) {
        if (!mounted) return;
        if (data['type'] == 'ROOM_PLAYERS_UPDATED' || data['type'] == 'ROOM_RECONNECT_SYNC') {
          final rawPlayers = data['players'] as List?;
          if (rawPlayers != null) {
            final newPlayers = rawPlayers.map((p) {
              final map = p as Map;
              return GamePlayer(
                id: (map['id'] ?? map['userId'] ?? '').toString(),
                name: (map['name'] ?? map['nickname'] ?? '玩家').toString(),
                avatar: (map['avatar'] ?? '').toString(),
                isAi: map['isAi'] == true,
              );
            }).toList();
            if (newPlayers.isNotEmpty) {
              _engine.updatePlayers(newPlayers);
            }
          }
          if (data['type'] == 'ROOM_RECONNECT_SYNC') {
            // 房主本地为权威主机，非房主重连时全面同步桌面、手牌、积分与回合
            if (!_isHost) {
              final take6Rows = (data['take6Rows'] ?? data['rows']) as List?;
              final take6Scores = (data['take6Scores'] ?? data['scores'] ?? data['penaltyScores']) as Map?;
              final rawHands = (data['take6PlayerHands'] ?? data['playerHands']) as Map?;
              final rawTurn = data['take6CurrentTurn'] ?? data['currentTurn'];
              final cTurn = rawTurn != null ? int.tryParse(rawTurn.toString()) : null;

              List<List<int>>? rowNums;
              if (take6Rows != null && take6Rows.isNotEmpty) {
                rowNums = <List<int>>[];
                for (final r in take6Rows) {
                  if (r is List) {
                    rowNums.add(r.map((x) => int.tryParse(x.toString()) ?? 0).toList());
                  }
                }
              }

              Map<String, int>? sc;
              if (take6Scores != null) {
                sc = <String, int>{};
                take6Scores.forEach((k, v) {
                  sc![k.toString()] = int.tryParse(v.toString()) ?? 0;
                });
              }

              Map<String, List<int>>? handsMap;
              if (rawHands != null && rawHands.isNotEmpty) {
                handsMap = <String, List<int>>{};
                rawHands.forEach((k, v) {
                  if (v is List) {
                    handsMap![k.toString()] = v.map((x) => int.tryParse(x.toString()) ?? 0).toList();
                  }
                });
              }

              _engine.syncFromRemote(
                rowNumbers: rowNums,
                penaltyScores: sc,
                playerHands: handsMap,
                currentTurn: cTurn,
              );
            }
          }
        } else if (data['type'] == 'KICKED_FROM_ROOM' || data['type'] == 'PLAYER_KICKED') {
          final code = data['roomCode']?.toString();
          if (code == null || code == widget.roomCode) {
            final targetId = data['targetPlayerId']?.toString();
            final myId = widget.localPlayerId;
            final cleanMy = myId.replaceAll('-', '').toLowerCase();
            final cleanTarget = (targetId ?? '').replaceAll('-', '').toLowerCase();
            if (cleanMy.isNotEmpty && cleanMy == cleanTarget) {
              _socketSub?.cancel();
              _countdownTimer?.cancel();
              _autoPlayTimer?.cancel();
              _stateSub?.cancel();
              _actionSub?.cancel();
              try {
                final roomProv = context.read<RoomProvider>();
                roomProv.closeActiveSession();
                roomProv.setCurrentRoom(null);
                final chatProv = context.read<ChatProvider>();
                chatProv.setCurrentRoomCode(null);
                chatProv.switchChannel('WORLD');
              } catch (_) {}
              PartyGameApp.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainFrameView()),
                (route) => false,
              );
              PartyGameApp.messengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('⚠️ 您已被房主移出该房间！'),
                  backgroundColor: Color(0xFFEF4444),
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
          }
        } else if (data['type'] == 'GAME_ACTION') {
          final action = data['action'];
          final senderId = data['senderId']?.toString();
          if (action == 'GAME_RESTART') {
            if (senderId != null && senderId.isNotEmpty && senderId != widget.localPlayerId) {
              _returnToRoomLobby(shouldBroadcast: false);
            }
            return;
          }
          if (action == 'GAME_OVER') {
            _triggerGameOverSettlement(data['payload'] as Map?);
            return;
          }
          if (senderId == widget.localPlayerId) return;
          if (action == 'PLAY_CARD') {
            final payload = data['payload'] as Map?;
            final cardNum = payload?['card'] ?? payload?['cardNumber'];
            if (cardNum != null) {
              final numVal = (cardNum is int) ? cardNum : int.tryParse(cardNum.toString());
              if (numVal != null && numVal >= 1 && numVal <= 104) {
                _engine.playerPickCard(senderId ?? 'remote', Take6Card.fromNumber(numVal));
              }
            }
          } else if (action == 'TAKE_ROW') {
            final payload = data['payload'] as Map?;
            final rowIndex = payload?['rowIndex'];
            if (rowIndex != null) {
              final rVal = (rowIndex is int) ? rowIndex : int.tryParse(rowIndex.toString());
              if (rVal != null && rVal >= 0 && rVal < 4) {
                _engine.playerChooseRowToTake(senderId ?? 'remote', rVal);
              }
            }
          } else if (action == 'TAKE6_STATE_SYNC') {
            final payload = data['payload'] as Map?;
            if (payload != null && payload['phase'] == 'gameOver') {
              _triggerGameOverSettlement(payload);
            }
            if (_isHost) return; // 房主本地为唯一权威状态机，绝不被远端状态逆向覆盖
            if (payload != null && payload['rows'] != null) {
              final rawRows = payload['rows'] as List;
              final rowNums = <List<int>>[];
              for (final r in rawRows) {
                if (r is List) {
                  rowNums.add(r.map((x) => int.tryParse(x.toString()) ?? 0).toList());
                }
              }
              final rawScores = (payload['scores'] ?? payload['penaltyScores']) as Map?;
              final sc = <String, int>{};
              if (rawScores != null) {
                rawScores.forEach((k, v) {
                  sc[k.toString()] = int.tryParse(v.toString()) ?? 0;
                });
              }
              final phaseStr = payload['phase']?.toString();
              Take6Phase? ph;
              if (phaseStr != null) {
                try {
                  ph = Take6Phase.values.firstWhere((p) => p.name == phaseStr);
                } catch (_) {}
              }
              final choosingId = payload['playerChoosingRowId']?.toString();
              final logMsg = payload['eventLogs']?.toString();
              final cTurn = (payload['currentTurn'] as num?)?.toInt();

              final rawRev = payload['revealedCards'] as Map?;
              final revMap = <String, int>{};
              if (rawRev != null) {
                rawRev.forEach((k, v) {
                  final numVal = int.tryParse(v.toString());
                  if (numVal != null) revMap[k.toString()] = numVal;
                });
              }

              final rawReady = payload['readyPlayerIds'] as List?;
              final readyIds = rawReady?.map((e) => e.toString()).toList();

              final rawHands = (payload['playerHands'] ?? payload['take6PlayerHands']) as Map?;
              Map<String, List<int>>? handsMap;
              if (rawHands != null && rawHands.isNotEmpty) {
                handsMap = <String, List<int>>{};
                rawHands.forEach((k, v) {
                  if (v is List) {
                    handsMap![k.toString()] = v.map((x) => int.tryParse(x.toString()) ?? 0).toList();
                  }
                });
              }

              _engine.syncFromRemote(
                rowNumbers: rowNums,
                penaltyScores: sc,
                phase: ph,
                currentTurn: cTurn,
                playerChoosingRowId: choosingId,
                revealedCards: revMap,
                readyPlayerIds: readyIds,
                playerHands: handsMap,
                log: logMsg,
              );
            }
          }
        }
      });
    }
  }

  void _handleStateEvents(Take6State state) {
    _startOrUpdateTurnCountdown(state);
    _checkAutoPlayAction(state);

    // 将游戏对局事件日志实时打印同步到房间聊天记录
    if (state.eventLogs.length > _lastHandledLogCount) {
      final newLogs = state.eventLogs.sublist(_lastHandledLogCount);
      _lastHandledLogCount = state.eventLogs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final chat = context.read<ChatProvider>();
          for (final logMsg in newLogs) {
            chat.addRoomSystemNotice(logMsg);
          }
        } catch (_) {}
      });
    }

    // 游戏结束结算
    if (state.phase == Take6Phase.gameOver && !_hasSettledGameOver) {
      _triggerGameOverSettlement(null);
    }
  }

  void _triggerGameOverSettlement(Map? remotePayload) {
    if (_hasSettledGameOver) return;
    _hasSettledGameOver = true;

    if (remotePayload != null) {
      final rawScores = (remotePayload['scores'] ?? remotePayload['penaltyScores']) as Map?;
      if (rawScores != null) {
        final sc = <String, int>{};
        rawScores.forEach((k, v) {
          sc[k.toString()] = int.tryParse(v.toString()) ?? 0;
        });
        _engine.syncFromRemote(penaltyScores: sc, phase: Take6Phase.gameOver);
      }
    }

    final curState = _engine.state;
    final playersList = curState.players.isNotEmpty ? curState.players : widget.players;
    final ranking = List<GamePlayer>.from(playersList)
      ..sort((a, b) => (curState.penaltyScores[a.id] ?? 0).compareTo(curState.penaltyScores[b.id] ?? 0));

    if (ranking.isEmpty) return;

    final isMeWinner = ranking.first.id == widget.localPlayerId;
    if (isMeWinner) {
      GameAudioService().playSound('victory');
    } else {
      GameAudioService().playSound('defeat');
    }

    widget.rewardBridge.onMatchFinished(
      gameCode: 'TAKE_6',
      rankedPlayers: ranking,
      summary: {
        'winnerId': ranking.first.id,
        'winnerName': ranking.first.name,
        'penaltyScores': curState.penaltyScores,
      },
    );

    // 排位天梯与金币商业结算
    try {
      context.read<AuthProvider>().settleRankMatch(isMeWinner, gameType: 'take6');
    } catch (_) {}

    // 权威同步服务端与各端：若为房主，广播 GAME_OVER 供多端展示结算榜
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty && _isHost) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'GAME_OVER',
        'roomCode': widget.roomCode,
        'senderId': widget.localPlayerId,
        'payload': {
          'scores': curState.penaltyScores,
          'phase': 'gameOver',
        },
      });
    }

    final rankItems = ranking.map((p) {
      final score = curState.penaltyScores[p.id] ?? 0;
      final isMe = p.id == widget.localPlayerId;
      return GameSettlementRankItem(
        id: p.id,
        name: p.name,
        avatar: p.avatar,
        scoreText: '🐮 $score 个',
        isMe: isMe,
      );
    }).toList();

    final winner = ranking.first;
    final winnerScore = curState.penaltyScores[winner.id] ?? 0;
    final subtitle = '🏆 【${winner.name}】荣获本场冠军！最终吃下 $winnerScore 个牛头惩罚，避坑王者！';

    // 弹出商业结算弹窗 (全量战绩排行榜)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        GameSettlementDialog.show(
          context,
          isWin: isMeWinner,
          gameTitle: '谁是牛头王',
          gameIcon: '🐮',
          subtitle: subtitle,
          rankItems: rankItems,
          isSpectator: widget.isSpectator,
          onPlayAgain: _handlePlayAgain,
          onExit: () {
            final user = context.read<AuthProvider>().user;
            context.read<RoomProvider>().leaveRoom(user?.id, widget.roomCode);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      }
    });
  }

  bool _isNavigatingToLobby = false;

  void _handlePlayAgain() {
    final isOnlineRoom = widget.roomCode != null && widget.roomCode!.isNotEmpty;
    if (isOnlineRoom) {
      _returnToRoomLobby(shouldBroadcast: true);
    } else {
      _hasSettledGameOver = false;
      _lastHandledLogCount = 0;
      _engine.startNewMatch(players: widget.players);
    }
  }

  void _returnToRoomLobby({bool shouldBroadcast = true}) {
    if (!mounted || _isNavigatingToLobby) return;
    _isNavigatingToLobby = true;
    final roomProv = context.read<RoomProvider>();
    final room = roomProv.currentRoom ??
        (widget.roomCode != null
            ? GameRoomModel(
                roomCode: widget.roomCode!,
                gameType: 'take6',
                roomName: '谁是牛头王房间',
                hostPlayerId: widget.localPlayerId,
                players: widget.players,
              )
            : null);

    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      ApiService().resetRoom(widget.roomCode!);
      if (shouldBroadcast) {
        SocketService().send({
          'type': 'GAME_ACTION',
          'action': 'GAME_RESTART',
          'roomCode': widget.roomCode,
          'senderId': widget.localPlayerId,
        });
      }
    }

    if (room != null) {
      room.status = 'WAITING';
      for (final p in room.players) {
        final isHost = p.id == room.hostPlayerId || (room.players.isNotEmpty && room.players.first.id == p.id);
        p.isReady = isHost || p.isAi;
      }
      roomProv.setCurrentRoom(room);
      roomProv.closeActiveSession();

      PartyGameApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/room'),
          builder: (_) => GameRoomLobbyView(room: room, isReconnecting: false),
        ),
        (route) => route.isFirst,
      );
    } else {
      PartyGameApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  void _copyRoomCode() {
    if (widget.roomCode == null) return;
    final inviteText = '【海马聚会桌游】谁是牛头王开局啦！\n👉 房间号：${widget.roomCode}\n快打开海马 App 加入我们！';
    Clipboard.setData(ClipboardData(text: inviteText));
    GameAudioService().playSound('bid_ding');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 房间号 ${widget.roomCode} 邀请信息已复制！'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _countdownTimer?.cancel();
    _stateSub?.cancel();
    _actionSub?.cancel();
    _socketSub?.cancel();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearThrowEvent();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);
      final roomProv = context.read<RoomProvider>();
      if (!roomProv.hasMinimizedRoom) {
        GameAudioService().stopBgm();
        _engine.dispose();
        widget.channel.dispose();
        final user = context.read<AuthProvider>().user;
        roomProv.leaveRoom(user?.id, widget.roomCode, true);
      }
    } catch (_) {}
    super.dispose();
  }

  void _onConfirmPlay() {
    if (widget.isSpectator || _selectedCard == null) return;
    final playedCard = _selectedCard!;
    widget.hostContext.playSound('card_play');
    widget.hostContext.triggerHapticFeedback();

    widget.channel.dispatchAction(GameAction(
      actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch}',
      playerId: widget.localPlayerId,
      actionType: 'PICK_CARD',
      payload: {'cardNumber': playedCard.number},
    ));

    // 同步到房间其他端 (如 H5 网页玩家)
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'PLAY_CARD',
        'roomCode': widget.roomCode,
        'senderId': widget.localPlayerId,
        'payload': {
          'card': playedCard.number,
          'cardNumber': playedCard.number,
          'bullheads': playedCard.bullheads,
        },
      });
    }

    setState(() {
      _selectedCard = null;
    });
  }

  void _onSelectRowToTake(int rowIndex) {
    if (widget.isSpectator) return;
    widget.hostContext.playSound('bull_penalty');
    widget.hostContext.triggerHapticFeedback(heavy: true);

    widget.channel.dispatchAction(GameAction(
      actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch}',
      playerId: widget.localPlayerId,
      actionType: 'CHOOSE_ROW',
      payload: {'rowIndex': rowIndex},
    ));

    // 同步到房间其他端 (如 H5 网页玩家)
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'TAKE_ROW',
        'roomCode': widget.roomCode,
        'senderId': widget.localPlayerId,
        'payload': {'rowIndex': rowIndex},
      });
    }
  }

  void _showExitDialog() {
    if (_engine.state.phase == Take6Phase.gameOver || _hasSettledGameOver) {
      _returnToRoomLobby(shouldBroadcast: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('离开房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('您可以选择【最小化挂起】对局（可随时点击悬浮窗返回），或【强制退出】彻底离开当前房间。若强制退出，系统将为您开启自动托管代打，不影响其他玩家进行游戏。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _minimizeRoom();
            },
            child: const Text('🗗 最小化挂起', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              // 强制退出前执行托管保护：若当前轮次尚未选牌，帮其自动选牌并广播，避免阻碍其他人游戏
              final cur = _engine.state;
              if (cur.phase == Take6Phase.selectingCard && cur.selectedCards[widget.localPlayerId] == null) {
                final hand = cur.playerHands[widget.localPlayerId] ?? [];
                if (hand.isNotEmpty) {
                  final bestCard = Take6Ai.decideCardToPlay(
                    aiPlayerId: widget.localPlayerId,
                    hand: hand,
                    rows: cur.rows,
                    personality: 'BALANCED',
                  );
                  _selectedCard = bestCard;
                  _onConfirmPlay();
                }
              } else if (cur.phase == Take6Phase.awaitingRowChoice && cur.playerChoosingRowId == widget.localPlayerId) {
                final bestRow = Take6Ai.decideRowToTake(rows: cur.rows);
                _onSelectRowToTake(bestRow);
              }

              if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
                SocketService().send({
                  'type': 'GAME_ACTION',
                  'action': 'PLAYER_FORCE_EXIT',
                  'roomCode': widget.roomCode,
                  'senderId': widget.localPlayerId,
                });
              }

              final user = Provider.of<AuthProvider>(context, listen: false).user;
              final roomProv = Provider.of<RoomProvider>(context, listen: false);
              roomProv.leaveRoom(user?.id, widget.roomCode, true);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('🚪 开启托管并退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    final myHand = state.playerHands[widget.localPlayerId] ?? [];
    final mySelectedCard = state.selectedCards[widget.localPlayerId];
    final isMyTurnToChooseRow = state.phase == Take6Phase.awaitingRowChoice &&
        state.playerChoosingRowId == widget.localPlayerId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // 护眼柔和浅米灰
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 18),
            tooltip: '返回或最小化',
            onPressed: _showExitDialog,
          ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🐮 谁是牛头王 (Take 6!)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
                if (widget.isSpectator) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF6366F1)),
                    ),
                    child: const Text(
                      '👀 旁观中',
                      style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (_isAutoPlay) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: const Text(
                      '托管中',
                      style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            if (widget.roomCode != null)
              GestureDetector(
                onTap: _copyRoomCode,
                child: Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room, color: Color(0xFFD97706), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '房间号: ${widget.roomCode} (点击复制)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else if (widget.hostContext.roomOrTableName != null)
              Text(
                widget.hostContext.roomOrTableName!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // 智能托管按钮 (旁观者视角隐藏)
          if (!widget.isSpectator)
            IconButton(
              icon: Icon(
                _isAutoPlay ? Icons.smart_toy : Icons.smart_toy_outlined,
                color: _isAutoPlay ? const Color(0xFFD97706) : const Color(0xFF64748B),
              ),
              tooltip: _isAutoPlay ? '取消AI托管' : '开启AI智能托管',
              onPressed: _toggleAutoPlay,
            ),
          // 房间最小化按钮
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_outlined, color: Color(0xFF475569)),
            tooltip: '最小化房间',
            onPressed: _minimizeRoom,
          ),
          IconButton(
            icon: Icon(
              GameAudioService().isBgmEnabled ? Icons.music_note : Icons.music_off,
              color: GameAudioService().isBgmEnabled ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
            ),
            tooltip: '背景音乐开关',
            onPressed: () {
              setState(() {
                GameAudioService().toggleBgm();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF475569)),
            tooltip: '牛头王规则',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('🐮 谁是牛头王 · 规则速览', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1️⃣ 【同时盲选】每回合全员暗选 1 张手牌同时亮出，按数字【从小到大】依次接龙入行。', style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155))),
                      SizedBox(height: 8),
                      Text('2️⃣ 【差值最小原则】牌必须接在【末尾数字比它小、且差值最小】的那一行后面。', style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155))),
                      SizedBox(height: 8),
                      Text('3️⃣ 【第6张爆行】每行最多放 5 张牌！放入第 6 张牌的玩家必须收走该行前 5 张牌作为牛头惩罚。', style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155))),
                      SizedBox(height: 8),
                      Text('4️⃣ 【过小选行】若出的牌比 4 行末尾数字都小，需任选一行收走全部牌。10 回合后牛头最少者获胜！', style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155))),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('我知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: '重新开局',
            onPressed: () {
              if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
                final room = context.read<RoomProvider>().currentRoom;
                final nonHosts = room?.players.where((p) => p.id != widget.localPlayerId && !p.isAi).toList() ?? [];
                final allReady = nonHosts.isEmpty || nonHosts.every((p) => p.isReady);
                if (!allReady) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('尚有玩家未准备就绪，无法直接开局！请在房间大厅等待全员就绪。'),
                      backgroundColor: Color(0xFFF59E0B),
                    ),
                  );
                  return;
                }
              }
              _lastHandledLogCount = 0;
              _engine.startNewMatch(players: widget.players);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            // 托管状态高亮横幅
            if (_isAutoPlay)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.smart_toy, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 智能托管代打算牌中：正在帮您分析最佳避坑出牌',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _toggleAutoPlay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('取消托管', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            // 顶部玩家状态与牛头惩罚榜
            _buildPlayerScoreBar(state),

            // 中间游戏牌阵对决主桌面
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    // 回合提示与当前状态指示条
                    _buildRoundStatusBar(state, isMyTurnToChooseRow),
                    const SizedBox(height: 6),

                    // 本轮亮牌展示区 (翻牌、入行结算或等待选行时展示)
                    if (_hasRevealedCards(state))
                      _buildRevealedCardsShowcase(state),

                    // 4 移行牌桌面 (直接铺满中间对决区域，无冗余中间区域)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Builder(
                          builder: (context) {
                            int minBullsRowIdx = -1;
                            if (isMyTurnToChooseRow && state.rows.isNotEmpty) {
                              int minBulls = 999999;
                              for (final r in state.rows) {
                                if (r.totalBullheads < minBulls) {
                                  minBulls = r.totalBullheads;
                                  minBullsRowIdx = r.rowIndex;
                                }
                              }
                            }
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: state.rows.map((row) {
                                return Take6RowWidget(
                                  key: ValueKey('take6-row-${row.rowIndex}'),
                                  row: row,
                                  isSelectableToTake: isMyTurnToChooseRow,
                                  isRecommendedRow: isMyTurnToChooseRow && (row.rowIndex == minBullsRowIdx),
                                  onSelectRow: () => _onSelectRowToTake(row.rowIndex),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部玩家手牌操作托盘 (旁观者显示专属全员亮牌大席，不可看私密手牌)
            if (state.phase != Take6Phase.gameOver)
              widget.isSpectator
                  ? _buildSpectatorBottomPanel(state)
                  : Take6HandWidget(
                      handCards: myHand,
                      selectedCard: _selectedCard,
                      canPlay: state.phase == Take6Phase.selectingCard && mySelectedCard == null,
                      hasCommitted: mySelectedCard != null && state.phase == Take6Phase.selectingCard,
                      isAutoPlay: _isAutoPlay,
                      onToggleAutoPlay: _toggleAutoPlay,
                      onCardSelected: (card) {
                        setState(() {
                          _selectedCard = card;
                        });
                      },
                      onConfirmPlay: _onConfirmPlay,
                    )
            else
              _buildGameOverResultBanner(state),
            ],
          ),
        ),
        Consumer<ChatProvider>(
          builder: (context, chat, _) => InteractiveThrowOverlay(
            event: chat.lastThrowEvent,
            onComplete: () => chat.clearThrowEvent(),
          ),
        ),
        if (widget.roomCode != null && widget.roomCode!.isNotEmpty)
          InGameChatOverlay(
            roomCode: widget.roomCode!,
            myPlayerId: widget.localPlayerId,
            myPlayerName: context.read<AuthProvider>().user?.nickname ?? '我',
            myPlayerAvatar: context.read<AuthProvider>().user?.avatar ?? '🦊',
          ),
      ],
    ),
  ),
);
}

  Widget _buildPlayerScoreBar(Take6State state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: state.players.map((p) {
          final isMe = p.id == widget.localPlayerId;
          final penalty = state.penaltyScores[p.id] ?? 0;
          final isReady = state.selectedCards[p.id] != null;
          final remainCards = state.playerHands[p.id]?.length ?? (11 - state.currentTurn).clamp(0, 10);

          return InkWell(
            onTap: isMe
                ? null
                : () {
                    InGameThrowDialog.show(
                      context,
                      targetPlayerId: p.id,
                      targetPlayerName: p.name,
                    );
                  },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFCCFBF1).withOpacity(0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: isMe ? Border.all(color: const Color(0xFF0D9488), width: 1.2) : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isMe ? const Color(0xFF0D9488) : const Color(0xFF059669),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0] : '玩',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: isMe ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                          fontSize: 11,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        state.phase == Take6Phase.selectingCard
                            ? (isReady ? '🎴 剩$remainCards张 · 已出' : '⏳ 剩$remainCards张 · 思考')
                            : '🐮 $penalty 头 (剩$remainCards张)',
                        style: TextStyle(
                          color: state.phase == Take6Phase.selectingCard
                              ? (isReady ? const Color(0xFF059669) : const Color(0xFFD97706))
                              : (penalty > 15 ? const Color(0xFFDC2626) : const Color(0xFF475569)),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoundStatusBar(Take6State state, bool isMyTurnToChooseRow) {
    String statusText;
    Color statusColor = const Color(0xFF0D9488);
    Color statusBg = const Color(0xFFF0FDFA);

    final readyCount = state.selectedCards.values.where((c) => c != null).length;
    final totalCount = state.players.length;

    final isSelecting = state.phase == Take6Phase.selectingCard;
    final isAwaitingChoice = state.phase == Take6Phase.awaitingRowChoice;
    final showTimer = (isSelecting || isAwaitingChoice) && _remainingSeconds > 0;
    final isUrgent = _remainingSeconds <= 5 && _remainingSeconds > 0;

    if (isSelecting) {
      final mySelected = state.selectedCards[widget.localPlayerId] != null;
      statusText = mySelected
          ? '🎴 您已暗扣出牌，等待其他玩家 ($readyCount/$totalCount 人已扣牌)...'
          : '第 ${state.currentTurn}/10 轮 · 请秘密暗扣一张手牌 ($readyCount/$totalCount 人已出)';
    } else if (state.phase == Take6Phase.revealing) {
      statusText = '🃏 全员出牌完毕！正在同时翻牌展示每位玩家手牌...';
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
    } else if (isAwaitingChoice) {
      statusText = isMyTurnToChooseRow ? '⚠️ 您的牌太小！请在上方选择收走任意一行' : '等待玩家挑选收走的行牌...';
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
    } else if (state.phase == Take6Phase.resolving) {
      statusText = '👉 正在从小到大依次入行结算...';
    } else {
      statusText = '🏆 10轮打完，游戏结束结算！';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showTimer) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${_remainingSeconds}s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameOverResultBanner(Take6State state) {
    final ranking = List<GamePlayer>.from(state.players)
      ..sort((a, b) => (state.penaltyScores[a.id] ?? 0).compareTo(state.penaltyScores[b.id] ?? 0));
    final winner = ranking.first;
    final isMeWinner = winner.id == widget.localPlayerId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMeWinner ? '🎉 恭喜您获得最终胜利！' : '🏁 游戏结束',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            '获胜者：${winner.name} (仅累计 🐮x${state.penaltyScores[winner.id]} 头牛)',
            style: const TextStyle(fontSize: 13, color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.military_tech_outlined, size: 16),
                label: const Text('结算明细', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final ranking = List<GamePlayer>.from(state.players)
                    ..sort((a, b) => (state.penaltyScores[a.id] ?? 0).compareTo(state.penaltyScores[b.id] ?? 0));
                  final rankItems = ranking.map((p) {
                    final score = state.penaltyScores[p.id] ?? 0;
                    final isMe = p.id == widget.localPlayerId;
                    return GameSettlementRankItem(
                      id: p.id,
                      name: p.name,
                      avatar: p.avatar,
                      scoreText: '🐮 $score 个',
                      isMe: isMe,
                    );
                  }).toList();

                  final winner = ranking.first;
                  final winnerScore = state.penaltyScores[winner.id] ?? 0;
                  final subtitle = '🏆 【${winner.name}】荣获本场冠军！最终吃下 $winnerScore 个牛头惩罚，避坑王者！';

                  GameSettlementDialog.show(
                    context,
                    isWin: isMeWinner,
                    gameTitle: '谁是牛头王',
                    gameIcon: '🐮',
                    subtitle: subtitle,
                    rankItems: rankItems,
                    isSpectator: widget.isSpectator,
                    onPlayAgain: _handlePlayAgain,
                    onExit: () => Navigator.pop(context),
                  );
                },
              ),
              const SizedBox(width: 12),
              if (widget.isSpectator)
                ElevatedButton.icon(
                  onPressed: () {
                    final user = context.read<AuthProvider>().user;
                    SocketService().send({
                      'type': 'GAME_ACTION',
                      'action': 'SPECTATOR_JOIN_SEAT',
                      'roomCode': widget.roomCode,
                      'userId': user?.id ?? widget.localPlayerId,
                      'userName': user?.nickname ?? '玩家',
                      'userAvatar': user?.avatar ?? '🦊',
                    });
                    _handlePlayAgain();
                  },
                  icon: const Icon(Icons.airline_seat_recline_normal, size: 16),
                  label: const Text('🪑 加入席位上桌准备', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _handlePlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('再来一局 🐮', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasRevealedCards(Take6State state) {
    if (state.phase == Take6Phase.gameOver) return false;
    if (state.phase == Take6Phase.revealing ||
        state.phase == Take6Phase.resolving ||
        state.phase == Take6Phase.awaitingRowChoice) {
      return true;
    }
    return state.selectedCards.values.any((c) => c != null && c.number > 1);
  }

  Widget _buildRevealedCardsShowcase(Take6State state) {
    final revealedEntries = <Map<String, dynamic>>[];
    for (final p in state.players) {
      final card = state.selectedCards[p.id];
      if (card != null && card.number > 1) {
        revealedEntries.add({
          'player': p,
          'card': card,
        });
      }
    }
    revealedEntries.sort((a, b) => (a['card'] as Take6Card).compareTo(b['card'] as Take6Card));

    if (revealedEntries.isEmpty) return const SizedBox.shrink();

    final cardsOnRows = <int>{};
    for (final r in state.rows) {
      for (final c in r.cards) {
        cardsOnRows.add(c.number);
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🎴', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              const Text(
                '本轮亮牌展示',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('从小到大入行', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (state.currentResolvingEntry != null)
                Text(
                  '👉 【${state.currentResolvingEntry!.playerName}】入行中',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: revealedEntries.map((item) {
                final p = item['player'] as GamePlayer;
                final card = item['card'] as Take6Card;
                final isCurrent = state.currentResolvingEntry?.playerId == p.id;
                final isChoosing = state.playerChoosingRowId == p.id;
                final isPlaced = cardsOnRows.contains(card.number);

                Color borderColor = const Color(0xFFCBD5E1);
                Color bgColor = Colors.white;
                String tag = '待入行';
                Color tagColor = const Color(0xFF64748B);

                if (isChoosing) {
                  borderColor = const Color(0xFFEF4444);
                  bgColor = const Color(0xFFFEF2F2);
                  tag = '⚠️ 选行';
                  tagColor = const Color(0xFFDC2626);
                } else if (isCurrent) {
                  borderColor = const Color(0xFFF59E0B);
                  bgColor = const Color(0xFFFEF3C7);
                  tag = '▶ 当前';
                  tagColor = const Color(0xFFD97706);
                } else if (isPlaced) {
                  borderColor = const Color(0xFF10B981);
                  bgColor = const Color(0xFFECFDF5);
                  tag = '✓ 已入';
                  tagColor = const Color(0xFF059669);
                }

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: isCurrent || isChoosing ? 2 : 1),
                    boxShadow: (isCurrent || isChoosing)
                        ? [BoxShadow(color: borderColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.avatar, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 55),
                            child: Text(
                              p.name,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${card.number}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 2),
                              Text('🐮${card.bullheads}', style: const TextStyle(fontSize: 9, color: Color(0xFFD97706))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: tagColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectatorBottomPanel(Take6State state) {
    final hasRevealed = _hasRevealedCards(state);
    final isSelecting = state.phase == Take6Phase.selectingCard;
    final readyCount = state.selectedCards.values.where((c) => c != null).length;

    final cardsOnRows = <int>{};
    for (final r in state.rows) {
      for (final c in r.cards) {
        cardsOnRows.add(c.number);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Color(0xFF818CF8), size: 13),
                      SizedBox(width: 4),
                      Text(
                        '观战大席',
                        style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasRevealed
                        ? '🃏 第 ${state.currentTurn}/10 轮 · 全员亮牌展示 (从小到大入行)'
                        : (isSelecting
                            ? '⏳ 第 ${state.currentTurn}/10 轮 · 选手扣牌中 ($readyCount/${state.players.length}已就绪)'
                            : '第 ${state.currentTurn}/10 轮对决进行中'),
                    style: TextStyle(
                      color: hasRevealed ? const Color(0xFFFDE68A) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    final user = context.read<AuthProvider>().user;
                    SocketService().send({
                      'type': 'GAME_ACTION',
                      'action': 'SPECTATOR_JOIN_SEAT',
                      'roomCode': widget.roomCode,
                      'userId': user?.id ?? widget.localPlayerId,
                      'userName': user?.nickname ?? '玩家',
                      'userAvatar': user?.avatar ?? '🦊',
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🪑 已提交上桌入席申请，本局打完后将自动为您就座！'),
                        backgroundColor: Color(0xFF6366F1),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF818CF8)),
                    ),
                    child: const Text('🪑 申请入席', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasRevealed) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: () {
                    final list = List<GamePlayer>.from(state.players);
                    list.sort((a, b) {
                      final ca = state.selectedCards[a.id]?.number ?? 999;
                      final cb = state.selectedCards[b.id]?.number ?? 999;
                      return ca.compareTo(cb);
                    });
                    return list.map((p) {
                      final card = state.selectedCards[p.id];
                      final isCurrent = state.currentResolvingEntry?.playerId == p.id;
                      final isChoosing = state.playerChoosingRowId == p.id;
                      final isPlaced = card != null && cardsOnRows.contains(card.number);

                      Color statusColor = const Color(0xFF64748B);
                      String statusLabel = '待入行';
                      if (isChoosing) {
                        statusColor = const Color(0xFFEF4444);
                        statusLabel = '⚠️ 选行中';
                      } else if (isCurrent) {
                        statusColor = const Color(0xFFF59E0B);
                        statusLabel = '▶ 入行中';
                      } else if (isPlaced) {
                        statusColor = const Color(0xFF10B981);
                        statusLabel = '✓ 已入行';
                      }

                      return Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.avatar, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 48),
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (card != null && card.number > 1)
                              Take6CardWidget(
                                card: card,
                                width: 46,
                                height: 64,
                                isSelected: isCurrent,
                                isHighlighted: isChoosing,
                              )
                            else
                              Container(
                                width: 46,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                alignment: Alignment.center,
                                child: const Text('❓', style: TextStyle(fontSize: 16)),
                              ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withOpacity(0.5), width: 0.8),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  }(),
                ),
              ),
            ] else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: state.players.map((p) {
                    final hasCommitted = state.selectedCards[p.id] != null;
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.avatar, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 48),
                                child: Text(
                                  p.name,
                                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Take6CardWidget(
                            card: hasCommitted ? Take6Card.fromNumber(1) : null,
                            isFaceDown: true,
                            width: 44,
                            height: 60,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasCommitted ? '✅ 已扣牌' : '💭 思考中',
                            style: TextStyle(
                              color: hasCommitted ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
