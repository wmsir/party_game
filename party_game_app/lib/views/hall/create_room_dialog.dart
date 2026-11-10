import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../room/game_room_lobby_view.dart';

class CreateRoomDialog extends StatefulWidget {
  final String initialGameType;

  const CreateRoomDialog({Key? key, this.initialGameType = 'liars_dice'}) : super(key: key);

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  late String _selectedGameType;
  final _roomNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isPassAndPlay = false;

  final List<Map<String, String>> _games = [
    {'type': 'liars_dice', 'name': '大话骰 (吹牛)', 'icon': '🎲', 'desc': '经典酒吧KTV必玩'},
    {'type': 'take6', 'name': '谁是牛头王', 'icon': '🐂', 'desc': '德式轻策略算牌排队'},
    {'type': 'party_wheel', 'name': '聚会转盘大冒险', 'icon': '🎡', 'desc': '酒桌真心话大冒险'},
    {'type': 'undercover', 'name': '谁是卧底', 'icon': '🕵️', 'desc': '经典破冰推理猜词'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedGameType = widget.initialGameType;
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submitCreate() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final me = GamePlayer(
      id: user.id,
      name: user.nickname,
      avatar: user.avatar,
    );

    final room = context.read<RoomProvider>().createRoom(
      gameType: _selectedGameType,
      hostPlayer: me,
      roomName: _roomNameCtrl.text.trim().isNotEmpty ? _roomNameCtrl.text.trim() : null,
      password: _passwordCtrl.text.trim(),
      isPassAndPlay: _isPassAndPlay,
    );

    Navigator.pop(context); // 关闭创建弹窗
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('🏠 创建对局房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择桌游玩法：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _games.map((g) {
                final isSel = _selectedGameType == g['type'];
                return ChoiceChip(
                  label: Text('${g['icon']} ${g['name']}'),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _selectedGameType = g['type']!),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _roomNameCtrl,
              decoration: const InputDecoration(
                labelText: '房间名称 (选填)',
                hintText: '例: 不服来战局 / 喝酒切磋',
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: '房间密码 (选填，留空则公开)',
                hintText: '4位数字或简单密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('本地同屏轮流玩 (Pass & Play)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('聚会多位好友共用一台手机轮流传阅操作', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              value: _isPassAndPlay,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isPassAndPlay = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _submitCreate,
          child: const Text('立即创建并进入'),
        ),
      ],
    );
  }
}
