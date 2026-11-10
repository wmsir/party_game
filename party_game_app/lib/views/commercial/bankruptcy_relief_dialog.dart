import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';
import 'mock_ad_player_dialog.dart';

/// 商业化破产低保救济基金 (留存与商业化双飞轮)
class BankruptcyReliefDialog extends StatefulWidget {
  const BankruptcyReliefDialog({super.key});

  static void checkAndShow(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user != null && user.coins < 200) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const BankruptcyReliefDialog(),
      );
    }
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const BankruptcyReliefDialog(),
    );
  }

  @override
  State<BankruptcyReliefDialog> createState() => _BankruptcyReliefDialogState();
}

class _BankruptcyReliefDialogState extends State<BankruptcyReliefDialog> {
  void _claimRelief(int amount, String source) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    GameSoundService().playWin();
    user.coins += amount;
    auth.saveUser(user);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 成功领取【$source】：+$amount 金币！祝客官逆风翻盘！'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _onWatchAdForRelief() {
    MockAdPlayerDialog.show(
      context,
      rewardTitle: '3,000 救济翻倍金币',
      onRewardEarned: () {
        _claimRelief(3000, '救济翻倍激励');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.25),
              blurRadius: 24,
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
                  colors: [Color(0xFF0369A1), Color(0xFF0C4A6E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Text('🛡️ ', style: TextStyle(fontSize: 24)),
                  const Expanded(
                    child: Text(
                      '聚会俱乐部 · 破产低保基金',
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
            ),

            // 救济内容
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    '检测到您的金币不足 200！',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '俱乐部特为您发放低保救济基金，助您东山再起重新开局！每日可领 3 次。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // 免费领取基础低保
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _claimRelief(1000, '基础救济金'),
                      child: const Text('直接领 1,000 金币 (免费)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 看广告翻倍领 3000
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_circle_fill, color: Colors.black),
                      label: const Text('看视频直接领 3,000 金币', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: _onWatchAdForRelief,
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
