import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repository;
    late SettingsLocalDataSource dataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      dataSource = SettingsLocalDataSource(prefs);
      repository = SettingsRepository(dataSource);
    });

    test('should get default monitoring mode', () {
      expect(
        repository.getMonitoringMode(),
        equals(AppConstants.monitoringModeSignificant),
      );
    });

    test('should set and get monitoring mode', () async {
      await repository.setMonitoringMode(AppConstants.monitoringModeMove);
      expect(
        repository.getMonitoringMode(),
        equals(AppConstants.monitoringModeMove),
      );
    });

    test('should set and get MQTT host', () async {
      const host = 'mqtt.example.com';
      await repository.setMqttHost(host);
      expect(repository.getMqttHost(), equals(host));
    });

    test('should set and get MQTT port', () async {
      const port = 8883;
      await repository.setMqttPort(port);
      expect(repository.getMqttPort(), equals(port));
    });

    test('should get default MQTT port', () {
      expect(repository.getMqttPort(), equals(AppConstants.defaultMqttPort));
    });

    test('should set and get MQTT TLS', () async {
      await repository.setMqttUseTls(true);
      expect(repository.getMqttUseTls(), isTrue);
    });

    test('should set and get MQTT credentials', () async {
      const username = 'testuser';
      const password = 'testpass';

      await repository.setMqttUsername(username);
      await repository.setMqttPassword(password);

      expect(repository.getMqttUsername(), equals(username));
      expect(repository.getMqttPassword(), equals(password));
    });

    test('should set and get connection mode', () async {
      await repository.setConnectionMode(AppConstants.connectionModeHttp);
      expect(
        repository.getConnectionMode(),
        equals(AppConstants.connectionModeHttp),
      );
    });

    test('should get default connection mode', () {
      expect(
        repository.getConnectionMode(),
        equals(AppConstants.connectionModeMqtt),
      );
    });

    test('should set and get device ID', () async {
      const deviceId = 'test-device-123';
      await repository.setDeviceId(deviceId);
      expect(repository.getDeviceId(), equals(deviceId));
    });

    test('should set and get encryption key', () async {
      const key = 'test-encryption-key';
      await repository.setEncryptionKey(key);
      expect(repository.getEncryptionKey(), equals(key));
    });

    test('should clear all settings', () async {
      await repository.setMqttHost('mqtt.example.com');
      await repository.setMqttPort(8883);
      await repository.setDeviceId('test-device');

      await repository.clearAll();

      expect(repository.getMqttHost(), isEmpty);
      expect(repository.getMqttPort(), equals(AppConstants.defaultMqttPort));
      expect(repository.getDeviceId(), isEmpty);
    });
  });
}
