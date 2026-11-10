import '../../../views/room/game_room_lobby_view.dart';
import '../../../models/game_room_model.dart';
import '../../../services/socket_service.dart';
import '../../../services/api_service.dart';
import '../../../views/widgets/in_game_chat_overlay.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/room_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/sound/dice_voice_announcer.dart';
import '../../core/contracts/game_channel.dart';
import '../../core/contracts/game_host_context.dart';
import '../../core/contracts/game_reward_bridge.dart';
import '../../core/models/game_action.dart';
import '../../core/models/game_player.dart';
import '../../core/services/game_audio_service.dart';
import '../adapters/dice_ai_channel.dart';
import '../adapters/dice_local_auditor.dart';
import '../domain/dice_ai.dart';
import '../domain/dice_bid.dart';
import '../domain/dice_rules_engine.dart';
import '../domain/dice_state.dart';
import 'widgets/bid_dial_widget.dart';
import 'widgets/dice_cup_widget.dart';
import 'widgets/dice_shake_detector.dart';
import '../../../views/widgets/in_game_throw_dialog.dart';
import '../../../views/widgets/game_settlement_dialog.dart';
import '../../../providers/chat_provider.dart';
import 'widgets/liars_dice_showdown_dialog.dart';
import '../../../main.dart';
import '../../../views/main_frame_view.dart';
import '../../../views/chat/widgets/interactive_throw_overlay.dart';
import '../../../views/widgets/entrance_banner_overlay.dart';

/// 大话骰 / 骰子街 - 沉浸酒桌质感与明亮护眼游戏主界面
/// 支持：真人语音喊点播报（3个3、4个3、开！）、房间最小化与一键重返、AI 智能托管代打、物理摇骰
class LiarsDiceGameScreen extends StatefulWidget {
  final IGameChannel channel;
  final DiceLocalAuditor auditor;
  final IGameRewardBridge rewardBridge;
  final IGameHostContext hostContext;
  final List<GamePlayer> players;
  final String myPlayerId;
  final String? roomCode;
  final bool isSpectator;

  const LiarsDiceGameScreen({
    Key? key,
    required this.channel,
    required this.auditor,
    required this.rewardBridge,
    required this.hostContext,
    required this.players,
    required this.myPlayerId,
    this.roomCode,
    this.isSpectator = false,
  }) : super(key: key);

  /// 快速构建工厂方法（默认单机/离线 AI 对战）
  static Widget createOffline({
    required List<GamePlayer> players,
    required String myPlayerId,
    required IGameRewardBridge rewardBridge,
    required IGameHostContext hostContext,
    String? roomCode,
    bool isSpectator = false,
  }) {
    final engine = DiceRulesEngine();
    final auditor = DiceLocalAuditor(engine: engine);
    final channel = DiceAiChannel();

    return LiarsDiceGameScreen(
      channel: channel,
      auditor: auditor,
      rewardBridge: rewardBridge,
      hostContext: hostContext,
      players: players,
      myPlayerId: myPlayerId,
      roomCode: roomCode,
      isSpectator: isSpectator,
    );
  }

  @override
  State<LiarsDiceGameScreen> createState() => _LiarsDiceGameScreenState();
}

class _LiarsDiceGameScreenState extends State<LiarsDiceGameScreen> {
  late DiceRulesEngine _engine;
  late StreamSubscription _channelSub;
  late StreamSubscription _stateSub;
  StreamSubscription? _socketSub;
  DiceState? _currentState;
  final ScrollController _logScrollController = ScrollController();
  final bool _isRealShakeMode = true;

  // 语音喊点与托管状态
  final DiceVoiceAnnouncer _voiceAnnouncer = DiceVoiceAnnouncer();
  bool _isAutoPlay = false;
  Timer? _autoPlayTimer;
  DiceBid? _lastSpokenBid;
  DicePhase? _lastSpokenPhase;

  @override
  void initState() {
    super.initState();
    _voiceAnnouncer.init();
    _initGame();
    GameAudioService().startBgm();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        EntranceBannerOverlay.show(
          context,
          playerName: user.nickname,
          avatar: user.avatar,
          avatarFrame: user.avatarFrame,
          vipLevel: user.vipLevel,
          bannerId: user.entranceBanner,
        );

        if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
          SocketService().send({
            'type': 'JOIN_ROOM',
            'roomCode': widget.roomCode,
            'userId': widget.myPlayerId,
            'nickname': user.nickname,
            'avatar': user.avatar,
          });
        }
      }
    });

    _socketSub = SocketService().messageStream.listen((data) {
      if (!mounted) return;
      final type = data['type'];
      if (type == 'KICKED_FROM_ROOM' || type == 'PLAYER_KICKED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.roomCode) {
          final targetId = data['targetPlayerId']?.toString();
          final myId = widget.myPlayerId;
          final cleanMy = myId.replaceAll('-', '').toLowerCase();
          final cleanTarget = (targetId ?? '').replaceAll('-', '').toLowerCase();
          if (cleanMy.isNotEmpty && cleanMy == cleanTarget) {
            _socketSub?.cancel();
            _channelSub.cancel();
            _stateSub.cancel();
            _autoPlayTimer?.cancel();
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
      } else if (type == 'GAME_ACTION') {
        final action = data['action'];
        final payload = data['payload'];
        if (action == 'ROUND_RESTART') {
          // 局内小轮重开（吹牛下一回合洗骰），重置回合与骰子，绝不退出大厅！
          _engine.startNewRound(
            players: widget.players,
            starterIndex: (_currentState?.currentTurnIndex ?? 0) + 1,
            initialChips: _currentState?.chipsScore,
          );
          GameAudioService().playSound('dice_shake');
        } else if (action == 'GAME_RESTART') {
          _returnToRoomLobby(shouldBroadcast: false);
        } else if (action == 'DICE_SETTLEMENT' && payload is Map) {
          // 权威开盅全桌验点明牌大弹窗
          LiarsDiceShowdownDialog.show(
            context,
            settlementData: Map<String, dynamic>.from(payload),
            players: widget.players,
            myPlayerId: widget.myPlayerId,
          );
        } else if (action == 'DICE_MY_HAND' && payload is Map) {
          // 服务端下发玩家权威专属 5 颗手骰
          final rawDice = payload['dice'];
          if (rawDice is List) {
            final diceList = rawDice.map((x) => int.tryParse(x.toString()) ?? 1).toList();
            _engine.syncPlayerDice(widget.myPlayerId, diceList);
          }
        } else if (action == 'BID' && payload is Map) {
          final sender = data['senderId']?.toString();
          if (sender != null && sender != widget.myPlayerId) {
            final count = int.tryParse(payload['count']?.toString() ?? '0') ?? 0;
            final face = int.tryParse(payload['face']?.toString() ?? '1') ?? 1;
            final isPure = payload['isPure'] == true;
            if (count > 0 && face >= 1 && face <= 6) {
              _engine.playerBid(
                playerId: sender,
                count: count,
                face: face,
                isPure: isPure,
              );
            }
          }
        } else if (action == 'CHALLENGE') {
          final sender = data['senderId']?.toString();
          if (sender != null && sender != widget.myPlayerId) {
            _engine.playerChallenge(sender);
          }
        }
      } else if (type == 'ROOM_RECONNECT_SYNC') {
        final rawDice = data['myDice'] ?? data['dice'];
        if (rawDice is List) {
          final diceList = rawDice.map((x) => int.tryParse(x.toString()) ?? 1).toList();
          _engine.syncPlayerDice(widget.myPlayerId, diceList);
        }
      }
    });
  }

  void _initGame() {
    _engine = widget.auditor.engine;

    // 订阅领域状态变更
    _stateSub = _engine.stateStream.listen((state) {
      if (mounted) {
        setState(() => _currentState = state);
        widget.channel.broadcastState(state);
        _scrollToBottom();
        _handleVoiceShout(state);
        _checkAutoPlayDelegation(state);
      }
    });

    // 订阅信道动作流
    _channelSub = widget.channel.actionStream.listen((action) {
      final res = widget.auditor.executeAction(action);
      if (!res.isSuccess && action.playerId == widget.myPlayerId && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${res.message}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // 启动首回合
    _engine.startNewRound(players: widget.players);
    _currentState = _engine.state;
    widget.channel.broadcastState(_currentState!);
  }

  /// 处理真人语音喊点播报（“3个3”、“4个3”、“5个6斋”、“开！”）
  void _handleVoiceShout(DiceState state) {
    if (!_voiceAnnouncer.isEnabled) return;

    // 叫点播报
    if (state.currentBid != null && state.currentBid != _lastSpokenBid) {
      _lastSpokenBid = state.currentBid;
      final bid = state.currentBid!;
      final pitch = 0.9 + (bid.bidderName.hashCode % 4) * 0.12;
      _voiceAnnouncer.speakBid(
        count: bid.count,
        face: bid.face,
        isPure: bid.isPure,
        bidderName: bid.bidderName,
        pitch: pitch,
      );
    }

    // 开/劈播报与排位商业结算
    if (state.phase == DicePhase.challenged && _lastSpokenPhase != DicePhase.challenged) {
      _lastSpokenPhase = state.phase;
      _voiceAnnouncer.speakChallenge(challengerName: state.currentPlayer.name);
      if (state.lastResult != null) {
        _voiceAnnouncer.speakResult(isChallengerWon: state.lastResult!.isChallengerWon);
        final isMyWin = state.lastResult!.loserId != widget.myPlayerId;
        context.read<AuthProvider>().settleRankMatch(isMyWin, gameType: 'liars_dice');
        if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
          SocketService().send({
            'type': 'GAME_ACTION',
            'action': 'GAME_OVER',
            'roomCode': widget.roomCode,
            'senderId': widget.myPlayerId,
          });
        }
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) {
            GameSettlementDialog.show(
              context,
              isWin: isMyWin,
              gameTitle: '吹牛骰子',
              gameIcon: '🎲',
              subtitle: isMyWin
                  ? '开盅辨真伪，心理战完美大捷！'
                  : '惜败本局！下回看准再抓，稳操胜券！',
              onPlayAgain: () {
                _restartNextRound();
              },
              onExit: () {
                final user = context.read<AuthProvider>().user;
                context.read<RoomProvider>().leaveRoom(user?.id, widget.roomCode);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            );
          }
        });
      }
    } else {
      _lastSpokenPhase = state.phase;
    }
  }

  void _returnToRoomLobby({bool shouldBroadcast = true}) {
    if (!mounted) return;
    final roomProv = context.read<RoomProvider>();
    final room = roomProv.currentRoom ??
        (widget.roomCode != null
            ? GameRoomModel(
                roomCode: widget.roomCode!,
                gameType: 'liars_dice',
                roomName: '吹牛骰子房间',
                hostPlayerId: widget.myPlayerId,
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
          'senderId': widget.myPlayerId,
        });
      }
    }

    if (room != null) {
      room.status = 'WAITING';
      for (final p in room.players) {
        final isHost = p.id == room.hostPlayerId || (room.players.isNotEmpty && room.players.first.id == p.id);
        p.isReady = isHost || p.isAi;
      }
      roomProv.closeActiveSession();

      // 若当前有结算弹窗等对话框覆盖在上层，安全关闭顶层弹窗
      if (ModalRoute.of(context)?.isCurrent == false) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      PartyGameApp.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/room'),
          builder: (_) => GameRoomLobbyView(room: room, isReconnecting: false, isSpectator: widget.isSpectator),
        ),
        (route) => route.isFirst,
      );
    } else {
      PartyGameApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  /// AI 智能托管逻辑（当玩家开启托管且轮到自己时，自动计算并叫点/开盅）
  void _checkAutoPlayDelegation(DiceState state) {
    if (!_isAutoPlay) return;

    if (state.phase == DicePhase.bidding && state.currentPlayer.id == widget.myPlayerId) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || !_isAutoPlay) return;
        final cur = _currentState;
        if (cur == null || cur.phase != DicePhase.bidding || cur.currentPlayer.id != widget.myPlayerId) return;
        final myCup = cur.playerCups[widget.myPlayerId];
        if (myCup == null) return;

        final decision = DiceAi.decideNextAction(
          aiPlayerId: widget.myPlayerId,
          myCup: myCup,
          state: cur,
          personality: 'SMART',
        );

        if (decision.type == AiDecisionType.challenge) {
          _onPlayerChallenge();
        } else {
          _onPlayerBid(decision.count, decision.face, decision.isPure);
        }
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    if (_isAutoPlay && _currentState != null) {
      _checkAutoPlayDelegation(_currentState!);
    } else {
      _autoPlayTimer?.cancel();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAutoPlay ? '🤖 已开启【AI智能托管】：系统将在轮到您时自动分析叫点/开盅' : '👤 已取消托管，恢复手动操作'),
        backgroundColor: _isAutoPlay ? const Color(0xFF0D9488) : const Color(0xFF475569),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 房间最小化：保存会话至 RoomProvider，并退回主界面，全局悬浮窗常驻
  void _minimizeRoom() {
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    roomProv.registerActiveSession(
      ActiveRoomSession(
        roomCode: widget.roomCode ?? '666888',
        gameType: 'liars_dice',
        gameTitle: '大话骰',
        gameIcon: '🎲',
        isMinimized: true,
        screenBuilder: (_) => widget,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗗 房间已最小化至右侧悬浮窗，可在任意页面随时点击恢复！'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF0D9488),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    GameAudioService().stopBgm();
    _channelSub.cancel();
    _stateSub.cancel();
    _socketSub?.cancel();
    _logScrollController.dispose();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearThrowEvent();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);
      final roomProv = context.read<RoomProvider>();
      if (!roomProv.hasMinimizedRoom) {
        final user = context.read<AuthProvider>().user;
        roomProv.leaveRoom(user?.id, widget.roomCode, true);
      }
    } catch (_) {}
    super.dispose();
  }

  void _onPlayerBid(int count, int face, bool isPure) {
    if (widget.isSpectator) return;
    HapticFeedback.lightImpact();
    GameAudioService().playSound('bid_ding');
    final action = GameAction(
      actionId: 'ACT-BID-${DateTime.now().millisecondsSinceEpoch}',
      playerId: widget.myPlayerId,
      actionType: 'BID',
      payload: {
        'count': count,
        'face': face,
        'isPure': isPure,
      },
    );
    widget.channel.dispatchAction(action);

    final user = context.read<AuthProvider>().user;
    final myName = user?.nickname ?? '我';
    final myAvatar = user?.avatar ?? '🦊';

    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'BID',
        'roomCode': widget.roomCode,
        'senderId': widget.myPlayerId,
        'senderName': myName,
        'payload': {
          'count': count,
          'face': face,
          'isPure': isPure,
          'bidderId': widget.myPlayerId,
          'bidderName': myName,
        },
      });

      context.read<ChatProvider>().sendMessage(
        senderId: widget.myPlayerId,
        senderName: myName,
        senderAvatar: myAvatar,
        content: '📢 我叫 $count 个 $face 点！',
        channel: 'ROOM',
        roomCode: widget.roomCode,
        textColor: user?.chatTextColor,
        vipLevel: user?.vipLevel ?? 0,
      );
    }
  }

  void _onPlayerChallenge() {
    if (widget.isSpectator) return;
    HapticFeedback.heavyImpact();
    GameAudioService().playSound('challenge_bang');
    final action = GameAction(
      actionId: 'ACT-CHALLENGE-${DateTime.now().millisecondsSinceEpoch}',
      playerId: widget.myPlayerId,
      actionType: 'CHALLENGE',
      payload: {},
    );
    widget.channel.dispatchAction(action);

    final user = context.read<AuthProvider>().user;
    final myName = user?.nickname ?? '我';
    final myAvatar = user?.avatar ?? '🦊';

    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'CHALLENGE',
        'roomCode': widget.roomCode,
        'senderId': widget.myPlayerId,
        'senderName': myName,
        'payload': {
          'challengerId': widget.myPlayerId,
          'challengerName': myName,
        },
      });

      context.read<ChatProvider>().sendMessage(
        senderId: widget.myPlayerId,
        senderName: myName,
        senderAvatar: myAvatar,
        content: '⚡ 开！！我不信！抓你吹牛！',
        channel: 'ROOM',
        roomCode: widget.roomCode,
        textColor: user?.chatTextColor,
        vipLevel: user?.vipLevel ?? 0,
      );
    }
  }

  void _restartNextRound() {
    HapticFeedback.mediumImpact();
    GameAudioService().playSound('dice_shake');
    _engine.startNewRound(
      players: widget.players,
      starterIndex: (_currentState?.currentTurnIndex ?? 0) + 1,
      initialChips: _currentState?.chipsScore,
    );

    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'ROUND_RESTART',
        'roomCode': widget.roomCode,
        'senderId': widget.myPlayerId,
      });
    }
  }

  void _onPhysicalShakeFinished() {
    HapticFeedback.heavyImpact();
    GameAudioService().playSound('dice_shake');

    // 只有在已开盅揭晓/结算态下，摇晃才代表开启下一轮！
    if (_currentState?.phase == DicePhase.challenged || _currentState?.phase == DicePhase.roundOver) {
      _restartNextRound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎲 摇骰感应成功！开启新一轮比拼！'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // 叫点进行中手摇：纯粹摇骰扣盅物理动效与沉浸音效，绝不退出房间！
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎲 骰盅已扣定！点数已洗好，请观察心理战叫点~'),
          backgroundColor: Color(0xFF0D9488),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _copyRoomCode() {
    if (widget.roomCode == null) return;
    final inviteText = '【海马聚会桌游】大话骰/吹牛开局啦！\n👉 房间号：${widget.roomCode}\n快打开海马 App 加入对局！';
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

  void _showExitDialog() {
    if (_currentState?.phase == DicePhase.roundOver) {
      _returnToRoomLobby(shouldBroadcast: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('离开房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('您可以选择【最小化挂起】对局（可随时点击悬浮窗返回），或【强制退出】彻底离开当前房间。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _minimizeRoom();
            },
            child: const Text('🗗 最小化挂起', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
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
    final state = _currentState;
    if (state == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
      );
    }

    final isMyTurn = state.phase == DicePhase.bidding && state.currentPlayer.id == widget.myPlayerId;
    final isRevealed = state.phase == DicePhase.challenged || state.phase == DicePhase.roundOver;
    final opponents = state.players.where((p) => p.id != widget.myPlayerId).toList();
    final myCup = state.playerCups[widget.myPlayerId];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // 沉浸式高档酒吧/夜店桌游深夜暗色调
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFF1F5F9), size: 18),
            tooltip: '返回或最小化',
            onPressed: _showExitDialog,
          ),
          title: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎲 大话骰 (吹牛)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                  ),
                if (widget.isSpectator) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF312E81),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF818CF8)),
                    ),
                    child: const Text(
                      '👀 旁观中',
                      style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 10, fontWeight: FontWeight.bold),
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
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room, color: Color(0xFFFBBF24), size: 11),
                      const SizedBox(width: 3),
                      Text(
                        '房间号: ${widget.roomCode}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFFDE68A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                '${widget.hostContext.appName} · 欢乐酒桌',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 1,
        actions: [
          // 智能托管按钮 (旁观模式隐藏)
          if (!widget.isSpectator)
            IconButton(
              icon: Icon(
                _isAutoPlay ? Icons.smart_toy : Icons.smart_toy_outlined,
                color: _isAutoPlay ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
              ),
              tooltip: _isAutoPlay ? '取消托管' : '开启智能托管',
              onPressed: _toggleAutoPlay,
            ),
                    // 手动摇骰扣盅按钮 (支持静音/无传感器场景一键扣盅)
          if (!widget.isSpectator)
            IconButton(
              icon: const Icon(Icons.casino_outlined, color: Color(0xFFFBBF24)),
              tooltip: '摇骰扣盅',
              onPressed: _onPhysicalShakeFinished,
            ),
          // 语音喊点开关 (3个3、4个3)
          IconButton(
            icon: Icon(
              _voiceAnnouncer.isEnabled ? Icons.record_voice_over : Icons.voice_over_off,
              color: _voiceAnnouncer.isEnabled ? const Color(0xFF2DD4BF) : const Color(0xFF64748B),
            ),
            tooltip: _voiceAnnouncer.isEnabled ? '语音喊点 (已开启)' : '语音喊点 (已静音)',
            onPressed: () {
              setState(() {
                _voiceAnnouncer.toggleVoice(!_voiceAnnouncer.isEnabled);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_voiceAnnouncer.isEnabled ? '🗣️ 已开启【真人语音喊点播报】！' : '🔇 已静音语音喊点'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          // 房间最小化按钮
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_outlined, color: Color(0xFF94A3B8)),
            tooltip: '最小化房间',
            onPressed: _minimizeRoom,
          ),
          // 规则弹窗
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF94A3B8)),
            onPressed: () => _showRulesDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          DiceShakeDetector(
            isEnabled: _isRealShakeMode,
            onShakeFinished: _onPhysicalShakeFinished,
            child: Column(
          children: [
            // 托管状态高亮横幅
            if (_isAutoPlay)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFF78350F),
                  border: Border(bottom: BorderSide(color: Color(0xFFB45309))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.smart_toy, color: Color(0xFFFDE68A), size: 15),
                    const SizedBox(width: 8),
                    const Text(
                      '智能托管代打中：轮到您时将自动分析博弈出招',
                      style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11, fontWeight: FontWeight.bold),
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
                        child: const Text('取消托管', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

            // 对手席位展示区 (固定高度 104，2~8人优雅自适应，支持横向丝滑滑动与互动投掷道具)
            Container(
              height: 104,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              child: opponents.length <= 4
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: opponents.map((opp) {
                        final cup = state.playerCups[opp.id]!;
                        final chips = state.chipsScore[opp.id] ?? 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: DiceCupWidget(
                            playerName: opp.name,
                            cup: cup,
                            isCurrentTurn: state.currentPlayer.id == opp.id,
                            isSelf: false,
                            isRevealedAll: isRevealed,
                            highlightFace: state.currentBid?.face,
                            isWild1Active: state.isWild1Active && !(state.currentBid?.isPure ?? false),
                            chips: chips,
                            onTap: () {
                              InGameThrowDialog.show(context, targetPlayerId: opp.id, targetPlayerName: opp.name);
                            },
                          ),
                        );
                      }).toList(),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: opponents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final opp = opponents[idx];
                        final cup = state.playerCups[opp.id]!;
                        final chips = state.chipsScore[opp.id] ?? 100;
                        return DiceCupWidget(
                          playerName: opp.name,
                          cup: cup,
                          isCurrentTurn: state.currentPlayer.id == opp.id,
                          isSelf: false,
                          isRevealedAll: isRevealed,
                          highlightFace: state.currentBid?.face,
                          isWild1Active: state.isWild1Active && !(state.currentBid?.isPure ?? false),
                          chips: chips,
                          onTap: () {
                            InGameThrowDialog.show(context, targetPlayerId: opp.id, targetPlayerName: opp.name);
                          },
                        );
                      },
                    ),
            ),

            // 当前最新叫点指示条
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: state.currentBid != null ? const Color(0xFFF59E0B) : const Color(0xFF475569),
                  width: state.currentBid != null ? 1.2 : 0.8,
                ),
                boxShadow: [
                  if (state.currentBid != null)
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      blurRadius: 6,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    state.currentBid != null ? Icons.campaign : Icons.hourglass_top,
                    color: state.currentBid != null ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.currentBid != null
                          ? '当前叫点：【${state.currentBid!.bidderName}】叫出 ${state.currentBid!.count} 个 ${state.currentBid!.face} 点 ${state.currentBid!.isPure ? "【斋】" : "【飞】"}'
                          : '🎲 新对局开始，等待首家起叫...',
                      style: TextStyle(
                        color: state.currentBid != null ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMyTurn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('轮到你', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // 中间：实时出价战报与真人喊点流
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: ListView.builder(
                  controller: _logScrollController,
                  itemCount: state.eventLogs.length,
                  itemBuilder: (ctx, idx) {
                    final log = state.eventLogs[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: log.contains('💥')
                              ? const Color(0xFFF87171)
                              : log.contains('🗣️')
                                  ? const Color(0xFF2DD4BF)
                                  : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: log.contains('💥') || log.contains('🗣️') ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 揭晓裁决结果提示横幅 (若已开盅)
            if (isRevealed && state.lastResult != null)
              _buildResultBanner(state.lastResult!),

            // 自己专属的骰盅 (支持一键掀开/扣上防窥、手牌速查分析)
            if (widget.isSpectator)
              _buildSpectatorPlaceholder()
            else if (myCup != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: DiceCupWidget(
                  playerName: '我的骰盅',
                  cup: myCup,
                  isCurrentTurn: isMyTurn,
                  isSelf: true,
                  isRevealedAll: isRevealed,
                  highlightFace: state.currentBid?.face,
                  isWild1Active: state.isWild1Active && !(state.currentBid?.isPure ?? false),
                  chips: state.chipsScore[widget.myPlayerId] ?? 100,
                ),
              ),

            // 底部叫点控制面板 (旁观者显示静观指示条或申请入席按钮)
            if (!isRevealed)
              widget.isSpectator
                  ? Container(
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('👀 旁观中，静观酒桌叫点风云...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                    )
                  : BidDialWidget(
                      currentBid: state.currentBid,
                      totalPlayers: state.players.length,
                      isWild1Active: state.isWild1Active,
                      isMyTurn: isMyTurn,
                      onBid: _onPlayerBid,
                      onChallenge: _onPlayerChallenge,
                    )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: widget.isSpectator
                    ? ElevatedButton.icon(
                        onPressed: () {
                          final user = context.read<AuthProvider>().user;
                          SocketService().send({
                            'type': 'GAME_ACTION',
                            'action': 'SPECTATOR_JOIN_SEAT',
                            'roomCode': widget.roomCode,
                            'userId': user?.id ?? widget.myPlayerId,
                            'userName': user?.nickname ?? '玩家',
                            'userAvatar': user?.avatar ?? '🦊',
                          });
                          _returnToRoomLobby();
                        },
                        icon: const Icon(Icons.airline_seat_recline_normal),
                        label: const Text('🪑 申请加入席位准备', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _restartNextRound,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('准备好了，摇骰开下一局！', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ),
          ],
        ),
      ),
      Consumer<ChatProvider>(
        builder: (context, chatProv, child) {
          final throwEvent = chatProv.lastThrowEvent;
          if (throwEvent == null) return const SizedBox.shrink();
          return Positioned.fill(
            child: InteractiveThrowOverlay(
              event: throwEvent,
              onComplete: () {
                chatProv.clearThrowEvent();
              },
            ),
          );
        },
      ),
      if (widget.roomCode != null && widget.roomCode!.isNotEmpty)
        InGameChatOverlay(
          roomCode: widget.roomCode!,
          myPlayerId: widget.myPlayerId,
          myPlayerName: context.read<AuthProvider>().user?.nickname ?? '我',
          myPlayerAvatar: context.read<AuthProvider>().user?.avatar ?? '🦊',
        ),
    ],
  ),
),
);
}

  Widget _buildResultBanner(DiceChallengeResult res) {
    final isSuccess = res.isChallengerWon;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFF064E3B).withOpacity(0.9) : const Color(0xFF7F1D1D).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuccess ? Icons.verified : Icons.error,
                color: isSuccess ? const Color(0xFF34D399) : const Color(0xFFF87171),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '全场实际共 ${res.actualMatchCount} 个 ${res.challengedBid.face}！',
                style: TextStyle(
                  color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '【${res.challengerName}】抓【${res.challengedBid.bidderName}】叫的 ${res.challengedBid.count} 个：'
            '${isSuccess ? "抓吹牛成功！" : "抓错了！"} '
            '【${res.loserName}】受罚！',
            style: TextStyle(
              color: isSuccess ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            '各家点数: ${res.details}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: (res.loserId != widget.myPlayerId ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (res.loserId != widget.myPlayerId ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(120),
              ),
            ),
            child: Text(
              res.loserId != widget.myPlayerId ? '🎖️ 排位天梯积分 +25 · 🪙 金币 +100' : '⚔️ 排位天梯积分 -15 · 🪙 救济金 +20',
              style: TextStyle(
                color: res.loserId != widget.myPlayerId ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎲 大话骰 / 骰子街 规则', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. 【起手】：每人 5 粒骰子，扣好骰盅。按住自己的骰盅可以偷瞄点数。\n'
                '2. 【叫点】：顺时针叫点（如“4个5”）。后续玩家必须“加数量”（如“5个5”）或“加点数”（如“4个6”）。\n'
                '3. 【通配与斋】：1 点默认为“飞/通配符”，可当做任意点数！一旦有人叫了 1 点或主动喊“斋”，1 点立刻失去通配功能，只能当 1 点。\n'
                '4. 【开/劈】：如果你认为上一家在吹牛，实际没有那么多颗骰子，直接按“开/劈”！全场亮盅核对：\n'
                '   - 实际数量 >= 叫点数：叫点者赢，开盅者受罚输 10 筹码。\n'
                '   - 实际数量 < 叫点数：开盅者赢，叫点者吹牛被抓输 10 筹码。\n'
                '5. 【智能托管】：点击顶部机器人按钮可随时交由 AI 帮您代打出牌与开盅。',
                style: TextStyle(color: Color(0xFF475569), height: 1.5, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectatorPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility, color: Color(0xFF818CF8), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('👀 当前处于旁观者模式', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('为保护公平竞技，旁观者不可查看选手私密骰盅，对局结束可点击入席！', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
