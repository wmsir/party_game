import 'package:flutter/material.dart';
import '../../../../models/game_player.dart';
import 'dice_3d_widget.dart';
import '../../../../core/sound/game_sound_service.dart';

/// 大话骰全桌开盅明牌验点大弹窗
class LiarsDiceShowdownDialog extends StatelessWidget {
  final Map<String, dynamic> settlementData;
  final List<GamePlayer> players;
  final String myPlayerId;

  const LiarsDiceShowdownDialog({
    super.key,
    required this.settlementData,
    required this.players,
    required this.myPlayerId,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> settlementData,
    required List<GamePlayer> players,
    required String myPlayerId,
  }) {
    GameSoundService().playVictory();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LiarsDiceShowdownDialog(
        settlementData: settlementData,
        players: players,
        myPlayerId: myPlayerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challengerName = settlementData['challengerName']?.toString() ?? '开盅者';
    final targetFace = int.tryParse(settlementData['targetFace']?.toString() ?? '1') ?? 1;
    final bidCount = int.tryParse(settlementData['bidCount']?.toString() ?? '1') ?? 1;
    final actualCount = int.tryParse(settlementData['actualCount']?.toString() ?? '0') ?? 0;
    final isPure = settlementData['isPure'] == true;
    final isBluffCaught = settlementData['isBluffCaught'] == true;
    final winnerName = settlementData['winnerName']?.toString() ?? '赢家';
    final loserName = settlementData['loserName']?.toString() ?? '败家';
    final winnerId = settlementData['winnerId']?.toString() ?? '';
    final isMyWin = winnerId == myPlayerId;

    final rawAllHands = settlementData['allHands'];
    final Map<String, List<int>> allHands = {};
    if (rawAllHands is Map) {
      rawAllHands.forEach((k, v) {
        if (v is List) {
          allHands[k.toString()] = v.map((x) => int.tryParse(x.toString()) ?? 1).toList();
        }
      });
    }

    // 辅助获取玩家昵称与头像
    String getPlayerName(String id) {
      final p = players.where((x) => x.id == id).firstOrNull;
      return p?.name ?? id;
    }

    String getPlayerAvatar(String id) {
      final p = players.where((x) => x.id == id).firstOrNull;
      return (p?.avatar != null && p!.avatar.isNotEmpty) ? p.avatar : '🎲';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isMyWin ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isMyWin ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 顶部大标题横幅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMyWin
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : [const Color(0xFF78350F), const Color(0xFFB45309)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Text(isMyWin ? '🏆' : '🎲', style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBluffCaught ? '💥 开盅！吹牛被当场抓获！' : '🎯 开盅！叫点属实，开盅失利！',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '【$challengerName】验点：胜者【$winnerName】，负者【$loserName】',
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

            // 2. 叫点 vs 实际总数核心判决对比板
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('被叫目标', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '$bidCount 个 $targetFace点${isPure ? " (斋)" : ""}',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: const Color(0xFF334155)),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('全桌实有点数', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$actualCount 个',
                              style: TextStyle(
                                color: actualCount >= bidCount ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPure ? '(斋单点)' : '(含通配1点)',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. 全桌所有玩家明牌骰子展示区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '👥 全桌手牌明细 (高亮为有效点数)：',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: allHands.entries.map((entry) {
                  final pId = entry.key;
                  final diceList = entry.value;
                  final pName = getPlayerName(pId);
                  final pAvatar = getPlayerAvatar(pId);
                  final isMe = pId == myPlayerId;
                  final isWinner = pId == winnerId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isWinner
                          ? const Color(0xFF10B981).withOpacity(0.12)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isWinner ? const Color(0xFF10B981) : const Color(0xFF334155),
                        width: isWinner ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 玩家头像与标识
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF334155),
                              child: Text(pAvatar, style: const TextStyle(fontSize: 16)),
                            ),
                            if (isWinner)
                              const Text('👑', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pName + (isMe ? ' (我)' : ''),
                                style: TextStyle(
                                  color: isMe ? const Color(0xFF38BDF8) : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWinner ? '🏅 胜者 (+200)' : '败者 (-200)',
                                style: TextStyle(
                                  color: isWinner ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 5 颗明牌骰子展示
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: diceList.map((d) {
                            final isMatch = (d == targetFace) || (!isPure && targetFace != 1 && d == 1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                              child: Dice3DWidget(
                                value: d,
                                size: 30,
                                isHighlighted: isMatch,
                                isDimmed: !isMatch,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // 4. 底部确定与结果提示
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyWin ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isMyWin ? '🎉 我赢了！收下筹码' : '查看完毕，继续下一局',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
