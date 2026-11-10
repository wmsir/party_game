import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../models/game_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';

/// 腾讯式极速组局开黑分享与召集弹窗 (支持微信/QQ口令 + 手机扫码/免下载网页开玩)
class TencentInviteDialog extends StatefulWidget {
  final GameRoomModel room;
  final String gameTitle;

  const TencentInviteDialog({
    super.key,
    required this.room,
    required this.gameTitle,
  });

  static void show(BuildContext context, {required GameRoomModel room, required String gameTitle}) {
    showDialog(
      context: context,
      builder: (_) => TencentInviteDialog(room: room, gameTitle: gameTitle),
    );
  }

  @override
  State<TencentInviteDialog> createState() => _TencentInviteDialogState();
}

class _TencentInviteDialogState extends State<TencentInviteDialog> {
  final Set<String> _invitedFriendIds = {};
  int _currentTab = 0; // 0: 手机扫码/免装网页开玩, 1: 口令召集/好友列表

  String get _webPlayUrl => 'http://39.97.158.22/party-game/play?roomId=${widget.room.roomCode}&gameType=${widget.room.gameType}';

  String _generateShareText(String hostName) {
    return '【聚会桌游吧】🎮 房主「$hostName」正在《${widget.gameTitle}》房间【${widget.room.roomCode}】等待你的加入，三缺一速来开黑！复制本段口令打开APP即可秒进房 🎲';
  }

  String _generateWebShareText(String hostName) {
    return '【聚会桌游吧】🎮 房主「$hostName」邀请你加入《${widget.gameTitle}》房间【${widget.room.roomCode}】！手机浏览器直接免安装打开玩：$_webPlayUrl （进房需输入游戏昵称与手机号验证码）🎲';
  }

  void _copyWebShareLink(BuildContext context, String hostName) {
    GameSoundService().playHapticMedium();
    final text = _generateWebShareText(hostName);
    Clipboard.setData(ClipboardData(text: text));
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      user.coins += 200;
      auth.saveUser(user);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 已复制网页免安装开黑链接！好友在微信打开秒玩，恭喜获得分享裂变奖励：+200 金币！'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyShareCode(BuildContext context, String hostName) {
    GameSoundService().playHapticMedium();
    final text = _generateShareText(hostName);
    Clipboard.setData(ClipboardData(text: text));
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      user.coins += 200;
      auth.saveUser(user);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 已复制微信/QQ开黑口令！恭喜获得分享开黑奖励：+200 金币！速去召唤桌友吧～'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyRoomCodeOnly(BuildContext context) {
    GameSoundService().playHapticLight();
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制房间号【${widget.room.roomCode}】'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final friendProv = context.watch<FriendProvider>();
    final hostName = auth.user?.nickname ?? '桌游老手';
    final friends = friendProv.friends;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部横幅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Text('👥 ', style: TextStyle(fontSize: 20)),
                      Text(
                        '召唤微信/QQ好友开黑',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 房间名片卡
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🏠', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.room.roomName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.gameTitle} · 席位: ${widget.room.players.length}/${widget.room.maxCapacity}人',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // 房间号徽章
                        InkWell(
                          onTap: () => _copyRoomCodeOnly(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber, width: 1),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('房号', style: TextStyle(color: Colors.amber, fontSize: 9)),
                                Text(
                                  widget.room.roomCode,
                                  style: const TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tab 切换控制器: 📱 扫码免装网页开玩 vs 💬 口令/好友召集
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              GameSoundService().playHapticLight();
                              setState(() => _currentTab = 0);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _currentTab == 0 ? const Color(0xFF6366F1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '📱 扫码免装网页玩',
                                    style: TextStyle(
                                      color: _currentTab == 0 ? Colors.white : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              GameSoundService().playHapticLight();
                              setState(() => _currentTab = 1);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _currentTab == 1 ? const Color(0xFF07C160) : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '💬 微信口令/好友',
                                    style: TextStyle(
                                      color: _currentTab == 1 ? Colors.white : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_currentTab == 0) ...[
                    // ===== Tab 0: 手机扫码免下载开玩 =====
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _webPlayUrl,
                              version: QrVersions.auto,
                              size: 155,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1E1B4B),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '📱 手机微信/相机扫码，免安装打开网页直接玩！',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '入房需输入游戏昵称、手机号及图形验证码防作弊',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // 一键复制网页开黑链接按钮
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.link, size: 18),
                              label: const Text('复制免安装网页开黑链接', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () => _copyWebShareLink(context, hostName),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ===== Tab 1: 腾讯经典一键微信/QQ口令 + 在线好友 =====
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF07C160), // 微信经典绿
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('复制微信/QQ开黑邀请口令', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () => _copyShareCode(context, hostName),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 好友直接邀请板块
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '在线好友快速召集',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '共 ${friends.length} 位好友',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: friends.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: const Text('暂无游戏好友，可先切换到扫码或复制口令发给微信好友～', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: friends.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (ctx, idx) {
                                final f = friends[idx];
                                final isInvited = _invitedFriendIds.contains(f.id);
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.bgElevated,
                                    child: Text(f.avatar.isNotEmpty ? f.avatar : '🦊', style: const TextStyle(fontSize: 16)),
                                  ),
                                  title: Text(
                                    f.nickname,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(f.levelTitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isInvited ? Colors.grey.shade700 : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: isInvited
                                        ? null
                                        : () {
                                            friendProv.sendDirectMessage(
                                              f.id,
                                              '老铁速来！我正在《${widget.gameTitle}》房间【${widget.room.roomCode}】等待开黑！',
                                              inviteRoomCode: widget.room.roomCode,
                                            );
                                            setState(() => _invitedFriendIds.add(f.id));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('已向好友【${f.nickname}】发送开黑邀请！')),
                                            );
                                          },
                                    child: Text(isInvited ? '已发送' : '一键召集', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
