import 'dart:math';
import 'game_player.dart';

class GameRoomModel {
  final String roomCode;
  final String gameType; // 'liars_dice', 'take6', 'party_wheel', 'undercover'
  final String roomName;
  final String hostPlayerId;
  final List<GamePlayer> players;
  final DateTime createdAt;
  final String password;
  final bool isPassAndPlay; // 本地同屏轮流传手机模式
  String status; // 'WAITING', 'PLAYING', 'FINISHED'
  bool allowSpectator; // 是否允许观众旁观
  bool isSpectator; // 当前用户是否为旁观者
  final List<GamePlayer> spectators;

  GameRoomModel({
    required this.roomCode,
    required this.gameType,
    required this.roomName,
    required this.hostPlayerId,
    this.password = '',
    this.isPassAndPlay = false,
    this.status = 'WAITING',
    this.allowSpectator = true,
    this.isSpectator = false,
    List<GamePlayer>? players,
    List<GamePlayer>? spectators,
    DateTime? createdAt,
  })  : players = players ?? [],
        spectators = spectators ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory GameRoomModel.create({
    required String gameType,
    required GamePlayer hostPlayer,
    String? roomName,
    String password = '',
    bool isPassAndPlay = false,
  }) {
    final rand = Random();
    final code = (100000 + rand.nextInt(900000)).toString();
    final gameTitle = {
      'liars_dice': '大话骰',
      'take6': '谁是牛头王',
      'party_wheel': '聚会大冒险转盘',
      'undercover': '谁是卧底',
    }[gameType] ?? '聚会桌游';

    return GameRoomModel(
      roomCode: code,
      gameType: gameType,
      roomName: roomName ?? '${hostPlayer.name}的$gameTitle房',
      hostPlayerId: hostPlayer.id,
      password: password,
      isPassAndPlay: isPassAndPlay,
      players: [hostPlayer],
    );
  }

  int get humanCount => players.where((p) => !p.isAi).length;
  int get aiCount => players.where((p) => p.isAi).length;

  int get minPlayers => gameType == 'undercover' ? 4 : 2;
  int get maxCapacity {
    switch (gameType) {
      case 'take6':
        return 10;
      case 'undercover':
        return 10;
      case 'party_wheel':
        return 12;
      case 'liars_dice':
      default:
        return 8;
    }
  }

  bool get allNonHostsReady {
    final nonHosts = players.where((p) => p.id != hostPlayerId).toList();
    if (nonHosts.isEmpty) return false;
    return nonHosts.every((p) => p.isReady);
  }

  bool get canStartGame => players.length >= minPlayers && allNonHostsReady;

  bool addAiPlayer({String? customName, String personality = 'BALANCED'}) {
    if (players.length >= maxCapacity) return false;

    final realisticNames = [
      '微醺小阿杰',
      '魔都骰神亮哥',
      '晴天小仙女',
      '随遇而安',
      '追风少年',
      '一杯敬自由',
      '奶茶半糖加椰果',
      '风吹麦浪',
      '橘子汽水',
      '星河入梦',
      '青衫故人',
      '熬夜冠军小刘',
      '可乐配炸鸡',
      '喵喵不吃鱼',
      '孤独的酒馆',
      '夜市摊主老王',
      '山间有轻风',
      '深海潜水员',
      '清晨第一缕阳光',
      '西湖断桥客',
      '骑猪看日出',
      '火锅狂热爱好者',
      '落日沉溺于海',
      '白日梦想家',
      '半支烟的距离',
      '向日葵的守望',
      '深夜食堂主理人',
      '江南烟雨客',
      '浮生若梦',
      '听风吹过的声音',
      '奔跑的五花肉',
      '爱笑的向日葵',
      '云淡风轻',
      '一壶浊酒',
      '时光慢些走',
      '街角咖啡香',
      '落叶知秋',
      '岁月静好',
      '星空下的守护者',
      '快乐小肥宅',
    ];

    final existingNames = players.map((p) => p.name).toSet();
    final availableNames = realisticNames.where((n) => !existingNames.contains(n)).toList();
    final name = customName ??
        (availableNames.isNotEmpty
            ? availableNames[Random().nextInt(availableNames.length)]
            : '玩家${1000 + Random().nextInt(9000)}');

    final realisticAvatars = ['🦊', '🐼', '🦁', '🐯', '🐰', '🦄', '🐨', '🐺', '🐱', '🐶', '🐻', '🦉', '🐬', '🐙', '🌸', '🌟'];
    final avatar = realisticAvatars[Random().nextInt(realisticAvatars.length)];

    final aiPlayer = GamePlayer(
      id: 'U-${100000 + Random().nextInt(899999)}',
      name: name,
      avatar: avatar,
      isAi: true,
      isReady: true,
      aiPersonality: personality,
    );

    players.add(aiPlayer);
    return true;
  }

  bool removeAiPlayer(String playerId) {
    final index = players.indexWhere((p) => p.id == playerId && p.isAi);
    if (index != -1) {
      players.removeAt(index);
      return true;
    }
    return false;
  }

  bool removePlayer(String playerId) {
    final index = players.indexWhere((p) => p.id == playerId);
    if (index != -1) {
      players.removeAt(index);
      return true;
    }
    return false;
  }

  void fillAiToCount(int targetTotal) {
    while (players.length < targetTotal && players.length < maxCapacity) {
      final ok = addAiPlayer();
      if (!ok) break;
    }
  }

  Map<String, dynamic> toJson() => {
    'roomCode': roomCode,
    'gameType': gameType,
    'roomName': roomName,
    'hostPlayerId': hostPlayerId,
    'password': password,
    'isPassAndPlay': isPassAndPlay,
    'players': players.map((p) => p.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory GameRoomModel.fromJson(Map<String, dynamic> json) {
    final hostId = json['hostPlayerId'] as String? ??
        (json['hostPlayer'] is Map ? (json['hostPlayer']['id']?.toString() ?? '') : '');

    var rawPlayers = json['players'];
    List<GamePlayer> parsedPlayers = [];
    if (rawPlayers is List) {
      for (int i = 0; i < rawPlayers.length; i++) {
        final item = rawPlayers[i];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final pid = m['id']?.toString() ?? 'P-$i';
          final isHostOfRoom = (m['isHost'] == true) || (pid == hostId) || (i == 0);
          parsedPlayers.add(GamePlayer(
            id: pid,
            name: m['name']?.toString() ?? '玩家',
            avatar: m['avatar']?.toString() ?? '🦊',
            isAi: m['isAi'] == true,
            score: (m['score'] is num) ? (m['score'] as num).toInt() : 0,
            isReady: isHostOfRoom ? true : (m['isReady'] == true),
            isEliminated: m['isEliminated'] == true,
          ));
        }
      }
    }
    // 若 players 为空，但服务端提供了 hostPlayer，则作为初始房主成员放入
    if (parsedPlayers.isEmpty && json['hostPlayer'] is Map) {
      try {
        final h = Map<String, dynamic>.from(json['hostPlayer'] as Map);
        parsedPlayers.add(GamePlayer(
          id: h['id']?.toString() ?? 'H-0',
          name: h['name']?.toString() ?? '房主',
          avatar: h['avatar']?.toString() ?? '🦊',
          isAi: false,
          isReady: true,
        ));
      } catch (_) {}
    }

    final rawCreated = json['createdAt'];
    DateTime parsedCreated = DateTime.now();
    if (rawCreated is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is num) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt());
    } else if (rawCreated != null) {
      final str = rawCreated.toString();
      final intVal = int.tryParse(str);
      if (intVal != null && str.length >= 10) {
        parsedCreated = DateTime.fromMillisecondsSinceEpoch(intVal);
      } else {
        parsedCreated = DateTime.tryParse(str) ?? DateTime.now();
      }
    }

    final parsedSpectators = <GamePlayer>[];
    if (json['spectators'] is List) {
      for (final item in (json['spectators'] as List)) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          parsedSpectators.add(GamePlayer(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? '观众',
            avatar: m['avatar']?.toString() ?? '👀',
            isAi: false,
            isReady: false,
          ));
        }
      }
    }

    return GameRoomModel(
      roomCode: json['roomCode'] as String? ?? '',
      gameType: json['gameType'] as String? ?? 'liars_dice',
      roomName: json['roomName'] as String? ?? '聚会房间',
      hostPlayerId: hostId,
      password: json['password'] as String? ?? '',
      isPassAndPlay: json['isPassAndPlay'] as bool? ?? false,
      status: json['status'] as String? ?? 'WAITING',
      allowSpectator: json['allowSpectator'] != false,
      isSpectator: json['isSpectator'] == true,
      players: parsedPlayers,
      spectators: parsedSpectators,
      createdAt: parsedCreated,
    );
  }
}
