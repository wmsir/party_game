import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> setString(String key, String value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<bool> setInt(String key, int value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  static Future<bool> setBool(String key, bool value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  static Future<bool> remove(String key) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.remove(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  static const String _authTokenKey = 'party_game_auth_token';
  static const String _themeModeKey = 'party_game_theme_mode';

  static Future<bool> saveAuthToken(String token) async {
    return setString(_authTokenKey, token.trim());
  }

  static String? getAuthToken() {
    final token = getString(_authTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  static Future<bool> clearAuthToken() async {
    return remove(_authTokenKey);
  }

  static Future<bool> saveThemeMode(String mode) async {
    return setString(_themeModeKey, mode);
  }

  static String? getThemeMode() => getString(_themeModeKey);

  static Future<bool> clear() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.clear();
  }
}
