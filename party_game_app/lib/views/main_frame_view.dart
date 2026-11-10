import 'package:flutter/services.dart';
import '../games/core/models/game_player.dart';
import '../providers/room_provider.dart';
import 'room/game_room_lobby_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/auth_provider.dart';
import 'chat/chat_square_view.dart';
import 'chat/widgets/interactive_throw_overlay.dart';
import 'profile/dressing_shop_view.dart';
import 'friends/friends_view.dart';
import 'hall/party_hall_view.dart';
import 'profile/profile_view.dart';
import 'widgets/mini_room_floating_widget.dart';
import '../services/socket_service.dart';

class MainFrameView extends StatefulWidget {
  const MainFrameView({super.key});

  @override
  State<MainFrameView> createState() => _MainFrameViewState();
}

class _MainFrameViewState extends State<MainFrameView> with WidgetsBindingObserver {
  String _lastCheckedClipboard = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final myUser = auth.user;
      if (myUser != null && myUser.id.isNotEmpty) {
        Provider.of<FriendProvider>(context, listen: false).refresh(myUser.id);
      }
      Provider.of<ChatProvider>(context, listen: false).syncRecentBroadcasts();
      _checkClipboardForRoomInvite();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForRoomInvite();
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final myUser = auth.user;
        if (myUser != null && myUser.id.isNotEmpty) {
          SocketService().connect(userId: myUser.id, nickname: myUser.nickname);
        } else {
          SocketService().connect();
        }
        Provider.of<ChatProvider>(context, listen: false).syncRecentBroadcasts();
      } catch (_) {}
    }
  }

  Future<void> _checkClipboardForRoomInvite() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastCheckedClipboard) return;

      final regRoomCode = RegExp(r'房间【([0-9a-zA-Z]{3,8})】');
      final regRoomUrl = RegExp(r'roomId=([0-9a-zA-Z]{3,8})');
      String? roomCode;

      final m1 = regRoomCode.firstMatch(text);
      if (m1 != null) {
        roomCode = m1.group(1);
      } else {
        final m2 = regRoomUrl.firstMatch(text);
        if (m2 != null) roomCode = m2.group(1);
      }

      if (roomCode != null && roomCode.isNotEmpty) {
        _lastCheckedClipboard = text;
        if (!mounted) return;
        _showInviteJoinDialog(roomCode);
      }
    } catch (_) {}
  }

  void _showInviteJoinDialog(String roomCode) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDarkMode(ctx);
        final titleAccent = isDark ? AppColors.darkAccent : AppColors.accent;
        final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
        return AlertDialog(
          backgroundColor: AppColors.adaptiveCard(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Text('🎮 ', style: TextStyle(fontSize: 20)),
              Text(
                '检测到组局开黑口令',
                style: TextStyle(
                  color: titleAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '好友通过微信/QQ向您发送了开黑邀请：',
                style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: titleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: titleAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '房间号',
                      style: TextStyle(color: AppColors.adaptiveTextSecondary(ctx), fontSize: 12),
                    ),
                    Text(
                      roomCode,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFEF08A) : AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('稍后再说', style: TextStyle(color: AppColors.adaptiveTextMuted(ctx))),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? AppColors.darkBg : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('立即加入房间', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                _joinRoomDirect(roomCode);
              },
            ),
          ],
        );
      },
    );
  }

  void _joinRoomDirect(String roomCode) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final user = auth.user;
    final me = GamePlayer(
      id: user?.id ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: user?.nickname ?? '开黑玩家',
      avatar: user?.avatar ?? '🦊',
    );

    try {
      final room = roomProv.joinRoomByCode(roomCode, me);
      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameRoomLobbyView(room: room),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入房间【$roomCode】失败，可能房间已满或号码有误')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入房间失败: $e')),
      );
    }
  }

  final List<Widget> _pages = const [
    PartyHallView(),
    ChatSquareView(),
    DressingShopView(),
    FriendsView(),
    ProfileView(),
  ];

  void _onNavSelected(int idx) {
    setState(() => _currentIndex = idx);
    if (idx == 3) {
      final myUser = Provider.of<AuthProvider>(context, listen: false).user;
      if (myUser != null && myUser.id.isNotEmpty) {
        Provider.of<FriendProvider>(context, listen: false).refresh(myUser.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendProv = Provider.of<FriendProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final unreadFriends = friendProv.totalUnreadCount;
    final throwEvent = chatProv.lastThrowEvent;
    final isDark = AppColors.isDarkMode(context);
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final cardBg = AppColors.adaptiveCard(context);
    final borderColor = AppColors.adaptiveBorder(context);
    final mutedColor = AppColors.adaptiveTextMuted(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppColors.adaptiveBg(context),
              body: isWide
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _currentIndex,
                          onDestinationSelected: _onNavSelected,
                          backgroundColor: cardBg,
                          labelType: NavigationRailLabelType.all,
                          selectedIconTheme: IconThemeData(color: primaryColor),
                          unselectedIconTheme: IconThemeData(color: mutedColor),
                          selectedLabelTextStyle: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                          destinations: [
                            const NavigationRailDestination(
                              icon: Icon(Icons.casino_outlined),
                              selectedIcon: Icon(Icons.casino),
                              label: Text('大厅'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.chat_bubble_outline),
                              selectedIcon: Icon(Icons.chat_bubble),
                              label: Text('广场'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.storefront_outlined),
                              selectedIcon: Icon(Icons.storefront),
                              label: Text('商城'),
                            ),
                            NavigationRailDestination(
                              icon: Badge(
                                isLabelVisible: unreadFriends > 0,
                                label: Text('$unreadFriends'),
                                backgroundColor: AppColors.secondary,
                                child: const Icon(Icons.people_alt_outlined),
                              ),
                              selectedIcon: Badge(
                                isLabelVisible: unreadFriends > 0,
                                label: Text('$unreadFriends'),
                                backgroundColor: AppColors.secondary,
                                child: const Icon(Icons.people_alt),
                              ),
                              label: const Text('好友'),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.person_outline),
                              selectedIcon: Icon(Icons.person),
                              label: Text('我的'),
                            ),
                          ],
                        ),
                        VerticalDivider(thickness: 1, width: 1, color: borderColor),
                        Expanded(
                          child: IndexedStack(
                            index: _currentIndex,
                            children: _pages,
                          ),
                        ),
                      ],
                    )
                  : IndexedStack(
                      index: _currentIndex,
                      children: _pages,
                    ),
              bottomNavigationBar: isWide
                  ? null
                  : Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppColors.darkShadow : AppColors.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: BottomNavigationBar(
                        currentIndex: _currentIndex,
                        backgroundColor: cardBg,
                        selectedItemColor: primaryColor,
                        unselectedItemColor: mutedColor,
                        type: BottomNavigationBarType.fixed,
                        selectedFontSize: 12,
                        unselectedFontSize: 12,
                        onTap: _onNavSelected,
                        items: [
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.casino_outlined),
                            activeIcon: Icon(Icons.casino, color: primaryColor),
                            label: '大厅',
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.chat_bubble_outline),
                            activeIcon: Icon(Icons.chat_bubble, color: primaryColor),
                            label: '广场',
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.storefront_outlined),
                            activeIcon: Icon(Icons.storefront, color: primaryColor),
                            label: '商城',
                          ),
                          BottomNavigationBarItem(
                            icon: Badge(
                              isLabelVisible: unreadFriends > 0,
                              label: Text('$unreadFriends'),
                              backgroundColor: AppColors.secondary,
                              child: const Icon(Icons.people_alt_outlined),
                            ),
                            activeIcon: Badge(
                              isLabelVisible: unreadFriends > 0,
                              label: Text('$unreadFriends'),
                              backgroundColor: AppColors.secondary,
                              child: Icon(Icons.people_alt, color: primaryColor),
                            ),
                            label: '好友',
                          ),
                          BottomNavigationBarItem(
                            icon: const Icon(Icons.person_outline),
                            activeIcon: Icon(Icons.person, color: primaryColor),
                            label: '我的',
                          ),
                        ],
                      ),
                    ),
            ),

            // 全局全服盛典特效层 (注意：房间内普通道具严禁在大厅播放，仅限全服特效！)
            if (throwEvent != null && throwEvent.isGlobal)
              Positioned.fill(
                child: InteractiveThrowOverlay(
                  event: throwEvent,
                  onComplete: () {
                    chatProv.clearThrowEvent();
                  },
                ),
              ),

            // 全局常驻最小化房间悬浮挂件 (点击可随时重返正在进行的对决)
            const MiniRoomFloatingWidget(),
          ],
        );
      },
    );
  }
}
