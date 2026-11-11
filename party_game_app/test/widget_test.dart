import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:party_game_app/core/constants/app_theme.dart';
import 'package:party_game_app/core/constants/app_version.dart';
import 'package:party_game_app/core/storage/local_storage.dart';
import 'package:party_game_app/models/game_player.dart';
import 'package:party_game_app/models/game_room_model.dart';
import 'package:party_game_app/models/user_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  test('LocalStorage and core models serialize and compute state cleanly', () async {
    await LocalStorage.setString('last_game', 'liars_dice');
    expect(LocalStorage.getString('last_game'), 'liars_dice');

    final user = UserModel(
      id: 'U-1001',
      username: 'tester',
      nickname: '测试玩家',
      winCount: 6,
      totalGames: 10,
    );
    expect(user.cleanId, 'U1001');
    expect(user.winRate, 60.0);

    final restoredUser = UserModel.fromJson(user.toJson());
    expect(restoredUser.nickname, '测试玩家');
    expect(restoredUser.ownsItem('CLASSIC_GOLD'), isTrue);

    final host = GamePlayer(id: user.id, name: user.nickname, isReady: true);
    final room = GameRoomModel.create(
      gameType: 'liars_dice',
      hostPlayer: host,
    );
    expect(room.roomCode.length, 6);
    expect(room.canStartGame, isFalse);

    expect(room.addAiPlayer(customName: 'AI陪练'), isTrue);
    expect(room.players.length, 2);
    expect(room.canStartGame, isTrue);
  });

  testWidgets('AppTheme renders self-contained Material shell without live timers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightEyeCareTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('聚会桌游吧')),
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('v${AppVersionInfo.versionName}'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('聚会桌游吧'), findsOneWidget);
    expect(find.text('v${AppVersionInfo.versionName}'), findsOneWidget);
  });
}
