class SavedAccountModel {
  final String id;
  final String phone;
  final String username;
  final String nickname;
  final String avatar;
  final String password;
  final String loginType; // 'phone' | 'password' | 'guest'
  final DateTime lastLoginTime;

  SavedAccountModel({
    required this.id,
    this.phone = '',
    this.username = '',
    required this.nickname,
    this.avatar = '🦊',
    this.password = '',
    this.loginType = 'password',
    DateTime? lastLoginTime,
  }) : lastLoginTime = lastLoginTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'username': username,
    'nickname': nickname,
    'avatar': avatar,
    'password': password,
    'loginType': loginType,
    'lastLoginTime': lastLoginTime.toIso8601String(),
  };

  factory SavedAccountModel.fromJson(Map<String, dynamic> json) {
    return SavedAccountModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '玩家',
      avatar: json['avatar']?.toString() ?? '🦊',
      password: json['password']?.toString() ?? '',
      loginType: json['loginType']?.toString() ?? 'password',
      lastLoginTime: json['lastLoginTime'] != null
          ? DateTime.tryParse(json['lastLoginTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get displayAccount {
    if (phone.isNotEmpty) return phone;
    if (username.isNotEmpty) return username;
    return id;
  }
}
