class GlobalBlessingModel {
  final String id;
  final String broadcastType; // 'MARQUEE', 'ROCKET', 'YACHT', 'CASTLE'
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final int senderVip;
  final String blessing;
  final String itemType;
  final String itemEmoji;
  final String giftTitle;
  final DateTime timestamp;

  GlobalBlessingModel({
    required this.id,
    this.broadcastType = 'MARQUEE',
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderVip = 0,
    required this.blessing,
    this.itemType = 'MARQUEE',
    this.itemEmoji = '📢',
    this.giftTitle = '全服喇叭',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GlobalBlessingModel.fromJson(Map<String, dynamic> json) {
    final rawBlessing = json['blessing']?.toString().trim();
    final rawContent = json['content']?.toString().trim();
    final rawMessage = json['message']?.toString().trim();
    final effectiveBlessing = (rawBlessing != null && rawBlessing.isNotEmpty)
        ? rawBlessing
        : ((rawContent != null && rawContent.isNotEmpty)
            ? rawContent
            : ((rawMessage != null && rawMessage.isNotEmpty)
                ? rawMessage
                : '祝大家玩得开心，天天赢大奖！'));

    final rawVip = json['senderVip'] ?? json['vipLevel'];
    final vip = int.tryParse(rawVip?.toString() ?? '0') ?? 0;

    DateTime? ts;
    final rawTs = json['timestamp'];
    if (rawTs != null) {
      if (rawTs is num) {
        ts = DateTime.fromMillisecondsSinceEpoch(rawTs.toInt());
      } else {
        final parsedNum = int.tryParse(rawTs.toString());
        if (parsedNum != null) {
          ts = DateTime.fromMillisecondsSinceEpoch(parsedNum);
        } else {
          try {
            ts = DateTime.parse(rawTs.toString());
          } catch (_) {}
        }
      }
    }

    return GlobalBlessingModel(
      id: json['id']?.toString() ?? 'BLS-${DateTime.now().millisecondsSinceEpoch}',
      broadcastType: json['broadcastType']?.toString() ?? 'MARQUEE',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '神秘贵宾',
      senderAvatar: json['senderAvatar']?.toString() ?? '🦊',
      senderVip: vip,
      blessing: effectiveBlessing,
      itemType: json['itemType']?.toString() ?? 'MARQUEE',
      itemEmoji: json['itemEmoji']?.toString() ?? '📢',
      giftTitle: json['giftTitle']?.toString() ?? '全服喇叭',
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'GLOBAL_BROADCAST',
      'broadcastType': broadcastType,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderVip': senderVip,
      'blessing': blessing,
      'itemType': itemType,
      'itemEmoji': itemEmoji,
      'giftTitle': giftTitle,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
