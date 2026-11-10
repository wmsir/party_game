import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';

/// 商业化激励视频广告播放模拟组件 (仿真穿山甲/优量汇商业化广告SDK体验)
class MockAdPlayerDialog extends StatefulWidget {
  final String rewardTitle;
  final VoidCallback onRewardEarned;

  const MockAdPlayerDialog({
    super.key,
    required this.rewardTitle,
    required this.onRewardEarned,
  });

  static Future<bool> show(BuildContext context, {required String rewardTitle, required VoidCallback onRewardEarned}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MockAdPlayerDialog(
        rewardTitle: rewardTitle,
        onRewardEarned: onRewardEarned,
      ),
    );
    return result ?? false;
  }

  @override
  State<MockAdPlayerDialog> createState() => _MockAdPlayerDialogState();
}

class _MockAdPlayerDialogState extends State<MockAdPlayerDialog> {
  int _countdown = 5;
  Timer? _timer;
  bool _canClaim = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    GameSoundService().playRoll();
    _startAdTimer();
  }

  void _startAdTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _countdown = 0;
          _canClaim = true;
        });
        GameSoundService().playWin();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _claimReward() {
    widget.onRewardEarned();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 恭喜获得商业化激励奖励：${widget.rewardTitle}！'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withOpacity(0.2),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // 顶部广告信息条
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber, width: 0.8),
                    ),
                    child: const Text('广告推广', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _canClaim ? '已完成观看，可领奖' : '观看倒计时: ${_countdown}s',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, size: 18, color: Colors.white70),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  if (_canClaim)
                    IconButton(
                      icon: const Icon(Icons.close, size: 22, color: Colors.white),
                      onPressed: () => Navigator.pop(context, false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // 广告视频模拟播放区域
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 广告动态光效背景
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF312E81), Color(0xFF0F172A)],
                        radius: 1.2,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '🎲 聚会桌游俱乐部 🎲',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '全国年轻人的派对轰趴首选桌游神器\n大话骰 · 谁是牛头王 · 大冒险转盘 · 卧底对决',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: Text(
                          '🎁 观看完成即领: ${widget.rewardTitle}',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  // 底部进度条
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: (5 - _countdown) / 5.0,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF38BDF8),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),

            // 底部操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canClaim ? const Color(0xFF10B981) : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(_canClaim ? Icons.check_circle_outline : Icons.timelapse, size: 20),
                  label: Text(
                    _canClaim ? '立即领取【${widget.rewardTitle}】' : '请观看完整广告 (${_countdown}s)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _canClaim ? _claimReward : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
