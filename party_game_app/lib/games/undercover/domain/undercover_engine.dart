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
  // 精选 45+ 组中文词对库（美食/日常/科技/校园/娱乐），防近期重复
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
    ['豆浆', '牛奶'],
    ['火锅', '麻辣烫'],
    ['奶茶', '果茶'],
    ['饺子', '馄饨'],
    ['包子', '馒头'],
    ['土豆丝', '酸辣粉'],
    ['烤串', '炸串'],
    ['西瓜', '哈密瓜'],
    ['耳机', '音响'],
    ['笔记本电脑', '平板电脑'],
    ['微信', 'QQ'],
    ['抖音', '快手'],
    ['地铁', '公交车'],
    ['高铁', '飞机'],
    ['电影院', 'KTV'],
    ['剧本杀', '密室逃脱'],
    ['狼人杀', '谁是卧底'],
    ['羽毛球', '乒乓球'],
    ['篮球', '足球'],
    ['游泳', '潜水'],
    ['图书馆', '自习室'],
    ['期末考试', '毕业论文'],
    ['班主任', '辅导员'],
    ['保温杯', '玻璃杯'],
    ['充电宝', '充电器'],
    ['太阳镜', '近视镜'],
    ['口红', '唇釉'],
    ['防晒霜', '隔离霜'],
    ['枕头', '抱枕'],
    ['沙发', '懒人椅'],
    ['空调', '电风扇'],
    ['除夕', '元旦'],
    ['春节', '中秋节'],
    ['喜剧片', '悬疑片'],
    ['钢琴', '吉他'],
  ];

  static final List<int> _recentPairIndices = [];

  late List<UndercoverPlayer> players;
  late String civilianWord;
  late String undercoverWord;
  UndercoverPhase phase = UndercoverPhase.wordDealing;
  int currentSpeakerIndex = 0;
  int roundNumber = 1;
  String? winnerTeam; // 'CIVILIAN' or 'UNDERCOVER'
  String statusMessage = '';
  List<String> tiedPlayerIds = [];
  bool isTieBreakerRound = false;
  final List<Map<String, String>> clueLogs = [];

  void startNewGame({
    required List<Map<String, dynamic>> playerConfigs, // [{id, name, avatar, isAi}]
  }) {
    final rand = Random();
    final availableIndices = <int>[
      for (int idx = 0; idx < wordPairs.length; idx++)
        if (!_recentPairIndices.contains(idx)) idx,
    ];
    final pool = availableIndices.isEmpty
        ? [for (int idx = 0; idx < wordPairs.length; idx++) idx]
        : availableIndices;
    final chosenIdx = pool[rand.nextInt(pool.length)];
    _recentPairIndices.add(chosenIdx);
    if (_recentPairIndices.length > 15) _recentPairIndices.removeAt(0);

    final pair = wordPairs[chosenIdx];
    final swap = rand.nextBool();
    civilianWord = swap ? pair[0] : pair[1];
    undercoverWord = swap ? pair[1] : pair[0];

    final total = playerConfigs.length;
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
    tiedPlayerIds = [];
    isTieBreakerRound = false;
    clueLogs.clear();
    statusMessage = '游戏已就绪，请每位玩家按顺序查看自己的底牌词语！';
  }

  void addClue(String playerId, String playerName, String clue) {
    final trimmed = clue.trim();
    if (trimmed.isEmpty) return;
    clueLogs.add({
      'playerId': playerId,
      'playerName': playerName,
      'clue': trimmed,
      'round': '$roundNumber',
    });
  }

  String generateAiClue(UndercoverPlayer ai) {
    final w = ai.word;
    final templates = <String>[
      '这个东西平时挺常见的，长度是${w.length}个字左右。',
      '大家或多或少都接触过它，我个人对它的印象还不错。',
      '它跟日常生活很贴近，不过不同人用法/口味可能不太一样。',
      '我给它贴个标签：实用又很有辨识度！',
      '在聚会或者闲暇时偶尔能见到它，大家仔细想想看！',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  void castAiVotes({String? excludePlayerId}) {
    final rand = Random();
    final active = activePlayers;
    final candidates = isTieBreakerRound
        ? active.where((p) => tiedPlayerIds.contains(p.id)).toList()
        : active;
    if (candidates.isEmpty) return;

    for (final ai in active) {
      if (!ai.isAi || ai.id == excludePlayerId) continue;
      final options = candidates.where((c) => c.id != ai.id).toList();
      final target = (options.isNotEmpty ? options : candidates)[rand.nextInt(options.isNotEmpty ? options.length : candidates.length)];
      target.votesReceived++;
    }
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
    final candidates = isTieBreakerRound
        ? active.where((p) => tiedPlayerIds.contains(p.id)).toList()
        : active;
    if (candidates.isEmpty) return;

    int maxVotes = 0;
    for (final p in candidates) {
      if (p.votesReceived > maxVotes) maxVotes = p.votesReceived;
    }
    final topTied = candidates.where((p) => p.votesReceived == maxVotes).toList();

    if (topTied.length > 1 && !isTieBreakerRound) {
      for (final p in players) {
        p.votesReceived = 0;
      }
      isTieBreakerRound = true;
      tiedPlayerIds = topTied.map((p) => p.id).toList();
      phase = UndercoverPhase.voting;
      statusMessage = '⚖️ 出现平票（${topTied.map((p) => p.name).join(' vs ')}）！进入平票 PK 复投环节！';
      return;
    }

    if (topTied.length > 1 && isTieBreakerRound) {
      isTieBreakerRound = false;
      tiedPlayerIds = [];
      roundNumber++;
      enterSpeakingPhase();
      statusMessage = '⚖️ PK 复投再次平票，本轮无人出局！进入第 $roundNumber 轮发言！';
      return;
    }

    final highest = topTied.first;
    isTieBreakerRound = false;
    tiedPlayerIds = [];
    highest.isOut = true;
    final roleText = highest.isUndercover ? '卧底' : '无辜平民';
    statusMessage = '投票出炉！【${highest.name}】被放逐！TA的真实身份是【$roleText】！';

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
      roundNumber++;
      enterSpeakingPhase();
    }
  }

  List<UndercoverPlayer> get activePlayers => players.where((p) => !p.isOut).toList();
}
