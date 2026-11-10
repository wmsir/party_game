import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';

/// 商业化聚会战令 (Battle Pass / 黄金通行证)
class BattlePassDialog extends StatefulWidget {
  const BattlePassDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const BattlePassDialog(),
    );
  }

  @override
  State<BattlePassDialog> createState() => _BattlePassDialogState();
}

class _BattlePassDialogState extends State<BattlePassDialog> {
  bool _hasUnlockedGoldPass = false;
  final int _currentLevel = 8;
  final int _currentExp = 320;
  final int _maxExp = 500;
  final Set<int> _claimedFreeLevels = {1, 2, 3, 4, 5};
  final Set<int> _claimedGoldLevels = {};

  void _claimReward(int level, bool isGold) {
    if (isGold && !_hasUnlockedGoldPass) {
      _unlockGoldPassDialog();
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    GameSoundService().playWin();

    setState(() {
      if (isGold) {
        _claimedGoldLevels.add(level);
      } else {
        _claimedFreeLevels.add(level);
      }
    });

    final coinsEarned = isGold ? 5000 : 1000;
    final diamondsEarned = isGold ? 50 : 0;
    user.coins += coinsEarned;
    user.diamonds += diamondsEarned;
    auth.saveUser(user);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 成功领取战令 Lv.$level 奖励：+$coinsEarned 金币 ${diamondsEarned > 0 ? "+$diamondsEarned 钻石" : ""}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _claimAll() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    int totalCoins = 0;
    int totalDiamonds = 0;

    setState(() {
      for (int i = 1; i <= _currentLevel; i++) {
        if (!_claimedFreeLevels.contains(i)) {
          _claimedFreeLevels.add(i);
          totalCoins += 1000;
        }
        if (_hasUnlockedGoldPass && !_claimedGoldLevels.contains(i)) {
          _claimedGoldLevels.add(i);
          totalCoins += 5000;
          totalDiamonds += 50;
        }
      }
    });

    if (totalCoins > 0 || totalDiamonds > 0) {
      GameSoundService().playWin();
      user.coins += totalCoins;
      user.diamonds += totalDiamonds;
      auth.saveUser(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 一键领取战令好礼：+$totalCoins 金币 ${totalDiamonds > 0 ? "+$totalDiamonds 钻石" : ""}！'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前暂无待领取的战令奖励，快去对局做任务升级吧！')),
      );
    }
  }

  void _unlockGoldPassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: const Row(
          children: [
            Text('👑 ', style: TextStyle(fontSize: 24)),
            Text('解锁进阶黄金战令', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('进阶黄金战令特权：', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• 立即可解锁当前已达到等级的全部豪华黄金奖励\n• 满级必得限定【赛博霓虹】3D 骰蛊\n• 累计返还 1,280 钻石 + 100,000 金币\n• 尊崇「黄金战神」入场名牌标识', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _hasUnlockedGoldPass = true);
              GameSoundService().playWin();
              final auth = context.read<AuthProvider>();
              final user = auth.user;
              if (user != null) {
                user.vipExp += 300;
                auth.saveUser(user);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('👑 恭喜尊贵客官成功激活 S1 进阶黄金战令！'),
                  backgroundColor: Colors.amber,
                ),
              );
            },
            child: const Text('立即支付 ￥30.00 解锁', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // 战令赛季头部
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF312E81), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('S1 赛季', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '聚会通行证 · 骰王争霸季',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 当前等级与经验条
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                          boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 10)],
                        ),
                        child: Center(
                          child: Text(
                            '$_currentLevel',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('战令经验值', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('$_currentExp / $_maxExp', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _currentExp / _maxExp,
                                minHeight: 8,
                                backgroundColor: Colors.white10,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 通行证状态与一键领取栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasUnlockedGoldPass ? Colors.amber.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _hasUnlockedGoldPass ? Colors.amber : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasUnlockedGoldPass ? Icons.verified : Icons.lock_outline,
                          size: 14,
                          color: _hasUnlockedGoldPass ? Colors.amber : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasUnlockedGoldPass ? '已解锁黄金战令' : '黄金战令未激活',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _hasUnlockedGoldPass ? Colors.amber : AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.download_done, size: 16, color: AppColors.primaryLight),
                    label: const Text('一键领奖', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _claimAll,
                  ),
                ],
              ),
            ),

            // 战令等级阶梯列表
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: 15,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final lvl = index + 1;
                  final isReached = lvl <= _currentLevel;
                  final isFreeClaimed = _claimedFreeLevels.contains(lvl);
                  final isGoldClaimed = _claimedGoldLevels.contains(lvl);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isReached ? AppColors.primary.withOpacity(0.5) : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 等级徽章
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isReached ? AppColors.primary : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Lv.$lvl',
                              style: TextStyle(color: isReached ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 免费轨奖励
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('普通战令', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text('🪙 ${lvl * 1000} 金币', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: (isReached && !isFreeClaimed) ? () => _claimReward(lvl, false) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFreeClaimed
                                  ? Colors.transparent
                                  : (isReached ? const Color(0xFF10B981) : Colors.white12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isFreeClaimed ? '已领取' : (isReached ? '领取' : '未解锁'),
                              style: TextStyle(fontSize: 11, color: isFreeClaimed ? AppColors.textMuted : Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),
                        Container(width: 1, height: 28, color: Colors.white10),
                        const SizedBox(width: 8),

                        // 进阶黄金轨奖励
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 10),
                                  SizedBox(width: 2),
                                  Text('黄金战令', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(lvl == 15 ? '⚡ 赛博骰蛊' : '💎 ${lvl * 50} 钻', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: isReached ? () => _claimReward(lvl, true) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isGoldClaimed
                                  ? Colors.transparent
                                  : (isReached
                                      ? (_hasUnlockedGoldPass ? Colors.amber : const Color(0xFF78350F))
                                      : Colors.white12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isGoldClaimed ? '已领取' : (_hasUnlockedGoldPass ? '领取' : '解锁'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isGoldClaimed ? AppColors.textMuted : (_hasUnlockedGoldPass ? Colors.black : Colors.amber),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 底部升级购买引导
            if (!_hasUnlockedGoldPass)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.workspace_premium, color: Colors.black),
                    label: const Text('解锁进阶黄金战令 (仅需 ￥30.00 · 立享 10 倍好礼)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: _unlockGoldPassDialog,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
