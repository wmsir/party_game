import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_models.dart';
import '../../providers/auth_provider.dart';
import '../../core/storage/local_storage.dart';

class DailyTasksDialog extends StatefulWidget {
  const DailyTasksDialog({super.key});

  @override
  State<DailyTasksDialog> createState() => _DailyTasksDialogState();
}

class _DailyTasksDialogState extends State<DailyTasksDialog> {
  late List<DailyTaskItem> _tasks;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final totalGames = user?.totalGames ?? 0;
    final winCount = user?.winCount ?? 0;
    final claimedIds = auth.getClaimedTasksToday();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final throwCount = LocalStorage.getInt('daily_throw_count_${user?.id}_$todayStr') ?? 0;

    _tasks = [
      DailyTaskItem(
        id: 'task_login',
        title: '每日签到登录活跃',
        target: 1,
        current: 1,
        rewardCoins: 100,
        rewardDiamonds: 5,
        isClaimed: claimedIds.contains('task_login'),
      ),
      DailyTaskItem(
        id: 'task_play_1',
        title: '参与 1 局聚会桌游对决',
        target: 1,
        current: totalGames >= 1 ? 1 : 0,
        rewardCoins: 200,
        rewardDiamonds: 10,
        isClaimed: claimedIds.contains('task_play_1'),
      ),
      DailyTaskItem(
        id: 'task_win_1',
        title: '赢得 1 场聚会游戏比赛',
        target: 1,
        current: winCount >= 1 ? 1 : 0,
        rewardCoins: 300,
        rewardDiamonds: 15,
        isClaimed: claimedIds.contains('task_win_1'),
      ),
      DailyTaskItem(
        id: 'task_throw_3',
        title: '向好友投掷 3 次互动道具',
        target: 3,
        current: throwCount >= 3 ? 3 : throwCount,
        rewardCoins: 150,
        rewardDiamonds: 5,
        isClaimed: claimedIds.contains('task_throw_3'),
      ),
      DailyTaskItem(
        id: 'task_play_3',
        title: '累计完成 3 局桌游对决',
        target: 3,
        current: totalGames >= 3 ? 3 : totalGames,
        rewardCoins: 500,
        rewardDiamonds: 30,
        isClaimed: claimedIds.contains('task_play_3'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withAlpha(50),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '每日聚会活跃任务',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '完成桌游与互动任务，领海量金币与代币钻石',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 任务列表
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                itemCount: _tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final t = _tasks[idx];
                  final isDone = t.isCompleted;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('🪙 +${t.rewardCoins} 金币  ', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('💎 +${t.rewardDiamonds} 钻石', style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 进度条
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: t.progress,
                                        backgroundColor: AppColors.bgDark,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isDone ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${t.current}/${t.target}',
                                    style: TextStyle(
                                      color: isDone ? const Color(0xFF10B981) : AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 领取或去完成按钮
                        if (t.isClaimed)
                          const Text('已领取', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold))
                        else if (isDone)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () async {
                              setState(() {
                                _tasks[idx] = DailyTaskItem(
                                  id: t.id,
                                  title: t.title,
                                  target: t.target,
                                  current: t.current,
                                  rewardCoins: t.rewardCoins,
                                  rewardDiamonds: t.rewardDiamonds,
                                  isClaimed: true,
                                );
                              });
                              await auth.claimTask(t);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 成功领取任务奖励：${t.rewardCoins} 金币 + ${t.rewardDiamonds} 钻石！'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            child: const Text('领取', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('去完成', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
