import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import 'create_room_dialog.dart';
import 'join_room_dialog.dart';
import '../room/game_room_lobby_view.dart';
import '../shop/widgets/recharge_dialog.dart';
import '../shop/widgets/vip_center_dialog.dart';
import '../activity/daily_sign_in_dialog.dart';
import '../activity/daily_tasks_dialog.dart';
import '../rank/rank_leaderboard_dialog.dart';
import '../profile/dressing_shop_view.dart';
import '../widgets/avatar_with_frame.dart';
import '../widgets/vip_badge_widget.dart';
import '../commercial/first_recharge_dialog.dart';
import '../commercial/battle_pass_dialog.dart';
import '../commercial/lucky_gacha_wheel_dialog.dart';
import '../commercial/mock_ad_player_dialog.dart';
import '../commercial/bankruptcy_relief_dialog.dart';
import '../commercial/global_blessing_dialog.dart';
import '../widgets/scan_qr_dialog.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../models/game_room_model.dart';
import '../../main.dart';

class PartyHallView extends StatefulWidget {
  const PartyHallView({Key? key}) : super(key: key);

  @override
  State<PartyHallView> createState() => _PartyHallViewState();
}

class _PartyHallViewState extends State<PartyHallView> {
  Map<String, dynamic>? _serverActiveRoom;
  Timer? _activeRoomPollTimer;
  String _selectedCategory = 'all';

  void _showGameRulesModal(BuildContext context, String gameType) {
    final Map<String, Map<String, dynamic>> rulesMap = {
      'liars_dice': {
        'title': '🎲 大话骰 (吹牛) · 官方玩法规则',
        'badge': '酒吧经典 · 2-8人心理博弈',
        'color': const Color(0xFF6366F1),
        'rules': [
          '1️⃣ 【摇盅看点】每局开始每人摇动 5 颗骰子，仅自己可见真实点数。',
          '2️⃣ 【轮流叫点】按座位顺序叫出全场所有玩家骰盅内某一点数的总个数（如“4个3”）。下家叫点必须比上家【数量更多】或【同数量但点数更大】。',
          '3️⃣ 【飞1百搭与报斋】默认未叫过 1 点或未报“斋”时，【1点】可充当任意点数的万能百搭；一旦喊“斋”（纯点数）或叫了 1 点，本轮 1 点不再百搭！',
          '4️⃣ 【开盅抓吹牛】若认为上家叫点超出全场实际总数，直接点击【⚡ 开！】全桌亮盅验点：够数则开盅者输，不够数则上家输！',
        ],
      },
      'take6': {
        'title': '🐂 谁是牛头王 (Take 6!) · 官方玩法规则',
        'badge': '德式策略名作 · 2-10人同台',
        'color': const Color(0xFFD97706),
        'rules': [
          '1️⃣ 【盲选亮牌】牌库共 1~104 号数字牌，每人发 10 张手牌，桌面初始铺设 4 行底牌。每回合所有人同时暗选 1 张牌并亮出。',
          '2️⃣ 【升序接龙】按亮出牌面数字【从小到大】依次放入桌面 4 行中：必须接在【末尾数字比它小、且差值最小】的那一行后面。',
          '3️⃣ 【第6张爆行惩罚】每行最多放 5 张牌！若你的牌成为某行的【第 6 张】，你必须收走该行前 5 张牌作为惩罚，你的牌成为该行新的第 1 张。',
          '4️⃣ 【吃行选最小】若你出的牌比 4 行末尾数字都小，必须任选一行收走全部牌（建议选牛头最少的一行）。10 回合后牛头惩罚最少者夺冠！',
        ],
      },
      'party_wheel': {
        'title': '🎡 聚会大冒险大转盘 · 玩法说明',
        'badge': '酒桌破冰神器 · 零门槛嗨玩',
        'color': const Color(0xFFEC4899),
        'rules': [
          '1️⃣ 【一键旋转】点击转盘中央或底部按钮即可触发物理惯性旋转，指针落定区域即为本轮指令。',
          '2️⃣ 【真心话 & 大冒险】转中【真心话】或【大冒险】将自动从聚会题库抽取精选辛辣提问与互动挑战！',
          '3️⃣ 【自动连转托管】开启右上角🤖【自动连转】后，每隔数秒自动开启下一轮，解放双手带动全场气氛！',
        ],
      },
      'undercover': {
        'title': '🕵️ 谁是卧底 · 官方推理规则',
        'badge': '经典语言推理 · 3-8人局',
        'color': const Color(0xFF10B981),
        'rules': [
          '1️⃣ 【秘密发词】全员获得词语，大多数【平民】拿到同一个词，少数【卧底】拿到高度相似的另一个词（玩家不知自己身份）。',
          '2️⃣ 【轮流描述】按麦序轮流用一句话描述自己的词：既不能过于直白让卧底猜出，也要让队友听出你是同阵营。',
          '3️⃣ 【公决投票】每轮发言结束后全员投票放逐得票最高者。放逐所有卧底则平民获胜；卧底存活到最后则卧底获胜！',
        ],
      },
    };
    final info = rulesMap[gameType] ?? rulesMap['liars_dice']!;
    final color = info['color'] as Color;
    final rules = info['rules'] as List<String>;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info['title'] as String,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(ctx)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                info['badge'] as String,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rules
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.adaptiveTextSecondary(ctx),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _onQuickMatch(context, gameType);
            },
            child: const Text('⚡ 立即速配开局', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoomProvider>().refreshRooms();
        BankruptcyReliefDialog.checkAndShow(context);
        _fetchServerActiveRoom();
        ChatService().syncRecentBroadcasts();
      }
    });
    // 每 5 秒轮询一次活跃房间状态，保证多端退出后立即展示
    _activeRoomPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchServerActiveRoom();
    });
  }

  @override
  void dispose() {
    _activeRoomPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchServerActiveRoom() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final res = await ApiService().getUserActiveRoom(user.id);
      if (mounted) {
        setState(() {
          _serverActiveRoom = res;
        });
      }
    } catch (_) {}
  }

  void _checkRoomConflict(BuildContext context, VoidCallback onContinue) {
    final roomProv = context.read<RoomProvider>();
    final currentRoom = roomProv.currentRoom;
    final activeSession = roomProv.activeSession;
    final hasExisting = currentRoom != null || activeSession != null;

    if (!hasExisting) {
      onContinue();
      return;
    }

    final roomCode = currentRoom?.roomCode ?? activeSession?.roomCode ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.adaptiveCard(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('已有正在进行的房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('您当前已在房间【$roomCode】中！\n每个玩家同时只能进入一个房间。\n\n请选择【重返当前房间】继续游戏，或【强制退出原房间】以进入新房间。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (activeSession != null) {
                roomProv.restoreActiveSession();
                Navigator.push(context, MaterialPageRoute(builder: activeSession.screenBuilder));
              } else if (currentRoom != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: currentRoom)));
              }
            },
            child: const Text('重返当前房间', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final user = context.read<AuthProvider>().user;
              roomProv.leaveRoom(user?.id, roomCode);
              onContinue();
            },
            child: const Text('强制退出原房间'),
          ),
        ],
      ),
    );
  }

  void _onQuickMatch(BuildContext context, String gameType) {
    _checkRoomConflict(context, () {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      final me = GamePlayer(
        id: user.id,
        name: user.nickname,
        avatar: user.avatar,
      );

      GameSoundService().playDiceShake();
      final room = context.read<RoomProvider>().quickMatch(gameType, me);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roomProv = context.watch<RoomProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final games = [
      {
        'type': 'liars_dice',
        'category': 'strategy',
        'title': '大话骰 (吹牛)',
        'subtitle': '3D摇蛊 · 叫点报斋 · 酒桌神仙局',
        'icon': '🎲',
        'tag': '热门爆款',
        'color': const Color(0xFF6366F1),
        'bgGradient': const [Color(0xFF4F46E5), Color(0xFF312E81)],
        'onlineCount': '🔥 9.8w人在线',
        'ante': '底注 100 币',
      },
      {
        'type': 'take6',
        'category': 'strategy',
        'title': '谁是牛头王',
        'subtitle': '策略算牌 · 6排接龙 · 避坑吃牌',
        'icon': '🐂',
        'tag': '策略益智',
        'color': const Color(0xFFF59E0B),
        'bgGradient': const [Color(0xFFD97706), Color(0xFF78350F)],
        'onlineCount': '⭐ 4.5w人在线',
        'ante': '底注 50 币',
      },
      {
        'type': 'party_wheel',
        'category': 'party',
        'title': '聚会大冒险大转盘',
        'subtitle': '物理转盘 · 真心话大冒险 · 破冰嗨玩',
        'icon': '🎡',
        'tag': '喝酒破冰',
        'color': const Color(0xFFEC4899),
        'bgGradient': const [Color(0xFFDB2777), Color(0xFF831843)],
        'onlineCount': '🍻 6.2w人在线',
        'ante': '免门票 · 畅饮局',
      },
      {
        'type': 'undercover',
        'category': 'deduction',
        'title': '谁是卧底',
        'subtitle': '词语推理 · 轮流发言 · 投票抓卧底',
        'icon': '🕵️',
        'tag': '聚会推理',
        'color': const Color(0xFF10B981),
        'bgGradient': const [Color(0xFF059669), Color(0xFF064E3B)],
        'onlineCount': '🧠 3.9w人在线',
        'ante': '底注 100 币',
      },
    ];
    final filteredGames = _selectedCategory == 'all'
        ? games
        : games.where((g) => g['category'] == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 6),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
              ),
            ),
            const Text('聚会桌游大厅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
              size: 21,
            ),
            tooltip: isDark ? '切换为明亮护眼模式' : '切换为夜店暗黑模式',
            onPressed: () {
              PartyGameApp.toggleThemeMode(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF38BDF8), size: 22),
            tooltip: '扫一扫 / 网页扫码登录',
            onPressed: () {
              ScanQrDialog.show(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            tooltip: '加入房间',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const JoinRoomDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 22),
            tooltip: '创建房间',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CreateRoomDialog(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              roomProv.refreshRooms(),
              ChatService().syncRecentBroadcasts(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 活跃正在进行中的对局横幅（支持一键恢复与接管托管）
              if (_serverActiveRoom != null && _serverActiveRoom!['roomCode'] != null) ...[
                _buildOngoingGameBanner(_serverActiveRoom!),
                const SizedBox(height: 12),
              ],
              // 玩家个人资产与快捷卡片（支持商业化财富与段位）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveCard(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.adaptiveBorder(context)),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AvatarWithFrame(
                          avatar: user?.avatar ?? '🦊',
                          avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                          vipLevel: user?.vipLevel ?? 0,
                          radius: 26,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView()));
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user?.nickname ?? '神秘玩家',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: (user?.vipLevel ?? 0) >= 4
                                            ? const Color(0xFFFF2E4D)
                                            : ((user?.vipLevel ?? 0) > 0 ? const Color(0xFFE60012) : AppColors.adaptiveTextPrimary(context)),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // VIP 尊贵图标 (统一仅显示一个 VIP 标识)
                                  InkWell(
                                    onTap: () => showDialog(context: context, builder: (_) => const VipCenterDialog()),
                                    child: VipBadgeWidget(vipLevel: user?.vipLevel ?? 0),
                                  ),
                                  if (user?.isGuest == true) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('游客', style: TextStyle(fontSize: 9, color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              // 段位与胜率（使用 Wrap 保证在任何窄屏手机上均完整显示，彻底告别被右侧资产遮挡）
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => showDialog(context: context, builder: (_) => const RankLeaderboardDialog()),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.primary.withAlpha(60), width: 0.8),
                                      ),
                                      child: Text(
                                        '⚔️ ${user?.rankTier ?? "暂无段位"} · ${user?.rankScore ?? 0}分',
                                        style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.adaptiveElevated(context),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.adaptiveBorder(context), width: 0.8),
                                    ),
                                    child: Text(
                                      '🎯 胜率 ${(user?.winRate ?? 0).toStringAsFixed(0)}%',
                                      style: TextStyle(fontSize: 10.5, color: AppColors.adaptiveTextSecondary(context), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      if (user != null) {
                                        Clipboard.setData(ClipboardData(text: user.cleanId));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('已复制UID: ${user.cleanId}'),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.adaptiveElevated(context),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.adaptiveBorder(context), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'ID: ${user?.cleanId ?? ""}',
                                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(Icons.copy_rounded, size: 10, color: AppColors.textMuted),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 资产展示与充值按钮
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => showDialog(context: context, builder: (_) => const RechargeDialog()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.adaptiveElevated(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.adaptiveBorder(context)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🪙 ', style: TextStyle(fontSize: 11)),
                                    Text(
                                      '${user?.coins ?? 0}',
                                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.add_circle, color: AppColors.accent, size: 13),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => showDialog(context: context, builder: (_) => const RechargeDialog()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.adaptiveElevated(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('💎 ', style: TextStyle(fontSize: 11)),
                                    Text(
                                      '${user?.diamonds ?? 0}',
                                      style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.add_circle, color: AppColors.cyan, size: 13),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 聚会商业街与全服互动核心专区 (超大超显眼入口，让玩家在首页一眼看到商城与全服大喇叭)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.55), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Text('🛍️', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text('聚会商业街 · 全服互动中枢', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Text('进入商城 ', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.bold)),
                                Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFFFDE68A)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // 卡片 1: 聚会装扮商城
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DressingShopView(initialTabIndex: 0))),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  const Text('🛍️', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('装扮商城', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        SizedBox(height: 2),
                                        Text('骰蛊·头像框·横幅', style: TextStyle(color: Colors.white70, fontSize: 9.5), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 卡片 2: 全服大喇叭
                        Expanded(
                          child: InkWell(
                            onTap: () => GlobalBlessingDialog.show(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFBE185D)]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  const Text('📢', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('全服大喇叭', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        SizedBox(height: 2),
                                        Text('跑马灯·火箭·超跑', style: TextStyle(color: Colors.white70, fontSize: 9.5), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 卡片 3: 互动整蛊道具
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DressingShopView(initialTabIndex: 3)),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Text('🎁', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('互动道具', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('鲜花·啤酒·拖鞋·炸弹', style: TextStyle(color: Colors.white70, fontSize: 9), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 卡片 4: 全服祝福盛典
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DressingShopView(initialTabIndex: 4)),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Text('✨', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('祝福盛典', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        Text('梦幻城堡·豪华超跑', style: TextStyle(color: Colors.white70, fontSize: 9), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 腾讯风格运营活动自动轮播横幅 (多活动精彩轮巡)
              const _TencentEventBannerCarousel(),
              const SizedBox(height: 12),

              // 商业化第一功能矩阵 (每日签到 · 福利任务 · 排位天梯 · VIP俱乐部)
              Row(
                children: [
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '每日签到',
                      subtitle: '领7天好礼',
                      icon: '📅',
                      gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
                      onTap: () => showDialog(context: context, builder: (_) => const DailySignInDialog()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '福利任务',
                      subtitle: '领金币钻石',
                      icon: '🎁',
                      gradient: const [Color(0xFF10B981), Color(0xFF047857)],
                      onTap: () => showDialog(context: context, builder: (_) => const DailyTasksDialog()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '排位天梯',
                      subtitle: '上分冲榜',
                      icon: '🏆',
                      gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                      onTap: () => showDialog(context: context, builder: (_) => const RankLeaderboardDialog()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: 'VIP俱乐部',
                      subtitle: '专属特权',
                      icon: '👑',
                      gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                      onTap: () => showDialog(context: context, builder: (_) => const VipCenterDialog()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 商业化第二功能矩阵 (聚会战令 · 幸运夺宝 · 视频福利 · 低保救济)
              Row(
                children: [
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '聚会战令',
                      subtitle: 'S1赛季通行证',
                      icon: '📜',
                      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      onTap: () => BattlePassDialog.show(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '幸运夺宝',
                      subtitle: '天天抽大奖',
                      icon: '🎰',
                      gradient: const [Color(0xFFEC4899), Color(0xFF9D174D)],
                      onTap: () => LuckyGachaWheelDialog.show(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '福利视频',
                      subtitle: '看广告领币',
                      icon: '📺',
                      gradient: const [Color(0xFF06B6D4), Color(0xFF0E7490)],
                      onTap: () {
                        MockAdPlayerDialog.show(
                          context,
                          rewardTitle: '2,000 聚会金币',
                          onRewardEarned: () {
                            context.read<AuthProvider>().awardCoins(2000);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCommercialEntry(
                      context,
                      title: '低保救济',
                      subtitle: '东山再起金',
                      icon: '🛡️',
                      gradient: const [Color(0xFF059669), Color(0xFF064E3B)],
                      onTap: () => BankruptcyReliefDialog.show(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 快速操作条 (加入房间 / 创建房间)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('创建对局房间', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _checkRoomConflict(context, () {
                          showDialog(
                            context: context,
                            builder: (_) => const CreateRoomDialog(),
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.keyboard_outlined, size: 20),
                      label: const Text('输入号码进房', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _checkRoomConflict(context, () {
                          showDialog(
                            context: context,
                            builder: (_) => const JoinRoomDialog(),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 腾讯式微信/QQ 一键组局快捷召集令
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF07C160).withOpacity(0.4), blurRadius: 6),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('💬', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('微信 / QQ 聚会一键开黑令', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                          SizedBox(height: 2),
                          Text('一键生成房间并复制开黑口令，微信好友免输入秒进房', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF07C160),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _checkRoomConflict(context, () {
                          final me = GamePlayer(
                            id: user?.id ?? 'host',
                            name: user?.nickname ?? '房主',
                            avatar: user?.avatar ?? '🦊',
                          );
                          final room = context.read<RoomProvider>().createRoom(
                            roomName: '【开黑】${user?.nickname ?? "我"}的聚会局',
                            gameType: 'liars_dice',
                            hostPlayer: me,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
                          );
                        });
                      },
                      child: const Text('立即召唤', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 游戏玩法矩阵卡片与分类筛选条
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('聚会桌游精选 🎯', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(context))),
                  InkWell(
                    onTap: () => _showGameRulesModal(context, 'take6'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 12, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('玩法宝典', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    {'id': 'all', 'label': '🔥 全部玩法 (4)'},
                    {'id': 'strategy', 'label': '🎲 策略博弈'},
                    {'id': 'party', 'label': '🎡 酒桌破冰'},
                    {'id': 'deduction', 'label': '🕵️ 推理猜词'},
                  ].map((cat) {
                    final isSelected = _selectedCategory == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.adaptiveTextSecondary(context),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.adaptiveCard(context),
                        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.adaptiveBorder(context)),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _selectedCategory = cat['id']!),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredGames.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final g = filteredGames[idx];
                  final gradient = g['bgGradient'] as List<Color>;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (g['color'] as Color).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onQuickMatch(context, g['type'] as String),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(g['icon'] as String, style: const TextStyle(fontSize: 32)),
                                ),
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
                                            g['title'] as String,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            g['tag'] as String,
                                            style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      g['subtitle'] as String,
                                      style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.85)),
                                    ),
                                    const SizedBox(height: 6),
                                    // 腾讯特色底注与在玩热度标签 + 规则速览
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            g['onlineCount'] as String? ?? '🔥 热游',
                                            style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            g['ante'] as String? ?? '免门票',
                                            style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _showGameRulesModal(context, g['type'] as String),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.22),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '📖 规则',
                                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _onQuickMatch(context, g['type'] as String),
                                    child: const Text('⚡ 速配', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () {
                                      _checkRoomConflict(context, () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => CreateRoomDialog(initialGameType: g['type'] as String),
                                        );
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '🏠 创房',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 正在招募中的公共房间
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('正在招募中的房间 📢', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(context))),
                  Row(
                    children: [
                      Text('${roomProv.publicRooms.length} 房在线', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => roomProv.refreshRooms(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.refresh, size: 16, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (roomProv.publicRooms.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.adaptiveCard(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.adaptiveBorder(context)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        '当前暂无正在招募的公共房间',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adaptiveTextPrimary(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击上方【🏠 创建专属房间】或下方玩法【速配开局】即可快速畅玩！',
                        style: TextStyle(fontSize: 12, color: AppColors.adaptiveTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: roomProv.publicRooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final r = roomProv.publicRooms[idx];
                    final isPlaying = r.status == 'PLAYING';
                    final allowSpec = r.allowSpectator;
                    final btnText = isPlaying ? (allowSpec ? '👀 观战' : '进行中') : '加入';
                    final btnColor = isPlaying
                        ? (allowSpec ? const Color(0xFF0284C7) : Colors.grey)
                        : AppColors.primary;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.adaptiveElevated(context),
                          child: Text(
                            r.gameType == 'liars_dice'
                                ? '🎲'
                                : (r.gameType == 'take6'
                                    ? '🐂'
                                    : (r.gameType == 'undercover' ? '🕵️' : '🎡')),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(r.roomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            if (isPlaying)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: allowSpec ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  allowSpec ? '可观战' : '禁观战',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: allowSpec ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('房间号: ${r.roomCode} · ${r.players.length}/${r.maxCapacity}人', style: TextStyle(fontSize: 12, color: AppColors.adaptiveTextSecondary(context))),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnColor,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          onPressed: () {
                            final user = context.read<AuthProvider>().user;
                            final me = user != null
                                ? GamePlayer(id: user.id, name: user.nickname, avatar: user.avatar, isAi: false)
                                : null;
                            if (isPlaying && !allowSpec) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('该房间正在对局中，且房主已关闭观战功能！'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            try {
                              if (me != null) {
                                roomProv.joinRoomByCode(r.roomCode, me);
                              } else {
                                roomProv.setCurrentRoom(r);
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameRoomLobbyView(
                                    room: r,
                                    isSpectator: isPlaying,
                                    isReconnecting: isPlaying,
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
                              );
                            }
                          },
                          child: Text(btnText),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCommercialEntry(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOngoingGameBanner(Map<String, dynamic> active) {
    final roomCode = active['roomCode']?.toString() ?? '';
    final gameType = active['gameType']?.toString() ?? 'take6';
    final isPlaying = active['status'] == 'PLAYING';
    final gTitle = gameType == 'take6' ? '谁是牛头王' : (gameType == 'liars_dice' ? '大话骰吹牛' : '聚会桌游');
    final gIcon = gameType == 'take6' ? '🐂' : (gameType == 'liars_dice' ? '🎲' : '🎮');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(gIcon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPlaying ? '⚡ 托管代打中' : '⏳ 等待准备',
                        style: const TextStyle(color: Color(0xFF78350F), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '房间 #$roomCode',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '【$gTitle】对战进行中，点击立即接管对局！',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEA580C),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => _rejoinActiveGame(roomCode, gameType),
            child: const Text('接管重连 ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  void _rejoinActiveGame(String roomCode, String gameType) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    GameSoundService().playDiceShake();

    final roomProv = context.read<RoomProvider>();
    final me = GamePlayer(id: user.id, name: user.nickname, avatar: user.avatar);
    var room = roomProv.joinRoomByCode(roomCode, me);
    if (room == null) {
      room = GameRoomModel(
        roomCode: roomCode,
        gameType: gameType,
        roomName: '房间 $roomCode',
        hostPlayerId: user.id,
        status: 'PLAYING',
        players: [me],
      );
      roomProv.setCurrentRoom(room);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room!, isReconnecting: true)),
    ).then((_) => _fetchServerActiveRoom());
  }
}

/// 腾讯风格运营活动自动轮播横幅组件 (带圆点指示器与定时平滑滑动)
class _TencentEventBannerCarousel extends StatefulWidget {
  const _TencentEventBannerCarousel();

  @override
  State<_TencentEventBannerCarousel> createState() => _TencentEventBannerCarouselState();
}

class _TencentEventBannerCarouselState extends State<_TencentEventBannerCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {
      'tag': '首充狂欢',
      'tagColor': const Color(0xFFEF4444),
      'icon': '👑',
      'title': '首充 6 元领 888 元豪礼：送限定【紫晶星系】骰蛊 + 66,666 金币！',
      'gradient': const [Color(0xFFB45309), Color(0xFF78350F), Color(0xFF451A03)],
      'action': (BuildContext ctx) => FirstRechargeDialog.show(ctx),
    },
    {
      'tag': '七日盛典',
      'tagColor': const Color(0xFFEC4899),
      'icon': '📅',
      'title': '七天尊享签到：每日登录领大礼，累计7天必得稀有金冠头像框！',
      'gradient': const [Color(0xFF831843), Color(0xFF4C0519), Color(0xFF1E102E)],
      'action': (BuildContext ctx) => showDialog(context: ctx, builder: (_) => const DailySignInDialog()),
    },
    {
      'tag': '天梯荣耀',
      'tagColor': const Color(0xFF6366F1),
      'icon': '🏆',
      'title': '雀圣排位天梯争霸赛：冲刺全服第一，瓜分百万金币大奖！',
      'gradient': const [Color(0xFF312E81), Color(0xFF1E1B4B), Color(0xFF0F172A)],
      'action': (BuildContext ctx) => showDialog(context: ctx, builder: (_) => const RankLeaderboardDialog()),
    },
    {
      'tag': 'S1 战令',
      'tagColor': const Color(0xFF8B5CF6),
      'icon': '📜',
      'title': '聚会战令通行证：完成任务对局升级，解锁绝版全服入场横幅！',
      'gradient': const [Color(0xFF4C1D95), Color(0xFF2E1065), Color(0xFF180828)],
      'action': (BuildContext ctx) => BattlePassDialog.show(ctx),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _banners.length,
            itemBuilder: (ctx, idx) {
              final b = _banners[idx];
              final gradient = b['gradient'] as List<Color>;
              final tagColor = b['tagColor'] as Color;

              return InkWell(
                onTap: () => (b['action'] as Function(BuildContext))(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b['tag'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(b['icon'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b['title'] as String,
                          style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 11.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFFFEF08A), size: 11),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // 轮播圆点指示器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 16 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: active ? Colors.amber : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}
