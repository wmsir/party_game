import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game_room_model.dart';
import '../models/game_player.dart';
import '../models/post_moment_model.dart';
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../models/shop_models.dart';
import '../core/storage/local_storage.dart';

/// 真实远程与本地多环境自适应网络服务层
/// 默认接入云端微服务: http://39.97.158.22/party-game 或直连 9001 端口
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const List<String> serverEndpoints = [
    'https://fwpt.cn/party-game',
    'http://39.97.158.22/party-game',
    'http://39.97.158.22:9001',
    'http://127.0.0.1:9001',
  ];

  String _activeBaseUrl = serverEndpoints[0];
  String get activeBaseUrl => _activeBaseUrl;

  Future<http.Response> _getWithFallback(String path) async {
    for (final base in serverEndpoints) {
      try {
        final url = Uri.parse('$base$path');
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          _activeBaseUrl = base;
          return res;
        }
      } catch (_) {}
    }
    throw Exception('无法连接到游戏服务器');
  }

  Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    for (final base in serverEndpoints) {
      try {
        final url = Uri.parse('$base$path');
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 || res.statusCode == 201) {
          _activeBaseUrl = base;
          return res;
        }
      } catch (_) {}
    }
    throw Exception('网络请求提交失败');
  }

  // ==================== 认证相关 ====================

  Future<UserModel> fetchGuestUser() async {
    try {
      final res = await _postWithFallback('/api/auth/guest', {});
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return UserModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('云端游客获取失败，进入本地独立模式: $e');
    }
    return UserModel.guest();
  }

  Future<UserModel?> login({
    String? username,
    String? password,
    String? phone,
    String? code,
    bool isGuest = false,
  }) async {
    try {
      final res = await _postWithFallback('/api/auth/login', {
        'username': username,
        'password': password,
        'phone': phone,
        'code': code,
        'isGuest': isGuest,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return UserModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('登录请求失败: $e');
    }
    return null;
  }

  /// 确认扫码登录授权（供手机 APP 扫码后调用授权 H5 登录）
  Future<bool> confirmQrLogin({
    required String ticket,
    required String userId,
  }) async {
    try {
      final res = await _postWithFallback('/api/auth/qr/confirm', {
        'ticket': ticket.trim(),
        'userId': userId.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('确认扫码授权失败: $e');
      return false;
    }
  }


  /// 发送模拟手机短信验证码
  Future<Map<String, dynamic>> sendSmsCode(String phone) async {
    try {
      final res = await _postWithFallback('/api/auth/send-sms-code', {
        'phone': phone.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return Map<String, dynamic>.from(map['data']);
      }
      throw Exception(map['message'] ?? '验证码发送失败');
    } catch (e) {
      debugPrint('发送验证码请求失败: $e');
      rethrow;
    }
  }

  /// 发送免费试玩手机短信验证码 (5分钟内有效)
  Future<Map<String, dynamic>> sendTrialSmsCode(String phone) async {
    try {
      final res = await _postWithFallback('/api/auth/trial-sms/send', {
        'phone': phone.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return Map<String, dynamic>.from(map['data']);
      }
      throw Exception(map['message'] ?? '验证码发送失败');
    } catch (e) {
      debugPrint('发送试玩验证码请求失败: $e');
      rethrow;
    }
  }

  /// 免费试玩手机验证码核验并进入游戏 (赠送初始金币与钻石)
  Future<UserModel?> verifyTrialSms(String phone, String code) async {
    try {
      final res = await _postWithFallback('/api/auth/trial-sms/verify', {
        'phone': phone.trim(),
        'code': code.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return UserModel.fromJson(map['data']);
      }
      throw Exception(map['message'] ?? '试玩验证失败');
    } catch (e) {
      debugPrint('试玩验证失败: $e');
      rethrow;
    }
  }

  /// 真实手机验证码登录接口 (直接入库保存至 MySQL 数据库)
  Future<UserModel?> loginWithPhone(String phone, String code) async {
    try {
      final res = await _postWithFallback('/api/auth/phone-login', {
        'phone': phone.trim(),
        'code': code.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return UserModel.fromJson(map['data']);
      }
      throw Exception(map['message'] ?? '登录失败');
    } catch (e) {
      debugPrint('手机验证码登录失败: $e');
      rethrow;
    }
  }

  /// 真实账号注册接口 (入库至 MySQL 数据库)
  Future<UserModel?> register({
    required String username,
    required String nickname,
    required String password,
    String phone = '',
  }) async {
    try {
      final res = await _postWithFallback('/api/auth/register', {
        'username': username.trim(),
        'nickname': nickname.trim(),
        'password': password,
        'phone': phone.trim(),
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return UserModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('账号注册失败: $e');
      rethrow;
    }
    return null;
  }

  /// 真实重置/找回密码接口
  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      final res = await _postWithFallback('/api/auth/reset-password', {
        'phone': phone.trim(),
        'newPassword': newPassword,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('重置密码网络请求异常: $e');
      return false;
    }
  }

  /// 账号与安全中心：更新账号、密码、手机号、昵称、头像
  Future<Map<String, dynamic>> updateAccountSecurity({
    required String userId,
    String? username,
    String? nickname,
    String? password,
    String? phone,
    String? avatar,
  }) async {
    try {
      final body = <String, dynamic>{
        'userId': userId.trim(),
      };
      if (username != null && username.trim().isNotEmpty) body['username'] = username.trim();
      if (nickname != null && nickname.trim().isNotEmpty) body['nickname'] = nickname.trim();
      if (password != null && password.trim().isNotEmpty) body['password'] = password.trim();
      if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone.trim();
      if (avatar != null && avatar.trim().isNotEmpty) body['avatar'] = avatar.trim();

      final res = await _postWithFallback('/api/auth/update-account', body);
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return Map<String, dynamic>.from(map);
    } catch (e) {
      debugPrint('更新账号安全信息网络请求异常: $e');
      return {'code': 500, 'message': '更新账号安全信息网络请求异常: $e'};
    }
  }

  /// 获取系统运行动态配置（如道具展示停留时长，默认3秒）
  Future<Map<String, dynamic>> fetchSystemConfig() async {
    try {
      final res = await _getWithFallback('/api/config/system');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return Map<String, dynamic>.from(map['data']);
      }
    } catch (e) {
      debugPrint('获取系统配置失败: $e');
    }
    return {'propDisplayDurationSeconds': 3, 'propDisplayDurationMs': 3000};
  }

  /// 开发者管理后台：修改道具屏幕停留时长
  Future<bool> updatePropDuration(int seconds) async {
    try {
      final res = await _postWithFallback('/api/admin/config/prop-duration', {
        'seconds': seconds,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('修改道具停留时长失败: $e');
      return false;
    }
  }

  /// 获取玩家真实历史对战战绩分页数据 (默认最近5场，支持精准分页)
  Future<Map<String, dynamic>> fetchBattleRecordsPaged(String userId, {int page = 0, int size = 5}) async {
    try {
      final res = await _getWithFallback('/api/game/battle-records?userId=$userId&page=$page&size=$size');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        List<Map<String, dynamic>> list = [];
        int total = 0;
        int totalPages = 1;
        if (map['data'] is Map) {
          final d = map['data'] as Map;
          if (d['records'] is List) {
            list = (d['records'] as List).map((x) => Map<String, dynamic>.from(x)).toList();
          }
          total = (d['total'] as num?)?.toInt() ?? list.length;
          totalPages = (d['totalPages'] as num?)?.toInt() ?? ((total / size).ceil());
        } else if (map['data'] is List) {
          list = (map['data'] as List).map((x) => Map<String, dynamic>.from(x)).toList();
          total = list.length;
          totalPages = (total / size).ceil();
        }

        // 检查本地持久化清空时间戳，彻底过滤已被用户清空的历史测试战绩
        var clearedTimestampStr = LocalStorage.getString('battle_records_cleared_timestamp_$userId');
        if (clearedTimestampStr != null && clearedTimestampStr.isNotEmpty) {
          final clearedTime = DateTime.tryParse(clearedTimestampStr);
          if (clearedTime != null) {
            list = list.where((r) {
              final playedAtStr = r['playedAt']?.toString();
              if (playedAtStr == null) return false;
              final playedAt = DateTime.tryParse(playedAtStr);
              if (playedAt == null) return false;
              return playedAt.isAfter(clearedTime);
            }).toList();
          }
        }
        return {
          'records': list,
          'total': total,
          'page': page,
          'size': size,
          'totalPages': totalPages < 1 ? 1 : totalPages,
        };
      }
    } catch (e) {
      debugPrint('获取历史对战记录失败: $e');
    }
    return {'records': <Map<String, dynamic>>[], 'total': 0, 'page': page, 'size': size, 'totalPages': 0};
  }

  /// 获取玩家真实历史对战战绩列表 (默认最近5场)
  Future<List<Map<String, dynamic>>> fetchBattleRecords(String userId, {int page = 0, int size = 5}) async {
    final paged = await fetchBattleRecordsPaged(userId, page: page, size: size);
    return List<Map<String, dynamic>>.from(paged['records'] ?? []);
  }

  /// 清空真实历史对战战绩列表
  Future<bool> clearBattleRecords({String? userId}) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        // 本地持久化记录清空时间，实现立刻 100% 清空历史无用/测试战绩
        await LocalStorage.setString(
          'battle_records_cleared_timestamp_$userId',
          DateTime.now().toIso8601String(),
        );
      }
      final query = (userId != null && userId.isNotEmpty) ? '?userId=$userId' : '';
      await _postWithFallback('/api/game/battle-records/clear$query', {});
      return true;
    } catch (e) {
      debugPrint('清空历史对战记录: $e');
      return true;
    }
  }

  /// 清空云端所有在线房间
  Future<bool> clearRooms() async {
    try {
      final res = await _postWithFallback('/api/rooms/clear', {});
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('清空云端在线房间失败: $e');
      return false;
    }
  }

  // ==================== 真实房间数据 ====================

  Future<List<GameRoomModel>> fetchRooms() async {
    try {
      final res = await _getWithFallback('/api/rooms');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        final list = (map['data'] as List).map((r) => GameRoomModel.fromJson(r)).toList();
        return list;
      }
    } catch (e) {
      debugPrint('从云端获取房间失败: $e');
    }
    return [];
  }

  Future<GameRoomModel?> createRoom({
    String? roomCode,
    required String gameType,
    required GamePlayer hostPlayer,
    String? roomName,
    String password = '',
    bool isPassAndPlay = false,
  }) async {
    try {
      final res = await _postWithFallback('/api/rooms/create', {
        if (roomCode != null && roomCode.isNotEmpty) 'roomCode': roomCode,
        'gameType': gameType,
        'roomName': roomName,
        'hostPlayer': hostPlayer.toJson(),
        'password': password,
        'isPassAndPlay': isPassAndPlay,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return GameRoomModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('创建房间同步失败: $e');
    }
    return null;
  }

  Future<GameRoomModel?> joinRoom({
    required String roomCode,
    required GamePlayer player,
    String password = '',
  }) async {
    try {
      final res = await _postWithFallback('/api/rooms/join', {
        'roomCode': roomCode,
        'player': player.toJson(),
        'password': password,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return GameRoomModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('加入房间失败: $e');
    }
    return null;
  }

  Future<GameRoomModel?> fetchRoomDetail(String roomCode) async {
    try {
      final res = await _getWithFallback('/api/rooms/detail?roomCode=${Uri.encodeComponent(roomCode)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return GameRoomModel.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('获取房间详情失败: $e');
    }
    return null;
  }

  Future<bool> addAiPlayer({required String roomCode, required Map<String, dynamic> player}) async {
    try {
      final res = await _postWithFallback('/api/rooms/add-ai', {
        'roomCode': roomCode,
        'player': player,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leaveRoom({required String roomCode, required String playerId}) async {
    try {
      final res = await _postWithFallback('/api/rooms/leave', {
        'roomCode': roomCode,
        'playerId': playerId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('退出房间同步异常: $e');
    }
    return false;
  }

  Future<bool> closeRoom(String roomCode) async {
    try {
      final res = await _postWithFallback('/api/rooms/close', {
        'roomCode': roomCode,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('解散房间同步异常: $e');
    }
    return false;
  }

  Future<bool> resetRoom(String roomCode) async {
    try {
      final res = await _postWithFallback('/api/rooms/reset', {
        'roomCode': roomCode,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('重置房间状态异常: $e');
    }
    return false;
  }

  Future<bool> updateRoomSettings({required String roomCode, bool? allowSpectator}) async {
    try {
      final res = await _postWithFallback('/api/rooms/settings', {
        'roomCode': roomCode,
        if (allowSpectator != null) 'allowSpectator': allowSpectator,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('更新房间设置失败: $e');
    }
    return false;
  }

  Future<bool> setPlayerReady({
    required String roomCode,
    required String playerId,
    required bool isReady,
  }) async {
    try {
      final res = await _postWithFallback('/api/rooms/ready', {
        'roomCode': roomCode,
        'playerId': playerId,
        'isReady': isReady,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('设置准备状态异常: $e');
    }
    return false;
  }

  Future<bool> kickPlayer({
    required String roomCode,
    required String operatorId,
    required String targetPlayerId,
  }) async {
    try {
      final res = await _postWithFallback('/api/rooms/kick', {
        'roomCode': roomCode,
        'operatorId': operatorId,
        'targetPlayerId': targetPlayerId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0 || map['code'] == 200;
    } catch (e) {
      debugPrint('踢出房间玩家异常: $e');
      return false;
    }
  }

  // ==================== 真实潮友圈动态 ====================

  Future<List<PostMomentModel>> fetchMoments() async {
    try {
      final res = await _getWithFallback('/api/moments');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((m) => PostMomentModel(
          id: m['id'],
          authorId: m['authorId'] ?? '',
          authorName: m['authorName'] ?? '玩家',
          authorAvatar: m['authorAvatar'] ?? '🦊',
          content: m['content'] ?? '',
          gameTag: m['gameTag'],
          recordHighlight: m['recordHighlight'],
          likeCount: m['likeCount'] ?? 0,
          likedByMe: m['likedByMe'] ?? false,
          comments: List<String>.from(m['comments'] ?? []),
          createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (e) {
      debugPrint('获取动态列表失败: $e');
    }
    return [];
  }

  Future<PostMomentModel?> publishMoment({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String content,
    String? gameTag,
    String? recordHighlight,
  }) async {
    try {
      final res = await _postWithFallback('/api/moments/publish', {
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'content': content,
        'gameTag': gameTag,
        'recordHighlight': recordHighlight,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        final m = map['data'];
        return PostMomentModel(
          id: m['id'],
          authorId: m['authorId'],
          authorName: m['authorName'],
          authorAvatar: m['authorAvatar'],
          content: m['content'],
          gameTag: m['gameTag'],
          recordHighlight: m['recordHighlight'],
          likeCount: m['likeCount'] ?? 1,
          likedByMe: true,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('发布动态失败: $e');
    }
    return null;
  }

  Future<void> likeMoment(String momentId) async {
    try {
      await _postWithFallback('/api/moments/like', {'momentId': momentId});
    } catch (_) {}
  }

  // ==================== 真实用户搜索与好友系统 ====================

  /// 获取云端全服推荐真实玩家（用于好友页/搜索弹窗首屏展示）
  Future<List<UserSearchResult>> fetchRecommendedUsers() async {
    try {
      final res = await _getWithFallback('/api/users/recommended');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((u) => UserSearchResult.fromJson(u)).toList();
      }
    } catch (e) {
      debugPrint('获取推荐用户失败: $e');
    }
    return [];
  }

  /// 实时同步用户至云端中心库（支持全服好友即时检索）
  Future<void> syncUserToServer(UserModel user) async {
    try {
      await _postWithFallback('/api/auth/sync-user', user.toJson());
    } catch (e) {
      debugPrint('同步用户至云端失败: $e');
    }
  }

  /// 搜索真实用户（按手机号、昵称、游戏号/ID）
  Future<List<UserSearchResult>> searchUsers(String keyword) async {
    try {
      final res = await _getWithFallback('/api/users/search?keyword=${Uri.encodeComponent(keyword)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((u) => UserSearchResult.fromJson(u)).toList();
      }
    } catch (e) {
      debugPrint('云端检索用户失败: $e');
    }
    return [];
  }

  /// 发起好友申请
  Future<Map<String, dynamic>> applyFriend({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final res = await _postWithFallback('/api/friends/apply', {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('发起好友申请网络失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后重试'};
    }
  }

  /// 获取收到的待处理好友申请
  Future<List<FriendRequestModel>> fetchFriendRequests(String userId) async {
    try {
      final res = await _getWithFallback('/api/friends/requests?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((r) => FriendRequestModel.fromJson(r)).toList();
      }
    } catch (e) {
      debugPrint('获取好友申请失败: $e');
    }
    return [];
  }

  /// 处理好友申请（ACCEPT 同意 / REJECT 拒绝）
  Future<Map<String, dynamic>> respondFriendRequest({
    required String requestId,
    required String action,
    required String userId,
  }) async {
    try {
      final res = await _postWithFallback('/api/friends/respond', {
        'requestId': requestId,
        'action': action,
        'userId': userId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('处理好友申请失败: $e');
      return {'code': -1, 'message': '操作失败，请重试'};
    }
  }

  /// 获取正式生效的好友列表
  Future<List<FriendModel>> fetchFriends(String userId) async {
    try {
      final res = await _getWithFallback('/api/friends/list?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((f) => FriendModel.fromJson(f)).toList();
      }
    } catch (e) {
      debugPrint('获取好友列表失败: $e');
    }
    return [];
  }

  /// 修改好友备注名
  Future<Map<String, dynamic>> updateFriendRemark({
    required String userId,
    required String friendId,
    required String remark,
  }) async {
    try {
      final res = await _postWithFallback('/api/friends/remark', {
        'userId': userId,
        'friendId': friendId,
        'remark': remark,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('修改好友备注网络失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后重试'};
    }
  }

  /// 获取指定用户的公开资料卡
  Future<Map<String, dynamic>?> fetchUserProfile({
    required String userId,
    String? currentUserId,
  }) async {
    try {
      final uri = '/api/user/profile?userId=${Uri.encodeComponent(userId)}${currentUserId != null ? '&currentUserId=${Uri.encodeComponent(currentUserId)}' : ''}';
      final res = await _getWithFallback(uri);
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if ((map['code'] == 0 || map['code'] == 200) && map['data'] is Map<String, dynamic>) {
        return map['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('获取用户公开资料失败: $e');
    }
    return null;
  }

  /// 获取未读/离线私信
  Future<List<DirectMessage>> fetchUnreadDirectMessages(String userId) async {
    try {
      final res = await _getWithFallback('/api/friends/messages/unread?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((m) {
          final ts = m['timestamp'];
          DateTime dt = DateTime.now();
          if (ts is num) {
            dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
          }
          return DirectMessage(
            id: m['id']?.toString() ?? 'DM-${DateTime.now().millisecondsSinceEpoch}',
            senderId: m['fromUserId']?.toString() ?? '',
            text: m['content']?.toString() ?? '',
            time: dt,
            isFromMe: false,
            inviteRoomCode: m['inviteRoomCode']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('获取离线私信失败: $e');
    }
    return [];
  }

  /// 获取与指定好友的历史聊天记录
  Future<List<DirectMessage>> fetchDirectMessageHistory(String userId, String friendId) async {
    try {
      final res = await _getWithFallback('/api/friends/messages/history?userId=${Uri.encodeComponent(userId)}&friendId=${Uri.encodeComponent(friendId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((m) {
          final ts = m['timestamp'];
          DateTime dt = DateTime.now();
          if (ts is num) {
            dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
          }
          final fromId = m['fromUserId']?.toString() ?? '';
          return DirectMessage(
            id: m['id']?.toString() ?? 'DM-${DateTime.now().millisecondsSinceEpoch}',
            senderId: fromId,
            text: m['content']?.toString() ?? '',
            time: dt,
            isFromMe: fromId == userId,
            inviteRoomCode: m['inviteRoomCode']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('获取聊天历史失败: $e');
    }
    return [];
  }

  /// 发送私信（可靠 HTTP 入库 + 唤起服务端 WebSocket 直推双重保障）
  Future<bool> sendDirectMessage({
    required String id,
    required String fromUserId,
    required String toUserId,
    required String content,
    String? fromNickname,
    String? fromAvatar,
    String? inviteRoomCode,
  }) async {
    try {
      final res = await _postWithFallback('/api/friends/messages/send', {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'content': content,
        'fromNickname': fromNickname ?? '玩家',
        'fromAvatar': fromAvatar ?? '🦊',
        'inviteRoomCode': inviteRoomCode,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('HTTP 发送私信失败: $e');
      return false;
    }
  }

  /// 标记与指定好友的私信为已读
  Future<bool> markDirectMessagesAsRead(String userId, String friendId) async {
    try {
      final res = await _postWithFallback('/api/friends/messages/read', {
        'userId': userId,
        'friendId': friendId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('上报私信已读失败: $e');
      return false;
    }
  }

  /// 发送全服横向跑马灯与全局盛典特效广播
  Future<bool> sendGlobalBroadcast(Map<String, dynamic> blessingJson) async {
    try {
      final res = await _postWithFallback('/api/chat/global-broadcast', blessingJson);
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map['code'] == 0;
    } catch (e) {
      debugPrint('HTTP 全服广播失败: $e');
      return false;
    }
  }

  /// 获取最近 5 分钟内的全服大喇叭历史 (用于后上线的客户端补齐展示)
  Future<List<Map<String, dynamic>>> fetchRecentGlobalBroadcasts() async {
    try {
      final res = await _getWithFallback('/api/chat/global-broadcast/recent');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取最近全服大喇叭失败: $e');
      return [];
    }
  }

  // ==================== 商业化经济系统与核心业务 API ====================

  /// 获取商城全量商品与充值档位配置
  Future<Map<String, dynamic>> fetchShopCatalog(String userId) async {
    try {
      final res = await _getWithFallback('/api/shop/goods?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        final d = map['data'];
        final goods = (d['goods'] as List).map((g) => ShopGoodsItem.fromJson(g)).toList();
        final rechargeTiers = (d['rechargeTiers'] as List).map((t) => RechargeTierItem.fromJson(t)).toList();
        return {
          'goods': goods,
          'rechargeTiers': rechargeTiers,
          'userBalance': d['userBalance'],
        };
      }
    } catch (e) {
      debugPrint('获取商城商品配置网络失败: $e');
    }
    return {
      'goods': <ShopGoodsItem>[],
      'rechargeTiers': <RechargeTierItem>[],
      'userBalance': null,
    };
  }

  /// 充值下单与即时到账
  /// 官方收银台充值支付 (微信支付 WXPAY / 支付宝 ALIPAY 模拟支付入账)
  Future<Map<String, dynamic>> payCashier({
    required String userId,
    required String tierId,
    required String payChannel, // 'WXPAY' | 'ALIPAY'
  }) async {
    try {
      final res = await _postWithFallback('/api/shop/pay', {
        'userId': userId,
        'tierId': tierId,
        'payChannel': payChannel,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('收银台支付失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后再试'};
    }
  }

  /// 充值下单与即时到账 (兼容老逻辑)
  Future<Map<String, dynamic>> recharge({
    required String userId,
    required String tierId,
  }) async {
    return payCashier(userId: userId, tierId: tierId, payChannel: 'WXPAY');
  }

  /// 钻石兑换金币 (严格遵循 1 钻石 = 100 金币比例)
  Future<Map<String, dynamic>> convertDiamondsToCoins({
    required String userId,
    required int diamonds,
  }) async {
    try {
      final res = await _postWithFallback('/api/shop/convert-diamonds', {
        'userId': userId,
        'diamonds': diamonds,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('钻石兑换金币失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后再试'};
    }
  }

  /// 获取大厅营销活动与轮播横幅列表
  Future<List<Map<String, dynamic>>> fetchMarketingBanners() async {
    try {
      final res = await _getWithFallback('/api/marketing/banners');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return List<Map<String, dynamic>>.from(map['data']);
      }
    } catch (e) {
      debugPrint('获取营销横幅失败: $e');
    }
    return [];
  }

  /// 购买装扮或礼包
  Future<Map<String, dynamic>> buyShopItem({
    required String userId,
    required String itemId,
    bool autoEquip = true,
  }) async {
    try {
      final res = await _postWithFallback('/api/shop/buy', {
        'userId': userId,
        'itemId': itemId,
        'autoEquip': autoEquip,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('购买装扮网络失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后再试'};
    }
  }

  /// 穿戴指定装扮
  Future<Map<String, dynamic>> equipItem({
    required String userId,
    required String slot, // 'dice_cup' | 'avatar_frame' | 'entrance_banner'
    required String itemId,
  }) async {
    try {
      final res = await _postWithFallback('/api/shop/equip', {
        'userId': userId,
        'slot': slot,
        'itemId': itemId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('穿戴装扮网络失败: $e');
      return {'code': -1, 'message': '网络连接失败，请稍后再试'};
    }
  }

  /// 获取七日签到打卡状态
  Future<SignInStatus?> fetchSignInStatus(String userId) async {
    try {
      final res = await _getWithFallback('/api/activity/sign-in?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        return SignInStatus.fromJson(map['data']);
      }
    } catch (e) {
      debugPrint('获取签到状态失败: $e');
    }
    return null;
  }

  /// 领取今日签到奖励
  Future<Map<String, dynamic>> claimSignIn(String userId) async {
    try {
      final res = await _postWithFallback('/api/activity/sign-in', {
        'userId': userId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('签到领奖失败: $e');
      return {'code': -1, 'message': '网络请求失败，请稍后重试'};
    }
  }

  /// 获取每日任务列表
  Future<List<DailyTaskItem>> fetchDailyTasks(String userId) async {
    try {
      final res = await _getWithFallback('/api/tasks/daily?userId=${Uri.encodeComponent(userId)}');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] is List) {
        return (map['data'] as List).map((t) => DailyTaskItem.fromJson(t)).toList();
      }
    } catch (e) {
      debugPrint('获取每日任务失败: $e');
    }
    return [];
  }

  /// 领取任务奖励
  Future<Map<String, dynamic>> claimDailyTask({
    required String userId,
    required String taskId,
  }) async {
    try {
      final res = await _postWithFallback('/api/tasks/claim', {
        'userId': userId,
        'taskId': taskId,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      return map;
    } catch (e) {
      debugPrint('领取任务奖励失败: $e');
      return {'code': -1, 'message': '网络请求失败，请稍后重试'};
    }
  }

  /// 游戏对局胜负排位商业结算
  Future<RankSettlementResult?> settleRankGame({
    required String userId,
    required bool isWin,
    String gameType = 'liars_dice',
  }) async {
    try {
      final res = await _postWithFallback('/api/game/settle-rank', {
        'userId': userId,
        'isWin': isWin,
        'gameType': gameType,
      });
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null && map['data']['settlement'] != null) {
        return RankSettlementResult.fromJson(map['data']['settlement']);
      }
    } catch (e) {
      debugPrint('排位结算请求失败: $e');
    }
    return null;
  }

  /// 获取全服排行榜（天梯榜 & 财富榜）
  Future<Map<String, List<LeaderboardItem>>> fetchLeaderboard() async {
    try {
      final res = await _getWithFallback('/api/rank/leaderboard');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 0 && map['data'] != null) {
        final d = map['data'];
        final rankBoard = (d['rankBoard'] as List? ?? []).map((x) => LeaderboardItem.fromJson(x)).toList();
        final wealthBoard = (d['wealthBoard'] as List? ?? []).map((x) => LeaderboardItem.fromJson(x)).toList();
        return {
          'rankBoard': rankBoard,
          'wealthBoard': wealthBoard,
        };
      }
    } catch (e) {
      debugPrint('获取排行榜数据失败: $e');
    }
    return {
      'rankBoard': [],
      'wealthBoard': [],
    };
  }

  /// 查询与指定好友/对手的亲密度详情
  Future<Map<String, dynamic>?> getIntimacyDetail(String user1Id, String user2Id) async {
    try {
      final res = await _getWithFallback('/api/intimacy/detail?user1Id=$user1Id&user2Id=$user2Id');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 200) {
        return map as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// 设置双方亲密关系 (朋友、发小、死党、闺蜜、基友、情侣、老婆、老公等)
  Future<Map<String, dynamic>> setIntimacyRelationship(String user1Id, String user2Id, String relationship) async {
    try {
      final res = await _postWithFallback('/api/intimacy/set-relationship', {
        'user1Id': user1Id,
        'user2Id': user2Id,
        'relationship': relationship,
      });
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': '设置亲密关系失败，请重试'};
    }
  }

  /// 查询用户活跃对战房间
  Future<Map<String, dynamic>?> getUserActiveRoom(String userId) async {
    try {
      final res = await _getWithFallback('/api/user/active-room?userId=$userId');
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map['code'] == 200 && map['hasActiveRoom'] == true) {
        return map['activeRoom'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

