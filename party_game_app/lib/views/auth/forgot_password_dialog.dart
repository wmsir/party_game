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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
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
    setState(() => _isLoading = false);

    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 密码重置成功，请使用新密码登录！'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('🔐 找回/重置密码', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('验证码已发送至手机：8888'), backgroundColor: AppColors.info),
                    );
                  },
                  child: const Text('获取验证码'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码',
                hintText: '设置不少于6位的新密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                hintText: '请再次输入新密码以确认',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('确认重置'),
        ),
      ],
    );
  }
}
