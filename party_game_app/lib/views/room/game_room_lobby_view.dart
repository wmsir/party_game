import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../games/hosts/standalone_offline_host/offline_host_context.dart';
import '../../games/hosts/standalone_offline_host/offline_reward_bridge.dart';
import '../../games/liars_dice/presentation/liars_dice_game_screen.dart';
import '../../games/take6/presentation/take6_game_screen.dart';
import '../../games/party_wheel/presentation/party_wheel_screen.dart';
import '../../games/undercover/presentation/undercover_game_screen.dart';
import '../../models/chat_message_model.dart';
import '../../models/game_player.dart';
import '../../models/game_room_model.dart';
import 'dart:async';
import 'dart:math';
import '../../games/take6/domain/take6_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/room_provider.dart';
import 'package:flutter/services.dart';
import '../../services/chat_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../chat/widgets/interactive_throw_overlay.dart';
import '../widgets/entrance_banner_overlay.dart';
import '../widgets/in_game_throw_dialog.dart';
import '../widgets/tencent_invite_dialog.dart';
import '../widgets/avatar_with_frame.dart';
import '../widgets/vip_badge_widget.dart';
import '../../main.dart';
import '../main_frame_view.dart';

class GameRoomLobbyView extends StatefulWidget {
  final GameRoomModel room;
  final bool isReconnecting;
  final bool isSpectator;

  const GameRoomLobbyView({
    super.key,
    required this.room,
    this.isReconnecting = false,
    this.isSpectator = false,
  });

  @override
  State<GameRoomLobbyView> createState() => _GameRoomLobbyViewState();
}

class _GameRoomLobbyViewState extends State<GameRoomLobbyView> {
  final _msgCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  final Map<String, String> _playerSpeechBubbles = {};
  StreamSubscription? _chatSub;
  Timer? _summonCountdownTimer;
  int _summonRemainingSeconds = 0;
  StreamSubscription? _socketSub;
  Timer? _roomSyncTimer;
  bool _hasStarted = false;
  DateTime _lobbyEnterTime = DateTime.now();
  late bool _isSpectator;
  late bool _allowSpectator;

  @override
  void initState() {
    super.initState();
    _lobbyEnterTime = DateTime.now();
    _isSpectator = widget.isSpectator || widget.room.isSpectator;
    _allowSpectator = widget.room.allowSpectator;

    final user = context.read<AuthProvider>().user;
    final myId = user?.id ?? '';
    final isHost = widget.room.hostPlayerId == myId || (widget.room.players.isNotEmpty && widget.room.players.first.id == myId);
    widget.room.status = 'WAITING';
    for (final p in widget.room.players) {
      final isH = p.id == widget.room.hostPlayerId || (widget.room.players.isNotEmpty && widget.room.players.first.id == p.id);
      p.isReady = isH || p.isAi;
    }
    if (isHost) {
      ApiService().resetRoom(widget.room.roomCode);
    }

    final chatProv = context.read<ChatProvider>();
    chatProv.switchChannel('ROOM');
    chatProv.setCurrentRoomCode(widget.room.roomCode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RoomProvider>().setCurrentRoom(widget.room);
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

        // 1. 发送 WebSocket 进房指令，长连接绑定对应房间
        SocketService().send({
          'type': 'JOIN_ROOM',
          'roomCode': widget.room.roomCode,
          'userId': user.id,
          'nickname': user.nickname,
          'avatar': user.avatar,
        });
      }
      // 立即拉取一次远端最新房间详情
      _pollRoomDetail();
    });

    // 2. 监听房间 WebSocket 广播变动 (玩家进退房与准备状态实时刷新)
    _socketSub = SocketService().messageStream.listen((data) {
      if (!mounted) return;
      final type = data['type'];
      if (type == 'ROOM_PLAYERS_UPDATED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          final rawPlayers = data['players'] as List?;
          if (rawPlayers != null) {
            _syncPlayersFromList(rawPlayers);
          }
        }
      } else if (type == 'SUMMON_STARTED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          final cd = (data['countdown'] as num?)?.toInt() ?? 10;
          _startSummonTimer(cd);
        }
      } else if (type == 'ROOM_SETTINGS_UPDATED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          if (data['allowSpectator'] is bool) {
            setState(() {
              _allowSpectator = data['allowSpectator'] as bool;
              widget.room.allowSpectator = _allowSpectator;
            });
          }
        }
      } else if (type == 'ROOM_SPECTATORS_UPDATED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          final rawSpecs = data['spectators'] as List?;
          if (rawSpecs != null) {
            setState(() {
              widget.room.spectators.clear();
              for (final s in rawSpecs) {
                if (s is Map) {
                  widget.room.spectators.add(GamePlayer.fromJson(Map<String, dynamic>.from(s)));
                }
              }
            });
          }
        }
      } else if (type == 'ROOM_RECONNECT_SYNC') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          if (data['isSpectator'] == true) {
            setState(() {
              _isSpectator = true;
              widget.room.isSpectator = true;
            });
          }
          if (data['allowSpectator'] is bool) {
            setState(() {
              _allowSpectator = data['allowSpectator'] as bool;
              widget.room.allowSpectator = _allowSpectator;
            });
          }
          // 仅在明确接管重连模式或旁观者进入模式下，若房间正在对局，自动同步进入游戏画面
          if ((widget.isReconnecting || _isSpectator) && !_hasStarted && data['status'] == 'PLAYING') {
            _startGame(isAutoTriggered: true, startPayload: data);
          }
        }
      } else if (type == 'GAME_ACTION' && data['action'] == 'GAME_STARTED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          final myId = context.read<AuthProvider>().user?.id ?? '';
          final isHost = widget.room.hostPlayerId == myId || (widget.room.players.isNotEmpty && widget.room.players.first.id == myId);
          if (!isHost && !_hasStarted) {
            final payload = data['payload'] as Map?;
            // 房主已开局，非房主（包含旁观者）自动跳转同步进入游戏画面
            _startGame(isAutoTriggered: true, startPayload: payload);
          }
        }
      } else if (type == 'KICKED_FROM_ROOM' || type == 'PLAYER_KICKED') {
        final code = data['roomCode']?.toString();
        if (code == null || code == widget.room.roomCode) {
          final targetId = data['targetPlayerId']?.toString();
          final myId = context.read<AuthProvider>().user?.id ?? '';
          final cleanMy = myId.replaceAll('-', '').toLowerCase();
          final cleanTarget = (targetId ?? '').replaceAll('-', '').toLowerCase();
          if (cleanMy.isNotEmpty && cleanMy == cleanTarget) {
            _roomSyncTimer?.cancel();
            _roomSyncTimer = null;
            _socketSub?.cancel();
            _socketSub = null;
            _chatSub?.cancel();
            _chatSub = null;
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
          } else if (type == 'PLAYER_KICKED') {
            final rawPlayers = data['players'] as List?;
            if (rawPlayers != null) _syncPlayersFromList(rawPlayers);
            final name = data['targetPlayerName'] ?? '玩家';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('玩家【$name】已被房主移出房间')));
          }
        }
      }
    });

    // 3. 2秒一次定时轮询，提供绝对一致性兜底保障
    _roomSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted) return;
      _pollRoomDetail();
    });

    // 4. 监听聊天与头顶气泡
    _chatSub = context.read<ChatProvider>().messageStream.listen((msg) {
      if (!mounted) return;
      String targetKey = msg.senderId;
      for (final p in widget.room.players) {
        if (p.id == msg.senderId || p.name == msg.senderName) {
          targetKey = p.id;
          break;
        }
      }
      setState(() {
        _playerSpeechBubbles[targetKey] = msg.content;
      });
      _scrollToBottom();
      Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        setState(() {
          if (_playerSpeechBubbles[targetKey] == msg.content) {
            _playerSpeechBubbles.remove(targetKey);
          }
        });
      });
    });
  }

  void _syncPlayersFromList(List rawList) {
    final newPlayers = <GamePlayer>[];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        final pid = m['id']?.toString() ?? 'P-$i';
        final isHostOfRoom = (m['isHost'] == true) || (pid == widget.room.hostPlayerId) || (i == 0);
        newPlayers.add(GamePlayer(
          id: pid,
          name: m['name']?.toString() ?? '玩家',
          avatar: m['avatar']?.toString() ?? '🦊',
          isAi: m['isAi'] == true,
          score: (m['score'] is num) ? (m['score'] as num).toInt() : 0,
          isReady: isHostOfRoom ? true : (m['isReady'] == true),
          isEliminated: m['isEliminated'] == true,
        ));
      }
    }
    // 保护性合并：保留当前已加入的 AI 机器人（避免轮询时差导致机器人闪烁消失）
    for (final localP in widget.room.players) {
      if (localP.isAi && !newPlayers.any((p) => p.id == localP.id)) {
        newPlayers.add(localP);
      }
    }
    if (newPlayers.isNotEmpty) {
      final myId = context.read<AuthProvider>().user?.id ?? '';
      if (_isSpectator && newPlayers.any((p) => p.id == myId)) {
        _isSpectator = false;
        widget.room.isSpectator = false;
      }
      setState(() {
        widget.room.players.clear();
        widget.room.players.addAll(newPlayers);
      });
    }
  }

  Future<void> _pollRoomDetail() async {
    if (_hasStarted || !mounted) return;
    try {
      final detail = await ApiService().fetchRoomDetail(widget.room.roomCode);
      if (_hasStarted || !mounted) return;
      if (detail != null && mounted) {
        if (detail.allowSpectator != _allowSpectator) {
          setState(() {
            _allowSpectator = detail.allowSpectator;
            widget.room.allowSpectator = detail.allowSpectator;
          });
        }
        if (detail.spectators.isNotEmpty) {
          setState(() {
            widget.room.spectators.clear();
            widget.room.spectators.addAll(detail.spectators);
          });
        }
        final myId = context.read<AuthProvider>().user?.id ?? '';
        if (_isSpectator && detail.players.any((p) => p.id == myId)) {
          setState(() {
            _isSpectator = false;
            widget.room.isSpectator = false;
          });
        }
        if (detail.players.isNotEmpty) {
          final mergedPlayers = List<GamePlayer>.from(detail.players);
          for (final localP in widget.room.players) {
            if (localP.isAi && !mergedPlayers.any((p) => p.id == localP.id)) {
              mergedPlayers.add(localP);
            }
          }
          setState(() {
            widget.room.players.clear();
            widget.room.players.addAll(mergedPlayers);
          });
        }
        if ((widget.isReconnecting || _isSpectator) && detail.status == 'PLAYING') {
          final isHost = widget.room.hostPlayerId == myId || (widget.room.players.isNotEmpty && widget.room.players.first.id == myId);
          final inGracePeriod = DateTime.now().difference(_lobbyEnterTime).inSeconds < 4;
          // 重连模式下房主与玩家均立即进入对局；旁观者模式在保护期后自动进入
          if (!_hasStarted && (widget.isReconnecting || (!isHost && !inGracePeriod))) {
            _startGame(isAutoTriggered: true);
          }
        }
      }
    } catch (_) {}
  }

  void _summonPlayers() {
    if (widget.room.players.length >= widget.room.maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('房间席位已满，无需召集！')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final me = auth.user;
    final myId = me?.id ?? 'me';
    final myName = me?.nickname ?? '房主';

    // 1. 发送 WebSocket 召集消息 (通知服务端向全服世界与同城频道广播)
    SocketService().send({
      'type': 'SUMMON_PLAYERS',
      'roomCode': widget.room.roomCode,
      'senderId': myId,
      'senderName': myName,
      'gameType': widget.room.gameType,
    });

    // 2. 开启 10 秒倒计时
    _startSummonTimer(10);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📢 已向全服与同城频道发布召集广播！若10秒内无玩家进入，将自动安排实力桌友陪玩～'),
        backgroundColor: Color(0xFFD97706),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startSummonTimer(int seconds) {
    _summonCountdownTimer?.cancel();
    setState(() => _summonRemainingSeconds = seconds);
    final currentCount = widget.room.players.length;

    _summonCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_summonRemainingSeconds <= 1) {
        timer.cancel();
        setState(() => _summonRemainingSeconds = 0);
        // 若10秒后人数未增加且未满员，补入拟真玩家
        if (widget.room.players.length <= currentCount && widget.room.players.length < widget.room.maxCapacity) {
          _addRealisticPlayer();
        }
      } else {
        setState(() => _summonRemainingSeconds--);
      }
    });
  }

  void _addRealisticPlayer() {
    if (widget.room.players.length >= widget.room.maxCapacity) return;
    setState(() => widget.room.addAiPlayer());
    GameSoundService().playCardPlay();
    final newP = widget.room.players.last;

    // WebSocket 同步拟真玩家进房 (无感知，以真实玩家形式展示)
    SocketService().send({
      'type': 'ADD_AI_PLAYER',
      'roomCode': widget.room.roomCode,
      'player': {
        'id': newP.id,
        'name': newP.name,
        'avatar': newP.avatar,
        'isAi': false,
        'isReady': true,
      },
    });

    // HTTP 备用持久化
    ApiService().addAiPlayer(
      roomCode: widget.room.roomCode,
      player: {
        'id': newP.id,
        'name': newP.name,
        'avatar': newP.avatar,
        'isAi': false,
        'isReady': true,
      },
    );

    // 800ms 后以人类拟真口吻在房间聊天中发一条问候语
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final greetings = [
        '来了来了！刚看到全服召集，求带飞~',
        '哈喽大家好！抓紧开开开！',
        '来啦来啦，这把看我表演！',
        '打工人上线摸鱼一把，大佬们轻虐！',
        '刚好有空，拉我一个！',
        '到！准备就绪，随时开战！',
      ];
      final greeting = greetings[Random().nextInt(greetings.length)];
      final chatProv = Provider.of<ChatProvider>(context, listen: false);
      chatProv.sendMessage(
        senderId: newP.id,
        senderName: newP.name,
        senderAvatar: newP.avatar,
        content: greeting,
      );
    });

    EntranceBannerOverlay.show(
      context,
      playerName: newP.name,
      avatar: newP.avatar,
      avatarFrame: 'FRAME_DEFAULT',
      vipLevel: 1,
      bannerId: 'BANNER_SHINE',
      punchline: '【${newP.name}】响应召集进入房间，准备就绪！',
    );
  }

  void _showEmptySeatOptions(int seatIdx, String gameTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '${seatIdx + 1}号麦位 · 邀请与添加',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign, color: Color(0xFFF59E0B)),
                  ),
                  title: const Text('📢 召集桌友开黑', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('全服/同城广播，10秒无响应自动补入实力桌友', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _summonPlayers();
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07C160).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share, color: Color(0xFF07C160)),
                  ),
                  title: const Text('微信 / QQ 邀请真实好友', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('复制链接或卡片发给微信/QQ群好友', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    TencentInviteDialog.show(context, room: widget.room, gameTitle: gameTitle);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _summonCountdownTimer?.cancel();
    _roomSyncTimer?.cancel();
    _socketSub?.cancel();
    _chatSub?.cancel();
    _msgCtrl.dispose();
    _chatScrollCtrl.dispose();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearThrowEvent();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);

      final user = context.read<AuthProvider>().user;
      final myId = user?.id ?? widget.room.hostPlayerId;
      final roomProv = context.read<RoomProvider>();
      final isStillInRoom = roomProv.hasMinimizedRoom || 
          (roomProv.activeSession != null && roomProv.activeSession!.roomCode == widget.room.roomCode);
      
      // 若未挂起最小化房间且当前不在对局中，代表彻底退出该房间界面
      if (!isStillInRoom) {
        SocketService().send({
          'type': 'LEAVE_ROOM',
          'roomCode': widget.room.roomCode,
          'userId': myId,
        });
        widget.room.players.removeWhere((p) => p.id == myId);
        if (widget.room.humanCount == 0 || widget.room.hostPlayerId == myId) {
          roomProv.leaveRoom(myId, widget.room.roomCode);
        }
      }
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _sendRoomMessage() {
    final text = _msgCtrl.text.trim();
    final user = context.read<AuthProvider>().user;
    if (text.isEmpty || user == null) return;
    GameSoundService().playHapticLight();
    context.read<ChatProvider>().sendMessage(
      senderId: user.id,
      senderName: user.nickname,
      senderAvatar: user.avatar,
      content: text,
      channel: 'ROOM',
      roomCode: widget.room.roomCode,
      textColor: user.chatTextColor,
      vipLevel: user.vipLevel,
    );
    setState(() {
      _playerSpeechBubbles[user.id] = text;
    });
    Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      setState(() {
        if (_playerSpeechBubbles[user.id] == text) {
          _playerSpeechBubbles.remove(user.id);
        }
      });
    });
    _msgCtrl.clear();
    _scrollToBottom();
  }

  void _onExitRoom() {
    final user = context.read<AuthProvider>().user;
    final roomProv = context.read<RoomProvider>();
    final chatProv = context.read<ChatProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCardSurface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.meeting_room_outlined, color: Colors.amber),
            const SizedBox(width: 8),
            Text('离开房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.adaptiveTextPrimary(ctx))),
          ],
        ),
        content: Text('您可以选择【最小化挂起】房间（保留席位并显示悬浮窗），或者【强制退出】彻底释放房间。', style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              chatProv.clearThrowEvent();
              // 最小化挂起房间
              roomProv.registerActiveSession(
                ActiveRoomSession(
                  roomCode: widget.room.roomCode,
                  gameType: widget.room.gameType,
                  gameTitle: widget.room.roomName,
                  gameIcon: '🏠',
                  isMinimized: true,
                  screenBuilder: (_) => GameRoomLobbyView(room: widget.room),
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('🗗 最小化挂起', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              chatProv.clearThrowEvent();
              chatProv.clearRoomMessages();
              chatProv.switchChannel('WORLD');
              chatProv.setCurrentRoomCode(null);
              final myId = user?.id ?? widget.room.hostPlayerId;
              widget.room.players.removeWhere((p) => p.id == myId);
              roomProv.leaveRoom(myId, widget.room.roomCode);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('🚪 强制退出'),
          ),
        ],
      ),
    );
  }

  void _showThrowMenu(GamePlayer target) {
    final me = context.read<AuthProvider>().user;
    if (me == null || target.id == me.id) return;

    InGameThrowDialog.show(
      context,
      targetPlayerId: target.id,
      targetPlayerName: target.name,
    );
  }

  void _startGame({bool isAutoTriggered = false, Map? startPayload}) {
    if (_hasStarted) return;

    List<List<int>>? initialRows;
    Map<String, List<int>>? initialHands;
    Map<String, int>? initialScores;
    int? initialTurn;

    if (!isAutoTriggered) {
      final nonHosts = widget.room.players.where((p) => p.id != widget.room.hostPlayerId).toList();
      if (!widget.room.canStartGame && widget.room.gameType != 'party_wheel') {
        if (widget.room.players.length < widget.room.minPlayers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('至少需要 ${widget.room.minPlayers} 位玩家才可开局！请添加 AI 或等待好友加入')),
          );
        } else if (!widget.room.allNonHostsReady) {
          final readyCount = nonHosts.where((p) => p.isReady).length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('还有玩家未准备 ($readyCount/${nonHosts.length})，请等待所有玩家准备就绪！')),
          );
        }
        return;
      }
    }

    _hasStarted = true;
    _roomSyncTimer?.cancel();
    _roomSyncTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _chatSub?.cancel();
    _chatSub = null;

    if (!isAutoTriggered) {
      // 如果是牛头王，房主端生成绝对统一的洗牌与发牌结果
      if (widget.room.gameType == 'take6') {
        final deck = Take6Card.generateDeck()..shuffle(Random());
        initialRows = [
          [deck.removeLast().number],
          [deck.removeLast().number],
          [deck.removeLast().number],
          [deck.removeLast().number],
        ];
        initialHands = {};
        for (final p in widget.room.players) {
          final hand = deck.sublist(0, 10)..sort();
          deck.removeRange(0, 10);
          initialHands[p.id] = hand.map((c) => c.number).toList();
        }
      }

      // 广播游戏正式开局指令，带上发牌数据，保证多端 100% 绝对一致
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'GAME_STARTED',
        'roomCode': widget.room.roomCode,
        'payload': {
          'gameType': widget.room.gameType,
          if (initialRows != null) 'initialRows': initialRows,
          if (initialRows != null) 'rows': initialRows,
          if (initialHands != null) 'playerHands': initialHands,
        },
      });
    } else if (startPayload != null) {
      if (startPayload['initialRows'] is List || startPayload['rows'] is List || startPayload['take6Rows'] is List) {
        final rawRows = (startPayload['initialRows'] ?? startPayload['rows'] ?? startPayload['take6Rows']) as List;
        initialRows = [];
        for (final r in rawRows) {
          if (r is List) {
            initialRows.add(r.map((x) => int.tryParse(x.toString()) ?? 0).toList());
          }
        }
      }
      if (startPayload['playerHands'] is Map || startPayload['take6PlayerHands'] is Map) {
        final rawHands = (startPayload['playerHands'] ?? startPayload['take6PlayerHands']) as Map;
        initialHands = {};
        rawHands.forEach((k, v) {
          if (v is List) {
            initialHands![k.toString()] = v.map((x) => int.tryParse(x.toString()) ?? 0).toList();
          }
        });
      }
      if (startPayload['scores'] is Map || startPayload['penaltyScores'] is Map || startPayload['take6Scores'] is Map) {
        final rawScores = (startPayload['scores'] ?? startPayload['penaltyScores'] ?? startPayload['take6Scores']) as Map;
        initialScores = {};
        rawScores.forEach((k, v) {
          initialScores![k.toString()] = int.tryParse(v.toString()) ?? 0;
        });
      }
      final rawTurn = startPayload['currentTurn'] ?? startPayload['take6CurrentTurn'];
      if (rawTurn != null) {
        initialTurn = int.tryParse(rawTurn.toString());
      }
    }

    GameSoundService().playVictory();
    final user = context.read<AuthProvider>().user;
    final myId = user?.id ?? 'ME';

    final roomProv = context.read<RoomProvider>();

    switch (widget.room.gameType) {
      case 'liars_dice':
        Widget screenBuilder(BuildContext _) => LiarsDiceGameScreen.createOffline(
          players: widget.room.players,
          myPlayerId: myId,
          rewardBridge: OfflineRewardBridge(localPlayerId: myId),
          hostContext: OfflineHostContext(customAppName: widget.room.roomName),
          roomCode: widget.room.roomCode,
          isSpectator: _isSpectator,
        );
        roomProv.registerActiveSession(
          ActiveRoomSession(
            roomCode: widget.room.roomCode,
            gameType: 'liars_dice',
            gameTitle: '大话骰',
            gameIcon: '🎲',
            isMinimized: false,
            screenBuilder: screenBuilder,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: screenBuilder));
        break;
      case 'take6':
        Widget screenBuilder(BuildContext _) => Take6GameScreen.createOffline(
          players: widget.room.players,
          localPlayerId: myId,
          rewardBridge: OfflineRewardBridge(localPlayerId: myId),
          hostContext: OfflineHostContext(customAppName: widget.room.roomName),
          roomCode: widget.room.roomCode,
          initialRowNumbers: initialRows,
          initialHandNumbers: initialHands,
          initialScores: initialScores,
          initialTurn: initialTurn,
          isSpectator: _isSpectator,
        );
        roomProv.registerActiveSession(
          ActiveRoomSession(
            roomCode: widget.room.roomCode,
            gameType: 'take6',
            gameTitle: '谁是牛头王',
            gameIcon: '🐂',
            isMinimized: false,
            screenBuilder: screenBuilder,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: screenBuilder));
        break;
      case 'party_wheel':
        Widget screenBuilder(BuildContext _) => const PartyWheelScreen();
        roomProv.registerActiveSession(
          ActiveRoomSession(
            roomCode: widget.room.roomCode,
            gameType: 'party_wheel',
            gameTitle: '聚会大转盘',
            gameIcon: '🎡',
            isMinimized: false,
            screenBuilder: screenBuilder,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: screenBuilder));
        break;
      case 'undercover':
        Widget screenBuilder(BuildContext _) => UndercoverGameScreen(
          playerConfigs: widget.room.players.map((p) => {
            'id': p.id,
            'name': p.name,
            'avatar': p.avatar,
            'isAi': p.isAi,
          }).toList(),
          roomCode: widget.room.roomCode,
          myPlayerId: myId,
        );
        roomProv.registerActiveSession(
          ActiveRoomSession(
            roomCode: widget.room.roomCode,
            gameType: 'undercover',
            gameTitle: '谁是卧底',
            gameIcon: '🕵️',
            isMinimized: false,
            screenBuilder: screenBuilder,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: screenBuilder));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final user = context.watch<AuthProvider>().user;
    final isHost = widget.room.hostPlayerId == user?.id;

    final gameTitle = {
      'liars_dice': '大话骰 (吹牛)',
      'take6': '谁是牛头王',
      'party_wheel': '聚会转盘大冒险',
      'undercover': '谁是卧底',
    }[widget.room.gameType] ?? '聚会桌游';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onExitRoom();
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回大厅',
                onPressed: _onExitRoom,
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '${widget.room.roomName} ($gameTitle)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isSpectator) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF818CF8)),
                      ),
                      child: const Text('👀 观战中', style: TextStyle(fontSize: 10, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              actions: [
                if (isHost)
                  IconButton(
                    icon: Icon(_allowSpectator ? Icons.visibility : Icons.visibility_off, color: _allowSpectator ? Colors.greenAccent : Colors.grey),
                    tooltip: _allowSpectator ? '当前允许观战 (点击切换)' : '当前禁止观战 (点击切换)',
                    onPressed: () {
                      final newAllow = !_allowSpectator;
                      setState(() {
                        _allowSpectator = newAllow;
                        widget.room.allowSpectator = newAllow;
                      });
                      SocketService().send({
                        'type': 'GAME_ACTION',
                        'action': 'TOGGLE_SPECTATOR_ALLOW',
                        'roomCode': widget.room.roomCode,
                        'allowSpectator': newAllow,
                      });
                      ApiService().updateRoomSettings(roomCode: widget.room.roomCode, allowSpectator: newAllow);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(newAllow ? '👁️ 已开启允许旁观模式' : '🚫 已关闭旁观模式，禁止新观众进入'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: '微信/QQ 组局开黑',
                  onPressed: () {
                    TencentInviteDialog.show(context, room: widget.room, gameTitle: gameTitle);
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // 顶部房间编号与状态条
                  Container(
                    color: AppColors.adaptiveBgCard(context),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_outlined, size: 18, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text('房间号：${widget.room.roomCode}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1, color: AppColors.adaptiveTextPrimary(context))),
                          ],
                        ),
                        Row(
                          children: [
                            if (widget.room.isPassAndPlay)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(color: Colors.purple.withAlpha(50), borderRadius: BorderRadius.circular(6)),
                                child: const Text('同屏轮流玩', style: TextStyle(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                              ),
                            Text(
                              '当前 ${widget.room.players.length}/${widget.room.maxCapacity} 人',
                              style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.adaptiveBorder(context)),

                  // 腾讯经典麦位舞台网格 (带麦位编号、房主金冠、头顶气泡与空位一键召唤)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '房间麦位席位 (${widget.room.players.length}/${widget.room.maxCapacity})',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.adaptiveTextSecondary(context)),
                              ),
                              Text('点击头像互动', style: TextStyle(fontSize: 11, color: AppColors.adaptiveTextMuted(context))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // 腾讯微信/QQ 快捷组局开黑按钮
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF07C160),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.people_alt, size: 14),
                                  label: const Text('微信/QQ邀请', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => TencentInviteDialog.show(context, room: widget.room, gameTitle: gameTitle),
                                ),
                              ),
                              if (isHost && widget.room.players.length < widget.room.maxCapacity) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.campaign, size: 16),
                                    label: Text(
                                      _summonRemainingSeconds > 0 ? '📢 召集中 (${_summonRemainingSeconds}s)' : '📢 召集玩家',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _summonPlayers,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_summonRemainingSeconds > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('📢 ', style: TextStyle(fontSize: 14)),
                                  Text(
                                    '已向全服与同城发布召集广播！桌友呼叫中 (${_summonRemainingSeconds}s)...',
                                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),

                          Expanded(
                            child: GridView.builder(
                              clipBehavior: Clip.none,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.81,
                              ),
                              itemCount: (widget.room.maxCapacity > 0 ? widget.room.maxCapacity : 6).clamp(6, 6),
                              itemBuilder: (ctx, idx) {
                                final isOccupied = idx < widget.room.players.length;

                                if (isOccupied) {
                                  final p = widget.room.players[idx];
                                  final isMe = p.id == user?.id;
                                  final isHostOfRoom = p.id == widget.room.hostPlayerId;
                                  final bubbleText = _playerSpeechBubbles[p.id];

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      InkWell(
                                        onTap: () => _showThrowMenu(p),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: isMe ? AppColors.primary.withAlpha(35) : AppColors.adaptiveBgCard(context),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isHostOfRoom ? Colors.amber.withAlpha(180) : (isMe ? AppColors.primary : AppColors.adaptiveBorder(context)),
                                              width: (isHostOfRoom || isMe) ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // 麦位与房主标签
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                                    child: Text('${idx + 1}号麦', style: const TextStyle(fontSize: 8.5, color: Colors.white)),
                                                  ),
                                                  if (isHostOfRoom)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6F00)]),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('👑 房主', style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              AvatarWithFrame(
                                                avatar: p.avatar,
                                                avatarFrame: isHostOfRoom ? 'FRAME_GOLD' : 'FRAME_DEFAULT',
                                                vipLevel: isHostOfRoom ? 1 : 0,
                                                radius: 20,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                p.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isMe)
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 3),
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(3)),
                                                      child: const Text('我', style: TextStyle(color: AppColors.primaryLight, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                    ),
                                                  if (isHostOfRoom)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                                      child: const Text('👑 房主', style: TextStyle(color: Colors.amber, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                    )
                                                  else if (p.isReady)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                                      child: const Text('🟢 已准备', style: TextStyle(color: Color(0xFF10B981), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                                      child: const Text('🟡 未准备', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                    ),
                                                ],
                                              ),
                                              if (isHost && !isMe)
                                                InkWell(
                                                  onTap: () async {
                                                    final myId = context.read<AuthProvider>().user?.id ?? '';
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text('移出玩家'),
                                                        content: Text('确定要将玩家【${p.name}】请离该房间吗？'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx, false),
                                                            child: const Text('取消'),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: const Text('移出', style: TextStyle(color: Colors.white)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true && mounted) {
                                                      try {
                                                        await ApiService().kickPlayer(
                                                          roomCode: widget.room.roomCode,
                                                          operatorId: myId,
                                                          targetPlayerId: p.id,
                                                        );
                                                      } catch (_) {
                                                        SocketService().send({
                                                          'type': 'KICK_PLAYER',
                                                          'roomCode': widget.room.roomCode,
                                                          'operatorId': myId,
                                                          'targetPlayerId': p.id,
                                                        });
                                                      }
                                                      if (mounted) {
                                                        setState(() => widget.room.removePlayer(p.id));
                                                        messenger.showSnackBar(
                                                          SnackBar(content: Text('已将【${p.name}】移出房间')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.only(top: 1),
                                                    child: Text('请离', style: TextStyle(color: Colors.redAccent, fontSize: 9)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // 苹果质感高对比防遮挡发言气泡 (完美避开 AvatarWithFrame 边框，无文字截断)
                                      if (bubbleText != null && bubbleText.isNotEmpty)
                                        Positioned(
                                          top: -38,
                                          left: -28,
                                          right: -28,
                                          child: IgnorePointer(
                                            child: Center(
                                              child: _buildSpeechBubbleWidget(bubbleText),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                } else {
                                  // 空闲席位（虚线框，点击弹出邀请或添加AI选项）
                                  return InkWell(
                                    onTap: () => _showEmptySeatOptions(idx, gameTitle),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.adaptiveBgDark(context).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.adaptiveBorder(context).withOpacity(0.5), style: BorderStyle.solid),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                            child: Text('${idx + 1}号麦', style: const TextStyle(fontSize: 8.5, color: Colors.white70)),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.add_circle_outline, color: AppColors.primaryLight, size: 24),
                                          const SizedBox(height: 4),
                                          Text(
                                            isHost ? '+ 邀请/召集' : '+ 邀请好友',
                                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 局内实时互动消息栏
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveBgCard(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        // 常用短语水平滚动条 (带腾讯经典音效与头顶气泡)
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: ChatService.presetPhrases.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final phrase = ChatService.presetPhrases[idx];
                              return ActionChip(
                                label: Text(phrase, style: TextStyle(fontSize: 11, color: AppColors.adaptiveTextPrimary(context))),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.adaptiveBgDark(context),
                                onPressed: () {
                                  if (user == null) return;
                                  GameSoundService().playVictory();
                                  GameSoundService().playHapticLight();
                                  setState(() {
                                    _playerSpeechBubbles[user.id] = phrase;
                                  });
                                  _scrollToBottom();
                                  Timer(const Duration(milliseconds: 3500), () {
                                    if (!mounted) return;
                                    setState(() {
                                      if (_playerSpeechBubbles[user.id] == phrase) {
                                        _playerSpeechBubbles.remove(user.id);
                                      }
                                    });
                                  });
                                  context.read<ChatProvider>().sendMessage(
                                    senderId: user.id,
                                    senderName: user.nickname,
                                    senderAvatar: user.avatar,
                                    content: phrase,
                                    type: ChatMessageType.phrase,
                                    channel: 'ROOM',
                                    roomCode: widget.room.roomCode,
                                    textColor: user.chatTextColor,
                                    vipLevel: user.vipLevel,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Divider(height: 1, color: AppColors.adaptiveBorder(context)),

                        // 消息列表 (绑定平滑自滚控制器，支持长按复制与高对比度展示)
                        Expanded(
                          child: ListView.builder(
                            controller: _chatScrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: chatProv.currentMessages.length,
                            itemBuilder: (ctx, idx) {
                              final msg = chatProv.currentMessages[idx];
                              return InkWell(
                                onLongPress: () {
                                  Clipboard.setData(ClipboardData(text: msg.content));
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已复制消息内容'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${msg.senderAvatar} ', style: const TextStyle(fontSize: 12)),
                                      if (msg.vipLevel > 0) ...[
                                        VipBadgeWidget(vipLevel: msg.vipLevel, fontSize: 8, isCrown: msg.vipLevel >= 4),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        '${msg.senderName}: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: VipBadgeWidget.getNicknameColor(msg.vipLevel, defaultColor: AppColors.primary),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          msg.content,
                                          style: TextStyle(
                                            fontWeight: msg.type == ChatMessageType.throwItem ? FontWeight.bold : FontWeight.normal,
                                            color: msg.type == ChatMessageType.throwItem
                                                ? AppColors.accent
                                                : ChatMessageModel.getTextColorFromCode(msg.textColor, defaultColor: AppColors.adaptiveTextPrimary(context)),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // 底部聊天打字输入框 (回车直发、圆角胶囊形态与防遮挡触觉反馈)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _msgCtrl,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendRoomMessage(),
                                  style: TextStyle(fontSize: 13, color: AppColors.adaptiveTextPrimary(context)),
                                  decoration: InputDecoration(
                                    hintText: '发弹幕或聊天交流...',
                                    hintStyle: TextStyle(fontSize: 12, color: AppColors.adaptiveTextMuted(context)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    filled: true,
                                    fillColor: AppColors.adaptiveBgDark(context),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.adaptiveBorder(context), width: 0.8)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: AppColors.primaryLight),
                                tooltip: '发送消息',
                                onPressed: _sendRoomMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 底部操作栏 (房主控制开局 / 非房主控制准备)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Builder(
                    builder: (ctx) {
                      final myId = user?.id ?? '';
                      final isHostOfRoom = widget.room.hostPlayerId == myId ||
                          (widget.room.players.isNotEmpty && widget.room.players.first.id == myId);

                      if (isHostOfRoom) {
                        final nonHosts = widget.room.players.where((p) => p.id != myId).toList();
                        final readyCount = nonHosts.where((p) => p.isReady).length;
                        final totalNonHosts = nonHosts.length;
                        final hasEnough = widget.room.players.length >= widget.room.minPlayers;
                        final allReady = nonHosts.isNotEmpty && nonHosts.every((p) => p.isReady);
                        final canStart = hasEnough && allReady;

                        String labelText;
                        Color btnColor;
                        IconData btnIcon;
                        VoidCallback? onBtnTap;

                        if (totalNonHosts == 0) {
                          if (widget.room.gameType == 'party_wheel') {
                            labelText = '🚀 立即开启转盘大冒险 (支持单机/多人)';
                            btnColor = const Color(0xFF10B981);
                            btnIcon = Icons.rocket_launch_rounded;
                            onBtnTap = () => _startGame();
                          } else {
                            labelText = '等待玩家加入 (当前 1/${widget.room.minPlayers}人)';
                            btnColor = const Color(0xFF475569);
                            btnIcon = Icons.hourglass_empty_rounded;
                            onBtnTap = () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('至少需要 2 位玩家！可点击“微信/QQ开黑”分享邀请好友，或点击“📢 召集玩家”召唤AI陪练')),
                              );
                            };
                          }
                        } else if (!allReady) {
                          labelText = '等待其他玩家准备 ($readyCount/$totalNonHosts 已准备)';
                          btnColor = const Color(0xFF64748B);
                          btnIcon = Icons.access_time_rounded;
                          onBtnTap = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('还有玩家未准备 ($readyCount/$totalNonHosts)，请等待所有玩家准备就绪后即可开局！')),
                            );
                          };
                        } else {
                          labelText = '🚀 所有人已就绪，立即开局！';
                          btnColor = const Color(0xFF10B981);
                          btnIcon = Icons.rocket_launch_rounded;
                          onBtnTap = () => _startGame();
                        }

                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: btnColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: canStart ? 4 : 0,
                            ),
                            icon: Icon(btnIcon, size: 22),
                            label: Text(labelText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: onBtnTap,
                          ),
                        );
                      } else if (_isSpectator) {
                        // 旁观者：显示“申请加入席位准备”
                        final isFull = widget.room.players.length >= widget.room.maxCapacity;
                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFull ? const Color(0xFF475569) : const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: isFull ? 0 : 3,
                            ),
                            icon: Icon(isFull ? Icons.block : Icons.airline_seat_recline_normal, size: 22),
                            label: Text(
                              isFull ? '席位已满 (继续观战)' : '🪑 申请加入席位准备',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: isFull
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('当前房间席位已满，无法加入，请继续观战～')),
                                    );
                                  }
                                : () {
                                    SocketService().send({
                                      'type': 'GAME_ACTION',
                                      'action': 'SPECTATOR_JOIN_SEAT',
                                      'roomCode': widget.room.roomCode,
                                      'userId': myId,
                                      'userName': user?.nickname ?? '玩家',
                                      'userAvatar': user?.avatar ?? '🦊',
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已发送上桌申请，等待入席就绪...')),
                                    );
                                  },
                          ),
                        );
                      } else {
                        // 非房主普通玩家：显示“点击准备 / 取消准备”
                        final myPlayer = widget.room.players.firstWhere(
                          (p) => p.id == myId,
                          orElse: () => GamePlayer(id: myId, name: user?.nickname ?? '我', isReady: false),
                        );
                        final isReady = myPlayer.isReady;

                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReady ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                            icon: Icon(isReady ? Icons.cancel_outlined : Icons.check_circle_outline, size: 22),
                            label: Text(
                              isReady ? '✓ 已就绪 (点击取消准备)' : '⚡ 点击准备',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              final newReady = !isReady;
                              setState(() {
                                myPlayer.isReady = newReady;
                              });
                              if (newReady) {
                                GameSoundService().playVictory();
                              } else {
                                GameSoundService().playCardPlay();
                              }
                              // 1. 发送 WebSocket 准备通知
                              SocketService().send({
                                'type': 'PLAYER_READY',
                                'roomCode': widget.room.roomCode,
                                'userId': myId,
                                'isReady': newReady,
                              });
                              // 2. HTTP 备选同步
                              ApiService().setPlayerReady(
                                roomCode: widget.room.roomCode,
                                playerId: myId,
                                isReady: newReady,
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // 全屏抛物线飞掷道具图层
        InteractiveThrowOverlay(
          event: chatProv.lastThrowEvent,
          onComplete: () => chatProv.clearThrowEvent(),
        ),
      ],
    ),
  );
}

  /// 苹果风轻奢麦位发言气泡组件：支持自动柔性多行换行、完全避免被头像框遮挡、高对比度阅读
  Widget _buildSpeechBubbleWidget(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 44, maxWidth: 145),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 底部指向麦位玩家头像的微型三角形指针
        CustomPaint(
          size: const Size(10, 5),
          painter: _BubbleTrianglePainter(color: Colors.white),
        ),
      ],
    );
  }
}

/// 气泡底部指向指针绘制器
class _BubbleTrianglePainter extends CustomPainter {
  final Color color;
  _BubbleTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

