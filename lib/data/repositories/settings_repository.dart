import 'dart:convert';

import 'package:owntrack/data/models/credential_migration_conflict.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';

export 'package:owntrack/data/models/credential_migration_conflict.dart';

/// Repository for application settings
class SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  final SecretStore _secretStore;
  bool _resolvingCredentials = false;

  SettingsRepository(this._localDataSource, {SecretStore? secretStore})
    : _secretStore = secretStore ?? SessionSecretStore();

  static const secretKeys = [
    AppConstants.prefKeyMqttUsername,
    AppConstants.prefKeyMqttPassword,
    AppConstants.prefKeyEncryptionKey,
    AppConstants.prefKeyHttpUrl,
  ];

  /// Share only identifiers and behavior. Endpoints may contain access tokens,
  /// so they and credentials must be entered on the receiving device.
  Map<String, dynamic> shareableConfiguration() => {
    'connectionMode': getConnectionMode(),
    'deviceId': getDeviceId(),
    'trackerId': getTrackerId(),
    'monitoringMode': getMonitoringMode(),
    'mqttPort': getMqttPort(),
    'mqttUseTls': getMqttUseTls(),
    'mqttClientId': getMqttClientId(),
  };

  /// Move legacy credentials only after the destination verifies its write.
  /// A failed migration leaves the source intact so bootstrap can be retried.
  Future<void> migrateSecrets() async {
    if (_resolvingCredentials) {
      throw StateError('Credential recovery is already in progress.');
    }
    final conflicts = <String, ({String secure, String legacy})>{};
    for (final key in secretKeys) {
      final legacy = _localDataSource.getString(key);
      final current = _secretStore.read(key);
      if (legacy != null && current != null && legacy != current) {
        conflicts[key] = (secure: current, legacy: legacy);
      }
    }
    if (conflicts.isNotEmpty) {
      const labels = {
        AppConstants.prefKeyMqttUsername: 'MQTT username',
        AppConstants.prefKeyMqttPassword: 'MQTT password',
        AppConstants.prefKeyEncryptionKey: 'Encryption key',
        AppConstants.prefKeyHttpUrl: 'HTTP endpoint and credentials',
      };
      throw CredentialMigrationConflict(
        conflicts: conflicts.keys
            .map((key) => CredentialConflict(key: key, label: labels[key]!))
            .toList(),
        resolve: (choices) => _resolveCredentialConflicts(conflicts, choices),
      );
    }
    for (final key in secretKeys) {
      final legacy = _localDataSource.getString(key);
      if (legacy == null) continue;
      final current = _secretStore.read(key);
      if (current != null && current != legacy) {
        throw StateError(
          'Legacy and secure credentials conflict. Both copies have been retained.',
        );
      }
      if (current == null) {
        await _secretStore.write(key, legacy);
      }
      if (_secretStore.read(key) != legacy) {
        throw StateError('Credential migration could not be verified.');
      }
      if (!await _localDataSource.remove(key)) {
        throw StateError('Unable to remove a migrated plaintext credential.');
      }
    }
  }

  Future<void> _resolveCredentialConflicts(
    Map<String, ({String secure, String legacy})> conflicts,
    Map<String, CredentialSource> choices,
  ) async {
    if (_resolvingCredentials) {
      throw StateError('Credential recovery is already in progress.');
    }
    if (choices.length != conflicts.length ||
        !conflicts.keys.every(choices.containsKey)) {
      throw ArgumentError('Choose a source for every conflicting credential.');
    }
    _resolvingCredentials = true;
    try {
      // Nothing is changed until every reviewed version has been checked.
      for (final entry in conflicts.entries) {
        if (_secretStore.read(entry.key) != entry.value.secure ||
            _localDataSource.getString(entry.key) != entry.value.legacy) {
          throw StateError(
            'Credentials changed. Reload before choosing again.',
          );
        }
      }
      for (final entry in conflicts.entries) {
        // Earlier writes can await the OS keychain. Do not overwrite a later
        // credential that changed while those writes were being verified.
        if (_secretStore.read(entry.key) != entry.value.secure ||
            _localDataSource.getString(entry.key) != entry.value.legacy) {
          throw StateError(
            'Credentials changed. Reload before choosing again.',
          );
        }
        final selected = choices[entry.key] == CredentialSource.secure
            ? entry.value.secure
            : entry.value.legacy;
        await _secretStore.write(entry.key, selected);
        if (_secretStore.read(entry.key) != selected) {
          throw StateError('The selected credential could not be verified.');
        }
        if (_localDataSource.getString(entry.key) != entry.value.legacy) {
          throw StateError(
            'Restored credentials changed. Reload before choosing again.',
          );
        }
        if (!await _localDataSource.remove(entry.key)) {
          throw StateError('Unable to remove a resolved legacy credential.');
        }
      }
    } finally {
      _resolvingCredentials = false;
    }
  }

  Future<void> _writeSecret(String key, String value) async {
    await _secretStore.write(key, value);
    if (_localDataSource.containsKey(key) &&
        !await _localDataSource.remove(key)) {
      throw StateError('Unable to remove a legacy plaintext credential.');
    }
  }

  Future<void> _savePreference(Future<bool> write) async {
    if (!await write) {
      throw StateError('Unable to save settings. Please retry.');
    }
  }

  // Monitoring mode
  int getMonitoringMode() =>
      _localDataSource.getInt(AppConstants.prefKeyMonitoringMode) ??
      AppConstants.monitoringModeSignificant;

  Future<void> setMonitoringMode(int mode) => _savePreference(
    _localDataSource.setInt(AppConstants.prefKeyMonitoringMode, mode),
  );

  TrackingPublicationPolicy getPublicationPolicy() {
    final raw = _localDataSource.getString('publication_policy');
    if (raw == null) return TrackingPublicationPolicy();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['version'] != 1 ||
          data['minimumIntervalSeconds'] is! int ||
          data['minimumDistanceMeters'] is! num ||
          data['heartbeatIntervalSeconds'] is! int ||
          (data['minimumHeadingChangeDegrees'] != null &&
              data['minimumHeadingChangeDegrees'] is! num)) {
        throw const FormatException('Invalid publication settings.');
      }
      return TrackingPublicationPolicy(
        minimumInterval: Duration(
          seconds: data['minimumIntervalSeconds'] as int,
        ),
        minimumDistanceMeters: (data['minimumDistanceMeters'] as num)
            .toDouble(),
        heartbeatInterval: Duration(
          seconds: data['heartbeatIntervalSeconds'] as int,
        ),
        minimumHeadingChangeDegrees:
            (data['minimumHeadingChangeDegrees'] as num?)?.toDouble(),
      );
    } on ArgumentError {
      throw const FormatException('Invalid publication settings.');
    }
  }

  Future<void> setPublicationPolicy(TrackingPublicationPolicy policy) async {
    final saved = await _localDataSource.setString(
      'publication_policy',
      jsonEncode({
        'version': 1,
        'minimumIntervalSeconds': _wholeSeconds(
          policy.minimumInterval,
          'minimumInterval',
        ),
        'minimumDistanceMeters': policy.minimumDistanceMeters,
        'heartbeatIntervalSeconds': _wholeSeconds(
          policy.heartbeatInterval,
          'heartbeatInterval',
        ),
        'minimumHeadingChangeDegrees': policy.minimumHeadingChangeDegrees,
      }),
    );
    if (!saved) throw StateError('Unable to save publication settings.');
  }

  static int _wholeSeconds(Duration interval, String name) {
    if (interval.inMicroseconds % Duration.microsecondsPerSecond != 0) {
      throw ArgumentError.value(
        interval,
        name,
        'Publication intervals must use whole seconds.',
      );
    }
    return interval.inSeconds;
  }

  // MQTT settings
  String getMqttHost() =>
      _localDataSource.getString(AppConstants.prefKeyMqttHost) ?? '';

  Future<void> setMqttHost(String host) => _savePreference(
    _localDataSource.setString(AppConstants.prefKeyMqttHost, host),
  );

  int getMqttPort() =>
      _localDataSource.getInt(AppConstants.prefKeyMqttPort) ??
      AppConstants.defaultMqttPort;

  Future<void> setMqttPort(int port) => _savePreference(
    _localDataSource.setInt(AppConstants.prefKeyMqttPort, port),
  );

  bool getMqttUseTls() =>
      _localDataSource.getBool(AppConstants.prefKeyMqttUseTls) ?? true;

  Future<void> setMqttUseTls(bool useTls) => _savePreference(
    _localDataSource.setBool(AppConstants.prefKeyMqttUseTls, useTls),
  );

  String getMqttUsername() =>
      _secretStore.read(AppConstants.prefKeyMqttUsername) ?? '';

  Future<void> setMqttUsername(String username) =>
      _writeSecret(AppConstants.prefKeyMqttUsername, username);

  String getMqttPassword() =>
      _secretStore.read(AppConstants.prefKeyMqttPassword) ?? '';

  Future<void> setMqttPassword(String password) =>
      _writeSecret(AppConstants.prefKeyMqttPassword, password);

  String getMqttClientId() =>
      _localDataSource.getString(AppConstants.prefKeyMqttClientId) ?? '';

  Future<void> setMqttClientId(String clientId) => _savePreference(
    _localDataSource.setString(AppConstants.prefKeyMqttClientId, clientId),
  );

  // HTTP settings
  String getHttpUrl() => _secretStore.read(AppConstants.prefKeyHttpUrl) ?? '';

  Future<void> setHttpUrl(String url) =>
      _writeSecret(AppConstants.prefKeyHttpUrl, url);

  // Connection mode
  String getConnectionMode() =>
      _localDataSource.getString(AppConstants.prefKeyConnectionMode) ??
      AppConstants.connectionModeMqtt;

  Future<void> setConnectionMode(String mode) => _savePreference(
    _localDataSource.setString(AppConstants.prefKeyConnectionMode, mode),
  );

  // Device ID
  String getDeviceId() =>
      _localDataSource.getString(AppConstants.prefKeyDeviceId) ?? '';

  Future<void> setDeviceId(String deviceId) => _savePreference(
    _localDataSource.setString(AppConstants.prefKeyDeviceId, deviceId),
  );

  // Tracker ID
  String getTrackerId() =>
      _localDataSource.getString(AppConstants.prefKeyTrackerId) ?? '';

  Future<void> setTrackerId(String trackerId) => _savePreference(
    _localDataSource.setString(AppConstants.prefKeyTrackerId, trackerId),
  );

  // Encryption key
  String getEncryptionKey() =>
      _secretStore.read(AppConstants.prefKeyEncryptionKey) ?? '';

  Future<void> setEncryptionKey(String key) =>
      _writeSecret(AppConstants.prefKeyEncryptionKey, key);

  // Clear all settings
  Future<void> clearAll() async {
    for (final key in secretKeys) {
      await _secretStore.delete(key);
    }
    if (!await _localDataSource.clear()) {
      throw StateError('Unable to clear settings.');
    }
  }
}
