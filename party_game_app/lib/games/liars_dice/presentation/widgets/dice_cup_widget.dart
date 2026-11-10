import 'package:flutter/material.dart';
import '../../domain/dice_model.dart';
import 'dice_3d_widget.dart';

/// 骰盅小部件 - 支持多人数紧凑排布、醒目掀开/遮挡切换、3D质感与点数智能速查
class DiceCupWidget extends StatefulWidget {
  final String playerName;
  final DiceCupModel cup;
  final bool isCurrentTurn;
  final bool isSelf;
  final bool isRevealedAll; // 游戏结束开盅揭晓
  final int? highlightFace;
  final bool isWild1Active;
  final int chips;
  final VoidCallback? onTap;

  const DiceCupWidget({
    Key? key,
    required this.playerName,
    required this.cup,
    this.isCurrentTurn = false,
    this.isSelf = false,
    this.isRevealedAll = false,
    this.highlightFace,
    this.isWild1Active = true,
    this.chips = 100,
    this.onTap,
  }) : super(key: key);

  @override
  State<DiceCupWidget> createState() => _DiceCupWidgetState();
}

class _DiceCupWidgetState extends State<DiceCupWidget> {
  // 自己的骰盅默认掀开，方便玩家直接看点；支持一键遮挡防窥
  late bool _isPeeking;

  @override
  void initState() {
    super.initState();
    _isPeeking = widget.isSelf;
  }

  @override
  void didUpdateWidget(covariant DiceCupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当进入新一局时默认掀开
    if (widget.isSelf && oldWidget.cup != widget.cup) {
      _isPeeking = true;
    }
  }

  /// 统计自己的手牌点数分析（含百搭通配1点）
  String _buildSelfTallyInfo() {
    final dice = widget.cup.dice;
    if (dice.isEmpty) return '';

    if (widget.highlightFace != null) {
      final targetFace = widget.highlightFace!;
      final targetCount = dice.where((d) => d.value == targetFace).length;
      final wildCount = (widget.isWild1Active && targetFace != 1)
          ? dice.where((d) => d.value == 1).length
          : 0;
      final total = targetCount + wildCount;

      if (wildCount > 0) {
        return '当前叫 $targetFace 点：手牌有 $targetCount 个 + $wildCount 个通配1点 = 共 $total 个！';
      } else {
        return '当前叫 $targetFace 点：手牌共有 $total 个！';
      }
    } else {
      // 统计手牌点数分布
      final counts = <int, int>{};
      for (final d in dice) {
        counts[d.value] = (counts[d.value] ?? 0) + 1;
      }
      final parts = counts.entries.map((e) => '${e.value}个${e.key}点').join('、');
      return '手牌分布：$parts';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 对手紧凑席位渲染
    if (!widget.isSelf) {
      return _buildCompactOpponentCard(context);
    }

    // 玩家本人的大号主控骰盅
    return _buildSelfMainCup(context);
  }

  /// 对手紧凑型席位卡片 (适用于 2~8 人多人数自适应排布)
  Widget _buildCompactOpponentCard(BuildContext context) {
    final isTurn = widget.isCurrentTurn;
    final isRevealed = widget.isRevealedAll;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isTurn
              ? const Color(0xFFFEF3C7)
              : const Color(0xFF1E293B).withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTurn ? const Color(0xFFF59E0B) : const Color(0xFF334155),
            width: isTurn ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isTurn)
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头像与回合提示
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isTurn ? const Color(0xFFD97706) : const Color(0xFF0F766E),
                  child: Text(
                    widget.playerName.isNotEmpty ? widget.playerName.characters.first : '玩',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isTurn)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up, color: Colors.white, size: 9),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // 昵称 (截断保证不溢出)
            Text(
              widget.playerName,
              style: TextStyle(
                color: isTurn ? const Color(0xFF92400E) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // 筹码
            Text(
              '🪙 ${widget.chips}',
              style: TextStyle(
                color: isTurn ? const Color(0xFFB45309) : const Color(0xFFFBBF24),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // 骰盅状态：未开盅为精致“5粒🔒”，开盅平铺点数
            if (!isRevealed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isTurn ? const Color(0xFFFDE68A) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isTurn ? const Color(0xFFD97706) : const Color(0xFF475569),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🥤', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 2),
                    Text(
                      '5粒🔒',
                      style: TextStyle(
                        color: isTurn ? const Color(0xFF92400E) : const Color(0xFFE2E8F0),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              // 开盅后：5 粒微型骰子点数
              Wrap(
                spacing: 1.5,
                runSpacing: 1.5,
                alignment: WrapAlignment.center,
                children: widget.cup.dice.map((d) {
                  final isMatch = widget.highlightFace != null &&
                      (d.value == widget.highlightFace || (widget.isWild1Active && d.value == 1));
                  return Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: isMatch ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isMatch ? const Color(0xFFD97706) : Colors.grey.shade400,
                        width: isMatch ? 1.2 : 0.6,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${d.value}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: d.value == 1 || d.value == 4 ? Colors.red : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  /// 玩家本人专属大号 3D 骰盅
  Widget _buildSelfMainCup(BuildContext context) {
    final isOpen = widget.isRevealedAll || _isPeeking;
    final tallyText = _buildSelfTallyInfo();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isCurrentTurn
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isCurrentTurn ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          width: widget.isCurrentTurn ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isCurrentTurn ? const Color(0xFFF59E0B).withOpacity(0.2) : Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部栏：标题 + 轮次指示 + 【掀开/遮挡防窥】切换大胶囊按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎲 我的骰盅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  if (widget.isCurrentTurn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('👉 轮到您叫点/开', style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),

              // 掀开 / 扣上防窥 一键操作胶囊按钮
              if (!widget.isRevealedAll)
                InkWell(
                  onTap: () => setState(() => _isPeeking = !_isPeeking),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: _isPeeking
                          ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)])
                          : const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF047857)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_isPeeking ? const Color(0xFFD97706) : const Color(0xFF0D9488)).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPeeking ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPeeking ? '扣上防窥 🙈' : '掀开看点 👁️',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 核心展示区：掀开展示 5 颗 3D 大骰子；遮挡展示精致闭合骰盅盖
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isOpen
                ? Column(
                    key: const ValueKey('open'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: widget.cup.dice.map((d) {
                            final isMatch = widget.highlightFace != null &&
                                (d.value == widget.highlightFace ||
                                    (widget.isWild1Active && d.value == 1));

                            return Dice3DWidget(
                              value: d.value,
                              size: 44,
                              isHighlighted: isMatch,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 智能手牌点数分析速查
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          tallyText,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    key: const ValueKey('covered'),
                    onTap: () => setState(() => _isPeeking = true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF78350F), Color(0xFF451A03)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.6), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.shield_outlined, color: Color(0xFFFDE68A), size: 28),
                          SizedBox(height: 6),
                          Text(
                            '🔒 骰盅已扣紧遮挡 (5粒在内)',
                            style: TextStyle(color: Color(0xFFFDE68A), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '点此或右上角按钮随时掀开查看 👁️',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

