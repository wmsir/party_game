import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/sound/game_sound_service.dart';
import '../../models/game_player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/api_service.dart';
import '../room/game_room_lobby_view.dart';

/// 扫一扫与网页扫码登录授权弹窗
class ScanQrDialog extends StatefulWidget {
  const ScanQrDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ScanQrDialog(),
    );
  }

  @override
  State<ScanQrDialog> createState() => _ScanQrDialogState();
}

class _ScanQrDialogState extends State<ScanQrDialog> {
  final _inputCtrl = TextEditingController();
  bool _isProcessing = false;
  String? _detectedQrTicket;
  String? _detectedRoomCode;

  @override
  void initState() {
    super.initState();
    // 自动尝试嗅探剪贴板内容
    _checkClipboard();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && mounted) {
        final text = data.text!.trim();
        _parseInput(text);
      }
    } catch (_) {}
  }

  void _parseInput(String text) {
    if (text.isEmpty) return;

    // 1. 尝试匹配扫码登录 Ticket (例如 ticket=QR-xxx、QR-xxx、或URL里的ticket参数)
    String? matchedTicket;
    final ticketParamMatch = RegExp(r'[?&]ticket=([A-Za-z0-9_\-]+)', caseSensitive: false).firstMatch(text);
    if (ticketParamMatch != null) {
      matchedTicket = ticketParamMatch.group(1);
    } else {
      final qrMatch = RegExp(r'(QR-[A-Za-z0-9]{8,32})', caseSensitive: false).firstMatch(text);
      if (qrMatch != null) {
        matchedTicket = qrMatch.group(1);
      }
    }

    if (matchedTicket != null) {
      setState(() {
        _detectedQrTicket = matchedTicket;
        _detectedRoomCode = null;
        _inputCtrl.text = matchedTicket!;
      });
      return;
    }

    // 2. 尝试匹配房间号 (例如 roomId=123456 或纯 6 位数字)
    final roomParamMatch = RegExp(r'[?&]roomId=([0-9]{6})', caseSensitive: false).firstMatch(text);
    if (roomParamMatch != null) {
      setState(() {
        _detectedRoomCode = roomParamMatch.group(1);
        _detectedQrTicket = null;
        _inputCtrl.text = _detectedRoomCode!;
      });
      return;
    }

    if (RegExp(r'^[0-9]{6}$').hasMatch(text)) {
      setState(() {
        _detectedRoomCode = text;
        _detectedQrTicket = null;
        _inputCtrl.text = text;
      });
      return;
    }

    setState(() {
      _detectedQrTicket = null;
      _detectedRoomCode = null;
    });
  }

  Future<void> _confirmQrAuth() async {
    if (_detectedQrTicket == null || _isProcessing) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录手机 APP 账号'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isProcessing = true);
    GameSoundService().playVictory();

    final ok = await ApiService().confirmQrLogin(
      ticket: _detectedQrTicket!,
      userId: user.id,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 授权成功！电脑/网页端已成功登入【${user.nickname}】账号并进入房间'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('授权失败，二维码可能已过期失效，请在网页端刷新后再试'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _joinDetectedRoom() {
    if (_detectedRoomCode == null) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final me = GamePlayer(
      id: user.id,
      name: user.nickname,
      avatar: user.avatar,
    );

    try {
      final room = context.read<RoomProvider>().joinRoomByCode(
        _detectedRoomCode!,
        me,
      );

      if (room != null) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameRoomLobbyView(room: room)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到该房间，可能已解散'), backgroundColor: AppColors.error),
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
    final user = context.watch<AuthProvider>().user;

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: Color(0xFF38BDF8), size: 24),
          SizedBox(width: 8),
          Text('📷 扫码与快速授权', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '支持快速授权电脑/网页端登录，或识别房间口令一键进房：',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),

            // 输入/解析框
            TextField(
              controller: _inputCtrl,
              onChanged: _parseInput,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: '粘贴二维码链接、Ticket 或房间号',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                prefixIcon: const Icon(Icons.link, color: Colors.white54, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, color: Color(0xFF38BDF8), size: 20),
                  tooltip: '粘贴剪贴板',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _parseInput(data!.text!.trim());
                    }
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 14),

            // 1. 识别到扫码登录授权请求
            if (_detectedQrTicket != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.computer, color: Color(0xFF38BDF8), size: 22),
                        SizedBox(width: 6),
                        Text(
                          '网页端扫码登录请求',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '授权当前登录账号【${user?.nickname ?? "我"}】在电脑/网页端直接登录并进入游戏房间。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isProcessing ? null : _confirmQrAuth,
                      icon: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isProcessing ? '正在授权...' : '✅ 确认授权网页端登录', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ]
            // 2. 识别到房间邀请
            else if (_detectedRoomCode != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.meeting_room_outlined, color: Color(0xFFF59E0B), size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '对局房间邀请 #$_detectedRoomCode',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '检测到有效的房间号，点击下方按钮立即秒进房间！',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _joinDetectedRoom,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('🚀 立即进入房间', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '💡 提示：在网页端点击【📷 扫码一键登录】，将页面中二维码链接粘贴到上方，即可秒速完成授权！',
                  style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
