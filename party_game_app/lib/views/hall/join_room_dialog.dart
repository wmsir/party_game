import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../room/game_room_lobby_view.dart';
import '../widgets/scan_qr_dialog.dart';

class JoinRoomDialog extends StatefulWidget {
  final String? initialCode;

  const JoinRoomDialog({Key? key, this.initialCode}) : super(key: key);

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _submitJoin() {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标准的 6 位数字房间号')),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final me = GamePlayer(
      id: user.id,
      name: user.nickname,
      avatar: user.avatar,
    );

    try {
      final room = context.read<RoomProvider>().joinRoomByCode(
        code,
        me,
        password: _pwdCtrl.text.trim(),
      );

      if (room != null) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameRoomLobbyView(
              room: room,
              isSpectator: room.isSpectator,
              isReconnecting: room.isSpectator,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到该房间号，可能房间已解散或号码输入有误'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('🔍 加入对局房间', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '输入6位房间码',
              prefixIcon: const Icon(Icons.pin),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                tooltip: '扫码进房',
                onPressed: () {
                  Navigator.pop(context);
                  ScanQrDialog.show(context);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pwdCtrl,
            decoration: const InputDecoration(
              labelText: '房间密码 (无密码请留空)',
              hintText: '若房主设置了密码请输入',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _submitJoin,
          child: const Text('立即加入'),
        ),
      ],
    );
  }
}
