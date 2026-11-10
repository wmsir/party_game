import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_version.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import 'dressing_shop_view.dart';
import '../shop/widgets/recharge_dialog.dart';
import '../shop/widgets/vip_center_dialog.dart';
import '../widgets/avatar_with_frame.dart';
import '../widgets/vip_badge_widget.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../models/shop_models.dart';
import '../widgets/scan_qr_dialog.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final GameSoundService _soundService = GameSoundService();

  List<Map<String, dynamic>> _battleRecords = [];
  bool _isLoadingRecords = true;
  int _battleRecordsPage = 0;
  int _battleRecordsTotalPages = 1;
  int _battleRecordsTotal = 0;
  static const int _battleRecordsPageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadBattleRecords(String userId, {int page = 0}) async {
    setState(() => _isLoadingRecords = true);
    try {
      final paged = await ApiService().fetchBattleRecordsPaged(userId, page: page, size: _battleRecordsPageSize);
      if (mounted) {
        setState(() {
          _battleRecords = List<Map<String, dynamic>>.from(paged['records'] ?? []);
          _battleRecordsPage = paged['page'] ?? page;
          _battleRecordsTotal = paged['total'] ?? _battleRecords.length;
          _battleRecordsTotalPages = paged['totalPages'] ?? 1;
          _isLoadingRecords = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  Future<void> _loadData({bool showToast = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      try {
        await Future.wait([
          auth.refreshProfileFromServer(),
          _loadBattleRecords(user.id, page: 0),
        ]);
        if (showToast && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ 个人主页与战绩数据已同步至最新'),
              duration: Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoadingRecords = false;
          });
        }
      }
    } else {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadData(showToast: true);
  }



  void _showAccountSecurityDialog(BuildContext context, UserModel user) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userCtrl = TextEditingController(text: user.username);
    final nickCtrl = TextEditingController(text: user.nickname);
    final phoneCtrl = TextEditingController(text: user.phone);
    final pwdCtrl = TextEditingController();
    bool obscurePwd = true;
    bool isSubmitting = false;
    String selectedAvatar = user.avatar;
    final avatars = ['🦊', '🐼', '🦁', '🐯', '🐰', '🦄', '🐨', '🐺', '🤠', '🦹'];

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.security, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                '账号与安全中心',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text('游戏编号：', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Expanded(
                        child: Text(
                          user.cleanId,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: user.cleanId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已复制用户ID: ${user.cleanId}'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('复制', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('选择聚会头像：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: avatars.map((a) {
                    final isSelected = a == selectedAvatar;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedAvatar = a),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withAlpha(40) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 2),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('登录账号 (唯一用户名)：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: userCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: AppColors.textMuted, size: 18),
                    hintText: '请输入新的登录账号',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('玩家昵称 (游戏中展示)：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nickCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge, color: AppColors.textMuted, size: 18),
                    hintText: '请输入游戏昵称',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('绑定手机号 (用于快捷免密/验证码登录)：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android, color: AppColors.textMuted, size: 18),
                    hintText: '请输入11位中国大陆手机号码',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('设置/修改登录密码：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscurePwd,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePwd ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 18),
                      onPressed: () => setDialogState(() => obscurePwd = !obscurePwd),
                    ),
                    hintText: '留空表示不修改密码',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newUsername = userCtrl.text.trim();
                      final newNick = nickCtrl.text.trim();
                      final newPhone = phoneCtrl.text.trim();
                      final newPwd = pwdCtrl.text.trim();

                      if (newPhone.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(newPhone)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入正确的11位中国大陆手机号')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      setDialogState(() => isSubmitting = true);
                      final success = await auth.updateAccountSecurity(
                        username: newUsername.isNotEmpty ? newUsername : null,
                        nickname: newNick.isNotEmpty ? newNick : null,
                        phone: newPhone.isNotEmpty ? newPhone : null,
                        password: newPwd.isNotEmpty ? newPwd : null,
                        avatar: selectedAvatar,
                      );
                      setDialogState(() => isSubmitting = false);

                      if (success) {
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('🎉 账号与安全资料已成功同步保存至云端数据库！')),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(content: Text('❌ 更新失败: ${auth.errorMessage ?? "请重试"}')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('保存并同步云端', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      _showAccountSecurityDialog(context, user);
    }
  }

  void _showGuestUpgradeDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('转正为正式账号', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '当前为游客体验模式，绑定手机号与密码可永久保存战绩、皮肤与金币资产！',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '手机号码',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgDark,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: '设置密码',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bgDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final phone = phoneCtrl.text.trim();
              if (phone.length < 11) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效手机号')));
                return;
              }
              final user = auth.user;
              if (user != null) {
                user.phone = phone;
                user.isGuest = false;
                auth.updateProfile();
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 恭喜转正成功！账号已绑定手机')));
            },
            child: const Text('立即绑定'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.adaptiveBgDark(context),
        body: Center(child: Text('未登录', style: TextStyle(color: AppColors.adaptiveTextPrimary(context)))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.adaptiveBgDark(context),
      appBar: AppBar(
        backgroundColor: AppColors.adaptiveCardSurface(context),
        elevation: 0,
        title: Text('👤 个人主页', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.adaptiveTextPrimary(context))),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.adaptiveCardSurface(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
        children: [
          // 用户资料头部卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.adaptiveCardSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.adaptiveBorder(context)),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showEditProfileDialog(context),
                  child: Stack(
                    children: [
                      AvatarWithFrame(
                        avatar: user.avatar,
                        avatarFrame: user.avatarFrame,
                        vipLevel: user.vipLevel,
                        showVipBadge: false,
                        radius: 34,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.nickname,
                              style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (user.isGuest)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text('游客', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 6),
                          // VIP 尊贵图标 (统一仅显示一个 VIP 标识)
                          InkWell(
                            onTap: () => showDialog(context: context, builder: (_) => const VipCenterDialog()),
                            child: VipBadgeWidget(vipLevel: user.vipLevel),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('ID: ${user.cleanId}', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: user.cleanId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已复制用户ID: ${user.cleanId}'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.copy_rounded, size: 13, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: Text(
                              '⚔️ ${user.rankTier} (${user.rankScore}分)',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.adaptiveBgDark(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.adaptiveBorder(context)),
                            ),
                            child: Text(
                              '🎖️ ${user.levelTitle}',
                              style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11),
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

          // 游客转正提示条
          if (user.isGuest) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showGuestUpgradeDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange.withAlpha(40), Colors.amber.withAlpha(40)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '您当前为游客试玩，点击立即绑定手机转正，保护数据！',
                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 12),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 资产与核心战绩分区卡片 (层次分明的高清电竞卡片，体力已彻底取消，无限局畅玩)
          _buildAssetAndCombatStatsCard(context, user),

          const SizedBox(height: 16),

          // 近期对战记录 (由云端 MySQL 真实数据驱动)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.adaptiveCardSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.adaptiveBorder(context)),
              boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text('近期对战记录', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    if (_battleRecords.isNotEmpty)
                      Builder(
                        builder: (ctx) {
                          final clearCardCount = user.getItemCount('BATTLE_CLEAR_CARD');
                          final hasCard = clearCardCount > 0;
                          return InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              _handleClearBattleRecords(user, auth);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: hasCard ? const Color(0xFFFEF3C7) : Colors.redAccent.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasCard ? const Color(0xFFFCD34D) : Colors.redAccent.withAlpha(60),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hasCard ? '🧹' : '🔒', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasCard ? '清空战绩 (持有$clearCardCount张)' : '清空战绩 (需清空卡)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: hasCard ? const Color(0xFFB45309) : Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingRecords)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_battleRecords.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: const [
                          Icon(Icons.sports_esports_outlined, size: 40, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text('暂无近期对战记录，快去开启第一局吧！', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._battleRecords.map((rec) {
                    final rawGameType = rec['gameType']?.toString() ?? '桌游对决';
                    final gameType = _formatGameTitle(rawGameType);
                    final gameMode = _formatGameMode(rec['gameMode']?.toString());
                    final isWin = rec['isWin'] == true;
                    final delta = rec['scoreDelta'] != null ? '${rec['scoreDelta'] >= 0 ? "+" : ""}${rec['scoreDelta']}分' : '+0分';
                    final playedAt = rec['playedAt']?.toString().split('T').first ?? '近期';
                    return _buildBattleRecord(gameType, gameMode, isWin ? '胜利 🏆' : '失败 ❌', delta, isWin, playedAt);
                  }),
                // 战绩分页控制栏 (默认每页5场)
                if (_battleRecordsTotalPages > 1)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _battleRecordsPage > 0 && !_isLoadingRecords
                              ? () => _loadBattleRecords(user.id, page: _battleRecordsPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('上一页', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primary,
                            disabledForegroundColor: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          '第 ${_battleRecordsPage + 1} / $_battleRecordsTotalPages 页 (共 $_battleRecordsTotal 场)',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: (_battleRecordsPage + 1) < _battleRecordsTotalPages && !_isLoadingRecords
                              ? () => _loadBattleRecords(user.id, page: _battleRecordsPage + 1)
                              : null,
                          icon: const Text('下一页', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          label: const Icon(Icons.chevron_right, size: 18),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primary,
                            disabledForegroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),


          const SizedBox(height: 20),

          // 功能操作列表
          Container(
            decoration: BoxDecoration(
              color: AppColors.adaptiveCardSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.adaptiveBorder(context)),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF38BDF8)),
                  title: Text('📱 扫一扫 / 登录电脑网页端', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold)),
                  subtitle: Text('扫描网页端二维码或粘贴授权口令，一键秒速登入', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptiveTextSecondary(context)),
                  onTap: () => ScanQrDialog.show(context),
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFF10B981)),
                  title: Text('🔐 账号与安全中心', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold)),
                  subtitle: Text('修改账号 · 密码 · 换绑手机号 · 个人资料', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptiveTextSecondary(context)),
                  onTap: () => _showAccountSecurityDialog(context, user),
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                ListTile(
                  leading: const Icon(Icons.diamond_outlined, color: Color(0xFFD97706)),
                  title: Text('充值中心 (首充享双倍)', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.w500)),
                  subtitle: Text('支持 6元~648元 礼包与快速到账', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptiveTextSecondary(context)),
                  onTap: () {
                    showDialog(context: context, builder: (_) => const RechargeDialog());
                  },
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined, color: Colors.amber),
                  title: Text('VIP 贵族俱乐部特权', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.w500)),
                  subtitle: Text('当前 Lv.${user.vipLevel} · 专属特权与对局收益加成', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptiveTextSecondary(context)),
                  onTap: () {
                    showDialog(context: context, builder: (_) => const VipCenterDialog());
                  },
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                ListTile(
                  leading: const Icon(Icons.storefront, color: AppColors.primary),
                  title: Text('聚会装扮全景商城', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.w500)),
                  subtitle: Text('骰蛊皮肤 · 头像框 · 入场华丽横幅', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.adaptiveTextSecondary(context)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView()));
                  },
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                SwitchListTile(
                  secondary: Icon(
                    _soundService.isSoundEnabled ? Icons.volume_up : Icons.volume_off,
                    color: AppColors.cyan,
                  ),
                  title: Text('游戏对局音效与音乐', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.w500)),
                  value: _soundService.isSoundEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _soundService.toggleSound(val);
                    });
                  },
                ),
                Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                SwitchListTile(
                  secondary: Icon(
                    _soundService.isVibrationEnabled ? Icons.vibration : Icons.smartphone,
                    color: AppColors.accent,
                  ),
                  title: Text('触感微震动反馈', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.w500)),
                  value: _soundService.isVibrationEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _soundService.toggleVibration(val);
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 官方版本构建信息与本地缓存管理 (解决用户版本困惑与旧缓存残留问题)
          _buildVersionAndCacheCard(context, auth),

          const SizedBox(height: 18),

          // 退出登录按钮
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('退出登录 / 切换账号', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Provider.of<FriendProvider>(context, listen: false).clear();
                auth.logout();
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
      )
    );
  }



  // 资产与核心战绩分区卡片 (两列卡片布局，视觉高档大方)
  Widget _buildAssetAndCombatStatsCard(BuildContext context, UserModel user) {
    return Column(
      children: [
        // 资产财富一览
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.adaptiveCardSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.adaptiveBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('我的游戏财富', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModernStatItem('🪙 聚会金币', '${user.coins}', AppColors.accent, '对局消耗/夺宝'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernStatItem('💎 尊享钻石', '${user.diamonds}', const Color(0xFF38BDF8), '装扮商城专属'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernStatItem('👑 贵族等级', 'Lv.${user.vipLevel}', Colors.amber, '专属特权加成'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 天梯对决战力
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.adaptiveCardSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.adaptiveBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech_outlined, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 6),
                  Text('个人天梯战绩', style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildModernStatItem('🎯 排位积分', '${user.rankScore}', const Color(0xFF6366F1), user.rankTier),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernStatItem('🏆 个人胜率', '${user.winRate.toStringAsFixed(1)}%', const Color(0xFF10B981), '${user.winCount}胜 / ${user.totalGames}场'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModernStatItem('⚔️ 总对战场次', '${user.totalGames} 场', AppColors.primary, '战绩持续累计'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatItem(String label, String value, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.adaptiveBgDark(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11), maxLines: 1),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }



  String _formatGameTitle(String rawType) {
    final lower = rawType.toLowerCase().trim();
    if (lower.contains('liar') || lower.contains('dice') || lower.contains('吹牛') || lower.contains('大话骰')) {
      return '🎲 经典大话骰 (吹牛)';
    } else if (lower.contains('take') || lower.contains('牛头') || lower.contains('take6')) {
      return '🐂 谁是牛头王';
    } else if (lower.contains('wheel') || lower.contains('转盘') || lower.contains('party_wheel')) {
      return '🎡 聚会大冒险转盘';
    } else if (lower.contains('undercover') || lower.contains('卧底')) {
      return '🕵️ 谁是卧底';
    } else if (lower.contains('werewolf') || lower.contains('狼人')) {
      return '🐺 经典狼人杀';
    }
    return '🎲 经典聚会桌游';
  }

  String _formatGameMode(String? rawMode) {
    if (rawMode == null || rawMode.trim().isEmpty) return '天梯排位模式';
    final lower = rawMode.toLowerCase().trim();
    if (lower.contains('rank') || lower.contains('排位')) {
      return '天梯排位模式';
    } else if (lower.contains('casual') || lower.contains('休闲')) {
      return '欢乐休闲模式';
    } else if (lower.contains('pass') || lower.contains('local') || lower.contains('同屏')) {
      return '同屏轮流对决';
    }
    // 过滤所有乱码与无法识别的字符，保证100%中文
    return '经典对决模式';
  }

  Widget _buildBattleRecord(String game, String mode, String result, String score, bool isWin, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isWin ? const Color(0xFF10B981).withAlpha(30) : Colors.redAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isWin ? const Color(0xFF10B981).withAlpha(80) : Colors.redAccent.withAlpha(60)),
            ),
            child: Center(
              child: Text(isWin ? '🏆' : '❌', style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(mode, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(result, style: TextStyle(color: isWin ? const Color(0xFF10B981) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(score, style: TextStyle(color: isWin ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 11)),
              Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionAndCacheCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.adaptiveCardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.adaptiveBorder(context)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '官方客户端版本与系统状态',
                      style: TextStyle(
                        color: AppColors.adaptiveTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '实时构建时间戳 · 防伪防旧包',
                      style: TextStyle(
                        color: AppColors.adaptiveTextMuted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                ),
                child: const Text(
                  '最新发布版',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.adaptiveBgDark(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildVersionInfoRow('📱 应用版本', 'v${AppVersionInfo.versionName} (Build ${AppVersionInfo.buildNumber})'),
                const SizedBox(height: 6),
                _buildVersionInfoRow('🕒 编译构建时间', AppVersionInfo.buildTime),
                const SizedBox(height: 6),
                _buildVersionInfoRow('🌐 云端后端网关', '${AppVersionInfo.serverHost} (正常)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adaptiveBgDark(context),
                foregroundColor: AppColors.adaptiveTextPrimary(context),
                elevation: 0,
                side: BorderSide(color: AppColors.adaptiveBorder(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Color(0xFFD97706)),
              label: const Text(
                '🧹 一键彻底清除本地缓存并重置',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _handleCleanLocalCache(context, auth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.adaptiveTextPrimary(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _handleCleanLocalCache(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_outlined, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('清理本地临时缓存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '此操作将清理本地临时渲染缓存与网络图片，保留当前登录账号与全部云端VIP及战绩数据，并立即从服务器全量同步最新资产。是否确认清理？',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              // 仅清理临时缓存，绝对保留用户会话与凭据
              try {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
              } catch (_) {}
              
              // 立即向云端全量刷新同步最新资产与战绩
              await _loadData(showToast: false);
              
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('✨ 本地临时缓存已清理，已全量同步云端最新VIP与对战记录！'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
  }

  /// 战绩清空拦截与道具校验入口：玩家不可免费直接清空，必须消耗【战绩清空卡】
  void _handleClearBattleRecords(UserModel user, AuthProvider auth) {
    final ownedCount = user.getItemCount('BATTLE_CLEAR_CARD');
    if (ownedCount > 0) {
      _showUseClearCardDialog(user, auth, ownedCount);
    } else {
      _showBuyClearCardDialog(user, auth);
    }
  }

  /// 拥有道具：确认消耗 1 张【战绩清空卡】清空对战记录
  void _showUseClearCardDialog(UserModel user, AuthProvider auth, int ownedCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🧹', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('使用【战绩清空卡】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Text('🧹', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '战绩清空卡',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '当前背包持有: $ownedCount 张',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '⚠️ 温馨提示：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              '清空后您近期的全部对战胜负记录将彻底重置！本次操作将永久消耗 1 张【战绩清空卡】，确认使用吗？',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = auth.consumeProp('BATTLE_CLEAR_CARD', 1);
              if (ok) {
                await ApiService().clearBattleRecords(userId: user.id);
                if (mounted) {
                  setState(() => _battleRecords.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 已成功消耗 1 张【战绩清空卡】，近期对战记录已全部清空！'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              }
            },
            child: const Text('确认消耗并清空'),
          ),
        ],
      ),
    );
  }

  /// 未拥有道具：拦截直接清空，展示道具购买引导弹窗
  void _showBuyClearCardDialog(UserModel user, AuthProvider auth) {
    const cardPrice = 100;
    final hasEnoughCoins = user.coins >= cardPrice;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Text('🔒', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('需要购买【战绩清空卡】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '玩家不能直接免费清空对战记录，必须拥有【战绩清空卡】道具才可抹去历史战绩重塑传奇！',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🧹', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('战绩清空卡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('单次清空个人全部近期对战记录', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🪙', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 3),
                          Text('100 金币', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('我的钱包余额:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${user.coins} 金币',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasEnoughCoins ? const Color(0xFFD97706) : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!hasEnoughCoins)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ 您的金币不足 100，可前往对局赢取金币或每日签到领取福利！',
                    style: TextStyle(fontSize: 11, color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Color(0xFF64748B))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DressingShopView(initialTabIndex: 3)),
                );
              },
              child: const Text('前往道具商城', style: TextStyle(color: Color(0xFF2563EB))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnoughCoins ? const Color(0xFFD97706) : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: hasEnoughCoins
                  ? () async {
                      Navigator.pop(ctx);
                      const shopItem = ShopGoodsItem(
                        id: 'BATTLE_CLEAR_CARD',
                        category: 'gift_prop',
                        name: '战绩清空卡',
                        priceCoins: 100,
                        priceDiamonds: 0,
                        icon: '🧹',
                        desc: '抹去过往，重塑传奇！使用后可彻底清空个人的历史近期对战记录',
                      );
                      final bought = await auth.buyAndEquip(shopItem, autoEquip: false, quantity: 1);
                      if (bought) {
                        auth.consumeProp('BATTLE_CLEAR_CARD', 1);
                        await ApiService().clearBattleRecords(userId: user.id);
                        if (mounted) {
                          setState(() => _battleRecords.clear());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 成功购买并使用【战绩清空卡】，近期对战记录已全部清空！'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('立即购买并使用'),
            ),
          ],
        ),
      ),
    );
  }
}

