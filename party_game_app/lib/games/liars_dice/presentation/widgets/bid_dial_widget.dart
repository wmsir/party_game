import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/dice_bid.dart';
import 'dice_3d_widget.dart';

/// 叫点轮盘与出价控制面板
class BidDialWidget extends StatefulWidget {
  final DiceBid? currentBid;
  final int totalPlayers;
  final bool isWild1Active;
  final bool isMyTurn;
  final Function(int count, int face, bool isPure) onBid;
  final VoidCallback onChallenge;
  final VoidCallback? onSpotOn;
  final bool canRerollStraight;
  final VoidCallback? onRerollStraight;

  const BidDialWidget({
    Key? key,
    required this.currentBid,
    required this.totalPlayers,
    required this.isWild1Active,
    required this.isMyTurn,
    required this.onBid,
    required this.onChallenge,
    this.onSpotOn,
    this.canRerollStraight = false,
    this.onRerollStraight,
  }) : super(key: key);

  @override
  State<BidDialWidget> createState() => _BidDialWidgetState();
}

class _BidDialWidgetState extends State<BidDialWidget> {
  late int _selectedCount;
  late int _selectedFace;
  bool _isPure = false;

  @override
  void initState() {
    super.initState();
    _resetBidDefaults();
  }

  @override
  void didUpdateWidget(covariant BidDialWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentBid != widget.currentBid) {
      _resetBidDefaults();
    }
  }

  void _resetBidDefaults() {
    final prev = widget.currentBid;
    if (prev == null) {
      // 默认起叫：总人数 + 1
      _selectedCount = max(2, widget.totalPlayers + 1);
      _selectedFace = 2;
      _isPure = false;
    } else if (prev.isPure || !widget.isWild1Active) {
      // 斋局序列：2 < 3 < 4 < 5 < 6 < 1
      _isPure = true;
      if (prev.face == 1) {
        _selectedCount = prev.count + 1;
        _selectedFace = 2;
      } else if (prev.face == 6) {
        _selectedCount = prev.count;
        _selectedFace = 1;
      } else {
        _selectedCount = prev.count;
        _selectedFace = prev.face + 1;
      }
    } else {
      // 飞局序列：2 < 3 < 4 < 5 < 6，满6升数量
      _isPure = false;
      if (prev.face == 6) {
        _selectedCount = prev.count + 1;
        _selectedFace = 2;
      } else {
        _selectedCount = prev.count;
        _selectedFace = prev.face + 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prev = widget.currentBid;
    final canChallenge = prev != null && widget.isMyTurn;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前最高叫点提示条
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: prev == null ? const Color(0xFF0F172A) : const Color(0xFF312E81).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: prev == null ? const Color(0xFF334155) : const Color(0xFF6366F1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    prev == null ? Icons.info_outline : Icons.volume_up,
                    color: prev == null ? const Color(0xFF94A3B8) : const Color(0xFFFBBF24),
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prev == null
                          ? '还没有玩家起叫，请由首位玩家起叫！'
                          : '当前最高：【${prev.bidderName}】叫出 ${prev.count} 个 ${prev.face} ${prev.isPure ? '【斋/纯】' : '【飞/通配】'}',
                      style: TextStyle(
                        color: prev == null ? const Color(0xFF94A3B8) : const Color(0xFFFDE68A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 出价数量与点数调节器 (紧凑防溢出布局)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 数量调节 (- / Count / +)
                Flexible(
                  child: Column(
                    children: [
                      const Text('叫点个数', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.remove, color: Color(0xFFF59E0B), size: 18),
                              onPressed: () {
                                if (_selectedCount > 2) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCount--);
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$_selectedCount 个',
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add, color: Color(0xFFF59E0B), size: 18),
                              onPressed: () {
                                if (_selectedCount < widget.totalPlayers * 5) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCount++);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 斋 / 纯 切换
                Flexible(
                  child: Column(
                    children: [
                      const Text('规则状态', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      const SizedBox(height: 4),
                      FilterChip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        selected: _isPure || !widget.isWild1Active,
                        label: Text(
                          _isPure || !widget.isWild1Active ? '🎯 斋 (无通配)' : '🕊️ 飞 (1点万能)',
                          style: TextStyle(
                            color: _isPure ? const Color(0xFFFDE68A) : const Color(0xFF5EEAD4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                        selectedColor: const Color(0xFF78350F).withValues(alpha: 0.7),
                        side: BorderSide(
                          color: _isPure ? const Color(0xFFF59E0B) : const Color(0xFF14B8A6),
                        ),
                        onSelected: (!widget.isWild1Active || (prev?.isPure ?? false))
                            ? null
                            : (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (_selectedFace == 1) {
                                    _isPure = true;
                                  } else {
                                    _isPure = val;
                                  }
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 骰子点数 1~6 选择器
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(6, (index) {
                final faceVal = index + 1;
                final isSelected = _selectedFace == faceVal;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedFace = faceVal;
                      if (faceVal == 1) {
                        _isPure = true; // 叫1点默认无飞
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF59E0B).withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Dice3DWidget(
                      value: faceVal,
                      size: 38,
                      isHighlighted: isSelected,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            if (widget.canRerollStraight && widget.onRerollStraight != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onRerollStraight,
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFBBF24)),
                    label: const Text('✨ 顺子手牌 · 免费重摇一次', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFDE68A),
                      backgroundColor: const Color(0xFF78350F).withValues(alpha: 0.35),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),

            // 操作按钮群：开/劈 vs 劈准 vs 叫点确认
            Row(
              children: [
                // 开/劈 按钮
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: canChallenge ? widget.onChallenge : null,
                    icon: const Icon(Icons.flash_on, color: Colors.white, size: 17),
                    label: const Text('开！(劈他)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF334155),
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (widget.onSpotOn != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: canChallenge ? widget.onSpotOn : null,
                      icon: const Icon(Icons.my_location, color: Colors.white, size: 15),
                      label: const Text('劈准(2x)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF334155),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),

                // 叫点 按钮
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: widget.isMyTurn
                        ? () {
                            HapticFeedback.lightImpact();
                            widget.onBid(_selectedCount, _selectedFace, _isPure);
                          }
                        : null,
                    icon: const Icon(Icons.volume_up, color: Colors.white, size: 17),
                    label: Text(
                      widget.isMyTurn ? '叫：$_selectedCount个$_selectedFace' : '等待他叫点...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF334155),
                      disabledForegroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
