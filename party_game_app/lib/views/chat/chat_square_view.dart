import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/chat_message_model.dart';
import '../../models/friend_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
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
  bool _showEmojiPicker = false;
  bool _showPhrasesPicker = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        title: const Text('💬 聚会交流广场', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.amber, size: 24),
            tooltip: '全服大喇叭',
            onPressed: () => GlobalBlessingDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 22),
            tooltip: '装扮商城',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView()));
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: '🌐 世界频道'),
            Tab(text: '📍 同城频道'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 顶端公约提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.primary.withAlpha(20),
            child: const Row(
              children: [
                Icon(Icons.campaign, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '公约：提倡文明友好互动，点击玩家头像可加好友或发起切磋！',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 消息流列表
          Expanded(
            child: ListView.builder(
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
    );
  }

  Widget _buildSystemBanner(String content) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          content,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withAlpha(120), width: 1),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg.itemEmoji ?? '💥', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              '${msg.senderName} 向 ${msg.targetPlayerName} ${msg.content}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessageItem(ChatMessageModel msg, bool isMe) {
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
                backgroundColor: AppColors.cardSurface,
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
                        Text(
                          msg.senderName,
                          style: TextStyle(
                            color: VipBadgeWidget.getNicknameColor(msg.vipLevel, defaultColor: AppColors.textSecondary),
                            fontSize: 11,
                            fontWeight: msg.vipLevel > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14).copyWith(
                      bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                      bottomLeft: !isMe ? Radius.zero : const Radius.circular(14),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                            defaultColor: isMe ? Colors.white : AppColors.textPrimary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 常用语按钮
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: _showPhrasesPicker ? AppColors.primary : AppColors.textSecondary,
              ),
              onPressed: () {
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
                color: _showEmojiPicker ? AppColors.primary : AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  if (_showEmojiPicker) _showPhrasesPicker = false;
                });
              },
            ),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '说点好玩的...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  filled: true,
                  fillColor: AppColors.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.border)),
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
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: ChatService.presetPhrases.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, idx) {
          final phrase = ChatService.presetPhrases[idx];
          return ListTile(
            dense: true,
            title: Text(phrase, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            trailing: const Icon(Icons.send_rounded, size: 16, color: AppColors.primary),
            onTap: () => _handleSend(phrase),
          );
        },
      ),
    );
  }

  void _showUserActionDialog(ChatMessageModel msg) {
    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: Text(msg.senderAvatar, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(height: 10),
                Text(
                  msg.senderName,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('用户ID: ${msg.senderId}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add),
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.casino),
                      label: const Text('邀TA开局'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已发送房间对决邀请！')),
                        );
                      },
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
