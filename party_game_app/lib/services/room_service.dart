import 'dart:async';
import '../models/game_player.dart';
import '../models/game_room_model.dart';
import 'api_service.dart';

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal() {
    refreshRooms();
  }

  final List<GameRoomModel> _rooms = [];
  List<GameRoomModel> get rooms => _rooms.where((r) => r.humanCount > 0).toList();

  Future<void> refreshRooms() async {
    try {
      final remoteRooms = await ApiService().fetchRooms();
      final now = DateTime.now();
      final validRooms = remoteRooms.where((r) {
        final ageMinutes = now.difference(r.createdAt).inMinutes;
        final isRecent = ageMinutes >= 0 && ageMinutes < 10;
        final hasHumanPlayers = r.humanCount > 0;
        if (!hasHumanPlayers) {
          ApiService().closeRoom(r.roomCode);
        }
        return isRecent && hasHumanPlayers;
      }).toList();

      _rooms.clear();
      _rooms.addAll(validRooms);
    } catch (_) {}
  }

  void cleanNoHumanRooms() {
    final toRemove = _rooms.where((r) => r.humanCount == 0).toList();
    for (final r in toRemove) {
      _rooms.remove(r);
      ApiService().closeRoom(r.roomCode);
    }
  }

  void removePlayerFromRoom(String roomCode, String playerId) {
    final code = roomCode.trim();
    final room = findRoomByCode(code);
    if (room != null) {
      room.players.removeWhere((p) => p.id == playerId);
      if (room.humanCount == 0 || room.hostPlayerId == playerId) {
        removeRoom(code);
      } else {
        ApiService().leaveRoom(roomCode: code, playerId: playerId);
      }
    }
    cleanNoHumanRooms();
  }

  void removeRoom(String roomCode) {
    final code = roomCode.trim();
    _rooms.removeWhere((r) => r.roomCode == code);
    ApiService().closeRoom(code);
  }

  void clearAllRooms() {
    _rooms.clear();
    ApiService().clearRooms();
  }

  GameRoomModel createRoom({
    required String gameType,
    required GamePlayer hostPlayer,
    String? roomName,
    String password = '',
    bool isPassAndPlay = false,
  }) {
    // 商业化防重复：同一房主先清理其历史旧房，绝不堆积
    _rooms.removeWhere((r) => r.hostPlayerId == hostPlayer.id);

    final room = GameRoomModel.create(
      gameType: gameType,
      hostPlayer: hostPlayer,
      roomName: roomName,
      password: password,
      isPassAndPlay: isPassAndPlay,
    );
    _rooms.insert(0, room);

    // 异步同步到后端云服务，统一双方房间编号
    ApiService().createRoom(
      roomCode: room.roomCode,
      gameType: gameType,
      hostPlayer: hostPlayer,
      roomName: roomName,
      password: password,
      isPassAndPlay: isPassAndPlay,
    );

    return room;
  }

  GameRoomModel? findRoomByCode(String code) {
    try {
      return _rooms.firstWhere((r) => r.roomCode == code.trim());
    } catch (_) {
      return null;
    }
  }

  /// 快速匹配或自动加入已有房间，若没有则自动创建新房间
  GameRoomModel quickMatch({
    required String gameType,
    required GamePlayer me,
  }) {
    // 寻找未满且无密码的房间
    final matched = _rooms.where((r) =>
        r.gameType == gameType &&
        r.password.isEmpty &&
        r.players.length < r.maxCapacity &&
        !r.players.any((p) => p.id == me.id)
    ).toList();

    if (matched.isNotEmpty) {
      final target = matched.first;
      target.players.add(me);
      ApiService().joinRoom(roomCode: target.roomCode, player: me);
      return target;
    }

    // 没有匹配到则创建新房间并补齐 1~2 个 AI
    final newRoom = createRoom(
      gameType: gameType,
      hostPlayer: me,
    );
    newRoom.addAiPlayer();
    newRoom.addAiPlayer();
    return newRoom;
  }
}
