import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Shared preferences helper. Selected **compound** id is stored as a [String] ([compoundCurrentIndexKey]).
/// There is no separate building-id cache in this app; add one here if needed (use [setString]/[getString]).
class CacheHelper {
  static final SharedPreferencesAsync asyncPrefs = SharedPreferencesAsync();
  static SharedPreferences sharedPreferences = init();

  /// Last selected compound document id (Appwrite $id or legacy numeric string).
  static const String compoundCurrentIndexKey = 'compoundCurrentIndex';

  static init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  static Future<void> saveCompoundCurrentIndex(String compoundId) async {
    await asyncPrefs.setString(compoundCurrentIndexKey, compoundId);
  }

  static Future<String?> getCompoundCurrentIndex() async {
    return asyncPrefs.getString(compoundCurrentIndexKey);
  }

  /// Per-user snapshot written on sign-out (email, compound id, compounds map).
  static String cachedUserDataKey(String userId) => 'cached_data_$userId';

  static Future<void> saveData({
    required String key,
    required dynamic value,
  }) async {
    if (value is String) return await asyncPrefs.setString(key, value);
    if (value is int) return await asyncPrefs.setInt(key, value);
    if (value is bool) return await asyncPrefs.setBool(key, value);
    if (value is double) return await asyncPrefs.setDouble(key, value);
  }

  static Future<dynamic> getData({
    required String key,
    required String type,
  }) async {
    if (type == "String") return await asyncPrefs.getString(key);
    if (type == "int") return await asyncPrefs.getInt(key);
    if (type == "bool") return await asyncPrefs.getBool(key);
    if (type == "double") return await asyncPrefs.getDouble(key);
  }

  static Future<void> removeData(String key) async {
    await asyncPrefs.remove(key);
  }

  /// Stores a JSON object as a UTF-8 string (maps, lists, primitives).
  static Future<void> saveJson(String key, Object? value) async {
    await saveData(key: key, value: jsonEncode(value));
  }

  /// Reads and decodes JSON; returns null if missing or invalid.
  static Future<dynamic> getJson(String key) async {
    final raw = await getData(key: key, type: "String") as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
