import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';

/// Repository for application settings
class SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  SettingsRepository(this._localDataSource);

  // Monitoring mode
  int getMonitoringMode() =>
      _localDataSource.getInt(AppConstants.prefKeyMonitoringMode) ??
      AppConstants.monitoringModeSignificant;

  Future<void> setMonitoringMode(int mode) =>
      _localDataSource.setInt(AppConstants.prefKeyMonitoringMode, mode);

  // MQTT settings
  String getMqttHost() =>
      _localDataSource.getString(AppConstants.prefKeyMqttHost) ?? '';

  Future<void> setMqttHost(String host) =>
      _localDataSource.setString(AppConstants.prefKeyMqttHost, host);

  int getMqttPort() =>
      _localDataSource.getInt(AppConstants.prefKeyMqttPort) ??
      AppConstants.defaultMqttPort;

  Future<void> setMqttPort(int port) =>
      _localDataSource.setInt(AppConstants.prefKeyMqttPort, port);

  bool getMqttUseTls() =>
      _localDataSource.getBool(AppConstants.prefKeyMqttUseTls) ?? false;

  Future<void> setMqttUseTls(bool useTls) =>
      _localDataSource.setBool(AppConstants.prefKeyMqttUseTls, useTls);

  String getMqttUsername() =>
      _localDataSource.getString(AppConstants.prefKeyMqttUsername) ?? '';

  Future<void> setMqttUsername(String username) =>
      _localDataSource.setString(AppConstants.prefKeyMqttUsername, username);

  String getMqttPassword() =>
      _localDataSource.getString(AppConstants.prefKeyMqttPassword) ?? '';

  Future<void> setMqttPassword(String password) =>
      _localDataSource.setString(AppConstants.prefKeyMqttPassword, password);

  String getMqttClientId() =>
      _localDataSource.getString(AppConstants.prefKeyMqttClientId) ?? '';

  Future<void> setMqttClientId(String clientId) =>
      _localDataSource.setString(AppConstants.prefKeyMqttClientId, clientId);

  // HTTP settings
  String getHttpUrl() =>
      _localDataSource.getString(AppConstants.prefKeyHttpUrl) ?? '';

  Future<void> setHttpUrl(String url) =>
      _localDataSource.setString(AppConstants.prefKeyHttpUrl, url);

  // Connection mode
  String getConnectionMode() =>
      _localDataSource.getString(AppConstants.prefKeyConnectionMode) ??
      AppConstants.connectionModeMqtt;

  Future<void> setConnectionMode(String mode) =>
      _localDataSource.setString(AppConstants.prefKeyConnectionMode, mode);

  // Device ID
  String getDeviceId() =>
      _localDataSource.getString(AppConstants.prefKeyDeviceId) ?? '';

  Future<void> setDeviceId(String deviceId) =>
      _localDataSource.setString(AppConstants.prefKeyDeviceId, deviceId);

  // Tracker ID
  String getTrackerId() =>
      _localDataSource.getString(AppConstants.prefKeyTrackerId) ?? '';

  Future<void> setTrackerId(String trackerId) =>
      _localDataSource.setString(AppConstants.prefKeyTrackerId, trackerId);

  // Encryption key
  String getEncryptionKey() =>
      _localDataSource.getString(AppConstants.prefKeyEncryptionKey) ?? '';

  Future<void> setEncryptionKey(String key) =>
      _localDataSource.setString(AppConstants.prefKeyEncryptionKey, key);

  // Clear all settings
  Future<void> clearAll() => _localDataSource.clear();
}
