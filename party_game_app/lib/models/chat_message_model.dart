import 'package:flutter/material.dart';

enum ChatMessageType {
  text,
  emoji,
  phrase,
  throwItem,
  system,
}

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final ChatMessageType type;
  final String? targetPlayerId;
  final String? targetPlayerName;
  final String channel; // 'WORLD', 'CITY', 'ROOM'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String textColor;
  final int vipLevel;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    this.type = ChatMessageType.text,
    this.targetPlayerId,
    this.targetPlayerName,
    this.channel = 'WORLD',
    DateTime? timestamp,
    this.metadata,
    this.textColor = 'COLOR_DEFAULT',
    this.vipLevel = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  static Color getTextColorFromCode(String? code, {Color defaultColor = const Color(0xFF1E293B)}) {
    switch (code) {
      case 'COLOR_SAKURA_PINK':
        return const Color(0xFFE11D48); // 柔美樱花粉红 (在亮色背景下高对比清晰显示)
      case 'COLOR_CYBER_BLUE':
        return const Color(0xFF0284C7); // 赛博蔚蓝
      case 'COLOR_AURORA_GREEN':
        return const Color(0xFF059669); // 极光翡翠绿
      case 'COLOR_DEEP_PURPLE':
        return const Color(0xFF7C3AED); // 幻魅幽紫
      case 'COLOR_BLAZING_GOLD':
        return const Color(0xFFD97706); // 炽烈流金
      case 'COLOR_QQ_RED':
        return const Color(0xFFDC2626); // 经典QQ至尊红
      case 'COLOR_DEFAULT':
      default:
        return defaultColor;
    }
  }

  factory ChatMessageModel.system(String text, {String channel = 'WORLD'}) {
    return ChatMessageModel(
      id: 'SYS-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'SYSTEM',
      senderName: '聚会系统广播',
      senderAvatar: '📢',
      content: text,
      type: ChatMessageType.system,
      channel: channel,
    );
  }

  factory ChatMessageModel.throwItem({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String targetPlayerId,
    required String targetPlayerName,
    required String itemType, // 'EGG', 'BEER', 'FLOWER', 'SLIPPER', 'BOMB', 'ROCKET', 'YACHT', 'CASTLE'
    required String itemEmoji,
    int combo = 1,
    String? giftTitle,
    bool isGlobal = false,
    String? roomCode,
    String? blessing,
  }) {
    final title = giftTitle ?? {
      'EGG': '调皮臭蛋',
      'BEER': '冰爽啤酒',
      'FLOWER': '浪漫玫瑰',
      'SLIPPER': '暴击飞拖',
      'BOMB': '核爆飞弹',
      'ROCKET': '超级火箭',
      'YACHT': '豪华超跑',
      'CASTLE': '嘉年华盛典',
    }[itemType] ?? '互动道具';

    final actionDesc = isGlobal
        ? '📢 触发全服盛典：向全服献上 $itemEmoji $title！'
        : '向 $targetPlayerName 送出 $itemEmoji $title ×$combo！';

    return ChatMessageModel(
      id: 'THROW-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      targetPlayerId: targetPlayerId,
      targetPlayerName: targetPlayerName,
      content: actionDesc,
      type: ChatMessageType.throwItem,
      channel: isGlobal ? 'WORLD' : 'ROOM',
      metadata: {
        'itemType': itemType,
        'itemEmoji': itemEmoji,
        'combo': combo,
        'giftTitle': title,
        'isGlobal': isGlobal,
        'roomCode': roomCode,
        'blessing': blessing,
      },
    );
  }

  String? get itemType => metadata?['itemType'] as String?;
  String? get itemEmoji => metadata?['itemEmoji'] as String?;
  int get combo => (metadata?['combo'] is num) ? (metadata!['combo'] as num).toInt() : 1;
  String? get giftTitle => metadata?['giftTitle'] as String?;
  bool get isGlobal => (metadata?['isGlobal'] as bool?) ?? false;
  String? get roomCode => metadata?['roomCode'] as String?;
  String? get blessing => metadata?['blessing'] as String?;
}
