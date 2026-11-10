import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import 'recharge_dialog.dart';

class VipCenterDialog extends StatelessWidget {
  const VipCenterDialog({super.key});

  static const List<Map<String, dynamic>> vipLevels = [
    {
      'level': 1,
      'name': 'VIP 1 · 聚会初贵 (王者初贵)',
      'needExp': 10,
      'privileges': '• 专属 VIP 1 贵族勋章标识\n• 解锁专属【星空霸主头像框】购买特权\n• 签到金币收益额外 +10%\n• 个人名片尊贵初级微光',
    },
    {
      'level': 2,
      'name': 'VIP 2 · 聚会名流 (王者进阶)',
      'needExp': 100,
      'privileges': '• 专属 VIP 2 进阶贵族徽章\n• 解锁【至尊黄金神龙骰盅】与【曜石金字色】\n• 签到金币收益额外 +20%\n• 大厅房间优先入座特权',
    },
    {
      'level': 3,
      'name': 'VIP 3 · 牌桌宗师 (精英贵族)',
      'needExp': 500,
      'privileges': '• 专属 VIP 3 白银精英徽章\n• 解锁【君临天下入场横幅】与【至尊红字色】\n• 房间免踢特权（非房主无法移出）\n• 每日破产救济金额外领取 +1 次',
    },
    {
      'level': 4,
      'name': 'VIP 4 · 雀圣尊爵 (璀璨贵族·SVIP)',
      'needExp': 2000,
      'privileges': '• 专属 SVIP 4 璀璨流光徽章\n• 解锁【黑金至尊帝王头像框】\n• 全服大喇叭 8 折特惠使用权\n• 每日破产救济金额外领取 +2 次\n• 对局结算金币额外 +20%',
    },
    {
      'level': 5,
      'name': 'VIP 5 · 酒界至尊 (耀世贵族·SVIP)',
      'needExp': 5000,
      'privileges': '• 专属 SVIP 5 耀世金芒徽章\n• 进房触发专属金色全屏流光光晕\n• 好友上限扩充至 100 人，私信无限制\n• 破产救济金金币倍率提升至 1.5 倍\n• 对局结算金币额外 +25%',
    },
    {
      'level': 6,
      'name': 'VIP 6 · 豪门传奇 (至尊贵族·SVIP)',
      'needExp': 10000,
      'privileges': '• 专属 SVIP 6 至尊金冠徽章\n• 尊贵黑金动态流光铭牌\n• 全服大喇叭 5 折特惠使用权\n• 每日破产救济金额外领取 +3 次\n• 对局结算金币额外 +30%',
    },
    {
      'level': 7,
      'name': 'VIP 7 · 巅峰霸主 (荣耀贵族·SVIP)',
      'needExp': 20000,
      'privileges': '• 专属 SVIP 7 荣耀紫金徽章\n• 贵族专属动态彩色发言气泡\n• 全服盛典超级火箭/超跑专属折扣\n• 专属客服优先响应通道\n• 对局结算金币额外 +40%',
    },
    {
      'level': 8,
      'name': 'VIP 8 · 永恒传说 (传说贵族·SVIP)',
      'needExp': 50000,
      'privileges': '• 专属 SVIP 8 传说荣耀皇冠勋章\n• 进房全服跑马灯公告通报（神豪降临）\n• 免广告特权（商业广告视频直达免等待）\n• 破产救济金金币翻倍（2.0 倍收益）\n• 对局结算金币额外 +50%',
    },
    {
      'level': 9,
      'name': 'VIP 9 · 神圣主宰 (神圣贵族·SVIP)',
      'needExp': 100000,
      'privileges': '• 专属 SVIP 9 神圣永恒皇冠徽章\n• 个人主页专属金钻流光背景特效\n• 全服房间置顶广播特权\n• 每日破产救济金额外领取 +5 次\n• 对局结算金币额外 +70%',
    },
    {
      'level': 10,
      'name': 'VIP 10 · 荣耀无双 (至高无上·无双王者)',
      'needExp': 188888,
      'privileges': '• 终极 SVIP 10 荣耀无双七彩神级徽章\n• 【同桌装扮共享特权】（牌友可共享使用您拥有的骰盅皮肤与牌桌特效，对标王者荣耀皮肤共享）\n• 神级龙腾入场全服公告横幅\n• 每日破产救济金无限次保底领取\n• 对局结算金币收益额外 +100% (翻倍)',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final currentLevel = user?.vipLevel ?? 0;
    final currentExp = user?.vipExp ?? 0;

    int nextExp = 188888;
    for (final v in vipLevels) {
      if (currentExp < (v['needExp'] as int)) {
        nextExp = v['needExp'] as int;
        break;
      }
    }
    final progress = nextExp > 0 ? (currentExp / nextExp).clamp(0.0, 1.0) : 1.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withAlpha(40),
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
                  colors: [Color(0xFF854D0E), Color(0xFF451A03)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: const Text('👑', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'VIP 贵族俱乐部 (Lv.$currentLevel)',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 经验进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.black38,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentLevel >= 10
                              ? '👑 已达成王者巅峰 VIP 10 荣耀无双 ($currentExp EXP)'
                              : '当前 VIP 贵族成长值: $currentExp / $nextExp EXP',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
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

            // 特权列表
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                itemCount: vipLevels.length,
                itemBuilder: (ctx, idx) {
                  final v = vipLevels[idx];
                  final lvl = v['level'] as int;
                  final isUnlocked = currentLevel >= lvl;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnlocked ? Colors.amber.withAlpha(15) : AppColors.bgDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnlocked ? Colors.amber.withAlpha(120) : AppColors.border,
                        width: isUnlocked ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v['name'] as String,
                              style: TextStyle(
                                color: isUnlocked ? Colors.amber : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUnlocked ? Colors.amber.withAlpha(40) : AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUnlocked ? '已享此特权' : '需 ${v['needExp']} EXP',
                                style: TextStyle(
                                  color: isUnlocked ? Colors.amber : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          v['privileges'] as String,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 底部操作按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (currentLevel > 0) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.card_giftcard, size: 18),
                        label: Text(
                          '领取今日 VIP $currentLevel 俸禄 (🪙 ${currentLevel * 1000} + 💎 ${currentLevel * 20})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          final coins = currentLevel * 1000;
                          final diamonds = currentLevel * 20;
                          if (user != null) {
                            user.coins += coins;
                            user.diamonds += diamonds;
                            auth.saveUser(user);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎉 尊贵贵族！今日 VIP $currentLevel 俸禄已到账：+$coins 金币, +$diamonds 钻石！'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.bolt),
                      label: const Text('立即充值获取 VIP 成长值', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(context: context, builder: (_) => const RechargeDialog());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
