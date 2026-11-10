import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/friend_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/api_service.dart';
import 'direct_chat_view.dart';

class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final myUser = auth.user;
      final friendProv = Provider.of<FriendProvider>(context, listen: false);
      if (myUser != null && myUser.id.isNotEmpty) {
        friendProv.refresh(myUser.id);
      }
      friendProv.loadRecommendedUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 弹出真实好友搜索与添加对话框（支持手机号 / 昵称 / 游戏号）
  void _showSearchAndAddDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myUser = auth.user;

    friendProv.clearSearchResults();

    showDialog(
      context: context,
      builder: (dialogCtx) => Consumer<FriendProvider>(
        builder: (ctx, fp, _) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isSearching = fp.isSearching;
            final searchResults = fp.searchResults;
            final isKeywordEmpty = searchCtrl.text.trim().isEmpty;

          return AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.person_search, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  '查找并添加聚会好友',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '支持输入玩家【手机号】、【昵称】或【游戏号】精准查找：',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '请输入玩家手机号 / 昵称 / 游戏ID',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 16),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      friendProv.clearSearchResults();
                                      setDialogState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.backgroundDark,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (val) async {
                            setDialogState(() {});
                            final kw = val.trim();
                            if (kw.isNotEmpty) {
                              await friendProv.searchUsers(kw);
                              setDialogState(() {});
                            } else {
                              friendProv.clearSearchResults();
                              setDialogState(() {});
                            }
                          },
                          onSubmitted: (val) async {
                            final kw = val.trim();
                            if (kw.isEmpty) return;
                            await friendProv.searchUsers(kw);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSearching
                            ? null
                            : () async {
                                final kw = searchCtrl.text.trim();
                                if (kw.isEmpty) return;
                                await friendProv.searchUsers(kw);
                                setDialogState(() {});
                              },
                        child: isSearching
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('查找', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 搜索结果提示
                  if (!isKeywordEmpty)
                    Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '匹配玩家 (${searchResults.length})：',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  if (!isKeywordEmpty) const SizedBox(height: 8),

                  // 搜索结果展示区
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: Builder(
                      builder: (_) {
                        if (isKeywordEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.person_search_outlined, color: AppColors.textMuted, size: 40),
                                SizedBox(height: 10),
                                Text(
                                  '请输入目标玩家的手机号、昵称或游戏ID\n点击“查找”即可找到该玩家并添加好友',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          );
                        }

                        if (isSearching) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                        }

                        if (searchResults.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.sentiment_dissatisfied, color: AppColors.textMuted, size: 36),
                                SizedBox(height: 8),
                                Text(
                                  '未找到匹配的聚会玩家\n请确认输入的手机号或昵称正确',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                          itemBuilder: (ctx, idx) {
                            final user = searchResults[idx];
                            final isMe = myUser != null && (user.id == myUser.id || (user.phone != null && user.phone == myUser.phone));
                            final isFriend = friendProv.friends.any((f) => f.id == user.id);

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.15),
                                    child: Text(user.avatar, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                user.nickname,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                user.levelTitle,
                                                style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: ${user.id} ${user.phone != null && user.phone!.isNotEmpty ? " · 📱 ${user.phone}" : ""}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 操作按钮
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('本人', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    )
                                  else if (isFriend)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('已是好友', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: const Size(0, 30),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        final res = await friendProv.applyFriend(
                                          fromUserId: myUser?.id ?? 'ME',
                                          targetUser: user,
                                        );
                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(res['message'] ?? '已发起好友申请，等待对方同意！'),
                                            backgroundColor: Colors.teal,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      },
                                      child: const Text('申请添加', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('关闭', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildFriendVipBadge(int vipLevel) {
    if (vipLevel <= 0) return const SizedBox.shrink();
    final isSvip = vipLevel >= 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSvip
              ? [const Color(0xFFFF0033), const Color(0xFFFF6B00)]
              : [const Color(0xFFFF002B), const Color(0xFFD50000)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFE066), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF002B).withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSvip) ...[
            const Text('👑', style: TextStyle(fontSize: 8)),
            const SizedBox(width: 2),
          ],
          Text(
            isSvip ? 'SVIP $vipLevel' : 'VIP $vipLevel',
            style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              val,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendOptions(BuildContext context, FriendModel friend) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar, Name, VIP, UID + Copy
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(friend.avatar, style: const TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    friend.displayNickname,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildFriendVipBadge(friend.vipLevel),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'UID: ${friend.cleanId}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: friend.cleanId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('已复制好友UID: ${friend.cleanId}'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgElevated,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.copy_rounded, size: 10, color: AppColors.primary),
                                        SizedBox(width: 2),
                                        Text('复制', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Remark Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (friend.remark != null && friend.remark!.trim().isNotEmpty)
                              ? '备注: ${friend.remark}'
                              : '备注: 暂无 (点击修改)',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showEditRemarkDialog(context, friend, () {
                          setModalState(() {});
                          setState(() {});
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('修改备注', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildStatCard('排位段位', friend.rankTier, Icons.military_tech, const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _buildStatCard('对战胜率', '${friend.winRate.toStringAsFixed(0)}%', Icons.show_chart, const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildStatCard('总对局', '${friend.totalGames}场', Icons.sports_esports, const Color(0xFF6366F1)),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 16),

                // Actions
                ListTile(
                  leading: const Icon(Icons.chat, color: AppColors.primary),
                  title: const Text('发送私聊消息', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatView(friend: friend)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.celebration, color: AppColors.secondary),
                  title: const Text('投掷整蛊道具', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (user == null) return;
                    _showThrowPicker(context, friend);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditRemarkDialog(BuildContext context, FriendModel friend, VoidCallback onUpdated) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    final ctrl = TextEditingController(text: friend.remark ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.drive_file_rename_outline, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('修改好友备注', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: '请输入新备注名 (留空可清空备注)',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.backgroundDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRemark = ctrl.text.trim();
              final friendProv = Provider.of<FriendProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.maybeOf(context);
              final res = await ApiService().updateFriendRemark(
                userId: user.id,
                friendId: friend.id,
                remark: newRemark,
              );
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
              if (res['code'] == 0 || res['code'] == 200) {
                friend.remark = newRemark;
                onUpdated();
                friendProv.refresh(user.id);
                messenger?.showSnackBar(
                  const SnackBar(content: Text('✅ 好友备注修改成功！'), behavior: SnackBarBehavior.floating),
                );
              } else {
                messenger?.showSnackBar(
                  SnackBar(content: Text(res['message']?.toString() ?? '修改失败'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确定保存', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThrowPicker(BuildContext context, FriendModel friend) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('向【${friend.nickname}】投掷互动道具：', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ChatService.throwItems.map((item) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      chat.throwItem(
                        senderId: user.id,
                        senderName: user.nickname,
                        senderAvatar: user.avatar,
                        targetPlayerId: friend.id,
                        targetPlayerName: friend.nickname,
                        itemType: item['type']!,
                        itemEmoji: item['emoji']!,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已向 ${friend.nickname} 投掷了 ${item['name']}！')),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(item['emoji']!, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(item['name']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${item['cost']}金币', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendProv = Provider.of<FriendProvider>(context);
    final friends = friendProv.friends;
    final requests = friendProv.pendingRequests;
    final reqCount = friendProv.pendingRequestsCount;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0.5,
        title: const Text('聚会好友', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showSearchAndAddDialog(context),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('添加好友', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(text: '我的好友 (${friends.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('好友申请'),
                  if (reqCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$reqCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 我的好友列表
          _buildFriendsList(context, friends),

          // Tab 2: 好友申请待处理列表
          _buildRequestsList(context, requests),
        ],
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, List<FriendModel> friends) {
    return Column(
      children: [
        // 顶部高亮真实好友/玩家搜索栏
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: InkWell(
            onTap: () => _showSearchAndAddDialog(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '🔍 输入手机号 / 昵称 / 游戏ID 搜索真实玩家...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('查找添加', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 好友列表内容区域
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              if (auth.user != null) {
                await Provider.of<FriendProvider>(context, listen: false).refresh(auth.user!.id);
              }
            },
            child: friends.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('暂无好友，快去搜索添加志同道合的牌友吧！', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showSearchAndAddDialog(context),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('查找推荐好友'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: friends.length,
                    itemBuilder: (ctx, idx) {
          final friend = friends[idx];
          return Card(
            elevation: 0.8,
            margin: const EdgeInsets.only(bottom: 8),
            color: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border, width: 0.8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: Text(friend.avatar, style: const TextStyle(fontSize: 22)),
                  ),
                  if (friend.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  if (friend.unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '${friend.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      friend.displayNickname,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildFriendVipBadge(friend.vipLevel),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      friend.levelTitle,
                      style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                friend.lastMessage.isNotEmpty ? friend.lastMessage : 'UID: ${friend.cleanId} · ${friend.rankTier}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: friend.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: friend.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (friend.unreadCount > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${friend.unreadCount}条未读',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 20),
                    tooltip: '发消息',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatView(friend: friend)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                    tooltip: '更多',
                    onPressed: () => _showFriendOptions(context, friend),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatView(friend: friend)));
              },
            ),
          );
        },
      ),
    ),
  ),
],
);
}

  Widget _buildRequestsList(BuildContext context, List<FriendRequestModel> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('暂无待处理的好友申请', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    final friendProv = Provider.of<FriendProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (ctx, idx) {
        final req = requests[idx];
        return Card(
          elevation: 0.8,
          margin: const EdgeInsets.only(bottom: 10),
          color: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: Text(req.avatar, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            req.nickname,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              req.levelTitle,
                              style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '游戏号: ${req.fromUserId} · 申请添加您为好友',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // 拒绝与同意操作
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await friendProv.respondRequest(
                          requestId: req.id,
                          accept: false,
                          myUserId: auth.user?.id ?? 'ME',
                        );
                        messenger.showSnackBar(
                          const SnackBar(content: Text('已拒绝该申请')),
                        );
                      },
                      child: const Text('拒绝', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final res = await friendProv.respondRequest(
                          requestId: req.id,
                          accept: true,
                          myUserId: auth.user?.id ?? 'ME',
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? '已同意好友申请！正式成为好友！'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      child: const Text('同意', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
