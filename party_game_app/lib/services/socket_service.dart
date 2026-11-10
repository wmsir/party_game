import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 真实 WebSocket 长连接即时通信服务
/// 支持实时聊天、向对手扔道具物理广播、房间席位变动同步
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  static const List<String> wsUrls = [
    'ws://39.97.158.22/party-game/ws',
    'ws://39.97.158.22/ws',
    'ws://39.97.158.22:9001/party-game/ws',
    'ws://39.97.158.22:9001/ws',
    'ws://127.0.0.1:9001/ws',
  ];

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  String? _currentUserId;
  String? _currentNickname;
  Map<String, dynamic>? _lastJoinRoomMsg;
  final List<Map<String, dynamic>> _pendingQueue = [];

  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  void initUser({required String userId, String? nickname}) {
    _currentUserId = userId;
    _currentNickname = nickname;
    if (isConnected) {
      send({
        'type': 'INIT_USER',
        'userId': userId,
        'nickname': nickname ?? '玩家',
      });
    } else {
      connect(userId: userId, nickname: nickname);
    }
  }

  Future<void> connect({String? userId, String? nickname}) async {
    if (userId != null) {
      _currentUserId = userId;
      _currentNickname = nickname;
    }

    if (isConnected) {
      if (userId != null) {
        send({
          'type': 'INIT_USER',
          'userId': userId,
          'nickname': nickname ?? '玩家',
        });
      }
      _flushPendingMessages();
      return;
    }

    if (_isConnecting) return;
    _isConnecting = true;

    for (final urlStr in wsUrls) {
      try {
        debugPrint('正在尝试建立 WebSocket 长连接: $urlStr');
        final socket = await WebSocket.connect(urlStr).timeout(const Duration(seconds: 4));
        _socket = socket;
        _isConnecting = false;
        debugPrint('🎉 WebSocket 连接成功: $urlStr');

        _startHeartbeat();

        // 注册当前用户信息
        final uid = userId ?? _currentUserId;
        final nick = nickname ?? _currentNickname;
        if (uid != null) {
          send({
            'type': 'INIT_USER',
            'userId': uid,
            'nickname': nick ?? '玩家',
          });
        }

        // 若之前在房间中，重新连上后自动重新加入房间绑定席位
        if (_lastJoinRoomMsg != null) {
          try {
            _socket!.add(jsonEncode(_lastJoinRoomMsg));
          } catch (_) {}
        }

        // 冲刷发送队列中积压的消息
        _flushPendingMessages();

        socket.listen(
          (data) {
            try {
              final raw = jsonDecode(data.toString());
              if (raw is Map) {
                final map = Map<String, dynamic>.from(raw);
                if (map['type'] == 'HEARTBEAT_PING') {
                  // 立即应答心跳 PONG，确保服务端会话永不超时断开
                  send({
                    'type': 'HEARTBEAT_PONG',
                    'userId': _currentUserId,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  });
                  return;
                }
                _messageController.add(map);
              }
            } catch (e) {
              debugPrint('Socket JSON解析错误: $e');
            }
          },
          onDone: () => _onDisconnected(),
          onError: (e) => _onDisconnected(),
        );
        return;
      } catch (e) {
        debugPrint('尝试 $urlStr 失败: $e');
      }
    }

    _isConnecting = false;
    _scheduleReconnect();
  }

  void send(Map<String, dynamic> msg) {
    if (msg['type'] == 'JOIN_ROOM') {
      _lastJoinRoomMsg = msg;
    } else if (msg['type'] == 'LEAVE_ROOM') {
      _lastJoinRoomMsg = null;
    }

    if (isConnected) {
      try {
        _socket!.add(jsonEncode(msg));
      } catch (_) {
        _pendingQueue.add(msg);
      }
    } else {
      // 队列缓存，保证连接建立后自动补发，绝不丢消息
      _pendingQueue.add(msg);
      connect(userId: _currentUserId, nickname: _currentNickname);
    }
  }

  void _flushPendingMessages() {
    while (_pendingQueue.isNotEmpty && isConnected) {
      final msg = _pendingQueue.removeAt(0);
      try {
        _socket!.add(jsonEncode(msg));
      } catch (_) {
        _pendingQueue.insert(0, msg);
        break;
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (t) {
      if (isConnected) {
        send({'type': 'PING'});
      }
    });
  }

  void _onDisconnected() {
    _socket = null;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 6), () {
      connect(userId: _currentUserId, nickname: _currentNickname);
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.close();
  }
}
