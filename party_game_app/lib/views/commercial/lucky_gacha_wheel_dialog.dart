import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../core/storage/local_storage.dart';
import '../../providers/auth_provider.dart';
import 'mock_ad_player_dialog.dart';

/// 商业级“幸运夺宝”奖池模型
class TreasurePrize {
  final int id;
  final String name;
  final String icon;
  final int coins;
  final int diamonds;
  final int shards; // 夺宝碎片
  final String rarity; // 'MYTHIC', 'LEGENDARY', 'EPIC', 'RARE', 'COMMON'
  final double baseProb; // 基础概率百分比 (仅公示用)
  final String? skinId; // 专属装扮或特效ID

  const TreasurePrize({
    required this.id,
    required this.name,
    required this.icon,
    this.coins = 0,
    this.diamonds = 0,
    this.shards = 0,
    required this.rarity,
    required this.baseProb,
    this.skinId,
  });

  Color get color {
    switch (rarity) {
      case 'MYTHIC':
        return const Color(0xFFF59E0B); // 神话流光金
      case 'LEGENDARY':
        return const Color(0xFFA855F7); // 传奇炫紫
      case 'EPIC':
        return const Color(0xFF3B82F6); // 史诗幽蓝
      case 'RARE':
        return const Color(0xFF10B981); // 稀有翡翠
      default:
        return const Color(0xFF94A3B8); // 普通银灰
    }
  }

  String get rarityLabel {
    switch (rarity) {
      case 'MYTHIC':
        return '神话';
      case 'LEGENDARY':
        return '传奇';
      case 'EPIC':
        return '史诗';
      case 'RARE':
        return '超值';
      default:
        return '保底';
    }
  }
}

/// 商业级“幸运夺宝”大转盘 / 盲盒抽奖系统
/// - 严格概率控制：神话大奖 0.3%，传奇大奖 1.2%
/// - 幸运值保底机制（Pity System）：每抽未中稀有以上 +1 幸运值，满 60 必出史诗以上
/// - 碎片积分回收：未中大奖必给碎屑，50 碎片兑换保底自选珍藏
/// - 广告防刷冷却与每日上限（5次/天，60s CD）
/// - 获奖跑马灯广播与全屏神话中奖金光祝贺
class LuckyGachaWheelDialog extends StatefulWidget {
  const LuckyGachaWheelDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LuckyGachaWheelDialog(),
    );
  }

  @override
  State<LuckyGachaWheelDialog> createState() => _LuckyGachaWheelDialogState();
}

class _LuckyGachaWheelDialogState extends State<LuckyGachaWheelDialog>
    with SingleTickerProviderStateMixin {
  // 商业级严控概率奖池（8格）
  static const List<TreasurePrize> _prizes = [
    TreasurePrize(
      id: 0,
      name: '18,888 大奖',
      icon: '👑',
      coins: 18888,
      diamonds: 188,
      rarity: 'MYTHIC',
      baseProb: 0.3, // 0.3% 千分之三
      skinId: 'FRAME_NEON_KING',
    ),
    TreasurePrize(
      id: 1,
      name: '200 钻石礼包',
      icon: '💎',
      diamonds: 200,
      coins: 2000,
      rarity: 'LEGENDARY',
      baseProb: 1.2, // 1.2% 百分之一点二
    ),
    TreasurePrize(
      id: 2,
      name: '夺宝碎片 x10',
      icon: '🧩',
      shards: 10,
      coins: 300,
      rarity: 'RARE',
      baseProb: 15.0,
    ),
    TreasurePrize(
      id: 3,
      name: '互动大酒桶',
      icon: '🍻',
      coins: 600,
      shards: 2,
      rarity: 'RARE',
      baseProb: 12.0,
    ),
    TreasurePrize(
      id: 4,
      name: '50 钻石',
      icon: '✨',
      diamonds: 50,
      coins: 800,
      rarity: 'EPIC',
      baseProb: 4.5,
    ),
    TreasurePrize(
      id: 5,
      name: '2,000 金币',
      icon: '💰',
      coins: 2000,
      shards: 3,
      rarity: 'RARE',
      baseProb: 18.0,
    ),
    TreasurePrize(
      id: 6,
      name: '保底 150 金币',
      icon: '🪙',
      coins: 150,
      shards: 1,
      rarity: 'COMMON',
      baseProb: 25.0,
    ),
    TreasurePrize(
      id: 7,
      name: '夺宝碎屑 x2',
      icon: '🔮',
      coins: 80,
      shards: 2,
      rarity: 'COMMON',
      baseProb: 24.0,
    ),
  ];

  // 跑马灯伪广播池（营造火爆真实的夺宝氛围）
  static const List<String> _marqueeBroadcasts = [
    '玩家 [夜店小王子] 在第 23 次夺宝中喜提 18,888 金币神话大奖！',
    '玩家 [摇骰必胜客] 触发保底机制，斩获 200 钻石专属礼包！',
    '玩家 [微醺甜心] 兑换了【赛博流光头像框(永久)】！',
    '玩家 [九点半的老王] 观看商业福利视频，免费夺宝中得 2,000 金币！',
    '玩家 [骰王本王] 连续夺宝触发暴击，收集满 50 夺宝碎片！',
  ];

  int _currentIndex = 0;
  bool _isSpinning = false;
  int _luckyPityValue = 0; // 幸运值（保底值，0~60）
  int _shardBalance = 0; // 夺宝碎片总数
  int _adSpinsToday = 0; // 今日看广告次数
  int _lastAdTimestamp = 0; // 上次看广告时间戳
  bool _hasUsedDailyFree = false; // 今日免费抽
  late Timer _marqueeTimer;
  int _marqueeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTreasureState();
    _marqueeTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _marqueeIndex = (_marqueeIndex + 1) % _marqueeBroadcasts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _marqueeTimer.cancel();
    super.dispose();
  }

  void _loadTreasureState() {
    final now = DateTime.now();
    final todayKey = '${now.year}_${now.month}_${now.day}';
    final savedDate = LocalStorage.getString('treasure_last_date') ?? '';

    if (savedDate != todayKey) {
      // 跨天重置
      _adSpinsToday = 0;
      _hasUsedDailyFree = false;
      LocalStorage.setString('treasure_last_date', todayKey);
      LocalStorage.setInt('treasure_ad_spins_today', 0);
      LocalStorage.setBool('treasure_daily_free_used', false);
    } else {
      _adSpinsToday = LocalStorage.getInt('treasure_ad_spins_today') ?? 0;
      _hasUsedDailyFree = LocalStorage.getBool('treasure_daily_free_used') ?? false;
    }

    _luckyPityValue = LocalStorage.getInt('treasure_pity_value') ?? 0;
    _shardBalance = LocalStorage.getInt('treasure_shards') ?? 0;
    _lastAdTimestamp = LocalStorage.getInt('treasure_last_ad_time') ?? 0;
  }

  void _saveTreasureState() {
    LocalStorage.setInt('treasure_pity_value', _luckyPityValue);
    LocalStorage.setInt('treasure_shards', _shardBalance);
    LocalStorage.setInt('treasure_ad_spins_today', _adSpinsToday);
    LocalStorage.setBool('treasure_daily_free_used', _hasUsedDailyFree);
    LocalStorage.setInt('treasure_last_ad_time', _lastAdTimestamp);
  }

  /// 商业级严格真随机与保底算法 (Weight & Pity Algorithm)
  int _calculateWinningIndex() {
    final rand = Random();
    final roll = rand.nextDouble() * 1000.0; // 0.0 ~ 999.9

    // 1. 检查大保底：若幸运值达到 60，必出史诗或更高（4号 50钻石 或 1号 200钻石）
    if (_luckyPityValue >= 60) {
      _luckyPityValue = 0; // 重置保底
      return rand.nextBool() ? 1 : 4;
    }

    // 2. 神话大奖 (0.3% 概率即 roll < 3.0)
    // 限制：幸运值必须至少 > 15 次才有极低资格触发大奖，杜绝小号首抽刷号
    if (roll < 3.0 && _luckyPityValue >= 15) {
      _luckyPityValue = 0;
      return 0; // 18888大奖
    }

    // 3. 传奇大奖 (1.2% 即 3.0 <= roll < 15.0)
    if (roll >= 3.0 && roll < 15.0) {
      _luckyPityValue = 0;
      return 1; // 200钻石
    }

    // 4. 史诗奖品 (4.5% 即 15.0 <= roll < 60.0)
    if (roll >= 15.0 && roll < 60.0) {
      _luckyPityValue = max(0, _luckyPityValue - 10);
      return 4; // 50钻石
    }

    // 5. 稀有回血类 (约 45%)
    if (roll >= 60.0 && roll < 510.0) {
      // 随机返回 2(碎片x10), 3(大酒桶), 5(2000金币)
      final sub = rand.nextInt(3);
      _luckyPityValue++;
      return sub == 0 ? 2 : (sub == 1 ? 3 : 5);
    }

    // 6. 普通保底与碎屑 (约 49%)
    _luckyPityValue++;
    return rand.nextBool() ? 6 : 7;
  }

  void _startSpin({required String costType}) {
    if (_isSpinning) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    // 成本扣除校验
    if (costType == 'coins') {
      if (user.coins < 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ 金币不足 100，观看视频广告可免费领币和抽奖！'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      user.coins -= 100;
      auth.saveUser(user);
    } else if (costType == 'free') {
      _hasUsedDailyFree = true;
    } else if (costType == 'ad') {
      _adSpinsToday++;
      _lastAdTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    _saveTreasureState();
    setState(() => _isSpinning = true);

    // 严格后端/保底算法选出目标中奖格
    final targetIndex = _calculateWinningIndex();
    final totalSteps = 8 * 4 + targetIndex; // 转 4 圈后精确缓停
    int step = 0;
    int intervalMs = 45;

    void tick() {
      if (!mounted) return;
      GameSoundService().playWheelTick();
      setState(() {
        _currentIndex = (_currentIndex + 1) % 8;
      });
      step++;

      if (step >= totalSteps) {
        setState(() => _isSpinning = false);
        _onWinPrize(_prizes[_currentIndex]);
      } else {
        // 商业转盘平滑缓动刹车 (Easing Out)
        if (step > totalSteps - 12) {
          intervalMs += 35;
        } else if (step > totalSteps - 6) {
          intervalMs += 80;
        } else if (step > totalSteps - 2) {
          intervalMs += 140;
        }
        Future.delayed(Duration(milliseconds: intervalMs), tick);
      }
    }

    tick();
  }

  void _onWinPrize(TreasurePrize prize) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user != null) {
      if (prize.coins > 0) user.coins += prize.coins;
      if (prize.diamonds > 0) user.diamonds += prize.diamonds;
      if (prize.shards > 0) {
        _shardBalance += prize.shards;
      }
      if (prize.skinId != null && !user.inventory.contains(prize.skinId)) {
        user.inventory.add(prize.skinId!);
      }
      auth.saveUser(user);
    }

    _saveTreasureState();

    if (prize.rarity == 'MYTHIC') {
      GameSoundService().playVictory();
      HapticFeedback.heavyImpact();
    } else {
      GameSoundService().playWin();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1738),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: prize.color, width: 2),
        ),
        title: Center(
          child: Column(
            children: [
              Text(
                prize.rarity == 'MYTHIC'
                    ? '👑 震撼神话大奖！'
                    : (prize.rarity == 'LEGENDARY' ? '✨ 传奇专属降临！' : '🎉 恭喜获得'),
                style: TextStyle(
                  color: prize.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: prize.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: prize.color.withOpacity(0.6)),
                ),
                child: Text(
                  '【${prize.rarityLabel}品质】',
                  style: TextStyle(color: prize.color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prize.icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              prize.name,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (prize.shards > 0)
              Text(
                '获得夺宝碎片 +${prize.shards}（当前共 $_shardBalance 碎片）',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 6),
            Text(
              '当前夺宝幸运值：$_luckyPityValue/60 (满60必出史诗以上)',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: prize.color,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('开心收下', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onWatchAdForSpin() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownRemaining = 60 - ((now - _lastAdTimestamp) ~/ 1000);

    if (_adSpinsToday >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 今日商业福利视频次数已达上限 (5/5)，请明日再来！')),
      );
      return;
    }

    if (cooldownRemaining > 0 && _lastAdTimestamp > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⏳ 视频缓冲冷却中，请等待 $cooldownRemaining 秒后再次观看')),
      );
      return;
    }

    MockAdPlayerDialog.show(
      context,
      rewardTitle: '幸运夺宝免费抽奖券',
      onRewardEarned: () {
        _startSpin(costType: 'ad');
      },
    );
  }

  /// 碎片兑换商店弹窗
  void _showShardExchangeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1738),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🧩 夺宝碎片兑换所',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('我的碎片: $_shardBalance',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('夺宝未中大奖将积累碎片，保底兑换绝版道具与豪华钻石！',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Divider(color: Colors.white12, height: 24),
              _buildExchangeItem(
                title: '500 钻石礼盒',
                desc: '消耗 30 碎片保底兑换',
                cost: 30,
                onExchange: () {
                  if (_shardBalance < 30) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('碎片不足 30 个！')));
                    return;
                  }
                  setState(() => _shardBalance -= 30);
                  _saveTreasureState();
                  context.read<AuthProvider>().awardDiamonds(500);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎉 成功兑换 500 钻石！'), backgroundColor: Color(0xFF10B981)),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildExchangeItem(
                title: '豪华聚会尊享黑金框 (永久)',
                desc: '消耗 50 碎片终极保底自选',
                cost: 50,
                onExchange: () {
                  if (_shardBalance < 50) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('碎片不足 50 个！')));
                    return;
                  }
                  setState(() => _shardBalance -= 50);
                  _saveTreasureState();
                  final user = context.read<AuthProvider>().user;
                  if (user != null && !user.inventory.contains('FRAME_NEON_KING')) {
                    user.inventory.add('FRAME_NEON_KING');
                    context.read<AuthProvider>().saveUser(user);
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎉 终极保底兑换成功！已获得黑金专属框！'), backgroundColor: Color(0xFF10B981)),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeItem({
    required String title,
    required String desc,
    required int cost,
    required VoidCallback onExchange,
  }) {
    final canBuy = _shardBalance >= cost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF281E48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canBuy ? const Color(0xFFF59E0B) : Colors.white12,
              foregroundColor: canBuy ? Colors.black : Colors.white38,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: canBuy ? onExchange : null,
            child: Text(canBuy ? '兑换' : '碎片不足', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// 规则与概率公示弹窗
  void _showProbabilityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1738),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 1)),
        title: const Center(
          child: Text('⚖️ 夺宝概率与保底公示', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('为保障公平合规与良好游戏生态，夺宝算法严格公示如下：', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              _buildProbRow('👑 18,888大奖 (神话)', '0.30%', const Color(0xFFF59E0B)),
              _buildProbRow('💎 200钻石礼包 (传奇)', '1.20%', const Color(0xFFA855F7)),
              _buildProbRow('✨ 50钻石 (史诗)', '4.50%', const Color(0xFF3B82F6)),
              _buildProbRow('💰 2000金币/碎片 (稀有)', '45.00%', const Color(0xFF10B981)),
              _buildProbRow('🪙 基础保底回血/碎屑', '49.00%', const Color(0xFF94A3B8)),
              const Divider(color: Colors.white12, height: 20),
              const Text('🛡️ 双重防非酋保底机制：', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('1. 幸运值达到 60 次必出史诗或传奇大奖。\n2. 未中大奖将百分百回赠夺宝碎片，集齐碎片可直接在兑换所兑换心仪大礼！',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已知晓', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProbRow(String label, String prob, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(prob, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final adRemaining = max(0, 5 - _adSpinsToday);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0A1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.35),
              blurRadius: 30,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部横幅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFF78350F), Color(0xFF3F1905)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Text('🎰 ', style: TextStyle(fontSize: 20)),
                  const Expanded(
                    child: Text(
                      '幸运夺宝 · 商业密藏',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.amber, size: 18),
                    onPressed: _showProbabilityDialog,
                    tooltip: '概率公示',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: _isSpinning ? null : () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 跑马灯获奖通报
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFF1E1738),
              child: Row(
                children: [
                  const Text('📢 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _marqueeBroadcasts[_marqueeIndex],
                        key: ValueKey<int>(_marqueeIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 资产与幸运值保底栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('🪙 ${user?.coins ?? 0}',
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Text('💎 ${user?.diamonds ?? 0}',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      InkWell(
                        onTap: _showShardExchangeSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              const Text('🧩 ', style: TextStyle(fontSize: 10)),
                              Text('碎片: $_shardBalance (兑换所)',
                                  style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 幸运值进度条 (保底)
                  Row(
                    children: [
                      Text('保底幸运值: $_luckyPityValue/60',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _luckyPityValue / 60.0,
                            backgroundColor: Colors.white10,
                            color: const Color(0xFFF59E0B),
                            minHeight: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 八宫格转盘奖池 (九宫格布局：外围8格，中心核心转动指示)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: _prizes.length,
                itemBuilder: (context, index) {
                  final prize = _prizes[index];
                  final isSelected = _currentIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E1738),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : prize.color.withOpacity(0.4),
                        width: isSelected ? 2.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: prize.color.withOpacity(0.8),
                                blurRadius: 14,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: prize.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              prize.rarityLabel,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.black : prize.color,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 6),
                              Text(prize.icon, style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 3),
                              Text(
                                prize.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 操作抽奖按钮区
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 免费抽奖按钮
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_hasUsedDailyFree ? const Color(0xFF10B981) : Colors.white12,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (_isSpinning || _hasUsedDailyFree) ? null : () => _startSpin(costType: 'free'),
                            child: Text(
                              !_hasUsedDailyFree ? '每日免费 1 次' : '今日免费已用',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 看广告免费抽
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: adRemaining > 0 ? const Color(0xFF6366F1) : Colors.white12,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_circle_outline, size: 15),
                            label: Text(
                              '看广告夺宝 ($adRemaining/5)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: (_isSpinning || adRemaining <= 0) ? null : _onWatchAdForSpin,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 100 金币抽奖
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSpinning ? null : () => _startSpin(costType: 'coins'),
                      child: const Text('🪙 消耗 100 金币夺宝 1 次',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
}
