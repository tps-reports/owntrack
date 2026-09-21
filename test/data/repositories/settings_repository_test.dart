import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSettingsLocalDataSource extends Mock
    implements SettingsLocalDataSource {}

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

    final preferenceWrites =
        <String, Future<void> Function(SettingsRepository)>{
          'monitoring mode': (settings) =>
              settings.setMonitoringMode(AppConstants.monitoringModeMove),
          'MQTT host': (settings) => settings.setMqttHost('mqtt.example.com'),
          'MQTT port': (settings) => settings.setMqttPort(8883),
          'MQTT TLS': (settings) => settings.setMqttUseTls(true),
          'MQTT client ID': (settings) => settings.setMqttClientId('phone'),
          'connection mode': (settings) =>
              settings.setConnectionMode(AppConstants.connectionModeHttp),
          'device ID': (settings) => settings.setDeviceId('phone'),
          'tracker ID': (settings) => settings.setTrackerId('ph'),
          'publication policy': (settings) =>
              settings.setPublicationPolicy(TrackingPublicationPolicy()),
        };
    for (final entry in preferenceWrites.entries) {
      test('${entry.key} write failure is surfaced to the caller', () async {
        final failingDataSource = MockSettingsLocalDataSource();
        when(
          () => failingDataSource.setString(any(), any()),
        ).thenAnswer((_) async => false);
        when(
          () => failingDataSource.setInt(any(), any()),
        ).thenAnswer((_) async => false);
        when(
          () => failingDataSource.setBool(any(), any()),
        ).thenAnswer((_) async => false);
        final failingRepository = SettingsRepository(failingDataSource);
        await expectLater(entry.value(failingRepository), throwsStateError);
      });
    }

    test(
      'does not persist credentials or encryption keys in preferences',
      () async {
        await repository.setMqttPassword('synthetic-password');
        await repository.setEncryptionKey('synthetic-key');
        expect(dataSource.getString(AppConstants.prefKeyMqttPassword), isNull);
        expect(dataSource.getString(AppConstants.prefKeyEncryptionKey), isNull);
      },
    );

    test(
      'shareable configuration excludes credentials and endpoint secrets',
      () async {
        await repository.setMqttUsername('synthetic-user');
        await repository.setMqttPassword('synthetic-password');
        await repository.setEncryptionKey('synthetic-key');
        await repository.setHttpUrl(
          'https://user:secret@example.com/?token=secret',
        );
        final configuration = repository.shareableConfiguration();
        expect(configuration.keys, isNot(contains('mqttPassword')));
        expect(configuration.keys, isNot(contains('mqttUsername')));
        expect(configuration.keys, isNot(contains('encryptionKey')));
        expect(configuration.keys, isNot(contains('httpUrl')));
        expect(configuration.toString(), isNot(contains('synthetic-')));
      },
    );

    test('defaults to TLS for new configurations', () {
      expect(repository.getMqttUseTls(), isTrue);
    });

    test(
      'conflicting migration preserves both copies of the encryption key',
      () async {
        final secure = SessionSecretStore();
        await secure.write(AppConstants.prefKeyEncryptionKey, 'secure-key');
        await dataSource.setString(
          AppConstants.prefKeyEncryptionKey,
          'legacy-key',
        );
        repository = SettingsRepository(dataSource, secretStore: secure);
        await expectLater(repository.migrateSecrets(), throwsStateError);
        expect(
          dataSource.getString(AppConstants.prefKeyEncryptionKey),
          'legacy-key',
        );
        expect(secure.read(AppConstants.prefKeyEncryptionKey), 'secure-key');
      },
    );

    test('should get default monitoring mode', () {
      expect(
        repository.getMonitoringMode(),
        equals(AppConstants.monitoringModeSignificant),
      );
    });

    test(
      'publication settings persist together across repository restart',
      () async {
        await repository.setPublicationPolicy(
          TrackingPublicationPolicy(
            minimumInterval: const Duration(seconds: 60),
            minimumDistanceMeters: 75,
            heartbeatInterval: const Duration(seconds: 600),
            minimumHeadingChangeDegrees: 30,
          ),
        );
        final restored = SettingsRepository(dataSource).getPublicationPolicy();
        expect(restored.minimumInterval, const Duration(seconds: 60));
        expect(restored.minimumDistanceMeters, 75);
        expect(restored.heartbeatInterval, const Duration(seconds: 600));
        expect(restored.minimumHeadingChangeDegrees, 30);
        await repository.setPublicationPolicy(TrackingPublicationPolicy());
        expect(
          repository.getPublicationPolicy().minimumHeadingChangeDegrees,
          isNull,
        );
      },
    );

    test(
      'malformed publication settings are surfaced, not silently ignored',
      () async {
        await dataSource.setString(
          'publication_policy',
          '{"minimumIntervalSeconds":"invalid"}',
        );
        expect(repository.getPublicationPolicy, throwsFormatException);
      },
    );

    final fractionalPolicies = {
      'minimum interval': TrackingPublicationPolicy(
        minimumInterval: const Duration(milliseconds: 500),
      ),
      'heartbeat interval': TrackingPublicationPolicy(
        minimumInterval: const Duration(seconds: 1),
        heartbeatInterval: const Duration(milliseconds: 1500),
      ),
    };
    for (final entry in fractionalPolicies.entries) {
      test(
        'fractional ${entry.key} is rejected before replacing saved settings',
        () async {
          await repository.setPublicationPolicy(TrackingPublicationPolicy());
          final original = dataSource.getString('publication_policy');
          await expectLater(
            repository.setPublicationPolicy(entry.value),
            throwsA(
              isA<ArgumentError>().having(
                (error) => error.message,
                'message',
                contains('whole seconds'),
              ),
            ),
          );
          expect(dataSource.getString('publication_policy'), original);
        },
      );
    }

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
