import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RankLeaderboardDialog extends StatefulWidget {
  const RankLeaderboardDialog({super.key});

  @override
  State<RankLeaderboardDialog> createState() => _RankLeaderboardDialogState();
}

class _RankLeaderboardDialogState extends State<RankLeaderboardDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LeaderboardItem> _rankBoard = [];
  List<LeaderboardItem> _wealthBoard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ApiService().fetchLeaderboard();
    if (mounted) {
      setState(() {
        _rankBoard = data['rankBoard'] ?? [];
        _wealthBoard = data['wealthBoard'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final maxDialogHeight = (MediaQuery.sizeOf(context).height * 0.84).clamp(360.0, 620.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: AppColors.adaptiveCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.adaptivePrimary(context), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(50),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF312E81)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '聚会桌游名人榜',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.amber,
                    indicatorWeight: 3,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: '⚔️ 排位天梯榜'),
                      Tab(text: '💎 豪门财富榜'),
                    ],
                  ),
                ],
              ),
            ),

            // 排行榜列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRankList(_rankBoard),
                        _buildWealthList(_wealthBoard),
                      ],
                    ),
            ),

            // 我的排名底栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.adaptiveBg(context),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(top: BorderSide(color: AppColors.adaptiveBorder(context))),
              ),
              child: Row(
                children: [
                  Text('我的战绩: ', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12)),
                  Flexible(
                    child: Text(
                      user?.rankTier ?? '暂无段位',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${user?.rankScore ?? 0} 分)',
                    style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '胜率: ${(user?.winRate ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankList(List<LeaderboardItem> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard_outlined, size: 48, color: AppColors.adaptiveTextMuted(context)),
              const SizedBox(height: 12),
              Text('暂无全服排位数据，参与对局即可登上榜单！', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        final rankIcon = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '${idx + 1}'));

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: idx < 3 ? AppColors.adaptiveElevated(ctx) : AppColors.adaptiveCard(ctx),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: idx < 3 ? Colors.amber.withAlpha(80) : AppColors.adaptiveBorder(ctx)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rankIcon,
                  style: TextStyle(
                    fontSize: idx < 3 ? 20 : 14,
                    fontWeight: FontWeight.bold,
                    color: idx < 3 ? Colors.amber : AppColors.adaptiveTextMuted(ctx),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.adaptiveBg(ctx),
                child: Text(item.avatar, style: const TextStyle(fontSize: 20)),
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
                            item.nickname,
                            style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.vipLevel > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withAlpha(100)),
                            ),
                            child: Text(
                              'V${item.vipLevel}',
                              style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.rankTier} · ${item.rankScore}分 · 胜率 ${item.winRate.toStringAsFixed(0)}%',
                      style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWealthList(List<LeaderboardItem> list) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_outlined, size: 48, color: AppColors.adaptiveTextMuted(context)),
              const SizedBox(height: 12),
              Text('暂无全服财富榜数据', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        final rankIcon = idx == 0 ? '👑' : (idx == 1 ? '💎' : (idx == 2 ? '⭐' : '${idx + 1}'));

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: idx < 3 ? AppColors.adaptiveElevated(ctx) : AppColors.adaptiveCard(ctx),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: idx < 3 ? const Color(0xFF38BDF8).withAlpha(80) : AppColors.adaptiveBorder(ctx)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rankIcon,
                  style: TextStyle(
                    fontSize: idx < 3 ? 20 : 14,
                    fontWeight: FontWeight.bold,
                    color: idx < 3 ? const Color(0xFF38BDF8) : AppColors.adaptiveTextMuted(ctx),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.adaptiveBg(ctx),
                child: Text(item.avatar, style: const TextStyle(fontSize: 20)),
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
                            item.nickname,
                            style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withAlpha(100)),
                          ),
                          child: Text(
                            'VIP ${item.vipLevel}',
                            style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '💎 ${item.diamonds} 钻石 · 🪙 ${item.coins} 金币',
                      style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
