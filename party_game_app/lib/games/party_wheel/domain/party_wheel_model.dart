import 'package:flutter/material.dart';

class WheelSegment {
  final String text;
  final Color color;
  final String type; // 'DRINK', 'TRUTH', 'DARE', 'LUCKY', 'PUNISH'

  const WheelSegment({
    required this.text,
    required this.color,
    this.type = 'PUNISH',
  });
}

class WheelScenePack {
  final String id;
  final String name;
  final String emoji;
  final String subtitle;
  final List<WheelSegment> segments;
  final List<String> truths;
  final List<String> dares;

  const WheelScenePack({
    required this.id,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.segments,
    required this.truths,
    required this.dares,
  });
}

class PartyWheelModel {
  static const List<WheelSegment> defaultSegments = [
    WheelSegment(text: '喝半杯', color: Color(0xFFEF4444), type: 'DRINK'),
    WheelSegment(text: '真心话', color: Color(0xFF8B5CF6), type: 'TRUTH'),
    WheelSegment(text: '左边喝', color: Color(0xFFF59E0B), type: 'DRINK'),
    WheelSegment(text: '大冒险', color: Color(0xFFEC4899), type: 'DARE'),
    WheelSegment(text: '右边喝', color: Color(0xFF10B981), type: 'DRINK'),
    WheelSegment(text: '免罚金牌', color: Color(0xFF3B82F6), type: 'LUCKY'),
    WheelSegment(text: '全场干杯', color: Color(0xFFF97316), type: 'DRINK'),
    WheelSegment(text: '指定一人', color: Color(0xFF14B8A6), type: 'DRINK'),
  ];

  static const List<String> truthQuestions = [
    '全场你对谁的第一印象最好？为什么？',
    '最近一次社死或尴尬经历是什么？',
    '手机里最近一张自拍是什么时候拍的？',
    '如果中了 500 万，你会立刻辞职还是继续上班？',
    '你最拿手的一道菜或隐藏才艺是什么？',
    '大学或工作以来最疯狂的一次熬夜在干嘛？',
    '现场谁看起来最像“喝醉了会哭或发疯”的人？',
    '你手机里最不舍得删的一张朋友黑照是谁的？',
  ];

  static const List<String> dareChallenges = [
    '模仿一种动物的叫声和动作，持续 10 秒！',
    '用播音腔念一句：“今晚全场的消费由我买单”！',
    '给左手边第一位玩家认真夸赞 3 个优点！',
    '现场给大家分享一个手机相册里最近拍的风景/美食图！',
    '站起来摆一个超级英雄出场 Pose 保持 5 秒！',
    '用方言念一段绕口令“四是四，十是十”！',
    '做 8 个俯卧撑或 10 个深蹲，节奏不能乱！',
  ];

  static const List<WheelScenePack> scenePacks = [
    WheelScenePack(
      id: 'icebreaker',
      name: '破冰暖场',
      emoji: '🫧',
      subtitle: '零尴尬轻松热场 · 新朋友也能秒熟',
      segments: defaultSegments,
      truths: [
        '全场你对谁的第一印象最好？为什么？',
        '最近一次社死或尴尬经历是什么？',
        '手机里最近一张自拍是什么时候拍的？',
        '如果中了 500 万，你会立刻辞职还是继续上班？',
        '你最拿手的一道菜或隐藏才艺是什么？',
        '大学或工作以来最疯狂的一次熬夜在干嘛？',
      ],
      dares: [
        '模仿一种动物的叫声和动作，持续 10 秒！',
        '用播音腔念一句：“今晚全场的消费由我买单”！',
        '给左手边第一位玩家认真夸赞 3 个优点！',
        '现场给大家分享一个手机相册里最近拍的风景/美食图！',
        '站起来摆一个超级英雄出场 Pose 保持 5 秒！',
        '用方言念一段绕口令“四是四，十是十”！',
      ],
    ),
    WheelScenePack(
      id: 'friends',
      name: '老友爆笑',
      emoji: '🍻',
      subtitle: '熟人局辛辣拷问 · 欢笑炸场',
      segments: [
        WheelSegment(text: '喝半杯', color: Color(0xFFDC2626), type: 'DRINK'),
        WheelSegment(text: '真心话', color: Color(0xFF7C3AED), type: 'TRUTH'),
        WheelSegment(text: '左边喝', color: Color(0xFFD97706), type: 'DRINK'),
        WheelSegment(text: '大冒险', color: Color(0xFFDB2777), type: 'DARE'),
        WheelSegment(text: '右边喝', color: Color(0xFF059669), type: 'DRINK'),
        WheelSegment(text: '免罚金牌', color: Color(0xFF2563EB), type: 'LUCKY'),
        WheelSegment(text: '全场干杯', color: Color(0xFFEA580C), type: 'DRINK'),
        WheelSegment(text: '指定一人', color: Color(0xFF0D9488), type: 'DRINK'),
      ],
      truths: [
        '现场谁看起来最像“喝醉了会哭或发疯”的人？',
        '你手机里最不舍得删的一张朋友黑照是谁的？',
        '做过最疯狂、从来没告诉过家人的事情是什么？',
        '上次悄悄买单或送朋友礼物最肉痛的一次花了多少？',
        '在场谁借钱最可能忘还（纯玩笑）？',
        '说出你和现场某位好友之间最难忘的一件糗事！',
      ],
      dares: [
        '给微信置顶或最近联系人发一句“今晚风好大，好想吃夜宵”！',
        '做 8 个俯卧撑或 10 个深蹲，节奏不能乱！',
        '和右边玩家深情对视 8 秒，谁先笑谁喝半杯！',
        '让右边桌友用你手机发一条仅大家可见的搞笑文案！',
        '模仿现场某位好友的经典口头禅和神态！',
        '用最深情的语气对着水杯/酒杯念一首情诗！',
      ],
    ),
    WheelScenePack(
      id: 'couple',
      name: '心动升温',
      emoji: '💘',
      subtitle: '甜蜜对视互动 · 气氛拉满',
      segments: [
        WheelSegment(text: '喝半杯', color: Color(0xFFE11D48), type: 'DRINK'),
        WheelSegment(text: '真心话', color: Color(0xFF9333EA), type: 'TRUTH'),
        WheelSegment(text: '左边喝', color: Color(0xFFF43F5E), type: 'DRINK'),
        WheelSegment(text: '大冒险', color: Color(0xFFEC4899), type: 'DARE'),
        WheelSegment(text: '右边喝', color: Color(0xFFFB7185), type: 'DRINK'),
        WheelSegment(text: '免罚金牌', color: Color(0xFF6366F1), type: 'LUCKY'),
        WheelSegment(text: '全场干杯', color: Color(0xFFF97316), type: 'DRINK'),
        WheelSegment(text: '指定一人', color: Color(0xFFC026D3), type: 'DRINK'),
      ],
      truths: [
        '谈过几次恋爱？最心动的一瞬间是什么？',
        '对方哪个小习惯让你觉得超级可爱？',
        '如果可以和在场某位交换一天人生，你想选谁？',
        '你最看重伴侣的哪三个特质？',
        '收到过最浪漫或最离谱的礼物是什么？',
        '异地/忙碌时最希望另一半为你做哪件小事？',
      ],
      dares: [
        '对右手边或指定好友深情表白 10 秒钟！',
        '现场比心并说出一句土味情话，不能卡壳！',
        '让对面玩家指定一个表情，连续做三连拍！',
        '闭眼猜出右边好友手里拿的小物件是什么！',
        '大声说出你对在场某位的心动第一眼印象！',
        '和指定好友击掌十次并同时喊出彼此昵称！',
      ],
    ),
    WheelScenePack(
      id: 'talent',
      name: '才艺整活',
      emoji: '🎤',
      subtitle: '麦霸秀技 · 整活不冷场',
      segments: [
        WheelSegment(text: '喝半杯', color: Color(0xFFEF4444), type: 'DRINK'),
        WheelSegment(text: '真心话', color: Color(0xFF6366F1), type: 'TRUTH'),
        WheelSegment(text: '左边喝', color: Color(0xFF0EA5E9), type: 'DRINK'),
        WheelSegment(text: '大冒险', color: Color(0xFFF59E0B), type: 'DARE'),
        WheelSegment(text: '右边喝', color: Color(0xFF10B981), type: 'DRINK'),
        WheelSegment(text: '免罚金牌', color: Color(0xFF3B82F6), type: 'LUCKY'),
        WheelSegment(text: '全场干杯', color: Color(0xFF8B5CF6), type: 'DRINK'),
        WheelSegment(text: '指定一人', color: Color(0xFF14B8A6), type: 'DRINK'),
      ],
      truths: [
        '如果上台参加才艺选秀，你会表演什么绝活？',
        '你最喜欢的一首歌是什么，为什么有故事？',
        '小时候最想成为的职业是什么？现在实现几分？',
        '最拿手的模仿对象是谁？',
        '人生中最有成就感的一次高光时刻是什么？',
        '如果拍一部关于你的电影，片名会叫什么？',
      ],
      dares: [
        '清唱你最拿手的一首歌的高潮部分（至少 4 句）！',
        '30 秒内说出一个冷笑话，逗笑至少一人算过关！',
        '用三种不同情绪（开心/委屈/霸道总裁）念“你好呀”！',
        '即兴跳一段 10 秒钟节奏舞步或手指舞！',
        '现场表演一段电影经典台词配音！',
        '单脚金鸡独立坚持 15 秒并背出 7 的乘法口诀！',
      ],
    ),
  ];

  static WheelScenePack packById(String id) {
    for (final p in scenePacks) {
      if (p.id == id) return p;
    }
    return scenePacks.first;
  }
}
