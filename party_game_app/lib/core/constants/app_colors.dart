import 'package:flutter/material.dart';

class AppColors {
  // 明亮护眼清新主题配色 (柔和自然竹绿、温暖琥珀金、舒适温润玉质纸白)
  static const Color primary = Color(0xFF1B8354);      // 护眼竹翠绿 (主操作色、视觉舒适)
  static const Color primaryLight = Color(0xFF2EAA6E);
  static const Color primaryDark = Color(0xFF115E3B);

  static const Color accent = Color(0xFFD97706);       // 温暖琥珀金 (高光与对决筹码)
  static const Color accentLight = Color(0xFFF59E0B);

  static const Color secondary = Color(0xFFE11D48);    // 柔和莓红 (互动道具与强调)
  static const Color cyan = Color(0xFF0284C7);         // 晴空蔚蓝 (在线状态与同城)

  // 明亮护眼背景色系 (柔和护眼、消除眩光)
  static const Color bgDark = Color(0xFFF5F3EE);       // 柔和暖玉米纸底色 (温润护眼，非刺眼纯白)
  static const Color bgCard = Color(0xFFFFFFFF);       // 纯净卡片白
  static const Color bgElevated = Color(0xFFECE7DE);   // 浮动与浅灰阴影层
  static const Color bgLight = Color(0xFFFAF9F6);      // 浅柔米色

  // 语义化通用颜色别名
  static const Color primaryGold = accent;
  static const Color backgroundDark = bgDark;
  static const Color cardSurface = bgCard;
  static const Color accentCyan = cyan;
  static const Color accentPink = secondary;

  // 明亮护眼文字系统 (高对比度深黛色，长时间阅读不累眼)
  static const Color textPrimary = Color(0xFF1E293B);   // 核心文字深青灰
  static const Color textSecondary = Color(0xFF475569); // 次级文字舒适中灰
  static const Color textMuted = Color(0xFF8A99AD);     // 弱化说明淡灰

  // 状态与标识
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  // 互动道具色彩
  static const Color eggYellow = Color(0xFFF59E0B);
  static const Color beerGold = Color(0xFFD97706);
  static const Color flowerPink = Color(0xFFE11D48);
  static const Color slipperRed = Color(0xFFDC2626);
  static const Color bombBlack = Color(0xFF334155);

  // 边框与阴影分割线
  static const Color border = Color(0xFFE2DCD5);
  static const Color shadow = Color(0x0C000000);

  // ===== 深色主题专用色板 (True Dark Color Palette) =====
  static const Color darkBg = Color(0xFF0F172A);          // 深墨夜空底色 (Slate 900)
  static const Color darkCard = Color(0xFF1E293B);        // 沉浸卡片底色 (Slate 800)
  static const Color darkElevated = Color(0xFF334155);    // 浮动层/浅灰遮罩 (Slate 700)
  static const Color darkBorder = Color(0xFF334155);      // 深色边框分割线
  static const Color darkShadow = Color(0x40000000);      // 深色阴影
  static const Color darkPrimary = Color(0xFF22C55E);     // 夜间高亮翡翠绿 (明亮对比度)
  static const Color darkAccent = Color(0xFFFBBF24);      // 夜间暖金 (Amber 400)
  static const Color darkSecondary = Color(0xFFFB7185);   // 夜间柔粉 (Rose 400)
  static const Color darkCyan = Color(0xFF38BDF8);        // 夜间亮青 (Sky 400)

  // 深色文字系统 (高对比度夜视)
  static const Color darkTextPrimary = Color(0xFFF8FAFC);   // 核心文字亮白 (Slate 50)
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // 次级文字浅灰 (Slate 300)
  static const Color darkTextMuted = Color(0xFF94A3B8);     // 弱化说明淡灰 (Slate 400)

  // ===== 上下文自适应色彩助手函数 =====
  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color adaptiveBg(BuildContext context) =>
      isDarkMode(context) ? darkBg : bgDark;

  static Color adaptiveBgDark(BuildContext context) => adaptiveBg(context);

  static Color adaptiveCard(BuildContext context) =>
      isDarkMode(context) ? darkCard : bgCard;

  static Color adaptiveBgCard(BuildContext context) => adaptiveCard(context);

  static Color adaptiveCardSurface(BuildContext context) => adaptiveCard(context);

  static Color adaptiveElevated(BuildContext context) =>
      isDarkMode(context) ? darkElevated : bgElevated;

  static Color adaptiveBorder(BuildContext context) =>
      isDarkMode(context) ? darkBorder : border;

  static Color adaptiveTextPrimary(BuildContext context) =>
      isDarkMode(context) ? darkTextPrimary : textPrimary;

  static Color adaptiveTextSecondary(BuildContext context) =>
      isDarkMode(context) ? darkTextSecondary : textSecondary;

  static Color adaptiveTextMuted(BuildContext context) =>
      isDarkMode(context) ? darkTextMuted : textMuted;
}
