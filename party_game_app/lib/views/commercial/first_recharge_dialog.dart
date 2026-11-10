import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';

/// 商业化首充超值豪礼弹窗 (手游核心转化闭环)
class FirstRechargeDialog extends StatelessWidget {
  const FirstRechargeDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const FirstRechargeDialog(),
    );
  }

  void _onRecharge(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    GameSoundService().playWin();

    // 更新用户资产与绝版装扮
    user.diamonds += 666;
    user.coins += 66666;
    user.vipExp += 60;
    user.diceCupSkin = 'PURPLE_GALAXY';
    user.entranceBanner = 'BANNER_DRAGON';
    
    // 同步至本地与服务端
    auth.saveUser(user);

    if (context.mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🎉 ', style: TextStyle(fontSize: 24)),
              Text('首充豪礼领取成功！', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('恭喜客官解锁聚会首充大礼包，以下丰厚资产已到账：', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              _buildRewardItem('👑 绝版【紫晶星系】奢华骰蛊', '已自动穿戴'),
              _buildRewardItem('🐉「凤舞龙吟」全服入场横幅', '已自动激活'),
              _buildRewardItem('🪙 66,666 聚会金币', '已存入钱包'),
              _buildRewardItem('💎 666 尊享钻石', '已存入钱包'),
              _buildRewardItem('⭐ VIP 贵族成长值 +60 点', '直升 VIP 1'),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('开心收下'),
            ),
          ],
        ),
      );
    }
  }

  static Widget _buildRewardItem(String title, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
          Text(status, style: const TextStyle(color: AppColors.accent, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF181126),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部聚光灯横幅
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFB45309), Color(0xFF78350F), Color(0xFF451A03)],
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
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('限购 1 次', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '👑 聚会首充超神豪礼',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '任意充值满 6 元，立享超值 10 倍返利！全服老手必备！',
                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // 核心奖励展示卡片
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      // 奖励九宫格
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF231A38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            _buildFeatureRow('🌌', '绝版【紫晶星系】3D 骰蛊', '价值 388 钻石', '闪耀全场，尊崇气派'),
                            const Divider(color: Colors.white10, height: 16),
                            _buildFeatureRow('🪙', '66,666 聚会金币', '价值 66 元', '开局畅玩，筹码无忧'),
                            const Divider(color: Colors.white10, height: 16),
                            _buildFeatureRow('💎', '666 尊贵钻石', '极品代币', '直购商城所有限定装扮'),
                            const Divider(color: Colors.white10, height: 16),
                            _buildFeatureRow('🐉', '「凤舞龙吟」进场特效横幅', '专属特效', '进房全屏神龙环绕提示'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 支付购买按钮
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: const Color(0xFFF59E0B).withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _onRecharge(context),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('立即充值 ￥6.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                              SizedBox(width: 8),
                              Text('(领 888 元豪礼)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '支持微信支付 · 支付宝 · 苹果 App Store 模拟沙盒免密扣款',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 关闭按钮
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String icon, String title, String tag, String desc) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
