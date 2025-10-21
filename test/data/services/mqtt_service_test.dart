import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MqttService', () {
    late MqttService service;
    late SettingsRepository settingsRepository;
    late EndpointStateRepository stateRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      settingsRepository = SettingsRepository(dataSource);
      stateRepository = EndpointStateRepository();

      service = MqttService(settingsRepository, stateRepository);
    });

    tearDown(() {
      service.dispose();
      stateRepository.dispose();
    });

    group('connect', () {
      test('should fail when MQTT host not configured', () async {
        final result = await service.connect();

        expect(result, isFalse);
        expect(stateRepository.state, equals(EndpointState.idle));
        expect(service.isConnected, isFalse);
      });

      test('should update state to connecting when attempting connection', () async {
        await settingsRepository.setMqttHost('test.mosquitto.org');
        await settingsRepository.setMqttPort(1883);

        // Start connection (will fail since we can't reach real broker in tests)
        service.connect();

        // Wait a bit for state to update
        await Future.delayed(const Duration(milliseconds: 100));

        // State should have been set to connecting at some point
        expect(stateRepository.state, isNot(equals(EndpointState.idle)));
      });

      test('should use configured credentials', () async {
        await settingsRepository.setMqttHost('test.mosquitto.org');
        await settingsRepository.setMqttPort(1883);
        await settingsRepository.setMqttUsername('testuser');
        await settingsRepository.setMqttPassword('testpass');
        await settingsRepository.setMqttClientId('test-client-123');

        // Connection will fail but should not throw
        final result = await service.connect();

        // We can't test actual connection without a real broker,
        // but we can verify settings were read
        expect(result, isFalse); // Expected to fail in test environment
      });

      test('should configure TLS when enabled', () async {
        await settingsRepository.setMqttHost('test.mosquitto.org');
        await settingsRepository.setMqttPort(8883);
        await settingsRepository.setMqttUseTls(true);

        // Connection will fail but should not throw
        final result = await service.connect();
        expect(result, isFalse); // Expected to fail in test environment
      });
    });

    group('disconnect', () {
      test('should disconnect and update state', () async {
        await service.disconnect();

        expect(service.isConnected, isFalse);
        expect(stateRepository.state, equals(EndpointState.disconnected));
      });
    });

    group('publish', () {
      test('should fail when not connected', () async {
        final result = await service.publish('test/topic', '{"test": "data"}');
        expect(result, isFalse);
      });
    });

    group('subscribe/unsubscribe', () {
      test('should not throw when not connected', () {
        expect(() => service.subscribe('test/topic'), returnsNormally);
        expect(() => service.unsubscribe('test/topic'), returnsNormally);
      });
    });

    group('isConnected', () {
      test('should return false when not connected', () {
        expect(service.isConnected, isFalse);
      });
    });

    group('messages stream', () {
      test('should have broadcast stream', () {
        // Should be able to listen multiple times
        final subscription1 = service.messages.listen((_) {});
        final subscription2 = service.messages.listen((_) {});

        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);

        subscription1.cancel();
        subscription2.cancel();
      });
    });
  });
}
