import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/commercial_ui_kit.dart';
import '../../models/chat_message_model.dart';
import '../../models/friend_model.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/chat_service.dart';
import '../commercial/global_blessing_dialog.dart';
import '../profile/dressing_shop_view.dart';
import '../room/game_room_lobby_view.dart';
import '../widgets/vip_badge_widget.dart';
import '../../services/api_service.dart';

class ChatSquareView extends StatefulWidget {
  const ChatSquareView({super.key});

  @override
  State<ChatSquareView> createState() => _ChatSquareViewState();
}

class _ChatSquareViewState extends State<ChatSquareView> with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _showPhrasesPicker = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && (_showEmojiPicker || _showPhrasesPicker)) {
        setState(() {
          _showEmojiPicker = false;
          _showPhrasesPicker = false;
        });
      }
    });
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final chatProv = Provider.of<ChatProvider>(context, listen: false);
        chatProv.switchChannel(_tabCtrl.index == 0 ? 'WORLD' : 'CITY');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chatProv = Provider.of<ChatProvider>(context, listen: false);
        chatProv.switchChannel(_tabCtrl.index == 0 ? 'WORLD' : 'CITY');
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    chat.sendMessage(
      senderId: user.id,
      senderName: user.nickname,
      senderAvatar: user.avatar,
      content: text.trim(),
      channel: _tabCtrl.index == 0 ? 'WORLD' : 'CITY',
      textColor: user.chatTextColor,
      vipLevel: user.vipLevel,
    );

    _textCtrl.clear();
    setState(() {
      _showEmojiPicker = false;
      _showPhrasesPicker = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user;
    final messages = _tabCtrl.index == 0
        ? chat.getMessages('WORLD')
        : chat.getMessages('CITY');

    final primaryColor = AppColors.adaptivePrimary(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.adaptiveCard(context),
        elevation: 0,
        title: const Text('💬 聚会交流广场', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.amber, size: 24),
            tooltip: '全服大喇叭',
            onPressed: () => GlobalBlessingDialog.show(context),
          ),
          IconButton(
            icon: Icon(Icons.storefront_outlined, color: primaryColor, size: 22),
            tooltip: '装扮商城',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView()));
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: AppColors.adaptiveTextSecondary(context),
          tabs: const [
            Tab(text: '🌐 世界频道'),
            Tab(text: '📍 同城频道'),
          ],
        ),
      ),
      body: ResponsiveContentFrame(
        maxWidth: 920,
        child: Column(
          children: [
            // 顶端公约提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: primaryColor.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '公约：提倡文明友好互动，点击玩家头像可加好友或发起切磋！',
                      style: TextStyle(
                        color: AppColors.isDarkMode(context) ? const Color(0xFF86EFAC) : AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 消息流列表
            Expanded(
              child: messages.isEmpty
                  ? CommercialEmptyState(
                      icon: Icons.forum_outlined,
                      title: '频道暂无发言，快来破冰开聊',
                      subtitle: '发送一句招呼或邀约牌友开局，点击玩家头像可加好友或发起切磋！',
                      quickChips: const ['大家好，来一局！🎲', '牛头王缺人吗？🐂', '大话骰速来切磋 🔥'],
                      onChipTap: _handleSend,
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        final isMe = currentUser != null && msg.senderId == currentUser.id;

                        if (msg.type == ChatMessageType.system) {
                          return _buildSystemBanner(msg.content);
                        }

                        if (msg.type == ChatMessageType.throwItem) {
                          return _buildThrowItemBanner(msg);
                        }

                        return _buildChatMessageItem(msg, isMe);
                      },
                    ),
            ),

            // 常用短语面板
            if (_showPhrasesPicker) _buildPhrasesPanel(),

            // 快捷表情面板
            if (_showEmojiPicker) _buildEmojiPanel(),

            // 底部输入栏
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBanner(String content) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.adaptiveElevated(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.adaptiveBorder(context)),
        ),
        child: Text(
          content,
          style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildThrowItemBanner(ChatMessageModel msg) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.adaptiveCard(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.adaptiveAccent(context).withAlpha(120), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.isDarkMode(context) ? AppColors.darkShadow : AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg.itemEmoji ?? '💥', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${msg.senderName} 向 ${msg.targetPlayerName} ${msg.content}',
                style: TextStyle(
                  color: AppColors.adaptiveTextPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessageItem(ChatMessageModel msg, bool isMe) {
    final isDark = AppColors.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _showUserActionDialog(msg),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.adaptiveCard(context),
                child: Text(msg.senderAvatar, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.vipLevel > 0) ...[
                          VipBadgeWidget(vipLevel: msg.vipLevel, fontSize: 9, isCrown: msg.vipLevel >= 4),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            msg.senderName,
                            style: TextStyle(
                              color: VipBadgeWidget.getNicknameColor(
                                msg.vipLevel,
                                defaultColor: AppColors.adaptiveTextSecondary(context),
                              ),
                              fontSize: 11,
                              fontWeight: msg.vipLevel > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.content,
                        style: TextStyle(
                          color: ChatMessageModel.getTextColorFromCode(
                            msg.textColor,
                            defaultColor: isMe ? Colors.white : AppColors.adaptiveTextPrimary(context),
                          ),
                          fontSize: 14,
                          fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (_extractRoomCode(msg.content) != null) ...[
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.flash_on, size: 14, color: Colors.black),
                          label: const Text('⚡ 立即加入房间', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _joinRoomByCode(_extractRoomCode(msg.content)!),
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
              radius: 18,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(msg.senderAvatar, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ],
      ),
    );
  }

  String? _extractRoomCode(String content) {
    final reg = RegExp(r'#(\d{6})');
    final match = reg.firstMatch(content);
    return match?.group(1);
  }

  void _joinRoomByCode(String roomCode) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    try {
      final room = await ApiService().fetchRoomDetail(roomCode);
      if (!mounted) return;
      if (room != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('房间不存在或已解散')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加入房间失败: $e')));
      }
    }
  }

  Widget _buildInputBar() {
    final primaryColor = AppColors.adaptivePrimary(context);
    final secondaryText = AppColors.adaptiveTextSecondary(context);
    final borderColor = AppColors.adaptiveBorder(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.adaptiveCard(context),
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 常用语按钮
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: _showPhrasesPicker ? primaryColor : secondaryText,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showPhrasesPicker = !_showPhrasesPicker;
                  if (_showPhrasesPicker) _showEmojiPicker = false;
                });
              },
            ),
            // 表情按钮
            IconButton(
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: _showEmojiPicker ? primaryColor : secondaryText,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  if (_showEmojiPicker) _showPhrasesPicker = false;
                });
              },
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _inputFocusNode,
                style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: '说点好玩的...',
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
                onSubmitted: _handleSend,
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => _handleSend(_textCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('发送', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.adaptiveCard(context),
        border: Border(top: BorderSide(color: AppColors.adaptiveBorder(context))),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: ChatService.presetEmojis.length,
        itemBuilder: (context, idx) {
          final emoji = ChatService.presetEmojis[idx];
          return InkWell(
            onTap: () {
              _textCtrl.text += emoji;
            },
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhrasesPanel() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.adaptiveCard(context),
        border: Border(top: BorderSide(color: AppColors.adaptiveBorder(context))),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: ChatService.presetPhrases.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.adaptiveBorder(context)),
        itemBuilder: (context, idx) {
          final phrase = ChatService.presetPhrases[idx];
          return ListTile(
            dense: true,
            title: Text(phrase, style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontSize: 13)),
            trailing: Icon(Icons.send_rounded, size: 16, color: AppColors.adaptivePrimary(context)),
            onTap: () => _handleSend(phrase),
          );
        },
      ),
    );
  }

  void _showInviteGamePicker(ChatMessageModel targetMsg) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final games = [
      {'type': 'liars_dice', 'name': '大话骰 (吹牛)', 'icon': '🎲'},
      {'type': 'take6', 'name': '谁是牛头王', 'icon': '🐂'},
      {'type': 'party_wheel', 'name': '聚会大冒险转盘', 'icon': '🎡'},
      {'type': 'undercover', 'name': '谁是卧底', 'icon': '🕵️'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.adaptiveCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CommercialSheetHandle(),
              Text(
                '选择桌游向 @${targetMsg.senderName} 发起组局邀请',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.adaptiveTextPrimary(ctx),
                ),
              ),
              const SizedBox(height: 10),
              ...games.map((g) => ListTile(
                    leading: Text(g['icon']!, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      g['name']!,
                      style: TextStyle(
                        color: AppColors.adaptiveTextPrimary(ctx),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptivePrimary(ctx)),
                    onTap: () {
                      Navigator.pop(ctx);
                      final me = GamePlayer(id: user.id, name: user.nickname, avatar: user.avatar);
                      final room = roomProv.createRoom(
                        gameType: g['type']!,
                        hostPlayer: me,
                        roomName: '${user.nickname}的${g['name']}局',
                      );
                      chat.sendMessage(
                        senderId: user.id,
                        senderName: user.nickname,
                        senderAvatar: user.avatar,
                        content: '@${targetMsg.senderName} 来【${g['name']}】一决高下！房间号 #${room.roomCode}',
                        channel: _tabCtrl.index == 0 ? 'WORLD' : 'CITY',
                        textColor: user.chatTextColor,
                        vipLevel: user.vipLevel,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
                      );
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserActionDialog(ChatMessageModel msg) {
    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.adaptiveCard(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CommercialSheetHandle(),
                const SizedBox(height: 6),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: Text(msg.senderAvatar, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(height: 10),
                Text(
                  msg.senderName,
                  style: TextStyle(
                    color: AppColors.adaptiveTextPrimary(ctx),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '用户ID: ${msg.senderId}',
                  style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('加为好友'),
                        onPressed: () async {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final myUser = auth.user;
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          if (myUser != null) {
                            final targetUser = UserSearchResult(
                              id: msg.senderId,
                              nickname: msg.senderName,
                              username: msg.senderName,
                              avatar: msg.senderAvatar,
                            );
                            final res = await friendProv.applyFriend(
                              fromUserId: myUser.id,
                              targetUser: targetUser,
                            );
                            messenger.showSnackBar(
                              SnackBar(content: Text(res['message'] ?? '已向 ${msg.senderName} 发送好友申请！')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.adaptiveAccent(ctx),
                          side: BorderSide(color: AppColors.adaptiveAccent(ctx)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.casino, size: 18),
                        label: const Text('邀TA开局'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInviteGamePicker(msg);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
