import 'package:flutter/material.dart';
import '../core/models/game_player.dart';
import '../hosts/standalone_offline_host/offline_host_context.dart';
import '../hosts/standalone_offline_host/offline_reward_bridge.dart';
import '../hosts/store_member_host/store_member_host_context.dart';
import '../hosts/store_member_host/store_member_reward_bridge.dart';
import '../liars_dice/presentation/liars_dice_game_screen.dart';
import '../take6/presentation/take6_game_screen.dart';
import '../core/models/game_room_model.dart';
import '../core/services/game_audio_service.dart';
import 'game_room_lobby_dialog.dart';

/// 聚会娱乐大厅 (Party Game Hall)
/// 呈现整洁架构双外壳（宿主）：门店会员系统 vs 独立单机离线模式
class PartyGameHallView extends StatefulWidget {
  final String? storeName;
  final String? currentTableNo;
  final String? memberPhone;

  const PartyGameHallView({
    Key? key,
    this.storeName,
    this.currentTableNo,
    this.memberPhone,
  }) : super(key: key);

  @override
  State<PartyGameHallView> createState() => _PartyGameHallViewState();
}

class _PartyGameHallViewState extends State<PartyGameHallView> {
  // 运行模式：0 - 独立离线单机模式，1 - 门店会员联机模式
  int _selectedModeIndex = 0;
  int _botCount = 3; // 默认 3 个 AI 对手
  String _aiDifficulty = 'BALANCED'; // BALANCED, AGGRESSIVE, CONSERVATIVE, BLUFF_MASTER
  String _tableNo = 'A08';

  @override
  void initState() {
    super.initState();
    if (widget.currentTableNo != null && widget.currentTableNo!.isNotEmpty) {
      _tableNo = widget.currentTableNo!;
      _selectedModeIndex = 1; // 门店已提供桌号时默认进入门店模式
    }
  }

  void _openGameLobby(String gameType, {String? customRoomCode}) {
    final myPlayer = GamePlayer(
      id: 'P-ME',
      name: widget.memberPhone != null && widget.memberPhone!.length >= 4
          ? '会员(${widget.memberPhone!.substring(widget.memberPhone!.length - 4)})'
          : '我 (房主)',
      isAi: false,
    );

    final room = customRoomCode != null && customRoomCode.isNotEmpty
        ? GameRoomModel(
            roomCode: customRoomCode,
            gameType: gameType,
            hostPlayerId: myPlayer.id,
            storeName: widget.storeName ?? '海马生活馆',
            tableNo: _tableNo,
            players: [myPlayer],
          )
        : GameRoomModel.create(
            gameType: gameType,
            hostPlayer: myPlayer,
            storeName: widget.storeName ?? '海马生活馆',
            tableNo: _tableNo,
          );

    // 若玩家之前配置了 AI 机器人数量且目前只有房主自己，自动补入初始 AI 席位供房主预览
    if (_botCount > 0) {
      room.fillAiToCount(1 + _botCount);
      // 赋予当前选中的难度风格
      for (final p in room.players) {
        if (p.isAi) {
          room.updateAiPersonality(p.id, _aiDifficulty);
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (lobbyCtx) => GameRoomLobbyView(
          room: room,
          onStartGame: (readyRoom) {
            Navigator.pop(lobbyCtx);
            if (gameType == 'take6') {
              _launchTake6WithRoom(readyRoom);
            } else {
              _launchLiarsDiceWithRoom(readyRoom);
            }
          },
        ),
      ),
    );
  }

  void _showJoinRoomDialog() {
    final codeCtrl = TextEditingController();
    String selectedGame = 'take6';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 8),
              Text(
                '输入房间号加入对局',
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择游戏类别:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('谁是牛头王'),
                      selected: selectedGame == 'take6',
                      selectedColor: const Color(0xFFFDE68A),
                      labelStyle: TextStyle(
                        color: selectedGame == 'take6' ? const Color(0xFF92400E) : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) => setDState(() => selectedGame = 'take6'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('大话骰'),
                      selected: selectedGame == 'liars_dice',
                      selectedColor: const Color(0xFFCCFBF1),
                      labelStyle: TextStyle(
                        color: selectedGame == 'liars_dice' ? const Color(0xFF115E59) : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) => setDState(() => selectedGame = 'liars_dice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('输入 6 位房间号:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 22,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '如 882619',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, letterSpacing: 1),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final code = codeCtrl.text.trim();
                if (code.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入合法的 6 位房间号')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _openGameLobby(selectedGame, customRoomCode: code);
              },
              icon: const Icon(Icons.login, size: 16),
              label: const Text('立即进入房间'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchTake6WithRoom(GameRoomModel room) {
    final myPlayer = room.players.firstWhere((p) => !p.isAi, orElse: () => room.players.first);
    final isStoreMode = _selectedModeIndex == 1;

    final hostContext = isStoreMode
        ? StoreMemberHostContext(
            storeName: widget.storeName ?? '海马旗舰店',
            tableNo: _tableNo,
            memberPhone: widget.memberPhone,
          )
        : OfflineHostContext(customAppName: '谁是牛头王 · 独立单机版');

    final rewardBridge = isStoreMode
        ? StoreMemberRewardBridge(
            currentMemberId: myPlayer.id,
            onRewardGranted: (pts, desc) => _showRewardToast(desc),
          )
        : OfflineRewardBridge(
            localPlayerId: myPlayer.id,
            onAchievementUnlocked: (ach) => _showRewardToast('🎉 解锁新成就: $ach'),
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Take6GameScreen.createOffline(
          players: room.players,
          localPlayerId: myPlayer.id,
          rewardBridge: rewardBridge,
          hostContext: hostContext,
          roomCode: room.roomCode,
        ),
      ),
    );
  }

  void _launchLiarsDiceWithRoom(GameRoomModel room) {
    final myPlayer = room.players.firstWhere((p) => !p.isAi, orElse: () => room.players.first);
    final isStoreMode = _selectedModeIndex == 1;

    final hostContext = isStoreMode
        ? StoreMemberHostContext(
            storeName: widget.storeName ?? '海马旗舰店',
            tableNo: _tableNo,
            memberPhone: widget.memberPhone,
          )
        : OfflineHostContext(customAppName: '骰子街 · 独立单机版');

    final rewardBridge = isStoreMode
        ? StoreMemberRewardBridge(
            currentMemberId: myPlayer.id,
            onRewardGranted: (pts, desc) => _showRewardToast(desc),
          )
        : OfflineRewardBridge(
            localPlayerId: myPlayer.id,
            onAchievementUnlocked: (ach) => _showRewardToast('🎉 解锁新成就: $ach'),
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiarsDiceGameScreen.createOffline(
          players: room.players,
          myPlayerId: myPlayer.id,
          rewardBridge: rewardBridge,
          hostContext: hostContext,
          roomCode: room.roomCode,
        ),
      ),
    );
  }

  void _showRewardToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // 护眼柔和浅灰底色
      appBar: AppBar(
        title: const Text(
          '聚会桌游大厅 · Clean Architecture',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(
              GameAudioService().isBgmEnabled ? Icons.music_note : Icons.music_off,
              color: GameAudioService().isBgmEnabled ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
            ),
            tooltip: '背景音乐开关',
            onPressed: () {
              setState(() {
                GameAudioService().toggleBgm();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF475569)),
            tooltip: '游戏与AI设置',
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部宿主模式切换控制器
            _buildHostModeSelector(),

            // 状态徽章条 (本地筹码 / 门店积分)
            _buildStatusHeader(),

            // 房间号加入与邀请专区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openGameLobby('take6'),
                      icon: const Icon(Icons.add_home_outlined, size: 18),
                      label: const Text('创建幸运房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showJoinRoomDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('输入房间号加入', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 游戏卡片区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  _buildGameCard(
                    title: '🐂 谁是牛头王 (Take 6! / 6 Nimmt!)',
                    subtitle: '德国经典数学博弈 · 极度解压聚会卡牌',
                    tag: '策略出牌 · 避牛排雷',
                    color: const Color(0xFFD97706),
                    bannerAsset: 'assets/images/take6_banner.png',
                    description: '• 1~104 号牛头卡牌，纯领域引擎驱动\n'
                        '• 4 排队列，每排放满 5 张，放置第 6 张者吃下整排牛头！\n'
                        '• 启发式 AI 并发计算，支持 2~10 人随时开杀',
                    onPlay: () => _openGameLobby('take6'),
                  ),
                  const SizedBox(height: 18),
                  _buildGameCard(
                    title: '🎲 骰子街 / 大话骰 (Liar\'s Dice)',
                    subtitle: '酒吧KTV必备吹牛神器 · 3D拟真摇骰窥盅',
                    tag: '心理博弈 · 诈唬开劈',
                    color: const Color(0xFF0D9488),
                    bannerAsset: 'assets/images/dice_banner.png',
                    description: '• 物理质感 3D 骰子，支持长按“掀盖偷瞄”防偷看\n'
                        '• 1 点通配/飞，叫斋规则，二项分布博弈 AI 机器人\n'
                        '• 支持真实手机物理摇晃感应摇骰与清脆碰撞音效',
                    onPlay: () => _openGameLobby('liars_dice'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostModeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedModeIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedModeIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedModeIndex == 0
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 16,
                        color: _selectedModeIndex == 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '独立单机 / 离线聚会',
                        style: TextStyle(
                          color: _selectedModeIndex == 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                          fontWeight: _selectedModeIndex == 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedModeIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedModeIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedModeIndex == 1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront,
                        size: 16,
                        color: _selectedModeIndex == 1 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '门店会员联机对战',
                        style: TextStyle(
                          color: _selectedModeIndex == 1 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                          fontWeight: _selectedModeIndex == 1 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
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
    );
  }

  Widget _buildStatusHeader() {
    final isStore = _selectedModeIndex == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isStore ? const Color(0xFFFFF7ED) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStore ? const Color(0xFFFDBA74) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStore ? Icons.local_activity : Icons.stars,
            color: isStore ? const Color(0xFFEA580C) : const Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isStore
                  ? '当前宿主：${widget.storeName ?? "海马生活馆"} · 桌号: $_tableNo (赢局累计积分与赠饮券)'
                  : '当前宿主：离线单机沙盒 · 筹码: 🪙 ${OfflineRewardBridge.localChips} · 连胜: ${OfflineRewardBridge.winStreak}次',
              style: TextStyle(
                color: isStore ? const Color(0xFF9A3412) : const Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
    required String bannerAsset,
    required String description,
    required VoidCallback onPlay,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头部彩带
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 核心说明
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSettingsDialog,
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text('AI: $_botCount人 (${_getPersonalityName(_aiDifficulty)})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_circle_fill, size: 18),
                        label: const Text('立即开局', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  String _getPersonalityName(String key) {
    switch (key) {
      case 'BALANCED':
        return '均衡型';
      case 'AGGRESSIVE':
        return '激进型';
      case 'CONSERVATIVE':
        return '稳健型';
      case 'BLUFF_MASTER':
        return '老千型';
      default:
        return '标准';
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⚙️ 游戏对局与 AI 设置', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI 机器人数量:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Slider(
                value: _botCount.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_botCount 人',
                activeColor: const Color(0xFFD97706),
                onChanged: (val) {
                  setDialogState(() => _botCount = val.toInt());
                  setState(() => _botCount = val.toInt());
                },
              ),
              const SizedBox(height: 10),
              const Text('AI 行为性格风格:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: _aiDifficulty,
                dropdownColor: Colors.white,
                isExpanded: true,
                style: const TextStyle(color: Color(0xFF1E293B)),
                items: const [
                  DropdownMenuItem(value: 'BALANCED', child: Text('均衡大师 (计算期望平衡)')),
                  DropdownMenuItem(value: 'AGGRESSIVE', child: Text('嗜血进攻 (疯狂加码顶价)')),
                  DropdownMenuItem(value: 'CONSERVATIVE', child: Text('稳健保守 (极低容差易劈)')),
                  DropdownMenuItem(value: 'BLUFF_MASTER', child: Text('老千诈唬 (假动作放烟雾弹)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => _aiDifficulty = val);
                    setState(() => _aiDifficulty = val);
                  }
                },
              ),
              if (_selectedModeIndex == 1) ...[
                const SizedBox(height: 12),
                const Text('门店包厢 / 桌号:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 4),
                TextField(
                  style: const TextStyle(color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: '如: A08',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  controller: TextEditingController(text: _tableNo),
                  onChanged: (val) => _tableNo = val,
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确定保存'),
            ),
          ],
        ),
      ),
    );
  }
}
