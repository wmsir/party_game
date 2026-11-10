import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../models/global_blessing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../shop/widgets/recharge_dialog.dart';

class GlobalBlessingDialog extends StatefulWidget {
  const GlobalBlessingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const GlobalBlessingDialog(),
    );
  }

  @override
  State<GlobalBlessingDialog> createState() => _GlobalBlessingDialogState();
}

class _GlobalBlessingDialogState extends State<GlobalBlessingDialog> {
  int _selectedTierIndex = 0;
  final TextEditingController _textCtrl = TextEditingController();

  // 4 档全局特效与播报
  static const List<Map<String, dynamic>> _tiers = [
    {
      'id': 'MARQUEE',
      'name': '全服喇叭',
      'emoji': '📢',
      'priceCoins': 50,
      'priceDiamonds': 10,
      'tag': '全服跑马灯',
      'desc': '顶部横向滚动祝福横幅，全服在线玩家均可看到！',
      'itemType': 'MARQUEE',
    },
    {
      'id': 'ROCKET',
      'name': '超级火箭盛典',
      'emoji': '🚀',
      'priceCoins': 200,
      'priceDiamonds': 18,
      'tag': '全屏飞天',
      'desc': '穿云破空直冲九霄，附带全服横幅跑马灯与粒子冲击波！',
      'itemType': 'ROCKET',
    },
    {
      'id': 'YACHT',
      'name': '豪华超跑炸场',
      'emoji': '🏎️',
      'priceCoins': 500,
      'priceDiamonds': 58,
      'tag': '声浪出街',
      'desc': '顶级引擎声浪甩尾漂移，全屏跑道与华丽横幅播报！',
      'itemType': 'YACHT',
    },
    {
      'id': 'CASTLE',
      'name': '梦幻城堡至尊',
      'emoji': '🏰',
      'priceCoins': 1000,
      'priceDiamonds': 168,
      'tag': '全服最高排面',
      'desc': '童话城堡拔地而起，全屏金光礼炮与全服荣耀跑马灯！',
      'itemType': 'CASTLE',
    },
  ];

  static const List<String> _presetBlessings = [
    '🎉 祝大家天天开心，把把暴击赢大奖！',
    '🌟 祝全服小伙伴财源广进，万事顺意！',
    '🔥 今晚全场由我买单！全服狂欢嗨起来！',
    '👑 大吉大利，今晚吃鸡，牌运亨通！',
    '❤️ 愿得一人心，白首不相离，祝有情人终成眷属！',
  ];

  @override
  void initState() {
    super.initState();
    _textCtrl.text = _presetBlessings[0];
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _onSend(AuthProvider auth, ChatProvider chatProv) {
    final user = auth.user;
    if (user == null) return;

    final tier = _tiers[_selectedTierIndex];
    final costCoins = tier['priceCoins'] as int;
    final costDiamonds = tier['priceDiamonds'] as int;
    final blessingText = _textCtrl.text.trim();

    if (blessingText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入祝福播报内容~')),
      );
      return;
    }

    // 优先金币，金币不足则检查钻石
    bool useCoins = true;
    if (user.coins >= costCoins) {
      useCoins = true;
    } else if (user.diamonds >= costDiamonds) {
      useCoins = false;
    } else {
      _showInsufficientBalanceDialog(costCoins, costDiamonds);
      return;
    }

    // 扣费
    if (useCoins) {
      auth.awardCoins(-costCoins);
    } else {
      auth.awardDiamonds(-costDiamonds);
    }

    final blessing = GlobalBlessingModel(
      id: 'BLS-${DateTime.now().millisecondsSinceEpoch}',
      broadcastType: tier['id'] as String,
      senderId: user.id,
      senderName: user.nickname,
      senderAvatar: user.avatar,
      senderVip: user.vipLevel,
      blessing: blessingText,
      itemType: tier['itemType'] as String,
      itemEmoji: tier['emoji'] as String,
      giftTitle: tier['name'] as String,
    );

    // 广播全服
    chatProv.sendGlobalBlessing(blessing);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Row(
          children: [
            Text(tier['emoji'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('全服广播发送成功！消耗 ${useCoins ? "$costCoins 金币" : "$costDiamonds 钻石"}'),
          ],
        ),
      ),
    );
  }

  void _showInsufficientBalanceDialog(int coins, int diamonds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.amber),
            SizedBox(width: 8),
            Text('资产余额不足', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text('发送该全服特效需要 $coins 金币 或 $diamonds 钻石，您的账户余额不足，请先前往充值！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(context: context, builder: (_) => const RechargeDialog());
            },
            child: const Text('前往充值'),
          ),
        ],
      ),
    );
  }

  void _onPreview(AuthProvider auth, ChatProvider chatProv) {
    final user = auth.user;
    if (user == null) return;
    final tier = _tiers[_selectedTierIndex];
    final blessingText = _textCtrl.text.trim().isNotEmpty
        ? _textCtrl.text.trim()
        : '祝大家万事顺意，牌运亨通！';

    final blessing = GlobalBlessingModel(
      id: 'PREV-${DateTime.now().millisecondsSinceEpoch}',
      broadcastType: tier['id'] as String,
      senderId: user.id,
      senderName: user.nickname,
      senderAvatar: user.avatar,
      senderVip: user.vipLevel,
      blessing: blessingText,
      itemType: tier['itemType'] as String,
      itemEmoji: tier['emoji'] as String,
      giftTitle: tier['name'] as String,
    );

    // 本地触发预览
    GameSoundService().playVictory();
    chatProv.finishCurrentBlessing();
    // 稍后入队，展示跑马灯与全屏动效
    Future.delayed(const Duration(milliseconds: 100), () {
      if (tier['itemType'] != 'MARQUEE') {
        chatProv.throwItem(
          senderId: user.id,
          senderName: user.nickname,
          senderAvatar: user.avatar,
          targetPlayerId: 'ALL',
          targetPlayerName: '全服玩家',
          itemType: tier['itemType'] as String,
          itemEmoji: tier['emoji'] as String,
          giftTitle: tier['name'] as String,
          isGlobal: true,
          blessing: blessingText,
        );
      }
      chatProv.sendGlobalBlessing(blessing);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('正在播放本地特效与横幅预览...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final user = auth.user;
    final coins = user?.coins ?? 0;
    final diamonds = user?.diamonds ?? 0;
    final tier = _tiers[_selectedTierIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1428),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB800).withOpacity(0.3),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头部横幅标题
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4C1D95), Color(0xFF831843), Color(0xFF78350F)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('📢', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '全服横向祝福播报与全局盛典',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '向全服在线玩家推送跑马灯横幅与全屏顶级动效',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11,
                            ),
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

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 特效档位选择网格
                    const Text(
                      '选择全服特效档位：',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tiers.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (ctx, idx) {
                        final item = _tiers[idx];
                        final isSelected = _selectedTierIndex == idx;
                        return InkWell(
                          onTap: () => setState(() => _selectedTierIndex = idx),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6B21A8).withOpacity(0.4)
                                  : const Color(0xFF271B38),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFFD700) : Colors.white24,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.35),
                                        blurRadius: 10,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(item['emoji'] as String, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item['name'] as String,
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item['priceCoins']} 金币',
                                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '/${item['priceDiamonds']} 钻',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 2. 快捷预设祝福语
                    const Text(
                      '常用吉祥祝福语（点击快速填入）：',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _presetBlessings.map((p) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _textCtrl.text = p;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1E40),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              p,
                              style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 11),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // 3. 自定义祝福语输入框
                    TextField(
                      controller: _textCtrl,
                      maxLength: 40,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF130B1C),
                        hintText: '输入想要播报的全服祝福或喊话 (40字以内)...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4. 当前资产与扣减信息
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF281C38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('当前资产: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('🪙 $coins', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(width: 8),
                              Text('💎 $diamonds', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('本次消耗: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${tier['priceCoins']} 金币',
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 5. 底部按钮区
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD700),
                              side: const BorderSide(color: Color(0xFFFFD700)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _onPreview(auth, chatProv),
                            child: const Text('👁️ 本地预览'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _onSend(auth, chatProv),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('📢 ', style: TextStyle(fontSize: 16)),
                                    Text(
                                      '立即全服广播',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
