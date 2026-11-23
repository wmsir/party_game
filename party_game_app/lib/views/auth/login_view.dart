import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_version.dart';
import '../../core/widgets/commercial_ui_kit.dart';
import '../../main.dart';
import '../../models/saved_account_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import 'register_view.dart';
import 'forgot_password_dialog.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _accountUserCtrl = TextEditingController();
  final _accountPwdCtrl = TextEditingController();

  final _phoneCtrl = TextEditingController(text: '13888888888');
  final _codeCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isSendingCode = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  String? _mockSmsCodeReceived;
  SavedAccountModel? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSavedAccount();
    });
  }

  void _initSavedAccount() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final list = auth.savedAccounts;
    if (list.isNotEmpty) {
      _applySavedAccount(list.first, autoSwitchTab: true);
    }
  }

  void _applySavedAccount(SavedAccountModel acc, {bool autoSwitchTab = false}) {
    setState(() {
      _selectedAccount = acc;
      if (acc.loginType == 'password') {
        _accountUserCtrl.text = acc.username.isNotEmpty ? acc.username : acc.phone;
        _accountPwdCtrl.text = acc.password;
        if (autoSwitchTab) _tabController.animateTo(1);
      } else {
        if (acc.phone.isNotEmpty) {
          _phoneCtrl.text = acc.phone;
        }
        if (autoSwitchTab) _tabController.animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _accountUserCtrl.dispose();
    _accountPwdCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  /// 发送模拟短信验证码
  Future<void> _onSendSmsCode() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入正确的11位手机号码'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      final auth = context.read<AuthProvider>();
      final code = await auth.sendSmsCode(phone);
      if (!mounted) return;

      setState(() {
        _isSendingCode = false;
        _mockSmsCodeReceived = code;
        _codeCtrl.text = code; // 自动完成验证码填入
      });
      _startCountdown();

      // 顶部拟真短信弹窗（提示3秒，登录进入游戏界面后立即消除）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.sms_rounded, color: AppColors.accent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('【聚会桌游】模拟验证码已送达', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('您的登录验证码是: $code (已自动填入)', style: const TextStyle(fontSize: 12, color: AppColors.accentLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  void _onPasswordLogin() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(
      _accountUserCtrl.text.trim(),
      _accountPwdCtrl.text.trim(),
    );
    if (ok && mounted) {
      messenger.clearSnackBars(); // 立即清除所有可能残留的验证码提示
      final user = auth.user;
      if (user != null) {
        context.read<FriendProvider>().refresh(user.id);
      }
    } else if (!ok && mounted && auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  void _onPhoneLogin() async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请输入有效的11位手机号码'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请输入6位短信验证码'), backgroundColor: AppColors.error),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPhone(phone, code);
    if (ok && mounted) {
      messenger.clearSnackBars(); // 立即消除验证码与浮动弹窗
      final user = auth.user;
      if (user != null) {
        context.read<FriendProvider>().refresh(user.id);
      }
    } else if (!ok && mounted && auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  void _onGuestLogin() {
    _showTrialSmsDialog();
  }

  void _showTrialSmsDialog() {
    final phoneCtrl = TextEditingController(text: '13812345678');
    final codeCtrl = TextEditingController();
    bool isSending = false;
    int countdown = 0;
    Timer? timer;
    String? mockCode;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            void startTimer() {
              setDlgState(() => countdown = 60);
              timer?.cancel();
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (!ctx.mounted) {
                  t.cancel();
                  return;
                }
                if (countdown <= 1) {
                  t.cancel();
                  setDlgState(() => countdown = 0);
                } else {
                  setDlgState(() => countdown--);
                }
              });
            }

            Future<void> sendTrialCode() async {
              final p = phoneCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(p)) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('请输入正确的11位手机号码'), backgroundColor: AppColors.error),
                );
                return;
              }
              setDlgState(() => isSending = true);
              try {
                final auth = context.read<AuthProvider>();
                final code = await auth.sendTrialSmsCode(p);
                setDlgState(() {
                  isSending = false;
                  mockCode = code;
                  codeCtrl.text = code;
                });
                startTimer();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('【试玩短信】验证码 $code 已送达 (5分钟内有效，已自动填入)'),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                setDlgState(() => isSending = false);
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
                );
              }
            }

            Future<void> submitTrialVerify() async {
              final p = phoneCtrl.text.trim();
              final c = codeCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (p.length != 11) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('请输入有效的11位手机号码'), backgroundColor: AppColors.error),
                );
                return;
              }
              if (c.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('请输入短信验证码'), backgroundColor: AppColors.error),
                );
                return;
              }

              final auth = context.read<AuthProvider>();
              final ok = await auth.loginWithTrialSms(p, c);
              if (ok && mounted) {
                timer?.cancel();
                if (dlgCtx.mounted) {
                  Navigator.of(dlgCtx).pop();
                }
                messenger.clearSnackBars();
                final user = auth.user;
                if (user != null) {
                  context.read<FriendProvider>().refresh(user.id);
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('🎮 手机短信验证通过！已获赠 2,000 试玩金币 + 50 钻石！'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (!ok && mounted && auth.errorMessage != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text(auth.errorMessage!), backgroundColor: AppColors.error),
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveCardSurface(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🎮', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              '手机验证码 · 免费极速试玩',
                              style: TextStyle(color: AppColors.adaptiveTextPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.adaptiveTextSecondary(context), size: 20),
                          onPressed: () {
                            timer?.cancel();
                            Navigator.of(dlgCtx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.25)),
                      ),
                      child: const Text(
                        '🛡️ 为防止恶意刷号保障绿色环境，试玩需手机接收短信验证码(5分钟内有效)。试玩即赠 2,000 金币 + 50 钻石！',
                        style: TextStyle(color: Colors.amber, fontSize: 11, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 手机号输入框
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: '接收验证码手机号',
                        hintText: '请输入11位手机号',
                        prefixIcon: const Icon(Icons.phone_android, size: 20),
                        suffixIcon: phoneCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setDlgState(() => phoneCtrl.clear()),
                              )
                            : null,
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // 验证码输入框
                    TextField(
                      controller: codeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '6位短信验证码',
                        hintText: '5分钟内有效',
                        prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: countdown > 0
                              ? Container(
                                  alignment: Alignment.center,
                                  width: 90,
                                  child: Text(
                                    '${countdown}s 后重发',
                                    style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : TextButton(
                                  onPressed: isSending ? null : sendTrialCode,
                                  child: isSending
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('获取验证码', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                        ),
                      ),
                    ),
                    if (mockCode != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '短信码: $mockCode (5分钟内有效)',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () => setDlgState(() => codeCtrl.text = mockCode!),
                              child: const Text('一键填入', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // 提交按钮
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: submitTrialVerify,
                        child: const Text(
                          '验证短信并立即开始试玩',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = AppColors.isDarkMode(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => PartyGameApp.toggleThemeMode(context),
                      tooltip: isDark ? '切换明亮护眼模式' : '切换暗夜模式',
                      icon: Icon(
                        isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                        color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
                      ),
                    ),
                  ),
                  // 应用官方设计 Logo 与商业化翡翠金色光环
                  Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(child: Text('🎲', style: TextStyle(fontSize: 44))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '聚会桌游俱乐部',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.adaptiveTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Party Game Club · 大话骰 · 牛头王 · 聚会转盘 · 谁是卧底',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.adaptiveTextSecondary(context)),
                  ),
                  const SizedBox(height: 22),

                  // 记住的历史账号快捷选用卡片 (一键登录 / 选用 / 切换其他账号)
                  _buildSavedAccountCard(auth),

                  // 登录方式 Tab
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveCard(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.adaptiveBorder(context)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.adaptivePrimary(context),
                      indicatorWeight: 3,
                      labelColor: AppColors.adaptivePrimary(context),
                      unselectedLabelColor: AppColors.adaptiveTextMuted(context),
                      tabs: const [
                        Tab(text: '手机验证码登录'),
                        Tab(text: '账号密码登录'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

              // Tab 表单内容 (自适应高度，兼容系统字体放大与短信辅助条不溢出)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _tabController.index == 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: '手机号码',
                              hintText: '请输入11位大陆手机号',
                              prefixIcon: const Icon(Icons.phone_android),
                              suffixIcon: _phoneCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _phoneCtrl.clear()),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '短信验证码',
                              hintText: '请输入6位验证码',
                              prefixIcon: const Icon(Icons.shield_outlined),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: _countdown > 0
                                    ? Container(
                                        alignment: Alignment.center,
                                        width: 96,
                                        child: Text(
                                          '${_countdown}s 后重发',
                                          style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: _isSendingCode ? null : _onSendSmsCode,
                                        child: _isSendingCode
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Text('获取验证码', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 模拟短信即时填入与测试辅助条
                          if (_mockSmsCodeReceived != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mark_email_unread_outlined, size: 16, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '模拟短信码: $_mockSmsCodeReceived',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setState(() => _codeCtrl.text = _mockSmsCodeReceived!);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text('一键填入', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 新手自动注册说明
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: AppColors.accent, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '新手机号验证后将自动完成注册并赠送新手福利',
                                  style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          TextField(
                            controller: _accountUserCtrl,
                            decoration: const InputDecoration(
                              labelText: '统一登录账号',
                              hintText: '支持 用户名 / 手机号 / 邮箱 登录',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _accountPwdCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: '密码',
                              hintText: '请输入登录密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const ForgotPasswordDialog(),
                                );
                              },
                              child: Text('忘记密码？', style: TextStyle(fontSize: 12, color: AppColors.adaptiveTextMuted(context))),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: auth.isLoading
                      ? null
                      : () {
                          if (_tabController.index == 0) {
                            _onPhoneLogin();
                          } else {
                            _onPasswordLogin();
                          }
                        },
                  child: auth.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('立即登录进入大厅', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 14),

              // 游客一键试玩通道 (醒目金黄色)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 1.5),
                    backgroundColor: AppColors.accent.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sports_esports_outlined, color: AppColors.accent),
                  label: const Text('游客极速试玩 (免注册 · 秒进游戏)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: auth.isLoading ? null : _onGuestLogin,
                ),
              ),
              const SizedBox(height: 20),

              // 底部注册入口
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('还没有聚会账号？', style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 13)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterView()),
                      );
                    },
                    child: const Text(
                      '立即免费注册',
                      style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 官方版本与构建时间防伪水印 (确保用户每次安装能直观确认已装上最新版本)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.adaptiveElevated(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.adaptiveBorder(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '聚会桌游吧 v${AppVersionInfo.versionName} · 构建: ${AppVersionInfo.buildTime}',
                        style: TextStyle(
                          color: AppColors.adaptiveTextMuted(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text('登录即代表同意', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  InkWell(
                    onTap: () => LegalAgreementDialog.show(context),
                    child: const Text('《用户服务协议》', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  Text('与', style: TextStyle(color: AppColors.adaptiveTextMuted(context), fontSize: 11)),
                  InkWell(
                    onTap: () => LegalAgreementDialog.show(context, isPrivacy: true),
                    child: const Text('《隐私保护声明》', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildSavedAccountCard(AuthProvider auth) {
    final list = auth.savedAccounts;
    if (list.isEmpty) return const SizedBox.shrink();

    final current = _selectedAccount ?? list.first;
    final isDark = AppColors.isDarkMode(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFFFFFFFF), Color(0xFFF0F9F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_toggle_off, color: AppColors.primaryLight, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '已保存的历史账号',
                    style: TextStyle(
                      color: AppColors.adaptiveTextPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showAccountSwitchSheet(auth),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '切换/管理 (${list.length})',
                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.primaryLight),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 头像
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.adaptiveElevated(context),
                  border: Border.all(color: AppColors.adaptiveBorder(context)),
                ),
                alignment: Alignment.center,
                child: Text(
                  current.avatar.isNotEmpty ? current.avatar : '🦊',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            current.nickname,
                            style: TextStyle(
                              color: AppColors.adaptiveTextPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: current.loginType == 'phone'
                                ? Colors.teal.withOpacity(0.25)
                                : (current.loginType == 'guest' ? Colors.orange.withOpacity(0.25) : Colors.indigo.withOpacity(0.25)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: current.loginType == 'phone'
                                  ? Colors.teal
                                  : (current.loginType == 'guest' ? Colors.orange : Colors.indigo),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            current.loginType == 'phone' ? '手机' : (current.loginType == 'guest' ? '游客' : '密码'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: current.loginType == 'phone'
                                  ? Colors.tealAccent
                                  : (current.loginType == 'guest' ? Colors.amber : Colors.indigoAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _maskAccount(current.displayAccount),
                      style: TextStyle(
                        color: AppColors.adaptiveTextSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 一键登录快捷按钮
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: auth.isLoading ? null : () => _quickLoginWithAccount(current),
                child: const Text('一键登录', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountSwitchSheet(AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.adaptiveCardSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final list = auth.savedAccounts;
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '选择或切换已存账号',
                        style: TextStyle(
                          color: AppColors.adaptiveTextPrimary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.adaptiveTextSecondary(context)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Divider(color: AppColors.adaptiveBorder(context)),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('暂无记住的账号', style: TextStyle(color: AppColors.adaptiveTextMuted(context))),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.adaptiveBorder(context)),
                        itemBuilder: (c, idx) {
                          final acc = list[idx];
                          final isCurrent = _selectedAccount?.id == acc.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.adaptiveElevated(context),
                                border: Border.all(color: isCurrent ? AppColors.primary : AppColors.adaptiveBorder(context)),
                              ),
                              alignment: Alignment.center,
                              child: Text(acc.avatar.isNotEmpty ? acc.avatar : '🦊', style: const TextStyle(fontSize: 22)),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.nickname,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? AppColors.primary : AppColors.adaptiveTextPrimary(context),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('当前', style: TextStyle(color: AppColors.primaryLight, fontSize: 10)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${acc.loginType == 'phone' ? '📱 手机号' : (acc.loginType == 'guest' ? '🎮 游客' : '👤 账号')}: ${_maskAccount(acc.displayAccount)}',
                              style: TextStyle(color: AppColors.adaptiveTextSecondary(context), fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrent ? AppColors.accent : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    _quickLoginWithAccount(acc);
                                  },
                                  child: Text(isCurrent ? '立即登入' : '选用登入', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  tooltip: '删除此账号记录',
                                  onPressed: () async {
                                    await auth.removeSavedAccount(acc.id);
                                    setSheetState(() {});
                                    setState(() {
                                      if (_selectedAccount?.id == acc.id) {
                                        _selectedAccount = null;
                                        if (auth.savedAccounts.isNotEmpty) {
                                          _applySavedAccount(auth.savedAccounts.first);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _quickLoginWithAccount(acc);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.adaptiveTextPrimary(context),
                        side: BorderSide(color: AppColors.adaptiveBorder(context)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('使用全新账号登录', style: TextStyle(fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _selectedAccount = null;
                          _accountUserCtrl.clear();
                          _accountPwdCtrl.clear();
                          _phoneCtrl.clear();
                          _codeCtrl.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _quickLoginWithAccount(SavedAccountModel acc) async {
    _applySavedAccount(acc, autoSwitchTab: true);
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    if (acc.loginType == 'password' && acc.password.isNotEmpty) {
      final username = acc.username.isNotEmpty ? acc.username : acc.phone;
      final ok = await auth.loginWithPassword(username, acc.password);
      if (ok && mounted) {
        messenger.clearSnackBars();
        final user = auth.user;
        if (user != null) {
          context.read<FriendProvider>().refresh(user.id);
        }
      } else if (!ok && mounted && auth.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(auth.errorMessage!), backgroundColor: AppColors.error),
        );
      }
    } else if (acc.loginType == 'guest') {
      _onGuestLogin();
    } else {
      final phone = acc.phone.isNotEmpty ? acc.phone : acc.username;
      _phoneCtrl.text = phone;
      _codeCtrl.clear();
      _tabController.animateTo(0);
      messenger.showSnackBar(
        SnackBar(
          content: Text('已为您填入手机号 ${_maskAccount(phone)}，请点击【获取验证码】完成安全验证'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  String _maskAccount(String acc) {
    if (acc.length == 11 && RegExp(r'^\d+$').hasMatch(acc)) {
      return '${acc.substring(0, 3)}****${acc.substring(7)}';
    }
    return acc;
  }
}
