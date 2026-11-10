import 'package:flutter/material.dart';
import '../models/game_player.dart';
import '../models/game_room_model.dart';
import '../services/room_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

/// 活跃中的游戏对局会话（支持最小化挂起与任意页面一键恢复再进入）
class ActiveRoomSession {
  final String roomCode;
  final String gameType;
  final String gameTitle;
  final String gameIcon;
  final Widget Function(BuildContext) screenBuilder;
  bool isMinimized;

  ActiveRoomSession({
    required this.roomCode,
    required this.gameType,
    required this.gameTitle,
    required this.gameIcon,
    required this.screenBuilder,
    this.isMinimized = false,
  });
}

class RoomProvider extends ChangeNotifier {
  final RoomService _roomService = RoomService();

  GameRoomModel? _currentRoom;
  GameRoomModel? get currentRoom => _currentRoom;

  List<GameRoomModel> get publicRooms => _roomService.rooms;

  Future<void> refreshRooms() async {
    await _roomService.refreshRooms();
    notifyListeners();
  }

  void clearAllRooms() {
    _roomService.clearAllRooms();
    notifyListeners();
  }

  // 全局活跃游戏会话（用于最小化悬浮窗和再次重返房间）
  ActiveRoomSession? _activeSession;
  ActiveRoomSession? get activeSession => _activeSession;
  bool get hasMinimizedRoom => _activeSession != null && _activeSession!.isMinimized;

  void registerActiveSession(ActiveRoomSession session) {
    _activeSession = session;
    notifyListeners();
  }

  void minimizeActiveSession() {
    if (_activeSession != null) {
      _activeSession!.isMinimized = true;
      notifyListeners();
    }
  }

  void restoreActiveSession() {
    if (_activeSession != null) {
      _activeSession!.isMinimized = false;
      notifyListeners();
    }
  }

  void closeActiveSession() {
    _activeSession = null;
    notifyListeners();
  }

  /// 判断当前用户是否已经在一个房间中（无论在大厅还是最小化悬浮中）
  bool isInRoom(String? playerId) {
    if (playerId == null) return false;
    if (_currentRoom != null && _currentRoom!.players.any((p) => p.id == playerId)) {
      return true;
    }
    return _activeSession != null;
  }

  void setCurrentRoom(GameRoomModel? room) {
    _currentRoom = room;
    notifyListeners();
  }

  GameRoomModel createRoom({
    required String gameType,
    required GamePlayer hostPlayer,
    String? roomName,
    String password = '',
    bool isPassAndPlay = false,
  }) {
    // 保证单房间：清理旧房间席位与会话
    if (_currentRoom != null) {
      _currentRoom!.players.removeWhere((p) => p.id == hostPlayer.id);
      closeActiveSession();
    }
    final room = _roomService.createRoom(
      gameType: gameType,
      hostPlayer: hostPlayer,
      roomName: roomName,
      password: password,
      isPassAndPlay: isPassAndPlay,
    );
    _currentRoom = room;
    notifyListeners();
    return room;
  }

  GameRoomModel? joinRoomByCode(String code, GamePlayer player, {String password = ''}) {
    final room = _roomService.findRoomByCode(code);
    if (room == null) return null;
    if (room.password.isNotEmpty && room.password != password) {
      throw Exception('房间密码错误');
    }

    final isExisting = room.players.any((p) => p.id == player.id);
    if (room.status == 'PLAYING' && !isExisting) {
      if (!room.allowSpectator) {
        throw Exception('当前对局正在进行中，且该房间未开启观战功能');
      }
      room.isSpectator = true;
      if (!room.spectators.any((s) => s.id == player.id)) {
        room.spectators.add(player);
      }
      _currentRoom = room;
      notifyListeners();
      return room;
    }

    if (room.players.length >= room.maxCapacity) {
      throw Exception('房间席位已满');
    }
    // 保证单房间：退出旧房间
    if (_currentRoom != null && _currentRoom!.roomCode != code) {
      _currentRoom!.players.removeWhere((p) => p.id == player.id);
      _currentRoom!.spectators.removeWhere((s) => s.id == player.id);
      closeActiveSession();
    }
    room.isSpectator = false;
    if (!room.players.any((p) => p.id == player.id)) {
      room.players.add(player);
    }
    _currentRoom = room;
    notifyListeners();
    return room;
  }

  GameRoomModel quickMatch(String gameType, GamePlayer me) {
    // 保证单房间：退出旧房间
    if (_currentRoom != null) {
      _currentRoom!.players.removeWhere((p) => p.id == me.id);
      closeActiveSession();
    }
    final room = _roomService.quickMatch(gameType: gameType, me: me);
    _currentRoom = room;
    notifyListeners();
    return room;
  }

  void addAiPlayer({String? personality}) {
    if (_currentRoom == null) return;
    _currentRoom!.addAiPlayer(personality: personality ?? 'BALANCED');
    notifyListeners();
  }

  void removeAiPlayer(String playerId) {
    if (_currentRoom == null) return;
    _currentRoom!.removeAiPlayer(playerId);
    notifyListeners();
  }

  void leaveRoom([String? playerId, String? roomCode, bool isPlaying = false]) {
    final targetCode = roomCode ?? _currentRoom?.roomCode ?? _activeSession?.roomCode;
    final targetPlayerId = playerId ?? _currentRoom?.hostPlayerId;

    if (isPlaying) {
      // 对局进行中退出：转为自动托管，绝不解散房间，保证其他玩家游戏继续进行
      if (targetCode != null) {
        SocketService().send({
          'type': 'GAME_ACTION',
          'action': 'PLAYER_AUTO_HOST',
          'roomCode': targetCode,
          'senderId': targetPlayerId ?? '',
        });
      }
      closeActiveSession();
      notifyListeners();
      return;
    }

    // 1. 在当前活跃房间中移除席位
    if (_currentRoom != null) {
      if (targetPlayerId != null) {
        _currentRoom!.players.removeWhere((p) => p.id == targetPlayerId);
      }
      if (_currentRoom!.humanCount == 0 || _currentRoom!.hostPlayerId == targetPlayerId) {
        _roomService.removeRoom(_currentRoom!.roomCode);
        ApiService().closeRoom(_currentRoom!.roomCode);
        _currentRoom = null;
      }
    }

    // 2. 在全局 RoomService 中彻底移除席位并校验剩余人类
    if (targetCode != null) {
      _roomService.removePlayerFromRoom(targetCode, targetPlayerId ?? '');
      SocketService().send({
        'type': 'LEAVE_ROOM',
        'roomCode': targetCode,
        'userId': targetPlayerId ?? '',
      });
    }

    // 3. 彻底销毁并清理所有无人类玩家的房间
    _roomService.cleanNoHumanRooms();

    closeActiveSession();
    notifyListeners();
  }
}
