import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../models/global_blessing_model.dart';
import '../services/chat_service.dart';
import '../core/storage/local_storage.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  String _activeChannel = 'WORLD'; // 'WORLD', 'CITY', 'ROOM'
  StreamSubscription? _msgSub;
  StreamSubscription? _blessingSub;

  String get activeChannel => _activeChannel;
  List<ChatMessageModel> get currentMessages => _chatService.getMessages(_activeChannel);
  Stream<ChatMessageModel> get messageStream => _chatService.messageStream;

  // 最近一次发生的投掷道具事件（用于触发物理粒子抛物线飞掷/全屏动效）
  ChatMessageModel? _lastThrowEvent;
  ChatMessageModel? get lastThrowEvent => _lastThrowEvent;

  // 全服横向滚动跑马灯祝福系统
  GlobalBlessingModel? _currentBlessing;
  GlobalBlessingModel? get currentBlessing => _currentBlessing;
  final List<GlobalBlessingModel> _blessingQueue = [];
  Timer? _recentBroadcastTimer;

  ChatProvider() {
    _msgSub = _chatService.messageStream.listen((msg) {
      if (msg.type == ChatMessageType.throwItem) {
        _lastThrowEvent = msg;
      }
      notifyListeners();
    });

    _blessingSub = _chatService.blessingStream.listen((blessing) {
      _enqueueBlessing(blessing);
    });

    // 启动即刻注册历史广播防堆积，仅播报最新广播
    _chatService.syncRecentBroadcasts(isInitial: true);

    // 4 秒一次轮询同步全服大喇叭，提供双通道绝对送达保障（防止 WebSocket 短暂重连或网络波动漏听）
    _recentBroadcastTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _chatService.syncRecentBroadcasts();
    });
  }

  void syncRecentBroadcasts() {
    _chatService.syncRecentBroadcasts();
  }

  @override
  void dispose() {
    _recentBroadcastTimer?.cancel();
    _msgSub?.cancel();
    _blessingSub?.cancel();
    super.dispose();
  }

  void switchChannel(String channel) {
    _activeChannel = channel;
    notifyListeners();
  }

  void setCurrentRoomCode(String? code) {
    _chatService.currentRoomCode = code;
  }

  void clearRoomMessages() {
    _chatService.clearRoomMessages();
    notifyListeners();
  }

  List<ChatMessageModel> getMessages(String channel) => _chatService.getMessages(channel);

  void sendMessage({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String content,
    String? channel,
    ChatMessageType type = ChatMessageType.text,
    String? roomCode,
    String? textColor,
    int? vipLevel,
  }) {
    _chatService.sendMessage(
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: content,
      channel: channel ?? _activeChannel,
      type: type,
      roomCode: roomCode,
      textColor: textColor,
      vipLevel: vipLevel,
    );
  }

  void throwItem({
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
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final key = 'daily_throw_count_${senderId}_$todayStr';
    final currentThrows = LocalStorage.getInt(key) ?? 0;
    LocalStorage.setInt(key, currentThrows + 1);

    final msg = _chatService.throwItemAtPlayer(
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
    _lastThrowEvent = msg;
    notifyListeners();
  }

  /// 发送全服横向跑马灯祝福播报与全局盛典特效
  void sendGlobalBlessing(GlobalBlessingModel blessing) {
    _chatService.sendGlobalBroadcast(blessing);
  }

  void _enqueueBlessing(GlobalBlessingModel blessing) {
    if (_currentBlessing == null) {
      _currentBlessing = blessing;
      notifyListeners();
    } else {
      _blessingQueue.add(blessing);
    }
  }

  void finishCurrentBlessing() {
    if (_blessingQueue.isNotEmpty) {
      _currentBlessing = _blessingQueue.removeAt(0);
    } else {
      _currentBlessing = null;
    }
    notifyListeners();
  }

  /// 彻底清除投掷事件，并通知所有挂载的 UI 树
  void clearThrowEvent() {
    if (_lastThrowEvent != null) {
      _lastThrowEvent = null;
      notifyListeners();
    }
  }

  /// 向房间聊天流追加系统/裁判对局播报消息
  void addRoomSystemNotice(String notice) {
    _chatService.addRoomSystemNotice(notice);
    notifyListeners();
  }
}
