import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/shop_models.dart';
import '../../../providers/auth_provider.dart';

class RechargeDialog extends StatefulWidget {
  final int initialTab;
  const RechargeDialog({super.key, this.initialTab = 0});

  @override
  State<RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends State<RechargeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<RechargeTierItem> tiers = [
    RechargeTierItem(
      id: 'tier_6',
      priceRmb: 6,
      diamonds: 666,
      coins: 66666,
      vipExp: 60,
      isFirstDouble: false,
      title: '6元首充特惠豪华包',
      badge: '直升VIP1',
    ),
    RechargeTierItem(
      id: 'tier_30',
      priceRmb: 30,
      diamonds: 300,
      coins: 5000,
      vipExp: 300,
      isFirstDouble: true,
      title: '30元微醺畅玩包',
      badge: '超值特惠',
    ),
    RechargeTierItem(
      id: 'tier_68',
      priceRmb: 68,
      diamonds: 680,
      coins: 12000,
      vipExp: 680,
      isFirstDouble: true,
      title: '68元骰王进阶包',
      badge: '热门首选',
    ),
    RechargeTierItem(
      id: 'tier_128',
      priceRmb: 128,
      diamonds: 1280,
      coins: 25000,
      vipExp: 1280,
      isFirstDouble: true,
      title: '128元雀圣霸主包',
      badge: '尊享特权',
    ),
    RechargeTierItem(
      id: 'tier_328',
      priceRmb: 328,
      diamonds: 3280,
      coins: 70000,
      vipExp: 3280,
      isFirstDouble: true,
      title: '328元至尊神豪包',
      badge: '神豪首选',
    ),
    RechargeTierItem(
      id: 'tier_648',
      priceRmb: 648,
      diamonds: 6480,
      coins: 150000,
      vipExp: 6480,
      isFirstDouble: true,
      title: '648元君临天下包',
      badge: '至尊加冕',
    ),
  ];

  int _selectedConvertDiamonds = 50;
  final TextEditingController _customConvertCtrl = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customConvertCtrl.dispose();
    super.dispose();
  }

  /// 弹出规范化聚会收银台 (支持微信支付与支付宝支付选择)
  void _openCashier(BuildContext parentContext, RechargeTierItem tier) {
    String selectedChannel = 'WXPAY'; // 'WXPAY' or 'ALIPAY'

    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (cashierCtx) {
        return StatefulBuilder(
          builder: (ctx, setCashierState) {
            final auth = parentContext.read<AuthProvider>();
            final diamondsAward = tier.isFirstDouble ? tier.diamonds * 2 : tier.diamonds;

            Future<void> doSimulatedPay() async {
              Navigator.pop(cashierCtx); // 关闭收银台

              final oldVip = auth.user?.vipLevel ?? 0;
              await auth.payCashier(tier, selectedChannel);
              final newVip = auth.user?.vipLevel ?? 0;

              if (parentContext.mounted) {
                final channelName = selectedChannel == 'WXPAY' ? '微信支付' : '支付宝';
                showDialog(
                  context: parentContext,
                  builder: (receiptCtx) => AlertDialog(
                    backgroundColor: AppColors.cardSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF10B981))),
                    title: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                        SizedBox(width: 8),
                        Text('支付成功 · 资产已入账', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('已通过 $channelName 完成模拟支付 ¥${tier.priceRmb}.00', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💎 到账钻石: +$diamondsAward 颗', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('🪙 赠送金币: +${tier.coins} 聚会金币', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('⭐ VIP成长值: +${tier.vipExp} Exp', style: const TextStyle(color: Colors.amber, fontSize: 13)),
                              if (newVip > oldVip) ...[
                                const SizedBox(height: 6),
                                Text('👑 恭喜！尊贵 VIP 等级升级为 Lv.$newVip！', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        onPressed: () => Navigator.pop(receiptCtx),
                        child: const Text('我知道了', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Text('💳', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 8),
                            Text('聚会收银台 · 【演示体验通道】', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(cashierCtx),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    // 订单信息
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tier.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('¥ ${tier.priceRmb}.00', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('到账 $diamondsAward 钻石 + ${tier.coins} 金币 (+${tier.vipExp} VIP成长值)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                      child: const Text('⚠️ 【演示体验提示】：测试联调通道无需真实扣费，点击即可模拟入账体验。虚拟道具不可反向兑换法定货币或转让；未成年人严禁充值。', style: TextStyle(color: Colors.amberAccent, fontSize: 10.5, height: 1.4)),
                    ),
                    const SizedBox(height: 14),
                    const Text('选择支付方式 (支持模拟入账测试):', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // 微信支付选项
                    InkWell(
                      onTap: () => setCashierState(() => selectedChannel = 'WXPAY'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981).withOpacity(0.12) : AppColors.bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981) : AppColors.border,
                            width: selectedChannel == 'WXPAY' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: const Color(0xFF07C160), borderRadius: BorderRadius.circular(8)),
                              alignment: Alignment.center,
                              child: const Text('💬', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('微信支付 (WeChat Pay)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('亿万用户的首选支付方式', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                            Icon(
                              selectedChannel == 'WXPAY' ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981) : AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 支付宝选项
                    InkWell(
                      onTap: () => setCashierState(() => selectedChannel = 'ALIPAY'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF).withOpacity(0.12) : AppColors.bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF) : AppColors.border,
                            width: selectedChannel == 'ALIPAY' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: const Color(0xFF1677FF), borderRadius: BorderRadius.circular(8)),
                              alignment: Alignment.center,
                              child: const Text('支', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('支付宝支付 (Alipay)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('数亿用户的快速安全支付', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                            Icon(
                              selectedChannel == 'ALIPAY' ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF) : AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 立即支付按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedChannel == 'WXPAY' ? const Color(0xFF07C160) : const Color(0xFF1677FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: doSimulatedPay,
                        child: Text(
                          '立即支付 ¥${tier.priceRmb}.00 (模拟到账)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withAlpha(50),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部横幅
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFF78350F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '聚会充值与资产中心',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1元=10钻石 · 1钻=100金币 · 首充赠双倍钻石',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
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

            // 当前资产栏
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Text('💎 钻石: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${user?.diamonds ?? 0}', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Container(height: 14, width: 1, color: AppColors.border),
                  Row(
                    children: [
                      const Text('🪙 金币: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${user?.coins ?? 0}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Container(height: 14, width: 1, color: AppColors.border),
                  Row(
                    children: [
                      const Text('👑 VIP: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('Lv.${user?.vipLevel ?? 0}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            // Tab 栏
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFF59E0B),
                indicatorWeight: 3,
                labelColor: const Color(0xFFF59E0B),
                unselectedLabelColor: AppColors.textMuted,
                tabs: const [
                  Tab(text: '💎 钻石充值 (送双倍)'),
                  Tab(text: '🪙 钻石兑换金币 (1:100)'),
                ],
              ),
            ),

            // Tab 内容
            Flexible(
              child: SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. 充值档位列表
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: tiers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final t = tiers[idx];
                        final diamondsShow = t.isFirstDouble ? t.diamonds * 2 : t.diamonds;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    t.priceRmb >= 128 ? '👑' : (t.priceRmb >= 68 ? '💎' : '💰'),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(t.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withAlpha(40),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.redAccent.withAlpha(120)),
                                          ),
                                          child: Text(t.badge, style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '获得 $diamondsShow 钻石 + ${t.coins} 金币 (+${t.vipExp} VIP成长值)',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _openCashier(context, t),
                                child: Text('¥ ${t.priceRmb}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 2. 钻石兑换金币面板 (1:100)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.swap_horiz, color: Color(0xFFF59E0B), size: 24),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '官方固定兑换比例：1 颗钻石 = 100 聚会金币。\n金币可用于普通装扮购买、对局筹码与互动道具。',
                                    style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('快捷选择兑换钻石数量:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [10, 50, 100, 200, 500, 1000].map((d) {
                              final isSel = _selectedConvertDiamonds == d;
                              return ChoiceChip(
                                label: Text('$d 钻 (=${d * 100}金币)'),
                                selected: isSel,
                                selectedColor: const Color(0xFFF59E0B),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.black : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: AppColors.bgElevated,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedConvertDiamonds = d;
                                      _customConvertCtrl.text = d.toString();
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customConvertCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '输入兑换钻石数量',
                              hintText: '例如: 100',
                              prefixIcon: Icon(Icons.diamond_outlined, color: AppColors.cyan),
                              suffixText: '颗钻石',
                            ),
                            onChanged: (val) {
                              final n = int.tryParse(val.trim()) ?? 0;
                              setState(() => _selectedConvertDiamonds = n);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('预计可获得金币:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              Text(
                                '${_selectedConvertDiamonds * 100} 🪙 聚会金币',
                                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final diamonds = int.tryParse(_customConvertCtrl.text.trim()) ?? 0;
                                if (diamonds <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入合法的兑换数量')));
                                  return;
                                }
                                if ((user?.diamonds ?? 0) < diamonds) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💎 钻石余额不足，请先充值')));
                                  return;
                                }
                                await auth.convertDiamondsToCoins(diamonds);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('🎉 恭喜！成功使用 $diamonds 钻石兑换 ${diamonds * 100} 聚会金币！'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                              child: const Text('立即确认兑换金币', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
