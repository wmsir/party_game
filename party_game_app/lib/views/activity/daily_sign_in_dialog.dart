import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../commercial/mock_ad_player_dialog.dart';

class DailySignInDialog extends StatefulWidget {
  const DailySignInDialog({super.key});

  static const List<SignInDayReward> defaultRewards = [
    SignInDayReward(day: 1, coins: 500, diamonds: 0, title: '第1天·金币初试', icon: '🪙'),
    SignInDayReward(day: 2, coins: 1000, diamonds: 0, title: '第2天·金币加倍', icon: '🪙'),
    SignInDayReward(day: 3, coins: 1200, diamonds: 0, prop: 'PROP_TRUMPET_10', title: '第3天·大喇叭x10', icon: '📢'),
    SignInDayReward(day: 4, coins: 1500, diamonds: 0, title: '第4天·金币盛宴', icon: '🪙'),
    SignInDayReward(day: 5, coins: 1800, diamonds: 0, prop: 'GIFT_ROSE_20', title: '第5天·玫瑰x20', icon: '💐'),
    SignInDayReward(day: 6, coins: 2500, diamonds: 0, title: '第6天·豪礼加倍', icon: '🪙'),
    SignInDayReward(day: 7, coins: 6666, diamonds: 66, prop: 'GIFT_BOX_LEGENDARY', avatarFrame: 'FRAME_GOLD', title: '第7天·66钻+黄金框', icon: '👑'),
  ];

  @override
  State<DailySignInDialog> createState() => _DailySignInDialogState();
}

class _DailySignInDialogState extends State<DailySignInDialog> {
  SignInStatus? _remoteStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    try {
      final status = await ApiService().fetchSignInStatus(user.id);
      if (mounted && status != null) {
        setState(() {
          _remoteStatus = status;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final isSignedToday = _remoteStatus?.isSignedToday ?? (user?.lastSignDate == todayStr);
    final streak = _remoteStatus?.streak ?? (user?.signInStreak ?? 0);
    final currentDay = _remoteStatus?.currentDay ?? (isSignedToday ? (((streak - 1) % 7) + 1) : ((streak % 7) + 1));
    final rewards = (_remoteStatus?.calendar.isNotEmpty ?? false)
        ? _remoteStatus!.calendar
        : DailySignInDialog.defaultRewards;

    final maxDialogHeight = (MediaQuery.sizeOf(context).height * 0.88).clamp(380.0, 680.0);
    final gridRewards = rewards.length > 6 ? rewards.sublist(0, 6) : rewards;
    final day7Reward = rewards.length >= 7 ? rewards[6] : null;
    final isDay7Past = (isSignedToday && 6 < currentDay) || (!isSignedToday && 6 < (currentDay - 1));
    final isDay7Today = !isSignedToday && (6 == (currentDay - 1));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: AppColors.adaptiveCardSurface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEC4899), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withAlpha(50),
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
                  colors: [Color(0xFFDB2777), Color(0xFF831843)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '七日狂欢签到礼',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已连续打卡 $streak 天 · 满7天领【66钻石+黄金头像框】',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
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

            // 7天签到内容：1-6天 3x2 网格 + 第7天全宽黄金大奖横幅
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.90,
                      ),
                      itemCount: gridRewards.length,
                      itemBuilder: (ctx, idx) {
                        final r = gridRewards[idx];
                        final isPastClaimed = (isSignedToday && idx < currentDay) || (!isSignedToday && idx < (currentDay - 1));
                        final isTodayTarget = !isSignedToday && (idx == (currentDay - 1));

                        String rewardSubText = '';
                        if (r.prop == 'PROP_TRUMPET_10') {
                          rewardSubText = '大喇叭+${r.coins}币';
                        } else if (r.prop == 'GIFT_ROSE_20') {
                          rewardSubText = '玫瑰x20+${r.coins}币';
                        } else if (r.diamonds > 0) {
                          rewardSubText = '${r.coins}币+${r.diamonds}钻';
                        } else {
                          rewardSubText = '${r.coins}金币';
                        }

                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPastClaimed
                                ? AppColors.adaptiveBgDark(context)
                                : (isTodayTarget ? const Color(0xFFEC4899).withAlpha(25) : AppColors.adaptiveElevated(context)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isTodayTarget
                                  ? const Color(0xFFEC4899)
                                  : AppColors.adaptiveBorder(context),
                              width: isTodayTarget ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '第${r.day}天',
                                style: TextStyle(
                                  color: isPastClaimed ? AppColors.adaptiveTextMuted(context) : AppColors.adaptiveTextPrimary(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r.displayIcon,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rewardSubText,
                                style: TextStyle(
                                  color: isPastClaimed ? AppColors.adaptiveTextMuted(context) : AppColors.adaptiveAccent(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              if (isPastClaimed)
                                const Text('已领取', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold))
                              else if (isTodayTarget)
                                const Text('今日可领', style: TextStyle(color: Color(0xFFEC4899), fontSize: 9, fontWeight: FontWeight.bold))
                              else
                                Text('未解锁', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 9)),
                            ],
                          ),
                        );
                      },
                    ),
                    if (day7Reward != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDay7Past
                                ? [AppColors.adaptiveBgDark(context), AppColors.adaptiveElevated(context)]
                                : const [Color(0xFF78350F), Color(0xFFB45309)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDay7Today ? const Color(0xFFEC4899) : Colors.amber,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(day7Reward.displayIcon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '第 7 天终极大奖 · 荣耀黄金框',
                                    style: TextStyle(
                                      color: isDay7Past ? AppColors.adaptiveTextMuted(context) : const Color(0xFFFEF08A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${day7Reward.coins} 金币 + ${day7Reward.diamonds} 钻石 + 传说礼盒',
                                    style: TextStyle(
                                      color: isDay7Past ? AppColors.adaptiveTextMuted(context) : Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDay7Past ? AppColors.adaptiveCard(context) : Colors.amber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isDay7Past ? '已领取' : (isDay7Today ? '今日可领' : '满7天解锁'),
                                style: TextStyle(
                                  color: isDay7Past ? AppColors.adaptiveTextMuted(context) : Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
            ),

            // 底部领取按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSignedToday ? AppColors.adaptiveElevated(context) : const Color(0xFFDB2777),
                        foregroundColor: isSignedToday ? AppColors.adaptiveTextMuted(context) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(isSignedToday ? Icons.check_circle : Icons.card_giftcard),
                      label: Text(
                        isSignedToday ? '今日已签到打卡，明日再来' : '立即签到领取第 $currentDay 天奖励',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: (isSignedToday || _isLoading)
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final targetIdx = (currentDay - 1).clamp(0, rewards.length - 1);
                              final reward = rewards[targetIdx];
                              await auth.claimSignInReward(reward);

                              if (context.mounted) {
                                setState(() {
                                  _isLoading = false;
                                  _remoteStatus = SignInStatus(
                                    calendar: rewards,
                                    streak: streak + 1,
                                    isSignedToday: true,
                                    currentDay: ((currentDay % 7) + 1),
                                  );
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 签到成功！获得 ${reward.coins} 金币${reward.diamonds > 0 ? " + ${reward.diamonds} 钻石" : ""}${reward.prop != null ? " +【${reward.prop}】" : ""}${reward.avatarFrame != null ? " +【荣耀黄金头像框】" : ""}！'),
                                    backgroundColor: const Color(0xFFDB2777),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  if (!isSignedToday) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_circle_fill, color: Colors.black, size: 18),
                        label: Text(
                          '看视频广告 · 双倍领第 $currentDay 天奖励 (🪙 ${rewards[(currentDay - 1).clamp(0, rewards.length - 1)].coins * 2})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                final targetIdx = (currentDay - 1).clamp(0, rewards.length - 1);
                                final reward = rewards[targetIdx];
                                MockAdPlayerDialog.show(
                                  context,
                                  rewardTitle: '签到双倍奖励 (🪙 ${reward.coins * 2} 金币)',
                                  onRewardEarned: () async {
                                    await auth.claimSignInReward(SignInDayReward(
                                      day: reward.day,
                                      coins: reward.coins * 2,
                                      diamonds: reward.diamonds * 2,
                                      prop: reward.prop,
                                      avatarFrame: reward.avatarFrame,
                                      title: reward.title,
                                      icon: reward.icon,
                                    ));
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
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
