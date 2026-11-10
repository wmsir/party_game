import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../models/global_blessing_model.dart';
import '../core/sound/game_sound_service.dart';
import 'socket_service.dart';
import 'auth_service.dart';
import 'api_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal() {
    _initSocketListener();
  }

  final List<ChatMessageModel> _worldMessages = [
    ChatMessageModel.system('🎉 欢迎来到聚会桌游吧！已实时接入云端 9001 端口对决中枢。'),
  ];
  final List<ChatMessageModel> _cityMessages = [
    ChatMessageModel.system('📍 同城聚会交友频道，已实时同步附近桌游玩家。'),
  ];
  final List<ChatMessageModel> _roomMessages = [];

  final _messageStreamCtrl = StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get messageStream => _messageStreamCtrl.stream;

  final _blessingStreamCtrl = StreamController<GlobalBlessingModel>.broadcast();
  Stream<GlobalBlessingModel> get blessingStream => _blessingStreamCtrl.stream;

  // 记录本机已消费/展示的全服广播 ID，精准防回环重复
  final Set<String> _locallyDispatchedBlessingIds = <String>{};

  // 腾讯经典快捷常用短语
  static const List<String> presetPhrases = [
    '快点吧，我等到花儿都谢了！',
    '手气这么好，你家里人知道吗？',
    '不要走，决战到天亮！',
    '你太有才了，佩服佩服！',
    '手下留情，给条活路吧！',
    '今晚全场的消费由赵公子买单！',
    '这把稳了，你们随便叫！',
    '你小子一定在吹牛！',
    '三缺一，求个老司机带飞！',
    '很高兴能和大家一起玩！',
    '山不转水转，咱们下局见分晓！',
  ];

  // 常用快捷表情
  static const List<String> presetEmojis = [
    '😀', '😂', '🤣', '😎', '🥳',
    '🍻', '🍷', '🥂', '🍾', '🎉',
    '🔥', '🐂', '🎲', '🃏', '👑',
    '💣', '🥚', '🌸', '🥿', '🙈',
  ];

  // 互动道具配置
  static const List<Map<String, String>> throwItems = [
    {'type': 'EGG', 'name': '扔鸡蛋', 'emoji': '🥚', 'cost': '10', 'desc': '向对手狠狠砸个臭鸡蛋！'},
    {'type': 'BEER', 'name': '碰啤酒', 'emoji': '🍻', 'cost': '20', 'desc': '跟桌友干杯，豪爽共饮！'},
    {'type': 'FLOWER', 'name': '送鲜花', 'emoji': '🌸', 'cost': '20', 'desc': '为心仪玩家送上芬芳玫瑰！'},
    {'type': 'SLIPPER', 'name': '扔拖鞋', 'emoji': '🥿', 'cost': '15', 'desc': '甩出一只大拖鞋拍向对方！'},
    {'type': 'BOMB', 'name': '大炸弹', 'emoji': '💣', 'cost': '50', 'desc': '丢出巨型炸弹引发轰鸣爆炸！'},
  ];

  void _initSocketListener() {
    SocketService().messageStream.listen((data) {
      final type = data['type'];
      if (type == 'CHAT_MESSAGE') {
        final msgId = data['id']?.toString() ?? '';
        final senderId = data['senderId']?.toString() ?? '';
        final senderName = data['senderName']?.toString() ?? '';
        final content = data['content']?.toString() ?? '';
        final targetChannel = data['channel']?.toString() ?? 'WORLD';

        final myUser = AuthService().currentUser;
        final myId = myUser?.id ?? '';
        final myNickname = myUser?.nickname ?? '';

        // 1. 发送者是自己：不论是 ID 还是昵称匹配，本地已乐观显示，直接拦截服务器回声，彻底避免发1条显示2条
        if ((myId.isNotEmpty && senderId == myId) ||
            (myNickname.isNotEmpty && senderName == myNickname)) {
          return;
        }

        final targetList = targetChannel == 'CITY'
            ? _cityMessages
            : (targetChannel == 'ROOM' ? _roomMessages : _worldMessages);

        // 2. 消息 ID 去重
        if (msgId.isNotEmpty && targetList.any((m) => m.id == msgId)) {
          return;
        }

        // 3. 内容与时间戳去重：同频道在最近 5 秒内已有相同内容，判定为回环重复投递，直接丢弃
        final now = DateTime.now();
        if (targetList.reversed.take(10).any((m) =>
            m.content == content && now.difference(m.timestamp).inSeconds.abs() < 5)) {
          return;
        }

        final msg = ChatMessageModel(
          id: msgId.isNotEmpty ? msgId : 'MSG-${now.millisecondsSinceEpoch}',
          senderId: senderId,
          senderName: senderName.isNotEmpty ? senderName : '玩家',
          senderAvatar: data['senderAvatar'] ?? '🦊',
          content: content,
          channel: targetChannel,
          textColor: data['textColor']?.toString() ?? 'COLOR_DEFAULT',
          vipLevel: (data['vipLevel'] is num) ? (data['vipLevel'] as num).toInt() : 0,
        );
        _appendMessage(msg);
      } else if (type == 'THROW_ITEM_EVENT') {
        final senderId = data['senderId']?.toString() ?? '';
        final myId = AuthService().currentUser?.id;
        if (myId != null && myId.isNotEmpty && senderId == myId) {
          // 本地已触发动效，忽略自身回声
          return;
        }

        final isGlobal = data['isGlobal'] == true || data['channel'] == 'WORLD';
        final roomCode = data['roomCode']?.toString();
        final blessing = data['blessing']?.toString();

        final msg = ChatMessageModel.throwItem(
          senderId: senderId,
          senderName: data['senderName'] ?? '玩家',
          senderAvatar: data['senderAvatar'] ?? '🦊',
          targetPlayerId: data['targetPlayerId'] ?? '',
          targetPlayerName: data['targetPlayerName'] ?? '对手',
          itemType: data['itemType'] ?? 'EGG',
          itemEmoji: data['itemEmoji'] ?? '🥚',
          combo: (data['combo'] is num) ? (data['combo'] as num).toInt() : 1,
          giftTitle: data['giftTitle']?.toString(),
          isGlobal: isGlobal,
          roomCode: roomCode,
          blessing: blessing,
        );
        _appendMessage(msg);
      } else if (type == 'GLOBAL_BROADCAST_EVENT' || type == 'GLOBAL_BROADCAST') {
        try {
          final bId = data['id']?.toString() ?? '';
          if (bId.isNotEmpty && _locallyDispatchedBlessingIds.contains(bId)) {
            // 本机已触发并展示过此广播，忽略本地回声
            return;
          }
          if (bId.isNotEmpty) {
            _locallyDispatchedBlessingIds.add(bId);
            if (_locallyDispatchedBlessingIds.length > 200) {
              _locallyDispatchedBlessingIds.remove(_locallyDispatchedBlessingIds.first);
            }
          }
          final blessing = GlobalBlessingModel.fromJson(data);
          _blessingStreamCtrl.add(blessing);

          // 同步追加一条醒目的系统广播到公屏（世界与同城频道），确保即使跑马灯滚动完毕也能在聊天列表中看到历史通知
          final broadcastSender = blessing.senderName.isNotEmpty ? blessing.senderName : '玩家';
          final broadcastContent = blessing.blessing.isNotEmpty ? blessing.blessing : '送出全服祝福';
          final giftName = blessing.giftTitle.isNotEmpty
              ? blessing.giftTitle
              : (blessing.itemType == 'MARQUEE' ? '全服大喇叭' : '豪华全服盛典');
          final announceText = '📢【$giftName】$broadcastSender: $broadcastContent';

          _appendMessage(ChatMessageModel.system(announceText, channel: 'WORLD'));
          _appendMessage(ChatMessageModel.system(announceText, channel: 'CITY'));

          // 若携带全屏动效（如超级火箭、豪华超跑、梦幻城堡），触发全局 VFX
          if (blessing.itemType != 'MARQUEE') {
            final msg = ChatMessageModel.throwItem(
              senderId: blessing.senderId,
              senderName: blessing.senderName,
              senderAvatar: blessing.senderAvatar,
              targetPlayerId: 'ALL',
              targetPlayerName: '全服玩家',
              itemType: blessing.itemType,
              itemEmoji: blessing.itemEmoji,
              giftTitle: blessing.giftTitle,
              isGlobal: true,
              blessing: blessing.blessing,
            );
            _appendMessage(msg);
          }
        } catch (e) {
          debugPrint('处理全服广播消息异常: $e');
        }
      }
    });
  }

  List<ChatMessageModel> getMessages(String channel) {
    switch (channel) {
      case 'CITY':
        return List.unmodifiable(_cityMessages);
      case 'ROOM':
        return List.unmodifiable(_roomMessages);
      case 'WORLD':
      default:
        return List.unmodifiable(_worldMessages);
    }
  }

  String? currentRoomCode;

  /// 发送文本消息
  void sendMessage({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String content,
    String channel = 'WORLD',
    ChatMessageType type = ChatMessageType.text,
    String? roomCode,
    String? textColor,
    int? vipLevel,
  }) {
    final msgId = 'MSG-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';
    final effectiveRoomCode = roomCode ?? currentRoomCode;
    final effectiveChannel = (effectiveRoomCode != null && effectiveRoomCode.isNotEmpty) ? 'ROOM' : channel;
    final effectiveTextColor = textColor ?? AuthService().currentUser?.chatTextColor ?? 'COLOR_DEFAULT';
    final effectiveVipLevel = vipLevel ?? AuthService().currentUser?.vipLevel ?? 0;

    final msg = ChatMessageModel(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: content,
      channel: effectiveChannel,
      type: type,
      textColor: effectiveTextColor,
      vipLevel: effectiveVipLevel,
    );

    _appendMessage(msg);
    GameSoundService().playCardPlay();

    // 实时同步至云端 WebSocket
    final payload = <String, dynamic>{
      'type': 'CHAT_MESSAGE',
      'id': msgId,
      'channel': effectiveChannel,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'textColor': effectiveTextColor,
      'vipLevel': effectiveVipLevel,
    };
    if (effectiveRoomCode != null && effectiveRoomCode.isNotEmpty) {
      payload['roomCode'] = effectiveRoomCode;
    }
    SocketService().send(payload);
  }

  /// 发起对局玩家互动道具投掷 / 抖音级刷礼物
  ChatMessageModel throwItemAtPlayer({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String targetPlayerId,
    required String targetPlayerName,
    required String itemType,
    required String itemEmoji,
    int combo = 1,
    String? giftTitle,
    bool isGlobal = false,
    String? roomCode,
    String? blessing,
  }) {
    final msg = ChatMessageModel.throwItem(
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      targetPlayerId: targetPlayerId,
      targetPlayerName: targetPlayerName,
      itemType: itemType,
      itemEmoji: itemEmoji,
      combo: combo,
      giftTitle: giftTitle,
      isGlobal: isGlobal,
      roomCode: roomCode,
      blessing: blessing,
    );

    _appendMessage(msg);
    GameSoundService().playItemHit(itemType);

    // 实时广播给全场对手
    SocketService().send({
      'type': 'THROW_ITEM',
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'targetPlayerId': targetPlayerId,
      'targetPlayerName': targetPlayerName,
      'itemType': itemType,
      'itemEmoji': itemEmoji,
      'combo': combo,
      'giftTitle': msg.giftTitle,
      'isGlobal': isGlobal,
      'roomCode': roomCode,
      'blessing': blessing,
    });

    return msg;
  }

  /// 发送全服横向跑马灯祝福播报与全局盛典特效
  void sendGlobalBroadcast(GlobalBlessingModel blessing) {
    if (blessing.id.isNotEmpty) {
      _locallyDispatchedBlessingIds.add(blessing.id);
    }
    _blessingStreamCtrl.add(blessing);
    GameSoundService().playVictory();

    // 本地乐观添加到世界和同城聊天流
    final giftName = blessing.giftTitle.isNotEmpty
        ? blessing.giftTitle
        : (blessing.itemType == 'MARQUEE' ? '全服大喇叭' : '豪华全服盛典');
    final announceText = '📢【$giftName】${blessing.senderName}: ${blessing.blessing}';
    _appendMessage(ChatMessageModel.system(announceText, channel: 'WORLD'));
    _appendMessage(ChatMessageModel.system(announceText, channel: 'CITY'));

    if (blessing.itemType != 'MARQUEE') {
      final msg = ChatMessageModel.throwItem(
        senderId: blessing.senderId,
        senderName: blessing.senderName,
        senderAvatar: blessing.senderAvatar,
        targetPlayerId: 'ALL',
        targetPlayerName: '全服玩家',
        itemType: blessing.itemType,
        itemEmoji: blessing.itemEmoji,
        giftTitle: blessing.giftTitle,
        isGlobal: true,
        blessing: blessing.blessing,
      );
      _appendMessage(msg);
    }

    // 1. 可靠 HTTP 双保险直接播发至云端中枢
    ApiService().sendGlobalBroadcast(blessing.toJson());

    // 2. 实时通过 WebSocket 直推
    SocketService().send(blessing.toJson());
  }

  /// 同步最近全服大喇叭历史 (防止网络波动或后上线的客户端遗漏广播)
  Future<void> syncRecentBroadcasts({bool isInitial = false}) async {
    try {
      final list = await ApiService().fetchRecentGlobalBroadcasts();
      if (isInitial) {
        // 初次加载时，先将历史广播全部登记到已播列表，仅允许展示最近 15 秒内的超新广播，避免启动时堆积回放海量旧广播
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final item in list) {
          final bId = item['id']?.toString() ?? '';
          if (bId.isNotEmpty) {
            _locallyDispatchedBlessingIds.add(bId);
          }
        }
        if (list.isNotEmpty) {
          final newest = list.first;
          final ts = (newest['timestamp'] is num) ? (newest['timestamp'] as num).toInt() : 0;
          if (ts > 0 && (nowMs - ts) < 15000) {
            final blessing = GlobalBlessingModel.fromJson(newest);
            _blessingStreamCtrl.add(blessing);
          }
        }
        return;
      }

      for (final item in list.reversed) {
        final bId = item['id']?.toString() ?? '';
        if (bId.isNotEmpty && _locallyDispatchedBlessingIds.contains(bId)) {
          continue;
        }
        if (bId.isNotEmpty) {
          _locallyDispatchedBlessingIds.add(bId);
          if (_locallyDispatchedBlessingIds.length > 200) {
            _locallyDispatchedBlessingIds.remove(_locallyDispatchedBlessingIds.first);
          }
        }
        final blessing = GlobalBlessingModel.fromJson(item);
        _blessingStreamCtrl.add(blessing);

        final broadcastSender = blessing.senderName.isNotEmpty ? blessing.senderName : '玩家';
        final broadcastContent = blessing.blessing.isNotEmpty ? blessing.blessing : '送出全服祝福';
        final giftName = blessing.giftTitle.isNotEmpty
            ? blessing.giftTitle
            : (blessing.itemType == 'MARQUEE' ? '全服大喇叭' : '豪华全服盛典');
        final announceText = '📢【$giftName】$broadcastSender: $broadcastContent';

        _appendMessage(ChatMessageModel.system(announceText, channel: 'WORLD'));
        _appendMessage(ChatMessageModel.system(announceText, channel: 'CITY'));
      }
    } catch (e) {
      debugPrint('syncRecentBroadcasts 异常: $e');
    }
  }

  void _appendMessage(ChatMessageModel msg) {
    final targetList = msg.channel == 'CITY'
        ? _cityMessages
        : (msg.channel == 'ROOM' ? _roomMessages : _worldMessages);

    // 严密去重：如果 ID 已在列表中，直接忽略
    if (targetList.any((m) => m.id == msg.id)) return;

    // 内容去重：如果最近 10 条消息中存在相同内容且在 5 秒之内，判定为网络回环包，直接丢弃
    if (targetList.reversed.take(10).any((m) =>
        m.content == msg.content &&
        DateTime.now().difference(m.timestamp).inSeconds.abs() < 5)) {
      return;
    }

    targetList.add(msg);
    if (targetList.length > 100) targetList.removeAt(0);
    _messageStreamCtrl.add(msg);
  }

  void clearRoomMessages() {
    _roomMessages.clear();
  }

  /// 向房间内聊天流注入裁判/游戏对局播报系统消息
  void addRoomSystemNotice(String notice) {
    final msg = ChatMessageModel(
      id: 'ROOM-SYS-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}',
      senderId: 'SYSTEM',
      senderName: '牛头王裁判',
      senderAvatar: '🐮',
      content: notice,
      type: ChatMessageType.system,
      channel: 'ROOM',
    );
    _appendMessage(msg);
  }
}
