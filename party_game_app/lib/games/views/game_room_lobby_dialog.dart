import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/game_room_model.dart';
import '../core/services/game_audio_service.dart';

/// 聚会桌游 - 全屏房间等候与席位调配大厅 (Full-Screen Game Room Lobby View)
/// 支持返回上一级、6 位房间号复制、手机号邀请、AI 席位自由增删改、一键补齐
class GameRoomLobbyView extends StatefulWidget {
  final GameRoomModel room;
  final Function(GameRoomModel updatedRoom) onStartGame;

  const GameRoomLobbyView({
    Key? key,
    required this.room,
    required this.onStartGame,
  }) : super(key: key);

  @override
  State<GameRoomLobbyView> createState() => _GameRoomLobbyViewState();
}

/// 兼容别名
typedef GameRoomLobbyDialog = GameRoomLobbyView;

class _GameRoomLobbyViewState extends State<GameRoomLobbyView> {
  late GameRoomModel _room;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  void _copyRoomCode() {
    final gameTitle = _room.gameType == 'take6' ? '谁是牛头王' : '骰子街/大话骰';
    final inviteText = '【海马聚会桌游】好友邀请您加入《$gameTitle》！\n👉 房间号：${_room.roomCode}\n快打开海马 App，在游戏大厅输入房间号即可进入对局！';
    Clipboard.setData(ClipboardData(text: inviteText));
    GameAudioService().playSound('bid_ding');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 房间号 ${_room.roomCode} 邀请信息已复制到剪贴板！'),
        backgroundColor: const Color(0xFF0D9488),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInvitePhoneDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Color(0xFF0D9488), size: 22),
            SizedBox(width: 8),
            Text('通过手机号邀请好友', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '输入好友手机号，系统将发送房间号与入场邀请：',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: '请输入好友手机号',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF0D9488), size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: '好友昵称 (选填)',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF0D9488), size: 18),
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
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null;

              setState(() {
                _room.inviteFriendByPhone(phone, friendName: name);
              });
              GameAudioService().playSound('bid_ding');
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📨 邀请成功！好友【${name ?? phone}】已进入房间！'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('发送邀请并入房'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _addAiDialog() {
    String selectedPersonality = 'BALANCED';
    final nameCtrl = TextEditingController(text: 'AI选手${_room.aiCount + 1}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('👥 呼叫在线玩家', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('玩家昵称 (留空自动匹配):', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('博弈思考性格风格:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: selectedPersonality,
                dropdownColor: Colors.white,
                isExpanded: true,
                style: const TextStyle(color: Color(0xFF1E293B)),
                items: const [
                  DropdownMenuItem(value: 'BALANCED', child: Text('⚖️ 均衡大师 (数学期望计算)')),
                  DropdownMenuItem(value: 'AGGRESSIVE', child: Text('🔥 嗜血激进 (狂暴顶价进攻)')),
                  DropdownMenuItem(value: 'CONSERVATIVE', child: Text('🛡️ 稳健保守 (极低容差防守)')),
                  DropdownMenuItem(value: 'BLUFF_MASTER', child: Text('🎭 老千诈唬 (放假动作烟雾弹)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDState(() => selectedPersonality = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _room.addAiPlayer(
                    customName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                    personality: selectedPersonality,
                  );
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确认添加'),
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final gameTitle = _room.gameType == 'take6' ? '🐮 谁是牛头王' : '🎲 骰子街 / 大话骰';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // 护眼柔和浅灰底色
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          tooltip: '返回大厅',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              '创建房间 · 等候大厅',
              style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              '当前游戏：$gameTitle',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：明亮护眼 6 位房间号展示大卡
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '房间号',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _room.roomCode,
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _copyRoomCode,
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('复制邀请', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB45309),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // 快捷控制工具条：手机号邀请 / 加AI / 补齐 / 清空
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showInvitePhoneDialog,
                      icon: const Icon(Icons.phone_android, size: 16),
                      label: const Text('手机号邀请好友', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _room.players.length < _room.maxCapacity ? _addAiDialog : null,
                    icon: const Icon(Icons.smart_toy, size: 16, color: Color(0xFFD97706)),
                    label: const Text('+ 添加AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _room.fillAiToCount(4);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('补齐4人', style: TextStyle(fontSize: 12)),
                  ),
                  if (_room.aiCount > 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _room.clearAllAi();
                        });
                      },
                      child: const Text('清空AI', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 席位统计条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '当前房间席位 (${_room.players.length}/${_room.maxCapacity}人)',
                    style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '真人: ${_room.humanCount}  |  AI机器人: ${_room.aiCount}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 玩家与 AI 席位卡片列表 (明亮护眼洁白卡片)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _room.players.length,
                itemBuilder: (ctx, index) {
                  final p = _room.players[index];
                  final isHost = p.id == _room.hostPlayerId;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isHost ? const Color(0xFFF59E0B) : (p.isAi ? const Color(0xFFE2E8F0) : const Color(0xFF14B8A6)),
                        width: isHost ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isHost ? const Color(0xFFFEF3C7) : const Color(0xFFCCFBF1),
                          child: Icon(
                            isHost ? Icons.workspace_premium : Icons.person,
                            color: isHost ? const Color(0xFFD97706) : const Color(0xFF0F766E),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isHost)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('房主', style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                '已就绪 · 在线',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        // 席位操作按钮：可请离非房主席位
                        if (!isHost) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20),
                            tooltip: '请离该席位',
                            onPressed: () {
                              setState(() {
                                _room.players.removeWhere((item) => item.id == p.id);
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // 底部：全宽立即开始游戏主按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _room.canStartGame
                    ? () {
                        GameAudioService().playSound('victory');
                        Navigator.pop(context);
                        widget.onStartGame(_room);
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  _room.canStartGame ? '🚀 人员已就绪，立即开局！' : '至少需要 2 位玩家 (点击上方添加AI)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
