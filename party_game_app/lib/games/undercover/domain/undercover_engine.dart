import 'dart:math';

enum UndercoverPhase {
  wordDealing,  // 发词看词
  speaking,     // 轮流发言描述
  voting,       // 投票公决
  gameOver,     // 游戏结束结算
}

class UndercoverPlayer {
  final String id;
  final String name;
  final String avatar;
  final bool isAi;
  final bool isUndercover;
  final String word;
  bool isOut;
  int votesReceived;

  UndercoverPlayer({
    required this.id,
    required this.name,
    required this.avatar,
    this.isAi = false,
    required this.isUndercover,
    required this.word,
    this.isOut = false,
    this.votesReceived = 0,
  });
}

class UndercoverEngine {
  // 经典双词词对库
  static const List<List<String>> wordPairs = [
    ['汉堡包', '肉夹馍'],
    ['可口可乐', '百事可乐'],
    ['大白兔奶糖', '金丝猴奶糖'],
    ['秋裤', '毛裤'],
    ['玫瑰', '月季'],
    ['自行车', '电动车'],
    ['小龙虾', '大闸蟹'],
    ['烤冷面', '手抓饼'],
    ['鸭脖', '鸡爪'],
    ['雨伞', '雨衣'],
  ];

  late List<UndercoverPlayer> players;
  late String civilianWord;
  late String undercoverWord;
  UndercoverPhase phase = UndercoverPhase.wordDealing;
  int currentSpeakerIndex = 0;
  int roundNumber = 1;
  String? winnerTeam; // 'CIVILIAN' or 'UNDERCOVER'
  String statusMessage = '';

  void startNewGame({
    required List<Map<String, dynamic>> playerConfigs, // [{id, name, avatar, isAi}]
  }) {
    final rand = Random();
    final pair = wordPairs[rand.nextInt(wordPairs.length)];
    // 随机决定谁是平民词谁是卧底词
    final swap = rand.nextBool();
    civilianWord = swap ? pair[0] : pair[1];
    undercoverWord = swap ? pair[1] : pair[0];

    final total = playerConfigs.length;
    // 卧底数量：4~6人 1卧底，7人以上 2卧底
    final undercoverCount = total >= 7 ? 2 : 1;
    final undercoverIndices = <int>{};
    while (undercoverIndices.length < undercoverCount) {
      undercoverIndices.add(rand.nextInt(total));
    }

    players = [];
    for (int i = 0; i < total; i++) {
      final isUc = undercoverIndices.contains(i);
      players.add(
        UndercoverPlayer(
          id: playerConfigs[i]['id'] as String,
          name: playerConfigs[i]['name'] as String,
          avatar: playerConfigs[i]['avatar'] as String? ?? '🦊',
          isAi: playerConfigs[i]['isAi'] as bool? ?? false,
          isUndercover: isUc,
          word: isUc ? undercoverWord : civilianWord,
        ),
      );
    }

    phase = UndercoverPhase.wordDealing;
    currentSpeakerIndex = 0;
    roundNumber = 1;
    winnerTeam = null;
    statusMessage = '游戏已就绪，请每位玩家按顺序查看自己的底牌词语！';
  }

  void enterSpeakingPhase() {
    phase = UndercoverPhase.speaking;
    currentSpeakerIndex = 0;
    statusMessage = '第 $roundNumber 轮描述：请 ${activePlayers[currentSpeakerIndex].name} 发言描述！';
  }

  void nextSpeaker() {
    final active = activePlayers;
    if (currentSpeakerIndex < active.length - 1) {
      currentSpeakerIndex++;
      statusMessage = '请 ${active[currentSpeakerIndex].name} 发言描述！';
    } else {
      // 描述完毕，进入投票放逐阶段
      enterVotingPhase();
    }
  }

  void enterVotingPhase() {
    phase = UndercoverPhase.voting;
    for (final p in players) {
      p.votesReceived = 0;
    }
    statusMessage = '全员描述完毕！请大家投票选出怀疑的卧底！';
  }

  void votePlayer(String targetPlayerId) {
    final target = players.firstWhere((p) => p.id == targetPlayerId);
    target.votesReceived++;
  }

  void finishVoting() {
    final active = activePlayers;
    active.sort((a, b) => b.votesReceived.compareTo(a.votesReceived));
    final highest = active.first;

    highest.isOut = true;
    final roleText = highest.isUndercover ? '卧底' : '无辜平民';
    statusMessage = '投票出炉！【${highest.name}】被放逐！TA的真实身份是【$roleText】！';

    // 检查胜负
    final remainingUndercovers = activePlayers.where((p) => p.isUndercover).length;
    final remainingCivilians = activePlayers.where((p) => !p.isUndercover).length;

    if (remainingUndercovers == 0) {
      winnerTeam = 'CIVILIAN';
      phase = UndercoverPhase.gameOver;
      statusMessage = '🎉 平民获胜！卧底已全部被指认淘汰！平民词【$civilianWord】，卧底词【$undercoverWord】！';
    } else if (remainingUndercovers >= remainingCivilians) {
      winnerTeam = 'UNDERCOVER';
      phase = UndercoverPhase.gameOver;
      statusMessage = '😈 卧底获胜！卧底人数已占优！卧底词【$undercoverWord】，平民词【$civilianWord】！';
    } else {
      // 继续下一轮
      roundNumber++;
      enterSpeakingPhase();
    }
  }

  List<UndercoverPlayer> get activePlayers => players.where((p) => !p.isOut).toList();
}
