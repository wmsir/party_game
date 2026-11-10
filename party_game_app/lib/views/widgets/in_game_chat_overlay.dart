import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/sound/game_sound_service.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'vip_badge_widget.dart';

enum InGameChatMode {
  minimized, // 最小化浮动胶囊
  halfScreen, // 半屏抽屉展开
  maximized, // 全屏最大化
}

/// 游戏内多态交互聊天浮层 (支持最小化悬浮胶囊、半屏抽屉与全屏最大化)
class InGameChatOverlay extends StatefulWidget {
  final String roomCode;
  final String myPlayerId;
  final String myPlayerName;
  final String myPlayerAvatar;

  const InGameChatOverlay({
    Key? key,
    required this.roomCode,
    required this.myPlayerId,
    required this.myPlayerName,
    required this.myPlayerAvatar,
  }) : super(key: key);

  @override
  State<InGameChatOverlay> createState() => _InGameChatOverlayState();
}

class _InGameChatOverlayState extends State<InGameChatOverlay> {
  InGameChatMode _mode = InGameChatMode.minimized;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _unreadCount = 0;
  int _lastMsgCount = 0;

  Offset? _pillPosition;

  static const List<String> _quickPhrases = [
    '快点吧，我等到花儿都谢了！',
    '手气这么好，你家里人知道吗？',
    '不要走，决战到天亮！',
    '你太有才了，佩服佩服！',
    '抓你吹牛！',
    '今晚全场的消费由赵公子买单！',
    '运气也是实力的一部分！',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProv = context.read<ChatProvider>();
      chatProv.setCurrentRoomCode(widget.roomCode);
      chatProv.switchChannel('ROOM');
      _lastMsgCount = chatProv.currentMessages.length;
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    try {
      final chatProv = context.read<ChatProvider>();
      chatProv.clearRoomMessages();
      chatProv.switchChannel('WORLD');
      chatProv.setCurrentRoomCode(null);
    } catch (_) {}
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

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _textCtrl.text.trim();
    if (text.isEmpty) return;

    GameSoundService().playCardPlay();
    final authUser = context.read<AuthProvider?>()?.user;
    context.read<ChatProvider>().sendMessage(
          senderId: widget.myPlayerId,
          senderName: widget.myPlayerName,
          senderAvatar: widget.myPlayerAvatar,
          content: text,
          channel: 'ROOM',
          roomCode: widget.roomCode,
          textColor: authUser?.chatTextColor,
          vipLevel: authUser?.vipLevel,
        );

    if (quickText == null) {
      _textCtrl.clear();
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final messages = chatProv.currentMessages;

    // 检查是否有新消息未读
    if (messages.length > _lastMsgCount) {
      if (_mode == InGameChatMode.minimized) {
        _unreadCount += (messages.length - _lastMsgCount);
      } else {
        _scrollToBottom();
      }
      _lastMsgCount = messages.length;
    }

    final latestMsg = messages.isNotEmpty ? messages.last : null;
    final screenSize = MediaQuery.of(context).size;

    if (_mode == InGameChatMode.minimized) {
      return _buildMinimizedPill(latestMsg, screenSize);
    } else if (_mode == InGameChatMode.halfScreen) {
      return _buildHalfScreenDrawer(messages);
    } else {
      return _buildMaximizedOverlay(messages);
    }
  }

  /// 1. 最小化悬浮胶囊：支持自由拖拽，默认停靠右上安全区域，绝不遮挡底部手牌与操作按钮
  Widget _buildMinimizedPill(ChatMessageModel? latestMsg, Size screenSize) {
    // 默认停靠位置：右上侧(避免遮挡底部手牌和主桌面)
    final defaultPos = Offset(screenSize.width - 150, 115.0);
    final pos = _pillPosition ?? defaultPos;

    return Positioned(
      left: pos.dx.clamp(8.0, (screenSize.width - 150.0).clamp(8.0, screenSize.width)),
      top: pos.dy.clamp(60.0, (screenSize.height - 180.0).clamp(60.0, screenSize.height)),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final cur = _pillPosition ?? defaultPos;
            _pillPosition = cur + details.delta;
          });
        },
        onTap: () {
          GameSoundService().playHapticLight();
          setState(() {
            _mode = InGameChatMode.halfScreen;
            _unreadCount = 0;
          });
          _scrollToBottom();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF00F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withOpacity(0.7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator, color: Colors.white38, size: 14),
              const SizedBox(width: 2),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 15)),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 135),
                child: Text(
                  latestMsg != null ? '${latestMsg.senderName}: ${latestMsg.content}' : '房间聊天',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_full_rounded, color: Colors.amber, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. 半屏抽屉展开 (支持点击上半部空白处即时收起，畅通进行出牌)
  Widget _buildHalfScreenDrawer(List<ChatMessageModel> messages) {
    return Positioned.fill(
      child: Stack(
        children: [
          // 点击背景空白区域秒收起，绝不阻碍游戏对战
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _mode = InGameChatMode.minimized);
              },
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF50F172A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 顶栏控制栏
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        const Text('💬 房间开黑互动', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        const Text('(点上方收起)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        const Spacer(),
                        // 最大化全屏
                        IconButton(
                          icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 19),
                          tooltip: '最大化全屏',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            GameSoundService().playHapticLight();
                            setState(() => _mode = InGameChatMode.maximized);
                            _scrollToBottom();
                          },
                        ),
                        const SizedBox(width: 14),
                        // 最小化收起
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
                          tooltip: '最小化收起',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            GameSoundService().playHapticLight();
                            setState(() => _mode = InGameChatMode.minimized);
                          },
                        ),
                      ],
                    ),
                  ),

                  // 消息列表
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text('房间暂无聊天记录，发条消息跟大家打个招呼吧～', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (ctx, idx) => _buildMessageBubble(messages[idx]),
                          ),
                  ),

                  // 快捷短语条
                  _buildQuickPhraseBar(),

                  // 底部发言框
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. 全屏最大化模式
  Widget _buildMaximizedOverlay(List<ChatMessageModel> messages) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF70F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 25, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  // 顶栏控制
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        const Text('💬 房间全屏聊天与对战纪要', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        // 还原半屏
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70, size: 22),
                          tooltip: '还原半屏',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            GameSoundService().playHapticLight();
                            setState(() => _mode = InGameChatMode.halfScreen);
                            _scrollToBottom();
                          },
                        ),
                        const SizedBox(width: 14),
                        // 最小化收起
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          tooltip: '最小化收起',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            GameSoundService().playHapticLight();
                            setState(() => _mode = InGameChatMode.minimized);
                          },
                        ),
                      ],
                    ),
                  ),

                  // 消息大列表
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text('房间暂无消息记录～', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            itemCount: messages.length,
                            itemBuilder: (ctx, idx) => _buildMessageBubble(messages[idx]),
                          ),
                  ),

                  // 快捷短语
                  _buildQuickPhraseBar(),

                  // 发送栏
                  _buildInputBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 单条消息气泡渲染
  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.senderId == widget.myPlayerId;
    final isSystem = msg.type == ChatMessageType.system || msg.senderId == 'SYSTEM';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Text(msg.content, style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 11)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF334155),
              child: Text(msg.senderAvatar.isNotEmpty ? msg.senderAvatar : '🦊', style: const TextStyle(fontSize: 13)),
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
                          VipBadgeWidget(vipLevel: msg.vipLevel, fontSize: 8, isCrown: msg.vipLevel >= 4),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          msg.senderName,
                          style: TextStyle(
                            color: VipBadgeWidget.getNicknameColor(msg.vipLevel, defaultColor: Colors.white54),
                            fontSize: 10,
                            fontWeight: msg.vipLevel > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMe ? Colors.indigoAccent : Colors.white12),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      color: ChatMessageModel.getTextColorFromCode(
                        msg.textColor,
                        defaultColor: isMe ? Colors.white : const Color(0xFFE2E8F0),
                      ),
                      fontSize: 12.5,
                      fontWeight: msg.content.startsWith('📢') || msg.content.startsWith('⚡') ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(widget.myPlayerAvatar.isNotEmpty ? widget.myPlayerAvatar : '🦊', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  /// 经典快捷短语横向滚动条
  Widget _buildQuickPhraseBar() {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickPhrases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final p = _quickPhrases[idx];
          return ActionChip(
            label: Text(p, style: const TextStyle(fontSize: 11, color: Colors.white)),
            backgroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Colors.white24, width: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: () => _sendMessage(p),
          );
        },
      ),
    );
  }

  /// 底部打字输入栏
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: '打字与全房玩家互动...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(54, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _sendMessage(),
            child: const Text('发送', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
