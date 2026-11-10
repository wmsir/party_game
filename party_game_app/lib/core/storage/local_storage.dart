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

  static Future<bool> clear() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    return p.clear();
  }
}
