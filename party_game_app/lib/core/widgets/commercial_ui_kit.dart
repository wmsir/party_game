import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 商业级自适应宽度容器：手机端占满全宽，平板/桌面端优雅居中并限制最大阅读宽度
class ResponsiveContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1040,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 底部抽屉顶部抓手条 (BottomSheet Drag Handle)
class CommercialSheetHandle extends StatelessWidget {
  const CommercialSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.adaptiveBorder(context),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// 商业化统一空状态卡片（带图标、说明、可选快捷短语标签与主操作按钮）
class CommercialEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<String>? quickChips;
  final ValueChanged<String>? onChipTap;

  const CommercialEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.quickChips,
    this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.adaptivePrimary(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.adaptiveCard(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.adaptiveBorder(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.adaptiveTextPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.adaptiveTextSecondary(context),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
              if (quickChips != null && quickChips!.isNotEmpty && onChipTap != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: quickChips!.map((chip) {
                    return ActionChip(
                      label: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.adaptiveTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.adaptiveElevated(context),
                      side: BorderSide(color: AppColors.adaptiveBorder(context)),
                      onPressed: () => onChipTap!(chip),
                    );
                  }).toList(),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 合规用户服务协议与隐私保护声明弹窗
class LegalAgreementDialog extends StatelessWidget {
  final bool isPrivacy;

  const LegalAgreementDialog({super.key, this.isPrivacy = false});

  static Future<void> show(BuildContext context, {bool isPrivacy = false}) {
    return showDialog<void>(
      context: context,
      builder: (_) => LegalAgreementDialog(isPrivacy: isPrivacy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? '🛡️ 隐私保护声明' : '📜 用户服务协议';
    final sections = isPrivacy
        ? const [
            ('1. 信息收集与最小必要原则', '为保障账号登录、实名安全及多人联机对战体验，我们仅收集您主动提供的手机号/账号昵称、头像选择与设备基础运行状态。'),
            ('2. 联机与本地存储', '您的对局记录、好友消息及装扮资产通过加密通道同步至云端；部分偏好设置（如护眼主题、音效与震动开关）仅存储在本地设备。'),
            ('3. 绿色健康社交规范', '我们不会向无关第三方出售或披露您的个人信息；您可随时在“个人主页 -> 账号与安全中心”修改资料或清理本地缓存。'),
          ]
        : const [
            ('1. 平台服务说明', '“聚会桌游吧 (PartyGame Club)”为合法健康的多人互动桌游社交平台，提供大话骰、谁是牛头王、聚会大转盘与谁是卧底等娱乐玩法。'),
            ('2. 虚拟道具与金币规则', '平台内金币、钻石、VIP 等级与装扮道具仅限聚会桌游吧线上娱乐交互使用，严禁任何形式的线下兑现、赌博或违规交易。'),
            ('3. 社区行为准则', '请文明友善发言与互动，禁止发布违法违规、骚扰辱骂或外挂作弊信息；违规账号将视情节采取禁言或封禁处理。'),
          ];

    return AlertDialog(
      backgroundColor: AppColors.adaptiveCard(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.adaptiveTextPrimary(context),
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: sections.map((sec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sec.$1,
                      style: TextStyle(
                        color: AppColors.adaptivePrimary(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sec.$2,
                      style: TextStyle(
                        color: AppColors.adaptiveTextSecondary(context),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('我已阅读并了解'),
        ),
      ],
    );
  }
}
