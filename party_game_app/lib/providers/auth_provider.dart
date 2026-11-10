import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/shop_models.dart';
import '../models/saved_account_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../core/storage/local_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? get user => _authService.currentUser;
  bool get isLoggedIn => user != null;

  List<SavedAccountModel> get savedAccounts => _authService.getSavedAccounts();

  Future<void> removeSavedAccount(String idOrPhone) async {
    await _authService.removeSavedAccount(idOrPhone);
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    await _authService.init();
    notifyListeners();
  }

  Future<bool> loginWithPassword(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.loginWithPassword(username, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<String> sendSmsCode(String phone) async {
    _errorMessage = null;
    try {
      final code = await _authService.sendSmsCode(phone);
      return code;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> loginWithPhone(String phone, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.loginWithPhone(phone, code);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.loginAsGuest();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// 发送免费试玩短信验证码
  Future<String> sendTrialSmsCode(String phone) async {
    _errorMessage = null;
    try {
      final code = await _authService.sendTrialSmsCode(phone);
      return code;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// 手机接收短信验证码进入免费试玩
  Future<bool> loginWithTrialSms(String phone, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.loginWithTrialSms(phone, code);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String nickname,
    required String password,
    String phone = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.register(
        username: username,
        nickname: nickname,
        password: password,
        phone: phone,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      return await _authService.resetPassword(phone, newPassword);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    }
  }

  void updateProfile({String? nickname, String? avatar, String? diceCupSkin, String? avatarFrame, String? entranceBanner, String? chatTextColor}) {
    if (user == null) return;
    if (nickname != null && nickname.trim().isNotEmpty) user!.nickname = nickname.trim();
    if (avatar != null && avatar.isNotEmpty) user!.avatar = avatar;
    if (diceCupSkin != null) user!.diceCupSkin = diceCupSkin;
    if (avatarFrame != null) user!.avatarFrame = avatarFrame;
    if (entranceBanner != null) user!.entranceBanner = entranceBanner;
    if (chatTextColor != null) user!.chatTextColor = chatTextColor;
    _authService.updateUserProfile(user!);
    notifyListeners();
  }

  /// 账号与安全中心：更新账号、密码、换绑手机、昵称与头像
  Future<bool> updateAccountSecurity({
    String? username,
    String? nickname,
    String? password,
    String? phone,
    String? avatar,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.updateAccountSecurity(
        username: username,
        nickname: nickname,
        password: password,
        phone: phone,
        avatar: avatar,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void saveUser([UserModel? newUser]) {
    final target = newUser ?? user;
    if (target != null) {
      _authService.updateUserProfile(target);
      notifyListeners();
    }
  }

  void awardCoins(int delta) {
    if (user == null) return;
    user!.coins += delta;
    if (user!.coins < 0) user!.coins = 0;
    _authService.updateUserProfile(user!);
    notifyListeners();
  }

  void awardDiamonds(int delta) {
    if (user == null) return;
    user!.diamonds += delta;
    if (user!.diamonds < 0) user!.diamonds = 0;
    _authService.updateUserProfile(user!);
    notifyListeners();
  }

  int calculateVipLevel(int vipExp) {
    if (vipExp >= 29800) return 8;
    if (vipExp >= 12800) return 7;
    if (vipExp >= 6480) return 6;
    if (vipExp >= 3280) return 5;
    if (vipExp >= 1280) return 4;
    if (vipExp >= 680) return 3;
    if (vipExp >= 300) return 2;
    if (vipExp >= 60) return 1;
    return 0;
  }

  String calculateRankTier(int score) {
    if (score <= 0) return '暂无段位';
    if (score >= 3000) return '最强王者';
    if (score >= 2600) return '星耀I';
    if (score >= 2300) return '星耀II';
    if (score >= 1900) return '钻石I';
    if (score >= 1600) return '钻石II';
    if (score >= 1300) return '铂金I';
    if (score >= 1000) return '铂金II';
    if (score >= 700) return '黄金I';
    if (score >= 400) return '黄金II';
    if (score >= 200) return '白银';
    return '青铜';
  }

  /// 商业充值下单（本地高保真与云端同步双重保险）
  Future<bool> recharge(RechargeTierItem tier) async {
    await payCashier(tier, 'WXPAY');
    return true;
  }

  /// 官方收银台支付 (微信支付 WXPAY / 支付宝 ALIPAY 模拟支付入账)
  Future<Map<String, dynamic>> payCashier(RechargeTierItem tier, String payChannel) async {
    if (user == null) return {'code': -1, 'message': '未登录'};
    final diamondsAward = tier.diamonds * (tier.isFirstDouble ? 2 : 1);
    final coinsAward = tier.coins;

    user!.diamonds += diamondsAward;
    user!.coins += coinsAward;
    user!.vipExp += tier.vipExp;
    user!.vipLevel = calculateVipLevel(user!.vipExp);
    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      final res = await ApiService().payCashier(
        userId: user!.id,
        tierId: tier.id,
        payChannel: payChannel,
      );
      return res;
    } catch (_) {
      return {'code': 0, 'message': '充值成功！'};
    }
  }

  /// 钻石兑换金币 (汇率 1:100)
  Future<Map<String, dynamic>> convertDiamondsToCoins(int diamonds) async {
    if (user == null) return {'code': -1, 'message': '未登录'};
    if (diamonds <= 0) return {'code': -1, 'message': '兑换数量需大于0'};
    if (user!.diamonds < diamonds) return {'code': -1, 'message': '钻石余额不足'};

    final coinsAward = diamonds * 100;
    user!.diamonds -= diamonds;
    user!.coins += coinsAward;
    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      final res = await ApiService().convertDiamondsToCoins(
        userId: user!.id,
        diamonds: diamonds,
      );
      return res;
    } catch (_) {
      return {'code': 0, 'coinsAward': coinsAward, 'message': '兑换成功'};
    }
  }

  /// 商城购买道具/装扮（支持单件购买与多件道具包购买）
  Future<bool> buyAndEquip(ShopGoodsItem item, {bool autoEquip = true, int quantity = 1}) async {
    if (user == null || quantity <= 0) return false;
    final totalDiamonds = item.priceDiamonds * quantity;
    final totalCoins = item.priceCoins * quantity;
    if (totalDiamonds > 0 && user!.diamonds < totalDiamonds) return false;
    if (totalCoins > 0 && user!.coins < totalCoins) return false;

    if (totalDiamonds > 0) user!.diamonds -= totalDiamonds;
    if (totalCoins > 0) user!.coins -= totalCoins;

    if (item.category == 'gift_prop') {
      user!.addItemCount(item.id, quantity);
    } else {
      if (!user!.inventory.contains(item.id)) {
        user!.inventory.add(item.id);
      }
    }

    if (autoEquip) {
      if (item.category == 'dice_cup') user!.diceCupSkin = item.id;
      if (item.category == 'avatar_frame') user!.avatarFrame = item.id;
      if (item.category == 'entrance_banner') user!.entranceBanner = item.id;
      if (item.category == 'chat_text_color' || item.category == 'chatTextColor') user!.chatTextColor = item.id;
    }

    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      await ApiService().buyShopItem(userId: user!.id, itemId: item.id, autoEquip: autoEquip);
    } catch (_) {}
    return true;
  }

  /// 消耗拥有的互动道具
  bool consumeProp(String itemId, int count) {
    if (user == null) return false;
    final ok = user!.consumeItem(itemId, count);
    if (ok) {
      _authService.updateUserProfile(user!);
      notifyListeners();
    }
    return ok;
  }

  /// 穿戴指定装扮
  void equipSlot(String slot, String itemId) {
    if (user == null) return;
    if (slot == 'dice_cup') user!.diceCupSkin = itemId;
    if (slot == 'avatar_frame') user!.avatarFrame = itemId;
    if (slot == 'entrance_banner') user!.entranceBanner = itemId;
    if (slot == 'chat_text_color' || slot == 'chatTextColor') user!.chatTextColor = itemId;
    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      ApiService().equipItem(userId: user!.id, slot: slot, itemId: itemId);
    } catch (_) {}
  }

  /// 获取今日已领取的任务列表
  List<String> getClaimedTasksToday() {
    if (user == null) return [];
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    return LocalStorage.getStringList('claimed_tasks_${user!.id}_$todayStr') ?? [];
  }

  /// 检查任务今日是否已领取
  bool isTaskClaimedToday(String taskId) {
    return getClaimedTasksToday().contains(taskId);
  }

  /// 领取七日签到奖励
  Future<bool> claimSignInReward(SignInDayReward reward) async {
    if (user == null) return false;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (user!.lastSignDate == todayStr) {
      return false; // 今日已签到防刷
    }
    user!.lastSignDate = todayStr;
    user!.signInStreak += 1;
    user!.coins += reward.coins;
    if (reward.diamonds > 0) user!.diamonds += reward.diamonds;
    if (reward.avatarFrame != null && !user!.inventory.contains(reward.avatarFrame)) {
      user!.inventory.add(reward.avatarFrame!);
    }
    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      await ApiService().claimSignIn(user!.id);
    } catch (_) {}
    return true;
  }

  /// 领取每日任务奖励（持久化防重）
  Future<bool> claimTask(DailyTaskItem task) async {
    if (user == null) return false;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final key = 'claimed_tasks_${user!.id}_$todayStr';
    final claimed = List<String>.from(LocalStorage.getStringList(key) ?? []);
    if (claimed.contains(task.id)) {
      return false; // 已领过，禁止重复领取
    }
    claimed.add(task.id);
    await LocalStorage.setStringList(key, claimed);

    user!.coins += task.rewardCoins;
    user!.diamonds += task.rewardDiamonds;
    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      await ApiService().claimDailyTask(userId: user!.id, taskId: task.id);
    } catch (_) {}
    return true;
  }

  /// 排位对局胜负商业结算
  void recordGameResult(bool isWin) {
    settleRankMatch(isWin);
  }

  void settleRankMatch(bool isWin, {String gameType = 'liars_dice'}) {
    if (user == null) return;
    user!.totalGames += 1;
    if (isWin) user!.winCount += 1;

    final scoreDelta = isWin ? 25 : -15;
    user!.rankScore = (user!.rankScore + scoreDelta).clamp(0, 99999);
    user!.rankTier = calculateRankTier(user!.rankScore);
    user!.coins += isWin ? 100 : 20;

    _authService.updateUserProfile(user!);
    notifyListeners();

    try {
      ApiService().settleRankGame(userId: user!.id, isWin: isWin, gameType: gameType);
    } catch (_) {}
  }

  /// 从云端全量刷新当前用户的资料与资产 (金币、钻石、VIP等级、段位、胜率等)
  Future<void> refreshProfileFromServer() async {
    if (user == null) return;
    try {
      final profile = await ApiService().fetchUserProfile(userId: user!.id);
      if (profile != null) {
        if (profile['coins'] is num) user!.coins = (profile['coins'] as num).toInt();
        if (profile['diamonds'] is num) user!.diamonds = (profile['diamonds'] as num).toInt();
        if (profile['vipLevel'] is num) user!.vipLevel = (profile['vipLevel'] as num).toInt();
        if (profile['rankScore'] is num) user!.rankScore = (profile['rankScore'] as num).toInt();
        if (profile['rankTier'] != null) user!.rankTier = profile['rankTier'].toString();
        if (profile['winCount'] is num) user!.winCount = (profile['winCount'] as num).toInt();
        if (profile['totalGames'] is num) user!.totalGames = (profile['totalGames'] as num).toInt();
        if (profile['nickname'] != null && profile['nickname'].toString().isNotEmpty) {
          user!.nickname = profile['nickname'].toString();
        }
        if (profile['avatar'] != null && profile['avatar'].toString().isNotEmpty) {
          user!.avatar = profile['avatar'].toString();
        }
        if (profile['avatarFrame'] != null) {
          user!.avatarFrame = profile['avatarFrame'].toString();
        }
        if (profile['entranceBanner'] != null) {
          user!.entranceBanner = profile['entranceBanner'].toString();
        }
        if (profile['chatTextColor'] != null) {
          user!.chatTextColor = profile['chatTextColor'].toString();
        }
        await _authService.updateUserProfile(user!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('从云端刷新用户信息失败: $e');
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }
}

