class PostMomentModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final String? gameTag; // '大话骰', '谁是牛头王', '聚会大冒险'
  final String? recordHighlight; // e.g. '【绝地反击】仅剩1颗骰子连翻三把获胜！'
  int likeCount;
  bool likedByMe;
  final List<String> comments;
  final DateTime createdAt;

  PostMomentModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.gameTag,
    this.recordHighlight,
    this.likeCount = 0,
    this.likedByMe = false,
    List<String>? comments,
    DateTime? createdAt,
  }) : comments = comments ?? [],
       createdAt = createdAt ?? DateTime.now();

  static List<PostMomentModel> getSampleMoments() {
    return [
      PostMomentModel(
        id: 'M-1',
        authorId: 'F-101',
        authorName: '骰王小霸王',
        authorAvatar: '🐯',
        content: '昨晚通宵大话骰，对面以为我全是斋，直接开我！结果全场开出来 7 个 6，哈哈哈哈哈！',
        gameTag: '大话骰',
        recordHighlight: '🏆 经典一击：7个6斋开全场逆风获胜！',
        likeCount: 28,
        likedByMe: false,
        comments: ['阿强: 太秀了', '甜心小丸子: 碰见你算对面倒霉😂'],
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      PostMomentModel(
        id: 'M-2',
        authorId: 'F-102',
        authorName: '算无遗策阿强',
        authorAvatar: '🐼',
        content: '牛头王 6 人局打完，整场比赛 0 罚分完胜！排位分直接飙升 120 点！',
        gameTag: '谁是牛头王',
        recordHighlight: '🐂 完美避坑：0张吃牌，全场最高成就！',
        likeCount: 42,
        likedByMe: true,
        comments: ['老司机: 大师求带我双排上分'],
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }
}
