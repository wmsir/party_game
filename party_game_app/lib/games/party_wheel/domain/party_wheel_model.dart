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

class PartyWheelModel {
  static const List<WheelSegment> defaultSegments = [
    WheelSegment(text: '喝半杯', color: Color(0xFFEF4444), type: 'DRINK'),
    WheelSegment(text: '真心话', color: Color(0xFF8B5CF6), type: 'TRUTH'),
    WheelSegment(text: '左边喝', color: Color(0xFFF59E0B), type: 'DRINK'),
    WheelSegment(text: '大冒险', color: Color(0xFFEC4899), type: 'DARE'),
    WheelSegment(text: '右边喝', color: Color(0xFF10B981), type: 'DRINK'),
    WheelSegment(text: '免罚金牌', color: Color(0xFF3B82F6), type: 'LUCKY'),
    WheelSegment(text: '全场干杯', color: Color(0xFFF97316), type: 'DRINK'),
    WheelSegment(text: '指定一人喝', color: Color(0xFF14B8A6), type: 'DRINK'),
  ];

  static const List<String> truthQuestions = [
    '你做过最尴尬的一件事是什么？',
    '现场所有人里，你对谁的第一印象最好？',
    '你上一次哭是什么时候？因为什么？',
    '你暗恋或心动过最不可能的人是谁？',
    '手机里最不舍得删的一张照片是什么？',
    '谈过几次恋爱？最难忘的一任是谁？',
    '做过最疯狂、从来没告诉过爸妈的事情是什么？',
    '现场选一个人，说出TA身上你最欣赏的一个优点！',
  ];

  static const List<String> dareChallenges = [
    '给手机通讯录第5个人发一条“我饿了想吃宵夜”！',
    '模仿一种动物的叫声和动作，持续15秒！',
    '和左边的玩家深情对视10秒，中途不能笑！',
    '做5个俯卧撑或者深蹲！',
    '模仿一段现场某位朋友的说话口头禅！',
    '用搞笑的腔调给右边的人念一段绕口令！',
    '现场展示一个你压箱底的小才艺（唱歌、口技、冷笑话等）！',
  ];
}
