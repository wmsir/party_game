import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/room_provider.dart';
import '../../../views/widgets/game_settlement_dialog.dart';
import '../../../views/widgets/in_game_throw_dialog.dart';
import '../../../views/chat/widgets/interactive_throw_overlay.dart';
import '../../../views/widgets/entrance_banner_overlay.dart';
import '../../../providers/chat_provider.dart';
import '../domain/undercover_engine.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/sound/game_sound_service.dart';

import '../../../services/socket_service.dart';

class UndercoverGameScreen extends StatefulWidget {
  final List<Map<String, dynamic>> playerConfigs;
  final String? roomCode;
  final String? myPlayerId;

  const UndercoverGameScreen({
    Key? key,
    required this.playerConfigs,
    this.roomCode,
    this.myPlayerId,
  }) : super(key: key);

  @override
  State<UndercoverGameScreen> createState() => _UndercoverGameScreenState();
}

class _UndercoverGameScreenState extends State<UndercoverGameScreen> {
  late UndercoverEngine _engine;
  int _viewWordPlayerIndex = 0;
  bool _isWordRevealed = false;
  String? _selectedVoteId;

  final TextEditingController _clueController = TextEditingController();

  // 联机状态与服务端权威私发词汇
  StreamSubscription? _socketSub;
  String? _onlineMyWord;
  bool _onlineIsUndercover = false;
  String? _onlineCivilianWord;
  String? _onlineUndercoverWord;
  List<String> _onlineTiedIds = [];
  bool _onlineIsTieBreaker = false;
  String? _currentSpeakerId;
  String? _currentSpeakerName;
  int _speakerCountdown = 30;
  Timer? _countdownTimer;
  String? _votedTargetId;

  // AI 智能托管模式
  bool _isAutoPlay = false;
  Timer? _autoPlayTimer;
  bool _hasSettledGameOver = false;

  bool _resolveIsMeUndercover() {
    if (_onlineMyWord != null) return _onlineIsUndercover;
    if (_engine.players.isEmpty) return false;
    final myId = widget.myPlayerId;
    if (myId != null && myId.isNotEmpty) {
      for (final p in _engine.players) {
        if (p.id == myId) return p.isUndercover;
      }
    }
    return _engine.players.first.isUndercover;
  }

  void _checkGameOverSettlement() {
    if (_engine.phase == UndercoverPhase.gameOver && !_hasSettledGameOver) {
      _hasSettledGameOver = true;
      final isCivilianWin = _engine.winnerTeam == 'CIVILIAN';
      final isMeUndercover = _resolveIsMeUndercover();
      final isWin = (isCivilianWin && !isMeUndercover) || (!isCivilianWin && isMeUndercover);

      context.read<AuthProvider>().settleRankMatch(isWin, gameType: 'undercover');

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          GameSettlementDialog.show(
            context,
            isWin: isWin,
            gameTitle: '谁是卧底',
            gameIcon: '🕵️',
            subtitle: isWin
                ? '精彩绝伦！成功帮助阵营赢得最终胜利！'
                : '真凶隐藏太深！阵营遗憾落败，再接再厉！',
            onPlayAgain: () {
              setState(() {
                _hasSettledGameOver = false;
                _engine.startNewGame(playerConfigs: widget.playerConfigs);
                _viewWordPlayerIndex = 0;
                _isWordRevealed = false;
              });
            },
            onExit: () {
              final user = context.read<AuthProvider>().user;
              context.read<RoomProvider>().leaveRoom(user?.id, widget.roomCode ?? 'UNDERCOVER-1');
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        }
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
    });
    if (_isAutoPlay) {
      _scheduleAutoAction();
    } else {
      _autoPlayTimer?.cancel();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isAutoPlay ? '🤖 已开启【AI智能托管】：系统将自动帮您看词、发言并投票！' : '👤 已取消托管，恢复手动操作'),
        backgroundColor: _isAutoPlay ? const Color(0xFF10B981) : const Color(0xFF475569),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scheduleAutoAction() {
    if (!_isAutoPlay) return;
    _autoPlayTimer?.cancel();

    _autoPlayTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || !_isAutoPlay) return;

      switch (_engine.phase) {
        case UndercoverPhase.wordDealing:
          _nextWordViewer();
          _scheduleAutoAction();
          break;
        case UndercoverPhase.speaking:
          GameSoundService().playCardPlay();
          setState(() {
            final active = _engine.activePlayers;
            if (active.isNotEmpty) {
              final curSp = active[_engine.currentSpeakerIndex % active.length];
              _engine.addClue(curSp.id, curSp.name, _engine.generateAiClue(curSp));
            }
            _engine.nextSpeaker();
          });
          _scheduleAutoAction();
          break;
        case UndercoverPhase.voting:
          final active = _engine.activePlayers;
          final candidates = _engine.isTieBreakerRound
              ? active.where((p) => _engine.tiedPlayerIds.contains(p.id)).toList()
              : active;
          if (candidates.isNotEmpty) {
            final randomTarget = candidates[Random().nextInt(candidates.length)];
            GameSoundService().playUndercoverVote();
            _engine.votePlayer(randomTarget.id);
            _engine.castAiVotes(excludePlayerId: widget.myPlayerId);
            setState(() {
              _selectedVoteId = null;
              _engine.finishVoting();
            });
            _checkGameOverSettlement();
          }
          break;
        case UndercoverPhase.gameOver:
          break;
      }
    });
  }

  void _minimizeRoom() {
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    roomProv.registerActiveSession(
      ActiveRoomSession(
        roomCode: 'UNDERCOVER-1',
        gameType: 'undercover',
        gameTitle: '谁是卧底',
        gameIcon: '🕵️',
        isMinimized: true,
        screenBuilder: (_) => UndercoverGameScreen(playerConfigs: widget.playerConfigs),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗗 房间已最小化至右侧悬浮窗，可在任意页面随时点击恢复！'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _engine = UndercoverEngine();

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
      }
    });
    _engine.startNewGame(playerConfigs: widget.playerConfigs);
    GameSoundService().playGameBgm('undercover');

    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      _initOnlineSocketListener();
    }
  }

  void _startSpeakerTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_speakerCountdown > 0) {
        setState(() {
          _speakerCountdown--;
        });
      } else {
        timer.cancel();
        if (_currentSpeakerId == widget.myPlayerId) {
          _onOnlineSpeakerFinish();
        }
      }
    });
  }

  void _onOnlineSpeakerFinish() {
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      final clueText = _clueController.text.trim();
      if (clueText.isNotEmpty) {
        final user = context.read<AuthProvider>().user;
        context.read<ChatProvider>().sendMessage(
          senderId: widget.myPlayerId ?? user?.id ?? '',
          senderName: user?.nickname ?? '我',
          senderAvatar: user?.avatar ?? '🦊',
          content: '🎤 [发言线索] $clueText',
          channel: 'ROOM',
          roomCode: widget.roomCode,
          textColor: user?.chatTextColor,
          vipLevel: user?.vipLevel ?? 0,
        );
        _engine.addClue(widget.myPlayerId ?? user?.id ?? '', user?.nickname ?? '我', clueText);
        _clueController.clear();
      }
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'UNDERCOVER_SPEAKER_FINISH',
        'roomCode': widget.roomCode,
      });
      GameSoundService().playCardPlay();
    }
  }

  void _onOnlineVote(String targetId) {
    if (widget.roomCode != null && widget.roomCode!.isNotEmpty) {
      setState(() {
        _votedTargetId = targetId;
      });
      SocketService().send({
        'type': 'GAME_ACTION',
        'action': 'UNDERCOVER_VOTE',
        'roomCode': widget.roomCode,
        'payload': {'targetId': targetId},
      });
      GameSoundService().playUndercoverVote();
    }
  }

  void _initOnlineSocketListener() {
    _socketSub = SocketService().messageStream.listen((data) {
      if (!mounted) return;
      final type = data['type'];
      if (type == 'GAME_ACTION') {
        final action = data['action'];
        final payload = data['payload'] is Map ? data['payload'] as Map : {};
        if (action == 'UNDERCOVER_ROLE_DEAL') {
          setState(() {
            _onlineMyWord = payload['myWord']?.toString();
            _onlineIsUndercover = payload['isUndercover'] == true;
            _engine.phase = UndercoverPhase.speaking;
            _engine.statusMessage = '🎉 身份词已秘密派发！第一轮发言开始，请按麦序发言！';
          });
        } else if (action == 'UNDERCOVER_NEXT_SPEAKER') {
          final speakerId = payload['speakerId']?.toString();
          String spName = '某玩家';
          for (final p in widget.playerConfigs) {
            if (p['id'] == speakerId) {
              spName = p['name'] ?? spName;
              break;
            }
          }
          setState(() {
            _onlineIsTieBreaker = false;
            _onlineTiedIds = [];
            _currentSpeakerId = speakerId;
            _currentSpeakerName = spName;
            _speakerCountdown = 30;
            _engine.phase = UndercoverPhase.speaking;
            _engine.statusMessage = '🎤 轮到【$spName】发言描述！';
          });
          _startSpeakerTimer();
        } else if (action == 'UNDERCOVER_PHASE_VOTING') {
          _countdownTimer?.cancel();
          setState(() {
            _onlineIsTieBreaker = false;
            _onlineTiedIds = [];
            _engine.phase = UndercoverPhase.voting;
            _engine.statusMessage = '🗳️ 全员发言完毕！请大家在 25 秒内指认公决怀疑的卧底！';
            _speakerCountdown = 25;
            _votedTargetId = null;
            _selectedVoteId = null;
          });
        } else if (action == 'UNDERCOVER_TIE_BREAKER') {
          final rawTied = payload['tiedPlayerIds'] is List
              ? (payload['tiedPlayerIds'] as List).map((e) => e.toString()).toList()
              : <String>[];
          setState(() {
            _onlineIsTieBreaker = true;
            _onlineTiedIds = rawTied;
            _votedTargetId = null;
            _selectedVoteId = null;
            _engine.phase = UndercoverPhase.voting;
            _engine.statusMessage = '⚖️ 投票出现平票！进入 PK 复投环节，请从平票玩家中再选一人！';
          });
        } else if (action == 'UNDERCOVER_VOTE_RESULT') {
          final outPlayerName = payload['outPlayerName']?.toString() ?? '玩家';
          final wasUndercover = payload['wasUndercover'] == true;
          final gameOver = payload['gameOver'] == true;
          final winnerTeam = payload['winnerTeam']?.toString();
          final outId = payload['outPlayerId']?.toString();
          final cWord = payload['civilianWord']?.toString();
          final uWord = payload['undercoverWord']?.toString();

          if (outId != null) {
            for (final p in _engine.players) {
              if (p.id == outId) {
                p.isOut = true;
                break;
              }
            }
          }

          setState(() {
            _onlineIsTieBreaker = false;
            _onlineTiedIds = [];
            if (cWord != null && cWord.isNotEmpty) _onlineCivilianWord = cWord;
            if (uWord != null && uWord.isNotEmpty) _onlineUndercoverWord = uWord;
            _engine.statusMessage = '💥 公投揭晓：【$outPlayerName】被放逐！身份为【${wasUndercover ? "卧底" : "平民"}】！';
            if (gameOver) {
              _engine.phase = UndercoverPhase.gameOver;
              _engine.winnerTeam = winnerTeam;
              _checkGameOverSettlement();
            }
          });
        }
      } else if (type == 'ROOM_RECONNECT_SYNC') {
        if (data['myWord'] != null) {
          setState(() {
            _onlineMyWord = data['myWord']?.toString();
            _onlineIsUndercover = data['isUndercover'] == true;
            if (data['undercoverPhase'] == 'VOTING') {
              _engine.phase = UndercoverPhase.voting;
            } else if (data['undercoverPhase'] == 'SPEAKING') {
              _engine.phase = UndercoverPhase.speaking;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _clueController.dispose();
    _socketSub?.cancel();
    _countdownTimer?.cancel();
    _autoPlayTimer?.cancel();
    GameSoundService().stopBgm();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearThrowEvent();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);
      final roomProv = context.read<RoomProvider>();
      if (!roomProv.hasMinimizedRoom) {
        final user = context.read<AuthProvider>().user;
        roomProv.leaveRoom(user?.id, widget.roomCode ?? 'UNDERCOVER-1');
      }
    } catch (_) {}
    super.dispose();
  }

  void _nextWordViewer() {
    setState(() {
      _isWordRevealed = false;
      if (_viewWordPlayerIndex < _engine.players.length - 1) {
        _viewWordPlayerIndex++;
      } else {
        _engine.enterSpeakingPhase();
      }
    });
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '🕵️ 谁是卧底 · 推理规则',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(ctx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1️⃣ 【秘密发词】大多数平民拿到同一个词，少数卧底拿到高度相似的另一个词（开局不知自己身份）。', style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.adaptiveTextSecondary(ctx))),
            const SizedBox(height: 8),
            Text('2️⃣ 【轮流描述】每人每轮用一句话描述自己的词，既不能过于直白让卧底猜出，也要让队友听出你是同阵营。', style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.adaptiveTextSecondary(ctx))),
            const SizedBox(height: 8),
            Text('3️⃣ 【公决投票】每轮发言后全员投票放逐得票最高者。抓出所有卧底则平民获胜；卧底存活到最后则卧底获胜！', style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.adaptiveTextSecondary(ctx))),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('明白了'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('离开房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('您可以选择【最小化挂起】对局（可随时点击悬浮窗返回），或【强制退出】彻底离开当前房间。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _minimizeRoom();
            },
            child: const Text('🗗 最小化挂起', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final user = Provider.of<AuthProvider>(context, listen: false).user;
              final roomProv = Provider.of<RoomProvider>(context, listen: false);
              roomProv.leaveRoom(user?.id, 'UNDERCOVER-1');
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('🚪 强制退出'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: AppColors.adaptiveTextPrimary(context), size: 18),
            tooltip: '返回或最小化',
            onPressed: _showExitDialog,
          ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                '🕵️ 谁是卧底 · 聚会推理',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (_isAutoPlay) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.isDarkMode(context) ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  '托管中',
                  style: TextStyle(
                    color: AppColors.isDarkMode(context) ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          // 智能托管按钮
          IconButton(
            icon: Icon(
              _isAutoPlay ? Icons.smart_toy : Icons.smart_toy_outlined,
              color: _isAutoPlay ? const Color(0xFF10B981) : AppColors.adaptiveTextSecondary(context),
            ),
            tooltip: _isAutoPlay ? '取消AI托管' : '开启AI智能托管',
            onPressed: _toggleAutoPlay,
          ),
          // 房间最小化按钮
          IconButton(
            icon: Icon(Icons.picture_in_picture_alt_outlined, color: AppColors.adaptiveTextSecondary(context)),
            tooltip: '最小化房间',
            onPressed: _minimizeRoom,
          ),
          // 规则说明按钮
          IconButton(
            icon: Icon(Icons.help_outline, color: AppColors.adaptiveTextSecondary(context)),
            tooltip: '推理规则',
            onPressed: _showRulesDialog,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.isDarkMode(context) ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.isDarkMode(context) ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          color: AppColors.isDarkMode(context) ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'AI 智能托管中：自动帮您看词、接棒发言并参与投票',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.isDarkMode(context) ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _toggleAutoPlay,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('取消托管', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 状态提示横幅 (深绿宝石高对比底色，彻底修复白底白字不可见问题)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF065F46), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.8)),
                          ),
                          child: Text(
                            _engine.statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Expanded(
                          child: _buildPhaseContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
          Consumer<ChatProvider>(
            builder: (context, chat, _) => InteractiveThrowOverlay(
              event: chat.lastThrowEvent,
              onComplete: () => chat.clearThrowEvent(),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPhaseContent() {
    switch (_engine.phase) {
      case UndercoverPhase.wordDealing:
        return _buildWordDealingCard();
      case UndercoverPhase.speaking:
        return _buildSpeakingList();
      case UndercoverPhase.voting:
        return _buildVotingList();
      case UndercoverPhase.gameOver:
        return _buildGameOverCard();
    }
  }

  // 发词看词卡片
  Widget _buildWordDealingCard() {
    if (_onlineMyWord != null) {
      return Center(
        child: Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🤫 您的专属底词卡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('（请勿将屏幕朝向他人，秘密记住自己的词语）', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _isWordRevealed = !_isWordRevealed),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isWordRevealed ? const Color(0xFF0F172A) : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _isWordRevealed ? const Color(0xFFF59E0B) : const Color(0xFF475569), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isWordRevealed ? '💎 $_onlineMyWord' : '🔒 点击翻开我的专属底词',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _isWordRevealed ? const Color(0xFFFDE68A) : Colors.white70,
                          ),
                        ),
                        if (_isWordRevealed) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '🤫 身份已保密，请通过全场发言自行推理阵营',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    onPressed: () => setState(() => _engine.enterSpeakingPhase()),
                    child: const Text('我记住了，准备进入发言环节', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final curPlayer = _engine.players[_viewWordPlayerIndex];
    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.adaptiveElevated(context),
                child: Text(curPlayer.avatar, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 12),
              Text(
                '请【${curPlayer.name}】看词',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '（其他人请回避，勿偷看！）',
                style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 12),
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTapDown: (_) => setState(() => _isWordRevealed = true),
                onTapUp: (_) => setState(() => _isWordRevealed = false),
                onTapCancel: () => setState(() => _isWordRevealed = false),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _isWordRevealed ? AppColors.primary.withOpacity(0.2) : AppColors.adaptiveElevated(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isWordRevealed ? AppColors.primary : AppColors.adaptiveBorder(context), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _isWordRevealed ? curPlayer.word : '按住此处查看你的底牌词',
                      style: TextStyle(
                        fontSize: _isWordRevealed ? 28 : 15,
                        fontWeight: FontWeight.bold,
                        color: _isWordRevealed ? Colors.amber : AppColors.adaptiveTextSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _nextWordViewer,
                  child: Text(
                    _viewWordPlayerIndex < _engine.players.length - 1 ? '我记住了，下一位玩家' : '全员看词完毕，开始发言',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 发言轮次展示
  Widget _buildSpeakingList() {
    final active = _engine.activePlayers;
    final speaker = active.isNotEmpty ? active[_engine.currentSpeakerIndex % active.length] : _engine.players.first;

    return Column(
      children: [
        if (_onlineMyWord != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('我的底词：', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Flexible(
                        child: Text(
                          _isWordRevealed ? '【$_onlineMyWord】' : '【密词已隐藏】',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _isWordRevealed ? const Color(0xFFFDE68A) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isWordRevealed = !_isWordRevealed),
                  child: Text(
                    _isWordRevealed ? '🙈 隐藏' : '👁️ 查看',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Text(speaker.avatar, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前发言中：${_currentSpeakerName ?? speaker.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '请用一句话或几个词描述你的词，切忌直接说出词名！',
                      style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: ListView.separated(
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = active[idx];
              final isCurrent = (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                  ? (p.id == _currentSpeakerId)
                  : (idx == _engine.currentSpeakerIndex);
              final hasSpoken = idx < _engine.currentSpeakerIndex;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.adaptiveElevated(context) : AppColors.adaptiveCard(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCurrent ? AppColors.accent : AppColors.adaptiveBorder(context)),
                ),
                child: Row(
                  children: [
                    Text('${idx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(p.avatar, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (p.id != widget.myPlayerId)
                      GestureDetector(
                        onTap: () {
                          InGameThrowDialog.show(context, targetPlayerId: p.id, targetPlayerName: p.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: const Text('🍻 道具', style: TextStyle(fontSize: 10, color: Colors.amber)),
                        ),
                      ),
                    if (isCurrent)
                      const Chip(label: Text('正在发言', style: TextStyle(fontSize: 11, color: Colors.amber)), visualDensity: VisualDensity.compact)
                    else if (hasSpoken)
                      const Chip(label: Text('已描述', style: TextStyle(fontSize: 11, color: Colors.green)), visualDensity: VisualDensity.compact)
                    else
                      Text('等待中', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),

        if (_engine.clueLogs.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.adaptiveCard(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.adaptiveBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _engine.clueLogs.reversed.take(3).map((item) => Text(
                    '💬 [第${item['round']}轮] ${item['playerName']}: ${item['clue']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.adaptiveTextSecondary(context)),
                  )).toList(),
            ),
          ),

        if ((widget.roomCode != null && widget.roomCode!.isNotEmpty)
            ? (_currentSpeakerId == widget.myPlayerId)
            : !speaker.isAi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _clueController,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: '输入你的简短描述线索（选填，切忌直说底词）...',
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.edit_note, size: 18),
              ),
            ),
          ),

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                  ? ((_currentSpeakerId == widget.myPlayerId) ? const Color(0xFF10B981) : const Color(0xFF334155))
                  : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            icon: Icon((widget.roomCode != null && _currentSpeakerId == widget.myPlayerId) ? Icons.mic : Icons.mic_none),
            label: Text(
              (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                  ? ((_currentSpeakerId == widget.myPlayerId)
                      ? '🎤 提交线索并交棒 (${_speakerCountdown}s)'
                      : '⏳ 等待【${_currentSpeakerName ?? speaker.name}】发言 (${_speakerCountdown}s)...')
                  : (speaker.isAi ? '🤖 AI 自动描述并下一位' : '【发言结束】交接给下一位'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                ? ((_currentSpeakerId == widget.myPlayerId) ? _onOnlineSpeakerFinish : null)
                : () {
                    GameSoundService().playCardPlay();
                    setState(() {
                      if (speaker.isAi) {
                        _engine.addClue(speaker.id, speaker.name, _engine.generateAiClue(speaker));
                      } else if (_clueController.text.trim().isNotEmpty) {
                        _engine.addClue(speaker.id, speaker.name, _clueController.text.trim());
                        _clueController.clear();
                      }
                      _engine.nextSpeaker();
                    });
                  },
          ),
        ),
      ],
    );
  }

  // 投票放逐列表 (支持平票 PK 候选隔离与 AI 智能投票)
  Widget _buildVotingList() {
    final active = _engine.activePlayers;
    final isPk = _onlineIsTieBreaker || _engine.isTieBreakerRound;
    final tiedSet = _onlineIsTieBreaker ? _onlineTiedIds : _engine.tiedPlayerIds;
    final candidates = (isPk && tiedSet.isNotEmpty)
        ? active.where((p) => tiedSet.contains(p.id)).toList()
        : active;
    return Column(
      children: [
        if (isPk)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Text(
              '⚖️ 平票 PK 复投中：请仅在以下平票玩家中选出放逐人选！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          )
        else
          Text('请指认并投票出你怀疑的卧底：', style: TextStyle(fontSize: 14, color: AppColors.adaptiveTextSecondary(context))),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final p = candidates[idx];
              final isSelected = _selectedVoteId == p.id;
              return InkWell(
                onTap: () => setState(() => _selectedVoteId = p.id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.error.withOpacity(0.2) : AppColors.adaptiveCard(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.error : AppColors.adaptiveBorder(context), width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(p.avatar, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppColors.error : Colors.grey,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _votedTargetId != null ? const Color(0xFF475569) : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                ? ((_selectedVoteId == null || _votedTargetId != null) ? null : () => _onOnlineVote(_selectedVoteId!))
                : (_selectedVoteId == null
                    ? null
                    : () {
                        GameSoundService().playUndercoverVote();
                        _engine.votePlayer(_selectedVoteId!);
                        _engine.castAiVotes(excludePlayerId: widget.myPlayerId);
                        setState(() {
                          _selectedVoteId = null;
                          _engine.finishVoting();
                        });
                        _checkGameOverSettlement();
                      }),
            child: Text(
              (widget.roomCode != null && widget.roomCode!.isNotEmpty)
                  ? (_votedTargetId != null ? '✓ 已成功投出，等待其他玩家公决计票...' : '确认投票指认此玩家')
                  : (isPk ? '确认 PK 复投' : '确认投票并揭晓放逐结果'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // 游戏结算大卡片
  Widget _buildGameOverCard() {
    final isCivilianWin = _engine.winnerTeam == 'CIVILIAN';
    final isMeUndercover = _resolveIsMeUndercover();
    final isWin = (isCivilianWin && !isMeUndercover) || (!isCivilianWin && isMeUndercover);
    final civWordDisplay = _onlineCivilianWord ?? _engine.civilianWord;
    final ucWordDisplay = _onlineUndercoverWord ?? _engine.undercoverWord;

    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCivilianWin ? '🏆 平民阵营获胜！' : '😈 卧底阵营获胜！',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isCivilianWin ? AppColors.accent : AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveBgDark(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.adaptiveBorder(context)),
                ),
                child: Column(
                  children: [
                    Text('平民词：【$civWordDisplay】', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(context))),
                    const SizedBox(height: 8),
                    Text('卧底词：【$ucWordDisplay】', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
              ),
              if (_onlineMyWord == null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: _engine.players.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (p.isUndercover ? AppColors.error : AppColors.primary).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.isUndercover ? AppColors.error : AppColors.primary),
                        ),
                        child: Text(
                          '${p.avatar} ${p.name} · ${p.isUndercover ? "卧底" : "平民"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: p.isUndercover ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      )).toList(),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.military_tech_outlined, size: 16),
                    label: const Text('结算明细', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      GameSettlementDialog.show(
                        context,
                        isWin: isWin,
                        gameTitle: '谁是卧底',
                        gameIcon: '🕵️',
                        subtitle: isWin
                            ? '精彩绝伦！成功帮助阵营赢得最终胜利！'
                            : '真凶隐藏太深！阵营遗憾落败，再接再厉！',
                        onPlayAgain: () {
                          setState(() {
                            _hasSettledGameOver = false;
                            _engine.startNewGame(playerConfigs: widget.playerConfigs);
                            _viewWordPlayerIndex = 0;
                            _isWordRevealed = false;
                          });
                        },
                        onExit: () => Navigator.pop(context),
                      );
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _hasSettledGameOver = false;
                        _engine.startNewGame(playerConfigs: widget.playerConfigs);
                        _viewWordPlayerIndex = 0;
                        _isWordRevealed = false;
                      });
                    },
                    child: const Text('再来一局', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
