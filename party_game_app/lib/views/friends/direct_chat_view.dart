import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/commercial_ui_kit.dart';
import '../../models/friend_model.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/friend_service.dart';
import '../room/game_room_lobby_view.dart';

class DirectChatView extends StatefulWidget {
  final FriendModel friend;

  const DirectChatView({super.key, required this.friend});

  @override
  State<DirectChatView> createState() => _DirectChatViewState();
}

class _DirectChatViewState extends State<DirectChatView> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<DirectMessage>? _dmSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final friendProv = Provider.of<FriendProvider>(context, listen: false);
      friendProv.markAsRead(widget.friend.id);
      if (auth.user != null) {
        friendProv.syncFriendHistory(auth.user!.id, widget.friend.id).then((_) {
          if (mounted) setState(() {});
          _scrollToBottom();
        });
      }
      _scrollToBottom();
    });

    // 实时监听来自当前好友的新私信，收到后自动滚屏并标为已读
    _dmSub = FriendService().onDirectMessage.listen((msg) {
      if (mounted) {
        final cleanFriendId = widget.friend.id.trim().toLowerCase();
        if (msg.senderId.trim().toLowerCase() == cleanFriendId) {
          Provider.of<FriendProvider>(context, listen: false).markAsRead(widget.friend.id);
          setState(() {});
          _scrollToBottom();
        }
      }
    });

    // 前台活跃期间每 2.5 秒极速拉取最新历史对齐，保证100%不漏信
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final friendProv = Provider.of<FriendProvider>(context, listen: false);
        if (auth.user != null && auth.user!.id.isNotEmpty) {
          friendProv.syncFriendHistory(auth.user!.id, widget.friend.id).then((_) {
            if (mounted) {
              setState(() {});
              _scrollToBottom();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _dmSub?.cancel();
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendDirectText(String text) {
    if (text.trim().isEmpty) return;
    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    friendProv.sendDirectMessage(widget.friend.id, text.trim());
    _msgCtrl.clear();
    _scrollToBottom();
  }

  void _inviteToGameDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.adaptiveCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final games = [
          {'type': 'liars_dice', 'name': '大话骰', 'icon': '🎲'},
          {'type': 'take6', 'name': '谁是牛头王', 'icon': '🐂'},
          {'type': 'party_wheel', 'name': '聚会大冒险转盘', 'icon': '🎡'},
          {'type': 'undercover', 'name': '谁是卧底', 'icon': '🕵️'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CommercialSheetHandle(),
                Text(
                  '选择游戏发起对决邀请：',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(ctx)),
                ),
                const SizedBox(height: 12),
                ...games.map((g) {
                  return ListTile(
                    leading: Text(g['icon']!, style: const TextStyle(fontSize: 24)),
                    title: Text(g['name']!, style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptivePrimary(ctx)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final mePlayer = GamePlayer(
                        id: user.id,
                        name: user.nickname,
                        avatar: user.avatar,
                        isAi: false,
                      );
                      final newRoom = roomProv.createRoom(
                        gameType: g['type']!,
                        hostPlayer: mePlayer,
                        roomName: '${user.nickname}的${g['name']}局',
                      );

                      // 发送对战邀请卡片到私信
                      friendProv.sendDirectMessage(
                        widget.friend.id,
                        '我创建了【${g['name']}】房间，快来和我一决高下！',
                        inviteRoomCode: newRoom.roomCode,
                      );

                      _scrollToBottom();

                      // 询问是否直接前往房间大厅
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已向 ${widget.friend.nickname} 发送房间邀请！'),
                          action: SnackBarAction(
                            label: '前往房间',
                            textColor: AppColors.primary,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: newRoom)),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _joinInvitedRoom(String roomCode) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final mePlayer = GamePlayer(
      id: user.id,
      name: user.nickname,
      avatar: user.avatar,
      isAi: false,
    );

    try {
      final room = roomProv.joinRoomByCode(roomCode, mePlayer);
      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('房间已解散或不存在！')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendProv = Provider.of<FriendProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final myAvatar = auth.user?.avatar ?? '🦊';
    final messages = friendProv.getMessages(widget.friend.id);
    final primaryColor = AppColors.adaptivePrimary(context);

    return Scaffold(
      backgroundColor: AppColors.adaptiveBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.adaptiveCard(context),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: primaryColor.withAlpha(25),
              child: Text(widget.friend.avatar, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friend.displayNickname,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adaptiveTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.friend.isOnline ? '🟢 在线 | ${widget.friend.levelTitle}' : '⚪ 离线 | ${widget.friend.levelTitle}',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.friend.isOnline ? AppColors.cyan : AppColors.adaptiveTextSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '邀TA对战',
            icon: Icon(Icons.sports_esports, color: primaryColor),
            onPressed: _inviteToGameDialog,
          ),
        ],
      ),
      body: ResponsiveContentFrame(
        maxWidth: 920,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? CommercialEmptyState(
                      icon: Icons.mark_chat_unread_outlined,
                      title: '和 ${widget.friend.displayNickname} 打个招呼吧',
                      subtitle: '发送文字开聊，或点击右上角游戏手柄一键发起房间对决邀请！',
                      quickChips: const ['在吗？来开一局！🎲', '牛头王走起？🐂', '拉你进房开黑！'],
                      onChipTap: _sendDirectText,
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        return _buildMessageItem(msg, myAvatar);
                      },
                    ),
            ),
            _buildBottomInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(DirectMessage msg, String myAvatar) {
    final isMe = msg.isFromMe;
    final isDark = AppColors.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.adaptiveCard(context),
              child: Text(widget.friend.avatar, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.adaptiveCard(context),
                    borderRadius: BorderRadius.circular(14).copyWith(
                      bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                      bottomLeft: !isMe ? Radius.zero : const Radius.circular(14),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.adaptiveBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? AppColors.darkShadow : AppColors.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.adaptiveTextPrimary(context),
                          fontSize: 14,
                        ),
                      ),
                      // 战局邀请卡片
                      if (msg.inviteRoomCode != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.adaptiveElevated(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.adaptiveBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.vpn_key, color: AppColors.accent, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '房间号: ${msg.inviteRoomCode}',
                                  style: TextStyle(
                                    color: AppColors.adaptiveTextPrimary(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _joinInvitedRoom(msg.inviteRoomCode!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '立即加入',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(myAvatar, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomInput() {
    final borderColor = AppColors.adaptiveBorder(context);
    final primaryColor = AppColors.adaptivePrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.adaptiveCard(context),
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: '发送好友私信...',
                  hintStyle: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  filled: true,
                  fillColor: AppColors.adaptiveBg(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
                onSubmitted: _sendDirectText,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _sendDirectText(_msgCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('发送', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
