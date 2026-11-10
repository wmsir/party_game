import 'dart:math';
import 'game_player.dart';

/// 聚会桌游房间会话实体 (Game Room Session Model)
/// 承载 6 位幸运房间号、玩家席位、AI 机器人动态调配与好友手机号邀请机制
class GameRoomModel {
  final String roomCode;
  final String gameType; // 'take6' or 'liars_dice'
  final String hostPlayerId;
  final String storeName;
  final String tableNo;
  final List<GamePlayer> players;
  final DateTime createdAt;

  GameRoomModel({
    required this.roomCode,
    required this.gameType,
    required this.hostPlayerId,
    this.storeName = '离线聚会吧',
    this.tableNo = '888',
    List<GamePlayer>? players,
    DateTime? createdAt,
  })  : players = players ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// 快速创建全新 6 位数字房间号房间 (例如: 882619)
  factory GameRoomModel.create({
    required String gameType,
    required GamePlayer hostPlayer,
    String storeName = '离线聚会吧',
    String tableNo = '888',
  }) {
    final rand = Random();
    // 生成 6 位不以 0 开头的房间号
    final code = (100000 + rand.nextInt(900000)).toString();
    return GameRoomModel(
      roomCode: code,
      gameType: gameType,
      hostPlayerId: hostPlayer.id,
      storeName: storeName,
      tableNo: tableNo,
      players: [hostPlayer],
    );
  }

  /// 当前人类真人玩家数量
  int get humanCount => players.where((p) => !p.isAi).length;

  /// 当前 AI 机器人数量
  int get aiCount => players.where((p) => p.isAi).length;

  /// 是否满足开局条件 (至少 2 人，牛头王上限 10 人，大话骰上限 8 人)
  bool get canStartGame => players.length >= 2;

  int get maxCapacity => gameType == 'take6' ? 10 : 8;

  /// 动态增加一名 AI 玩家
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

    final aiPlayer = GamePlayer(
      id: 'U-${100000 + Random().nextInt(899999)}',
      name: name,
      isAi: true,
      aiPersonality: personality,
    );

    players.add(aiPlayer);
    return true;
  }

  /// 删除指定 AI 席位
  bool removeAiPlayer(String playerId) {
    final index = players.indexWhere((p) => p.id == playerId && p.isAi);
    if (index != -1) {
      players.removeAt(index);
      return true;
    }
    return false;
  }

  /// 修改指定 AI 玩家的难度与性格风格
  bool updateAiPersonality(String playerId, String newPersonality) {
    final index = players.indexWhere((p) => p.id == playerId && p.isAi);
    if (index != -1) {
      final old = players[index];
      players[index] = GamePlayer(
        id: old.id,
        name: old.name,
        isAi: true,
        aiPersonality: newPersonality,
      );
      return true;
    }
    return false;
  }

  /// 一键将空位用 AI 机器人补齐到目标人数
  void fillAiToCount(int targetCount) {
    final count = targetCount.clamp(2, maxCapacity);
    while (players.length < count) {
      addAiPlayer();
    }
  }

  /// 一键清空所有 AI，只保留真实真人玩家
  void clearAllAi() {
    players.removeWhere((p) => p.isAi);
  }

  /// 通过手机号邀请好友加入房间
  bool inviteFriendByPhone(String phone, {String? friendName}) {
    if (players.length >= maxCapacity) return false;
    final shortPhone = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    final name = friendName ?? '好友($shortPhone)';

    final friend = GamePlayer(
      id: 'HUMAN-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      isAi: false,
    );
    players.add(friend);
    return true;
  }
}
