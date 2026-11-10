import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';
import '../commercial/bankruptcy_relief_dialog.dart';
import '../commercial/first_recharge_dialog.dart';
import '../commercial/lucky_gacha_wheel_dialog.dart';

class GameSettlementRankItem {
  final String id;
  final String name;
  final String avatar;
  final String scoreText;
  final bool isMe;

  const GameSettlementRankItem({
    required this.id,
    required this.name,
    required this.avatar,
    required this.scoreText,
    this.isMe = false,
  });
}

class GameSettlementDialog extends StatelessWidget {
  final bool isWin;
  final String gameTitle;
  final String gameIcon;
  final String? subtitle;
  final List<GameSettlementRankItem>? rankItems;
  final bool isSpectator;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onExit;

  const GameSettlementDialog({
    super.key,
    required this.isWin,
    required this.gameTitle,
    required this.gameIcon,
    this.subtitle,
    this.rankItems,
    this.isSpectator = false,
    this.onPlayAgain,
    this.onExit,
  });

  static void show(
    BuildContext context, {
    required bool isWin,
    required String gameTitle,
    required String gameIcon,
    String? subtitle,
    List<GameSettlementRankItem>? rankItems,
    bool isSpectator = false,
    VoidCallback? onPlayAgain,
    VoidCallback? onExit,
  }) {
    if (isWin) {
      GameSoundService().playSound('victory');
    } else {
      GameSoundService().playSound('defeat');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameSettlementDialog(
        isWin: isWin,
        gameTitle: gameTitle,
        gameIcon: gameIcon,
        subtitle: subtitle,
        rankItems: rankItems,
        isSpectator: isSpectator,
        onPlayAgain: onPlayAgain,
        onExit: onExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final vipLevel = user?.vipLevel ?? 0;
    final vipBonusRate = vipLevel >= 8 ? 0.5 : (vipLevel >= 5 ? 0.2 : (vipLevel >= 3 ? 0.1 : 0.0));
    final baseCoins = isWin ? 100 : 20;
    final vipBonusCoins = (baseCoins * vipBonusRate).round();
    final totalCoins = baseCoins + vipBonusCoins;
    final scoreDelta = isWin ? 25 : -15;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppColors.adaptiveCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isWin ? Colors.amber : const Color(0xFFEF4444),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isWin ? Colors.amber : const Color(0xFFEF4444)).withAlpha(60),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部横幅
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWin
                      ? [const Color(0xFFD97706), const Color(0xFF78350F)]
                      : [const Color(0xFF991B1B), const Color(0xFF450A0A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Text(
                    isWin ? '🏆 获胜！胜券在握' : '⚔️ 惜败！再接再厉',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$gameIcon $gameTitle · 本局结算',
                    style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // 战果收益与段位变动网格
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  // 全员排名榜单 (与网页端战绩榜完全一致)
                  if (rankItems != null && rankItems!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveElevated(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.adaptiveBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🏆 ', style: TextStyle(fontSize: 14)),
                              Text(
                                '对局战绩结算榜',
                                style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                gameTitle.contains('牛头') ? '牛头惩罚越少排名越高' : '实时战绩排名结算',
                                style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: rankItems!.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (ctx, idx) {
                                final item = rankItems![idx];
                                final rankEmojis = ['🥇', '🥈', '🥉'];
                                final rankBadge = idx < 3 ? rankEmojis[idx] : '#${idx + 1}';
                                final isWinner = idx == 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: item.isMe
                                        ? const Color(0xFF0D9488).withOpacity(0.18)
                                        : (isWinner ? Colors.amber.withOpacity(0.12) : AppColors.adaptiveCard(context)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isWinner
                                          ? Colors.amber.withOpacity(0.8)
                                          : (item.isMe ? const Color(0xFF0D9488) : AppColors.adaptiveBorder(context)),
                                      width: isWinner || item.isMe ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 26,
                                        child: Text(
                                          rankBadge,
                                          style: TextStyle(
                                            fontSize: idx < 3 ? 16 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: idx < 3 ? Colors.amber : AppColors.adaptiveTextSecondary(context),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(item.avatar.isNotEmpty ? item.avatar : '🐂', style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item.name}${item.isMe ? ' (我)' : ''}',
                                          style: TextStyle(
                                            color: item.isMe
                                                ? const Color(0xFF14B8A6)
                                                : (isWinner ? Colors.amber : AppColors.adaptiveTextPrimary(context)),
                                            fontWeight: item.isMe || isWinner ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        item.scoreText,
                                        style: const TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
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
                  ],

                  // 段位积分变动卡片
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveElevated(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.adaptiveBorder(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('⚔️ ', style: TextStyle(fontSize: 20)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('排位天梯积分', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  user?.rankTier ?? '暂无段位',
                                  style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isWin ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isWin ? '+$scoreDelta 分' : '$scoreDelta 分',
                            style: TextStyle(
                              color: isWin ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 金币收益卡片
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveElevated(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.adaptiveBorder(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🪙 ', style: TextStyle(fontSize: 20)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('聚会金币结算', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  vipBonusCoins > 0 ? '基础 $baseCoins + VIP加成 $vipBonusCoins' : '基础奖励',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '+$totalCoins 金币',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 任务已同步提示
                  // 商业化智能转化与挽留横幅
                  _buildCommercialActionCard(context, user),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveElevated(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '每日活跃任务进度已自动推进，记得去领取奖励！',
                            style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 操作按钮条
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.adaptiveTextSecondary(context),
                        side: BorderSide(color: AppColors.adaptiveBorder(context)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (onExit != null) onExit!();
                      },
                      child: const Text('返回大厅', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSpectator
                            ? const Color(0xFF6366F1)
                            : (isWin ? const Color(0xFFD97706) : AppColors.primary),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (onPlayAgain != null) onPlayAgain!();
                      },
                      child: Text(
                        isSpectator ? '🪑 申请加入席位准备' : '🔄 再战一局',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  /// 商业化自适应转化卡片：根据玩家破产/首充/VIP状态智能呈现高ROI引导
  Widget _buildCommercialActionCard(BuildContext context, user) {
    if (user == null) return const SizedBox.shrink();

    // 1. 若金币告急（< 200），触发破产救济挽留
    if (user.coins < 200) {
      return InkWell(
        onTap: () => BankruptcyReliefDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF87171), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: const Row(
            children: [
              Text('🛡️ ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('金币告急！免费领取 1,000 救济金', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 1),
                    Text('每日3次免费补给，绝不离场', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
            ],
          ),
        ),
      );
    }

    // 2. 若尚未首充（VIP 0），展示6元首充高价值礼包
    if (user.vipLevel == 0) {
      return InkWell(
        onTap: () => FirstRechargeDialog.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF78350F), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: const Row(
            children: [
              Text('🎁 ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('首充特惠：1元立领 66,666 金币+绝版骰盅', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(height: 1),
                    Text('送全服龙吟横幅 · 直升 VIP 1', style: TextStyle(color: Color(0xFFFEF08A), fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
            ],
          ),
        ),
      );
    }

    // 3. 常规活跃：幸运转盘抽奖
    return InkWell(
      onTap: () => LuckyGachaWheelDialog.show(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Text('🎰 ', style: TextStyle(fontSize: 15)),
            Expanded(
              child: Text('今日幸运转盘待开启（每日送1次免费抽奖）', style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA5B4FC), size: 11),
          ],
        ),
      ),
    );
  }
}
