import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../shop/widgets/recharge_dialog.dart';
import '../../services/api_service.dart';

class InGameThrowDialog extends StatefulWidget {
  final String targetPlayerId;
  final String targetPlayerName;

  const InGameThrowDialog({
    super.key,
    required this.targetPlayerId,
    required this.targetPlayerName,
  });

  static void show(BuildContext context, {required String targetPlayerId, required String targetPlayerName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InGameThrowDialog(
        targetPlayerId: targetPlayerId,
        targetPlayerName: targetPlayerName,
      ),
    );
  }

  @override
  State<InGameThrowDialog> createState() => _InGameThrowDialogState();
}

class _InGameThrowDialogState extends State<InGameThrowDialog> {
  int _selectedIndex = 0;
  int _selectedCombo = 1;
  int _intimacyScore = 0;
  String? _relationship;

  @override
  void initState() {
    super.initState();
    _fetchIntimacy();
  }

  void _fetchIntimacy() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = auth.user?.id;
    if (myId == null || myId == widget.targetPlayerId) {
      return;
    }
    final res = await ApiService().getIntimacyDetail(myId, widget.targetPlayerId);
    if (mounted && res != null) {
      setState(() {
        _intimacyScore = res['intimacyScore'] ?? 0;
        _relationship = res['relationship'];
      });
    }
  }

  void _showRelationshipPicker() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myId = auth.user?.id;
    if (myId == null) return;

    final options = [
      {'title': '朋友', 'threshold': 50, 'emoji': '🤝'},
      {'title': '发小', 'threshold': 100, 'emoji': '👦'},
      {'title': '死党', 'threshold': 100, 'emoji': '💪'},
      {'title': '知己', 'threshold': 200, 'emoji': '🍵'},
      {'title': '闺蜜', 'threshold': 200, 'emoji': '👭'},
      {'title': '基友', 'threshold': 200, 'emoji': '👬'},
      {'title': '情侣', 'threshold': 520, 'emoji': '💑'},
      {'title': '老婆', 'threshold': 520, 'emoji': '👰'},
      {'title': '老公', 'threshold': 520, 'emoji': '🤵'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '与【${widget.targetPlayerName}】缔结亲密关系',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Text(
                    '当前亲密度: $_intimacyScore 点 (赠送互动礼物即可提升)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((opt) {
                      final title = opt['title'] as String;
                      final req = opt['threshold'] as int;
                      final emoji = opt['emoji'] as String;
                      final isUnlocked = _intimacyScore >= req;
                      final isCurrent = _relationship == title;

                      return InkWell(
                        onTap: isUnlocked
                            ? () async {
                                final res = await ApiService().setIntimacyRelationship(myId, widget.targetPlayerId, title);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (res['code'] == 200) {
                                  setState(() => _relationship = title);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('🎉 恭喜！您与【${widget.targetPlayerName}】成功缔结【$title】关系！'), backgroundColor: const Color(0xFF10B981)),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res['message'] ?? '设置失败'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('亲密度不足！设置【$title】需达到 $req 亲密度，当前仅有 $_intimacyScore'), backgroundColor: const Color(0xFFD97706)),
                                );
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF10B981).withAlpha(40)
                                : (isUnlocked ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF10B981)
                                  : (isUnlocked ? const Color(0xFF3B82F6) : Colors.grey.shade800),
                              width: isCurrent ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(title, style: TextStyle(color: isUnlocked ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              if (isCurrent)
                                const Text('已缔结', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold))
                              else if (!isUnlocked)
                                Text('🔒需$req', style: TextStyle(color: Colors.grey.shade500, fontSize: 10))
                              else
                                const Text('可设置', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const List<Map<String, dynamic>> throwItems = [
    {'type': 'BEER', 'emoji': '🍺', 'name': '冰爽啤酒', 'cost': 20, 'isDiamond': false, 'desc': '敬TA一杯酒，聚会好朋友'},
    {'type': 'FLOWER', 'emoji': '💐', 'name': '浪漫玫瑰', 'cost': 20, 'isDiamond': false, 'desc': '赠人玫瑰，手有余香'},
    {'type': 'EGG', 'emoji': '🥚', 'name': '调皮臭蛋', 'cost': 10, 'isDiamond': false, 'desc': '打脸吹牛，啪叽一响'},
    {'type': 'SLIPPER', 'emoji': '👡', 'name': '暴击飞拖', 'cost': 15, 'isDiamond': false, 'desc': '酒桌互怼，专治不服'},
    {'type': 'BOMB', 'emoji': '💣', 'name': '核爆飞弹', 'cost': 50, 'isDiamond': false, 'desc': '全场轰炸，震撼全桌'},
    {'type': 'CHAMPAGNE', 'emoji': '🍾', 'name': '胜利香槟', 'cost': 66, 'isDiamond': false, 'desc': '开香槟庆祝，嗨翻全场'},
    {'type': 'HAMMER', 'emoji': '🔨', 'name': '暴击雷锤', 'cost': 30, 'isDiamond': false, 'desc': '雷霆万钧，重锤出击'},
    {'type': 'KISS', 'emoji': '💋', 'name': '甜蜜飞吻', 'cost': 25, 'isDiamond': false, 'desc': '浓情蜜意，送上飞吻'},
    {'type': 'BRICK', 'emoji': '🧱', 'name': '糊你板砖', 'cost': 20, 'isDiamond': false, 'desc': '精准投掷，糊上一脸'},
    {'type': 'WATER_GUN', 'emoji': '🔫', 'name': '搞笑水枪', 'cost': 15, 'isDiamond': false, 'desc': '疯狂滋水，清凉一夏'},
    {'type': 'POOP', 'emoji': '💩', 'name': '搞笑便便', 'cost': 10, 'isDiamond': false, 'desc': '恶搞整蛊，快乐加倍'},
    {'type': 'ROCKET', 'emoji': '🚀', 'name': '超级火箭', 'cost': 18, 'isDiamond': true, 'desc': '穿云破空，抖音刷屏大火箭'},
    {'type': 'YACHT', 'emoji': '🏎️', 'name': '豪华超跑', 'cost': 58, 'isDiamond': true, 'desc': '声浪轰鸣，霸气登场'},
    {'type': 'DIAMOND_RING', 'emoji': '💍', 'name': '璀璨钻戒', 'cost': 88, 'isDiamond': true, 'desc': '真心恒久远，一颗永流传'},
    {'type': 'CROWN', 'emoji': '👑', 'name': '皇冠加冕', 'cost': 128, 'isDiamond': true, 'desc': '加冕为王，聚会焦点'},
    {'type': 'CASTLE', 'emoji': '🏰', 'name': '嘉年华盛典', 'cost': 168, 'isDiamond': true, 'desc': '全屏金光粒子，顶级奢华'},
  ];

  static const List<int> comboOptions = [1, 5, 10, 66, 99];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final currentCoins = user?.coins ?? 0;
    final currentDiamonds = user?.diamonds ?? 0;

    final curItem = throwItems[_selectedIndex];
    final itemType = curItem['type'] as String;
    final costPerUnit = curItem['cost'] as int;
    final isDiamond = curItem['isDiamond'] as bool;
    final totalCost = costPerUnit * _selectedCombo;
    final ownedCount = user?.getItemCount(itemType) ?? 0;
    final canUseInventory = ownedCount >= _selectedCombo;
    final hasEnough = canUseInventory || (isDiamond ? (currentDiamonds >= totalCost) : (currentCoins >= totalCost));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部栏与资产胶囊
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('🎁 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        '赠送【${widget.targetPlayerName}】互动礼物',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text('$currentDiamonds', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(width: 6),
                        const Text('🪙', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text('$currentCoins', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 亲密度与亲密关系徽章栏 (送礼增加亲密度，满阈值可一键缔结/更改关系)
          if (user != null && widget.targetPlayerId != user.id)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Text('❤️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text('双方亲密度: $_intimacyScore', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                  const SizedBox(width: 8),
                  if (_relationship != null && _relationship!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                      ),
                      child: Text('【$_relationship】', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else
                    const Text('(暂未缔结关系)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showRelationshipPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withAlpha(35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                      ),
                      child: Text(
                        _relationship != null ? '更改关系' : '缔结关系',
                        style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 礼物网格 (支持滑动浏览全部16款道具)
          SizedBox(
            height: 200,
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: throwItems.length,
            itemBuilder: (ctx, idx) {
              final item = throwItems[idx];
              final isSelected = _selectedIndex == idx;
              final itemIsDiamond = item['isDiamond'] as bool;
              final cost = item['cost'] as int;
              final owned = user?.getItemCount(item['type'] as String) ?? 0;

              return InkWell(
                onTap: () => setState(() => _selectedIndex = idx),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withAlpha(35) : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item['emoji']!, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            item['name']!,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(itemIsDiamond ? '💎' : '🪙', style: const TextStyle(fontSize: 9)),
                              const SizedBox(width: 2),
                              Text(
                                '$cost',
                                style: TextStyle(
                                  color: itemIsDiamond ? const Color(0xFF38BDF8) : AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (owned > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '×$owned',
                              style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          ),
          const SizedBox(height: 12),

          // 连击选择条
          Row(
            children: [
              const Text('连击暴击：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: comboOptions.map((combo) {
                      final isSel = _selectedCombo == combo;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('×$combo', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.bgElevated,
                          labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          onSelected: (val) {
                            if (val) setState(() => _selectedCombo = combo);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 赠送操作与去充值
          Row(
            children: [
              if (!hasEnough)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('充值', style: TextStyle(fontSize: 12)),
                    onPressed: () => showDialog(context: context, builder: (_) => const RechargeDialog()),
                  ),
                ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUseInventory
                        ? const Color(0xFF059669)
                        : (hasEnough ? (isDiamond ? const Color(0xFF2563EB) : AppColors.primary) : Colors.grey.shade800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    final itemEmoji = curItem['emoji'] as String;
                    final itemName = curItem['name'] as String;

                    // 优先消耗背包中的同款互动道具，无需扣金币/钻石！
                    if (canUseInventory) {
                      auth.consumeProp(itemType, _selectedCombo);
                    } else if (hasEnough) {
                      if (isDiamond) {
                        auth.awardDiamonds(-totalCost);
                      } else {
                        auth.awardCoins(-totalCost);
                      }
                    }

                    GameSoundService().playItemHit(itemType);
                    final chatProv = Provider.of<ChatProvider>(context, listen: false);
                    chatProv.throwItem(
                      senderId: user?.id ?? 'me',
                      senderName: user?.nickname ?? user?.username ?? '我',
                      senderAvatar: user?.avatar ?? '🦁',
                      targetPlayerId: widget.targetPlayerId,
                      targetPlayerName: widget.targetPlayerName,
                      itemType: itemType,
                      itemEmoji: itemEmoji,
                      combo: _selectedCombo,
                      giftTitle: itemName,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(canUseInventory
                            ? '🎉 已从库存送出 $itemEmoji $itemName ×$_selectedCombo！(剩余 ${user?.getItemCount(itemType) ?? 0} 件)'
                            : '🎉 成功向【${widget.targetPlayerName}】送出 $itemEmoji $itemName ×$_selectedCombo！双方亲密度已提升～'),
                        backgroundColor: canUseInventory ? const Color(0xFF059669) : AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        canUseInventory
                            ? '🚀 豪横送出 (消耗库存 ×$_selectedCombo · 免费)'
                            : (hasEnough
                                ? '🚀 豪横送出 (消耗 ${isDiamond ? "💎" : "🪙"} $totalCost)'
                                : '体验赠送 (消耗 ${isDiamond ? "💎" : "🪙"} $totalCost)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
