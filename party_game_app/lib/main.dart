import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'core/sound/game_sound_service.dart';
import 'core/storage/local_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/moment_provider.dart';
import 'providers/room_provider.dart';
import 'views/auth/login_view.dart';
import 'views/main_frame_view.dart';
import 'views/widgets/global_blessing_marquee.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 状态栏与导航栏明亮护眼沉浸式设计
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF5F3EE),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 初始化本地持久化与音频触感引擎
  await LocalStorage.init();
  GameSoundService().init();
  PartyGameApp.restoreThemeMode();

  runApp(const PartyGameApp());
}

class PartyGameApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  static void restoreThemeMode() {
    final saved = LocalStorage.getThemeMode();
    if (saved == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
      applySystemUiOverlay(ThemeMode.dark);
    } else if (saved == 'light') {
      themeModeNotifier.value = ThemeMode.light;
      applySystemUiOverlay(ThemeMode.light);
    }
  }

  static void applySystemUiOverlay(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3EE),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  static void toggleThemeMode(BuildContext context) {
    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;
    final nextMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = nextMode;
    LocalStorage.saveThemeMode(nextMode == ThemeMode.dark ? 'dark' : 'light');
    applySystemUiOverlay(nextMode);
  }

  const PartyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => MomentProvider()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, currentThemeMode, _) {
          return MaterialApp(
            navigatorKey: PartyGameApp.navigatorKey,
            scaffoldMessengerKey: PartyGameApp.messengerKey,
            title: '聚会桌游吧 (PartyGame Club)',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('zh', 'CN'),
            theme: AppTheme.lightEyeCareTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentThemeMode,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final clampedScaler = mq.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.2,
              );
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final overlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3EE),
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: MediaQuery(
                  data: mq.copyWith(textScaler: clampedScaler),
                  child: Stack(
                    children: [
                      if (child != null) child,
                      // 全服大喇叭与盛典跑马灯：置顶于全 App 最上层（覆盖所有子路由、全屏弹窗与对话框）
                      const GlobalBlessingMarquee(),
                    ],
                  ),
                ),
              );
            },
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoggedIn) {
                  return const MainFrameView();
                } else {
                  return const LoginView();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
