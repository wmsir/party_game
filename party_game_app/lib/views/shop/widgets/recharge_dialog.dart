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
                    backgroundColor: AppColors.adaptiveCard(receiptCtx),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF10B981))),
                    title: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                        const SizedBox(width: 8),
                        Flexible(child: Text('支付成功 · 资产已入账', style: TextStyle(color: AppColors.adaptiveTextPrimary(receiptCtx), fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('已通过 $channelName 完成模拟支付 ¥${tier.priceRmb}.00', style: TextStyle(color: AppColors.adaptiveTextSecondary(receiptCtx), fontSize: 13)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.adaptiveBg(receiptCtx), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💎 到账钻石: +$diamondsAward 颗', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('🪙 赠送金币: +${tier.coins} 聚会金币', style: TextStyle(color: AppColors.adaptiveAccent(receiptCtx), fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('⭐ VIP成长值: +${tier.vipExp} Exp', style: TextStyle(color: AppColors.adaptiveAccent(receiptCtx), fontSize: 13)),
                              if (newVip > oldVip) ...[
                                const SizedBox(height: 6),
                                Text('👑 恭喜！尊贵 VIP 等级升级为 Lv.$newVip！', style: TextStyle(color: AppColors.adaptivePrimary(receiptCtx), fontWeight: FontWeight.bold, fontSize: 13)),
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: (MediaQuery.sizeOf(ctx).height * 0.86).clamp(360.0, 640.0),
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveCard(ctx),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                const Text('💳', style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '聚会收银台 · 演示体验',
                                    style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.adaptiveTextSecondary(ctx), size: 20),
                            onPressed: () => Navigator.pop(cashierCtx),
                          ),
                        ],
                      ),
                      Divider(color: AppColors.adaptiveBorder(ctx)),
                      const SizedBox(height: 8),
                      // 订单信息
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(tier.title, style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('¥ ${tier.priceRmb}.00', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('到账 $diamondsAward 钻石 + ${tier.coins} 金币 (+${tier.vipExp} VIP成长值)', style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 11)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withValues(alpha: 0.35))),
                        child: Text(
                          '⚠️ 【演示体验提示】：测试联调通道无需真实扣费，点击即可模拟入账体验。虚拟道具不可反向兑换法定货币或转让；未成年人严禁充值。',
                          style: TextStyle(color: AppColors.adaptiveAccent(ctx), fontSize: 10.5, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('选择支付方式 (支持模拟入账测试):', style: TextStyle(color: AppColors.adaptiveTextMuted(ctx), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // 微信支付选项
                      InkWell(
                        onTap: () => setCashierState(() => selectedChannel = 'WXPAY'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981).withValues(alpha: 0.12) : AppColors.adaptiveBg(ctx),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981) : AppColors.adaptiveBorder(ctx),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('微信支付 (WeChat Pay)', style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('亿万用户的首选支付方式', style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Icon(
                                selectedChannel == 'WXPAY' ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: selectedChannel == 'WXPAY' ? const Color(0xFF10B981) : AppColors.adaptiveTextMuted(ctx),
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
                            color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF).withValues(alpha: 0.12) : AppColors.adaptiveBg(ctx),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF) : AppColors.adaptiveBorder(ctx),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('支付宝支付 (Alipay)', style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('数亿用户的快速安全支付', style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Icon(
                                selectedChannel == 'ALIPAY' ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: selectedChannel == 'ALIPAY' ? const Color(0xFF1677FF) : AppColors.adaptiveTextMuted(ctx),
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

    final maxDialogHeight = (MediaQuery.sizeOf(context).height * 0.86).clamp(400.0, 660.0);
    final tabViewHeight = (MediaQuery.sizeOf(context).height * 0.45).clamp(240.0, 380.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: AppColors.adaptiveCard(context),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.adaptiveBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.adaptiveBorder(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💎 ', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12)),
                        Flexible(
                          child: Text(
                            '${user?.diamonds ?? 0}',
                            style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 14, width: 1, color: AppColors.adaptiveBorder(context)),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🪙 ', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12)),
                        Flexible(
                          child: Text(
                            '${user?.coins ?? 0}',
                            style: TextStyle(color: AppColors.adaptiveAccent(context), fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 14, width: 1, color: AppColors.adaptiveBorder(context)),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👑 ', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12)),
                        Text('Lv.${user?.vipLevel ?? 0}', style: TextStyle(color: AppColors.adaptiveAccent(context), fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 栏
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.adaptiveElevated(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.adaptiveBorder(context)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFF59E0B),
                indicatorWeight: 3,
                labelColor: const Color(0xFFD97706),
                unselectedLabelColor: AppColors.adaptiveTextMuted(context),
                tabs: const [
                  Tab(text: '💎 钻石充值'),
                  Tab(text: '🪙 钻石换金币'),
                ],
              ),
            ),

            // Tab 内容
            Flexible(
              child: SizedBox(
                height: tabViewHeight,
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
                            color: AppColors.adaptiveElevated(ctx),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.adaptiveBorder(ctx)),
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
                                        Flexible(
                                          child: Text(
                                            t.title,
                                            style: TextStyle(color: AppColors.adaptiveTextPrimary(ctx), fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                                      style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 11),
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
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz, color: Color(0xFFF59E0B), size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '官方固定兑换比例：1 颗钻石 = 100 聚会金币。\n金币可用于普通装扮购买、对局筹码与互动道具。',
                                    style: TextStyle(color: AppColors.adaptiveAccent(context), fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('快捷选择兑换钻石数量:', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12, fontWeight: FontWeight.bold)),
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
                                  color: isSel ? Colors.black : AppColors.adaptiveTextPrimary(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                backgroundColor: AppColors.adaptiveElevated(context),
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
                              Text('预计可获得金币:', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 13)),
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
