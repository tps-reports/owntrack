import 'package:shared_preferences/shared_preferences.dart';

/// Local data source for settings using SharedPreferences
class SettingsLocalDataSource {
  final SharedPreferences _prefs;

  SettingsLocalDataSource(this._prefs);

  /// Get string value
  String? getString(String key) => _prefs.getString(key);

  /// Set string value
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  /// Get int value
  int? getInt(String key) => _prefs.getInt(key);

  /// Set int value
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  /// Get bool value
  bool? getBool(String key) => _prefs.getBool(key);

  /// Set bool value
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  /// Get double value
  double? getDouble(String key) => _prefs.getDouble(key);

  /// Set double value
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  /// Get list of strings
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  /// Set list of strings
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  /// Remove a key
  Future<bool> remove(String key) => _prefs.remove(key);

  /// Clear all preferences
  Future<bool> clear() => _prefs.clear();

  /// Check if key exists
  bool containsKey(String key) => _prefs.containsKey(key);

  /// Get all keys
  Set<String> getKeys() => _prefs.getKeys();
}
