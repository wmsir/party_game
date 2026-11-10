import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_models.dart';
import '../../providers/auth_provider.dart';
import '../shop/widgets/recharge_dialog.dart';
import '../shop/widgets/vip_center_dialog.dart';
import '../widgets/entrance_banner_overlay.dart';
import '../commercial/global_blessing_dialog.dart';
import '../../models/chat_message_model.dart';

class DressingShopView extends StatefulWidget {
  final int initialTabIndex;
  const DressingShopView({super.key, this.initialTabIndex = 0});

  @override
  State<DressingShopView> createState() => _DressingShopViewState();
}

class _DressingShopViewState extends State<DressingShopView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<ShopGoodsItem> _diceCupSkins = [
    ShopGoodsItem(
      id: 'CLASSIC_GOLD',
      category: 'dice_cup',
      name: '经典黑金骰盅',
      priceCoins: 0,
      priceDiamonds: 0,
      icon: '🏆',
      desc: '尊贵黑金拉丝质感，聚会老手标志',
      isDefault: true,
    ),
    ShopGoodsItem(
      id: 'NEON_CYBER',
      category: 'dice_cup',
      name: '赛博霓虹骰盅',
      priceCoins: 5000,
      priceDiamonds: 0,
      icon: '⚡',
      desc: '赛博朋克流光幻彩，夜晚开局焦点 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'PURPLE_GALAXY',
      category: 'dice_cup',
      name: '紫晶星系骰盅',
      priceCoins: 10000,
      priceDiamonds: 0,
      icon: '🌌',
      desc: '星河流转璀璨迷人，运气爆棚加持 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'FLAME_DRAGON',
      category: 'dice_cup',
      name: '烈焰赤龙骰盅',
      priceCoins: 0,
      priceDiamonds: 88,
      icon: '🔥',
      desc: '烈火熊熊势不可挡，纯钻石奢华专属',
    ),
    ShopGoodsItem(
      id: 'PURE_DIAMOND',
      category: 'dice_cup',
      name: '璀璨钻石骰盅',
      priceCoins: 0,
      priceDiamonds: 188,
      icon: '💎',
      desc: '八心八箭至尊水晶切割，闪耀全场 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'ROYAL_DRAGON_GOLD',
      category: 'dice_cup',
      name: '至尊黄金神龙骰盅',
      priceCoins: 0,
      priceDiamonds: 288,
      minVip: 2,
      icon: '👑',
      desc: 'VIP 2 专属奢华黄金盘龙，尊崇绝伦',
    ),
  ];

  static const List<ShopGoodsItem> _avatarFrames = [
    ShopGoodsItem(
      id: 'FRAME_DEFAULT',
      category: 'avatar_frame',
      name: '聚会新星框',
      priceCoins: 0,
      priceDiamonds: 0,
      icon: '⭐',
      desc: '初入聚会社区基础装扮',
      isDefault: true,
    ),
    ShopGoodsItem(
      id: 'FRAME_NEON',
      category: 'avatar_frame',
      name: '赛博流光框',
      priceCoins: 3000,
      priceDiamonds: 0,
      icon: '🌈',
      desc: '流光幻彩渐变边框，彰显个性 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'FRAME_GOLD',
      category: 'avatar_frame',
      name: '荣耀黄金框',
      priceCoins: 8000,
      priceDiamonds: 0,
      icon: '🥇',
      desc: '璀璨真金抛光工艺，王者气派 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'FRAME_GALAXY_DOMINATOR',
      category: 'avatar_frame',
      name: '星空霸主框',
      priceCoins: 0,
      priceDiamonds: 128,
      minVip: 1,
      icon: '🌌',
      desc: 'VIP 1 专属星辰环绕动效框 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'FRAME_BLACK_GOLD_ROYAL',
      category: 'avatar_frame',
      name: '黑金至尊帝王框',
      priceCoins: 0,
      priceDiamonds: 388,
      minVip: 4,
      icon: '🔱',
      desc: 'VIP 4 专属黑金龙纹霸气图腾 (纯钻石专属)',
    ),
  ];

  static const List<ShopGoodsItem> _entranceBanners = [
    ShopGoodsItem(
      id: 'BANNER_DEFAULT',
      category: 'entrance_banner',
      name: '普通登场横幅',
      priceCoins: 0,
      priceDiamonds: 0,
      icon: '🚪',
      desc: '系统默认进房提示横幅',
      isDefault: true,
    ),
    ShopGoodsItem(
      id: 'BANNER_SHINE',
      category: 'entrance_banner',
      name: '闪亮登场横幅',
      priceCoins: 5000,
      priceDiamonds: 0,
      icon: '✨',
      desc: '全场星光闪烁，醒目进场焦点 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'BANNER_DRAGON',
      category: 'entrance_banner',
      name: '凤舞龙吟横幅',
      priceCoins: 0,
      priceDiamonds: 128,
      icon: '🐉',
      desc: '神龙破空进场横幅，全屏焦点 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'BANNER_EMPEROR',
      category: 'entrance_banner',
      name: '君临天下横幅',
      priceCoins: 0,
      priceDiamonds: 588,
      minVip: 3,
      icon: '👑',
      desc: 'VIP 3 专属尊贵入场全服公告 (纯钻石专属)',
    ),
  ];

  static const List<ShopGoodsItem> _chatTextColors = [
    ShopGoodsItem(
      id: 'COLOR_DEFAULT',
      category: 'chat_text_color',
      name: '默认深黛灰',
      priceCoins: 0,
      priceDiamonds: 0,
      icon: '💬',
      desc: '系统经典高对比度护眼清晰深灰发言',
      isDefault: true,
    ),
    ShopGoodsItem(
      id: 'COLOR_SAKURA_PINK',
      category: 'chat_text_color',
      name: '炫彩樱花粉',
      priceCoins: 3000,
      priceDiamonds: 0,
      icon: '🌸',
      desc: '烂漫甜美樱花粉文字，聊天少女心爆棚 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'COLOR_CYBER_BLUE',
      category: 'chat_text_color',
      name: '赛博冰川蓝',
      priceCoins: 5000,
      priceDiamonds: 0,
      icon: '💎',
      desc: '未来感极光冰蓝文字，科技感十足 (金币专享)',
    ),
    ShopGoodsItem(
      id: 'COLOR_AURORA_GREEN',
      category: 'chat_text_color',
      name: '翡翠极光绿',
      priceCoins: 0,
      priceDiamonds: 68,
      icon: '🌲',
      desc: '清爽翡翠翠绿文字，充满生机活力 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'COLOR_DEEP_PURPLE',
      category: 'chat_text_color',
      name: '幻影深空紫',
      priceCoins: 0,
      priceDiamonds: 88,
      icon: '🔮',
      desc: '神秘华贵深空紫色文字，低调奢华 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'COLOR_BLAZING_GOLD',
      category: 'chat_text_color',
      name: '炽焰曜石金',
      priceCoins: 0,
      priceDiamonds: 168,
      minVip: 2,
      icon: '👑',
      desc: 'VIP 2 专属奢华曜石炽金色文字，贵气逼人 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'COLOR_QQ_RED',
      category: 'chat_text_color',
      name: '至尊红钻绯红',
      priceCoins: 0,
      priceDiamonds: 288,
      minVip: 3,
      icon: '🩸',
      desc: 'VIP 3 尊享至尊红钻炽热绯红文字，全场焦点 (纯钻石专属)',
    ),
  ];

  static const List<ShopGoodsItem> _giftItems = [
    ShopGoodsItem(
      id: 'BATTLE_CLEAR_CARD',
      category: 'gift_prop',
      name: '战绩清空卡',
      priceCoins: 10000,
      priceDiamonds: 100,
      icon: '🧹',
      desc: '抹去过往，重塑传奇！使用后可彻底清空个人的历史对战记录 (支持金币或钻石兑换)',
    ),
    ShopGoodsItem(
      id: 'CARD_RENAME',
      category: 'gift_prop',
      name: '改名换姓卡',
      priceCoins: 0,
      priceDiamonds: 50,
      icon: '🏷️',
      desc: '尊贵昵称修改凭证，立即修改个人游戏昵称 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'PROP_TRUMPET_10',
      category: 'gift_prop',
      name: '全服广播大喇叭',
      priceCoins: 0,
      priceDiamonds: 10,
      icon: '📢',
      desc: '全服横幅跑马灯实时广播 1 次 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'BEER',
      category: 'gift_prop',
      name: '冰爽啤酒',
      priceCoins: 100,
      priceDiamonds: 0,
      icon: '🍺',
      desc: '敬TA一杯酒，聚会好朋友，互动碰杯畅饮',
    ),
    ShopGoodsItem(
      id: 'FLOWER',
      category: 'gift_prop',
      name: '浪漫玫瑰',
      priceCoins: 100,
      priceDiamonds: 0,
      icon: '💐',
      desc: '赠人玫瑰手有余香，对局互动高贵芬芳',
    ),
    ShopGoodsItem(
      id: 'EGG',
      category: 'gift_prop',
      name: '调皮臭蛋',
      priceCoins: 50,
      priceDiamonds: 0,
      icon: '🥚',
      desc: '精准打脸吹牛大师，啪叽糊上一脸',
    ),
    ShopGoodsItem(
      id: 'SLIPPER',
      category: 'gift_prop',
      name: '暴击飞拖',
      priceCoins: 80,
      priceDiamonds: 0,
      icon: '👡',
      desc: '专治各种不服，啪啪拍向对手面门',
    ),
    ShopGoodsItem(
      id: 'BOMB',
      category: 'gift_prop',
      name: '核爆飞弹',
      priceCoins: 200,
      priceDiamonds: 0,
      icon: '💣',
      desc: '轰天引爆，全屏黑烟与爆裂火花震撼全桌',
    ),
    ShopGoodsItem(
      id: 'ROCKET',
      category: 'gift_prop',
      name: '超级火箭',
      priceCoins: 0,
      priceDiamonds: 100,
      icon: '🚀',
      desc: '穿云破空直冲九霄，全服玩家见证盛典动效 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'YACHT',
      category: 'gift_prop',
      name: '豪华超跑',
      priceCoins: 0,
      priceDiamonds: 300,
      icon: '🏎️',
      desc: '轰鸣声浪霸气出街，全场焦点顶级座驾 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'CASTLE',
      category: 'gift_prop',
      name: '梦幻城堡',
      priceCoins: 0,
      priceDiamonds: 680,
      minVip: 1,
      icon: '🏰',
      desc: '浪漫至极奢华加冕，全屏流光盛典 (纯钻石专属)',
    ),
    ShopGoodsItem(
      id: 'CHAMPAGNE',
      category: 'gift_prop',
      name: '胜利香槟',
      priceCoins: 66,
      priceDiamonds: 0,
      icon: '🍾',
      desc: '开香槟热烈庆祝，全桌金波喷涌畅饮',
    ),
    ShopGoodsItem(
      id: 'HAMMER',
      category: 'gift_prop',
      name: '暴击雷锤',
      priceCoins: 30,
      priceDiamonds: 0,
      icon: '🔨',
      desc: '雷霆万钧重锤出击，啪叽敲击对手',
    ),
    ShopGoodsItem(
      id: 'KISS',
      category: 'gift_prop',
      name: '甜蜜飞吻',
      priceCoins: 25,
      priceDiamonds: 0,
      icon: '💋',
      desc: '浓情蜜意浪漫飞吻，爱心满屏飘散',
    ),
    ShopGoodsItem(
      id: 'BRICK',
      category: 'gift_prop',
      name: '糊你板砖',
      priceCoins: 20,
      priceDiamonds: 0,
      icon: '🧱',
      desc: '专治装腔作势，结结实实拍上一板砖',
    ),
    ShopGoodsItem(
      id: 'WATER_GUN',
      category: 'gift_prop',
      name: '搞笑水枪',
      priceCoins: 15,
      priceDiamonds: 0,
      icon: '🔫',
      desc: '疯狂滋水互动整蛊，清凉全场',
    ),
    ShopGoodsItem(
      id: 'POOP',
      category: 'gift_prop',
      name: '搞笑便便',
      priceCoins: 10,
      priceDiamonds: 0,
      icon: '💩',
      desc: '恶搞整蛊损友必备，搞笑滑稽满分',
    ),
    ShopGoodsItem(
      id: 'DIAMOND_RING',
      category: 'gift_prop',
      name: '璀璨钻戒',
      priceCoins: 0,
      priceDiamonds: 88,
      icon: '💍',
      desc: '真心恒久远一颗永流传，至尊订制礼物',
    ),
    ShopGoodsItem(
      id: 'CROWN',
      category: 'gift_prop',
      name: '皇冠加冕',
      priceCoins: 0,
      priceDiamonds: 128,
      minVip: 1,
      icon: '👑',
      desc: '尊贵黄金帝皇皇冠，全服加冕称王',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final coins = user?.coins ?? 0;
    final diamonds = user?.diamonds ?? 0;
    final vipLevel = user?.vipLevel ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        titleSpacing: 8,
        title: const Text('🛍️ 聚会装扮商城', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          // 钻石计数胶囊
          InkWell(
            onTap: () => showDialog(context: context, builder: (_) => const RechargeDialog(initialTab: 0)),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38BDF8).withAlpha(120)),
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text('$diamonds', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(width: 2),
                  const Icon(Icons.add_circle, color: AppColors.cyan, size: 12),
                ],
              ),
            ),
          ),
          // 金币计数胶囊 (点击直达钻石兑换金币)
          InkWell(
            onTap: () => showDialog(context: context, builder: (_) => const RechargeDialog(initialTab: 1)),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text('$coins', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(width: 2),
                  const Icon(Icons.add_circle, color: AppColors.accent, size: 12),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: '🎲 骰盅皮肤'),
            Tab(text: '🖼️ 头像框'),
            Tab(text: '🚀 入场横幅'),
            Tab(text: '🎨 字体颜色'),
            Tab(text: '🎁 互动道具'),
            Tab(text: '📢 全服祝福'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGoodsList(
            items: _diceCupSkins,
            slot: 'dice_cup',
            currentEquippedId: user?.diceCupSkin ?? 'CLASSIC_GOLD',
            auth: auth,
            vipLevel: vipLevel,
          ),
          _buildGoodsList(
            items: _avatarFrames,
            slot: 'avatar_frame',
            currentEquippedId: user?.avatarFrame ?? 'FRAME_DEFAULT',
            auth: auth,
            vipLevel: vipLevel,
          ),
          _buildGoodsList(
            items: _entranceBanners,
            slot: 'entrance_banner',
            currentEquippedId: user?.entranceBanner ?? 'BANNER_DEFAULT',
            auth: auth,
            vipLevel: vipLevel,
          ),
          _buildGoodsList(
            items: _chatTextColors,
            slot: 'chat_text_color',
            currentEquippedId: user?.chatTextColor ?? 'COLOR_DEFAULT',
            auth: auth,
            vipLevel: vipLevel,
          ),
          _buildGoodsList(
            items: _giftItems,
            slot: 'gift_prop',
            currentEquippedId: '',
            auth: auth,
            vipLevel: vipLevel,
          ),
          _buildGlobalBlessingTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: Text('👑 VIP 俱乐部 (Lv.$vipLevel)', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const VipCenterDialog());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.diamond_outlined),
                label: const Text('充值中心 · 首充特惠', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const RechargeDialog());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoodsList({
    required List<ShopGoodsItem> items,
    required String slot,
    required String currentEquippedId,
    required AuthProvider auth,
    required int vipLevel,
  }) {
    final user = auth.user;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isOwned = user?.ownsItem(item.id) ?? false;
        final isEquipped = currentEquippedId == item.id;
        final isVipLocked = item.minVip > 0 && vipLevel < item.minVip;

        return InkWell(
          onTap: () {
            if (slot == 'entrance_banner') {
              EntranceBannerOverlay.show(
                context,
                playerName: user?.nickname ?? '神秘玩家',
                avatar: user?.avatar ?? '🦊',
                avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                vipLevel: user?.vipLevel ?? 0,
                bannerId: item.id,
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEquipped ? AppColors.primary : AppColors.border,
              width: isEquipped ? 2 : 1,
            ),
            boxShadow: isEquipped
                ? [BoxShadow(color: AppColors.primary.withAlpha(40), blurRadius: 10, spreadRadius: 1)]
                : const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              // 预览图
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.isDiamondItem ? const Color(0xFF6366F1) : const Color(0xFF334155),
                      item.minVip > 0 ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: slot == 'chat_text_color'
                      ? Text(
                          '字',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ChatMessageModel.getTextColorFromCode(item.id, defaultColor: AppColors.textPrimary),
                          ),
                        )
                      : Text(item.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              // 介绍
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isEquipped) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('佩戴中', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (item.minVip > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Text(
                              'VIP ${item.minVip}',
                              style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    if (slot == 'chat_text_color') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '💬 发言: 聚会开启，决战到天亮！',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: ChatMessageModel.getTextColorFromCode(item.id, defaultColor: AppColors.textPrimary),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.isFree
                              ? '免费默认初始获得'
                              : (item.isDiamondItem ? '单价: ${item.priceDiamonds} 钻石' : '单价: ${item.priceCoins} 聚会金币'),
                          style: TextStyle(
                            color: item.isFree ? AppColors.cyan : (item.isDiamondItem ? const Color(0xFF38BDF8) : AppColors.accent),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (slot == 'gift_prop') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (user?.getItemCount(item.id) ?? 0) > 0 ? AppColors.accent.withAlpha(25) : AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (user?.getItemCount(item.id) ?? 0) > 0 ? AppColors.accent : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '拥有 ×${user?.getItemCount(item.id) ?? 0}',
                              style: TextStyle(
                                fontSize: 10,
                                color: (user?.getItemCount(item.id) ?? 0) > 0 ? AppColors.accent : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 按钮
              if (slot == 'gift_prop')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isVipLocked ? AppColors.bgElevated : (item.isDiamondItem ? const Color(0xFF2563EB) : AppColors.primary),
                    foregroundColor: isVipLocked ? AppColors.textMuted : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isVipLocked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('⚠️ 该礼物道具为 VIP ${item.minVip} 专属特权，请提升 VIP 等级后再来解锁！')),
                          );
                        }
                      : () => _showBuyPropDialog(context, item, auth),
                  child: Text(isVipLocked ? 'VIP限制' : '选购道具', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else if (isEquipped)
                ElevatedButton(
                  onPressed: () {
                    if (slot == 'entrance_banner') {
                      EntranceBannerOverlay.show(
                        context,
                        playerName: user?.nickname ?? '神秘玩家',
                        avatar: user?.avatar ?? '🦊',
                        avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                        vipLevel: user?.vipLevel ?? 0,
                        bannerId: item.id,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withAlpha(35),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(slot == 'entrance_banner' ? '已佩戴(预览)' : '已穿戴', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (isOwned)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slot == 'entrance_banner')
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.amber),
                        tooltip: '预览入场横幅',
                        onPressed: () {
                          EntranceBannerOverlay.show(
                            context,
                            playerName: user?.nickname ?? '神秘玩家',
                            avatar: user?.avatar ?? '🦊',
                            avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                            vipLevel: user?.vipLevel ?? 0,
                            bannerId: item.id,
                          );
                        },
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        auth.equipSlot(slot, item.id);
                        if (slot == 'entrance_banner') {
                          EntranceBannerOverlay.show(
                            context,
                            playerName: user?.nickname ?? '神秘玩家',
                            avatar: user?.avatar ?? '🦊',
                            avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                            vipLevel: user?.vipLevel ?? 0,
                            bannerId: item.id,
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🎉 成功佩戴【${item.name}】！已为您展示入场特效！')),
                        );
                      },
                      child: const Text('佩戴', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slot == 'entrance_banner')
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.amber),
                        tooltip: '试看入场特效',
                        onPressed: () {
                          EntranceBannerOverlay.show(
                            context,
                            playerName: user?.nickname ?? '神秘玩家',
                            avatar: user?.avatar ?? '🦊',
                            avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                            vipLevel: user?.vipLevel ?? 0,
                            bannerId: item.id,
                          );
                        },
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVipLocked ? AppColors.bgElevated : (item.isDiamondItem ? const Color(0xFF2563EB) : AppColors.primary),
                        foregroundColor: isVipLocked ? AppColors.textMuted : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isVipLocked
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('⚠️ 该装扮为 VIP ${item.minVip} 专属特权，请提升 VIP 等级后再来解锁！')),
                              );
                            }
                          : () async {
                              final success = await auth.buyAndEquip(item, autoEquip: true);
                              if (context.mounted) {
                                if (success) {
                                  if (slot == 'entrance_banner') {
                                    EntranceBannerOverlay.show(
                                      context,
                                      playerName: user?.nickname ?? '神秘玩家',
                                      avatar: user?.avatar ?? '🦊',
                                      avatarFrame: user?.avatarFrame ?? 'FRAME_DEFAULT',
                                      vipLevel: user?.vipLevel ?? 0,
                                      bannerId: item.id,
                                    );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('🎉 成功解锁并穿戴【${item.name}】！已展示特效！')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(item.isDiamondItem ? '💎 钻石不足，快去充值吧！' : '🪙 金币不足，去对战赚取吧！'),
                                      action: item.isDiamondItem
                                          ? SnackBarAction(
                                              label: '去充值',
                                              textColor: Colors.amber,
                                              onPressed: () {
                                                showDialog(context: context, builder: (_) => const RechargeDialog());
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(
                        isVipLocked ? 'VIP限制' : (item.isDiamondItem ? '💎 购买' : '🪙 购买'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showBuyPropDialog(BuildContext context, ShopGoodsItem item, AuthProvider auth) {
    final user = auth.user;
    int selectedPackIndex = 0;
    final packs = [
      {'count': 1, 'title': '单件试用', 'discount': 1.0, 'tag': '随买随用'},
      {'count': 10, 'title': '10件超值包', 'discount': 0.9, 'tag': '立省10%'},
      {'count': 50, 'title': '50件豪横箱', 'discount': 0.8, 'tag': '劲省20%'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pack = packs[selectedPackIndex];
          final count = pack['count'] as int;
          final discount = pack['discount'] as double;
          final unitPrice = item.isDiamondItem ? item.priceDiamonds : item.priceCoins;
          final originalTotal = unitPrice * count;
          final actualTotal = (originalTotal * discount).round();
          final hasEnough = item.isDiamondItem
              ? (user?.diamonds ?? 0) >= actualTotal
              : (user?.coins ?? 0) >= actualTotal;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选购【${item.name}】互动道具',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '当前库存: ×${user?.getItemCount(item.id) ?? 0} 件',
                              style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('选择购买套餐：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(packs.length, (idx) {
                      final p = packs[idx];
                      final isSel = selectedPackIndex == idx;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedPackIndex = idx),
                          child: Container(
                            margin: EdgeInsets.only(right: idx < packs.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary.withAlpha(25) : AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel ? AppColors.primary : AppColors.border,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '×${p['count']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p['title'] as String,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.primary : AppColors.accent.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p['tag'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSel ? Colors.white : AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '应付总额: ${item.isDiamondItem ? "💎" : "🪙"} $actualTotal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.isDiamondItem ? const Color(0xFF38BDF8) : AppColors.accent,
                        ),
                      ),
                      Text(
                        '当前余额: ${item.isDiamondItem ? "💎 ${user?.diamonds ?? 0}" : "🪙 ${user?.coins ?? 0}"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasEnough ? (item.isDiamondItem ? const Color(0xFF2563EB) : AppColors.primary) : Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (!hasEnough) {
                          Navigator.pop(ctx);
                          if (item.isDiamondItem) {
                            showDialog(context: context, builder: (_) => const RechargeDialog());
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🪙 金币不足，请先对战赚取金币或充值兑换！')),
                            );
                          }
                          return;
                        }

                        final success = await auth.buyAndEquip(item, autoEquip: false, quantity: count);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 成功购入【${item.icon} ${item.name} ×$count】！库存已增加至 ${user?.getItemCount(item.id) ?? count}！'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        hasEnough ? '立即购买 (实付 ${item.isDiamondItem ? "💎" : "🪙"} $actualTotal)' : '余额不足，去充值',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlobalBlessingTab() {
    final blessings = [
      {
        'name': '全服喇叭',
        'emoji': '📢',
        'tag': '全服跑马灯',
        'cost': '50 金币 / 10 钻',
        'desc': '屏幕顶层奢华金紫胶囊跑马灯，水平横向滚屏文字，全服即时同步！',
      },
      {
        'name': '超级火箭盛典',
        'emoji': '🚀',
        'tag': '全屏飞天',
        'cost': '200 金币 / 18 钻',
        'desc': '穿云破空直冲九霄，全屏爆炸冲击波与光晕粒子，附带跑马灯！',
      },
      {
        'name': '豪华超跑炸场',
        'emoji': '🏎️',
        'tag': '轰鸣出街',
        'cost': '500 金币 / 58 钻',
        'desc': '顶级引擎声浪甩尾漂移，霸气开道，跑道特效炸裂全场！',
      },
      {
        'name': '梦幻城堡至尊',
        'emoji': '🏰',
        'tag': '至尊盛典',
        'cost': '1000 金币 / 168 钻',
        'desc': '童话城堡拔地而起，全屏金光礼炮与全服荣耀跑马灯播报！',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4C1D95), Color(0xFF831843), Color(0xFF78350F)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('📢', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '全服横向祝福播报与全局盛典',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '向所有在线玩家发送全服滚动跑马灯与华丽全屏动效',
                      style: TextStyle(color: Color(0xFFFEF08A), fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => GlobalBlessingDialog.show(context),
                child: const Text('立即广播', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '全服特效档位一览（点击任意卡片即可配置并发送）：',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...blessings.map((b) {
          return InkWell(
            onTap: () => GlobalBlessingDialog.show(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF221633), Color(0xFF180E24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B1854), Color(0xFF260D38)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6)),
                    ),
                    child: Center(child: Text(b['emoji']!, style: const TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              b['name']!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFC084FC), width: 0.8),
                              ),
                              child: Text(
                                b['tag']!,
                                style: const TextStyle(color: Color(0xFFF3E8FF), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          b['desc']!,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          b['cost']!,
                          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('配置', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios, color: Color(0xFFF59E0B), size: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
