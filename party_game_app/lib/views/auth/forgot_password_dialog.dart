import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _obscurePwd = true;
  bool _obscureConfirmPwd = true;
  int _countdown = 0;
  Timer? _timer;
  String? _mockCodeHint;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的11位大陆手机号')),
      );
      return;
    }
    setState(() => _isSendingCode = true);
    try {
      final code = await context.read<AuthProvider>().sendSmsCode(phone);
      if (!mounted) return;
      setState(() {
        _isSendingCode = false;
        _mockCodeHint = code;
        _codeCtrl.text = code;
        _countdown = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_countdown <= 1) {
          t.cancel();
          setState(() => _countdown = 0);
        } else {
          setState(() => _countdown--);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证码已发送至 $phone'), backgroundColor: AppColors.info),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pwd = _newPwdCtrl.text.trim();
    final confirmPwd = _confirmPwdCtrl.text.trim();
    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效手机号')));
      return;
    }
    if (pwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新密码至少6位')));
      return;
    }
    if (pwd != confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致，请重新核对')));
      return;
    }

    setState(() => _isLoading = true);
    final ok = await context.read<AuthProvider>().resetPassword(phone, pwd);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 密码重置成功，请使用新密码登录！'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码重置失败，请确认手机号与验证码'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.adaptiveCard(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '🔐 找回/重置密码',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.adaptiveTextPrimary(context)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '请输入注册手机号',
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      hintText: '输入验证码',
                      prefixIcon: Icon(Icons.security),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (_isSendingCode || _countdown > 0) ? null : _sendCode,
                  child: _isSendingCode
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                ),
              ],
            ),
            if (_mockCodeHint != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '模拟短信码：$_mockCodeHint',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _newPwdCtrl,
              obscureText: _obscurePwd,
              decoration: InputDecoration(
                labelText: '新密码',
                hintText: '设置不少于6位的新密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePwd ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPwdCtrl,
              obscureText: _obscureConfirmPwd,
              decoration: InputDecoration(
                labelText: '确认新密码',
                hintText: '请再次输入新密码以确认',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPwd ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPwd = !_obscureConfirmPwd),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('确认重置'),
        ),
      ],
    );
  }
}
