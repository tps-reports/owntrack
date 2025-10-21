import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService service;
    late SettingsRepository settingsRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      settingsRepository = SettingsRepository(dataSource);
      service = EncryptionService(settingsRepository);
    });

    group('when encryption is disabled', () {
      test('should return original payload when encrypting', () async {
        const payload = '{"test": "data"}';
        final encrypted = await service.encrypt(payload);
        expect(encrypted, equals(payload));
      });

      test('should return original payload when decrypting', () async {
        const payload = '{"test": "data"}';
        final decrypted = await service.decrypt(payload);
        expect(decrypted, equals(payload));
      });

      test('isEnabled should be false', () {
        expect(service.isEnabled, isFalse);
      });
    });

    group('when encryption is enabled', () {
      setUp(() async {
        await settingsRepository.setEncryptionKey('test-encryption-key-123');
      });

      test('isEnabled should be true', () {
        expect(service.isEnabled, isTrue);
      });

      test('should encrypt payload to base64 string', () async {
        const payload = '{"test": "data"}';
        final encrypted = await service.encrypt(payload);

        expect(encrypted, isNotNull);
        expect(encrypted, isNot(equals(payload)));
        expect(() => base64.decode(encrypted!), returnsNormally);
      });

      test('should decrypt encrypted payload back to original', () async {
        const payload = '{"test": "data"}';
        final encrypted = await service.encrypt(payload);
        final decrypted = await service.decrypt(encrypted!);

        expect(decrypted, equals(payload));
      });

      test('should encrypt and decrypt complex JSON', () async {
        final payload = json.encode({
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
          'tst': 1704110400,
          'acc': 10,
          'batt': 85,
        });

        final encrypted = await service.encrypt(payload);
        final decrypted = await service.decrypt(encrypted!);

        expect(decrypted, equals(payload));
        final parsed = json.decode(decrypted!);
        expect(parsed['_type'], equals('location'));
        expect(parsed['lat'], equals(37.7749));
      });

      test('should fail to decrypt with wrong key', () async {
        const payload = '{"test": "data"}';
        final encrypted = await service.encrypt(payload);

        // Change key
        await settingsRepository.setEncryptionKey('different-key');
        final service2 = EncryptionService(settingsRepository);

        final decrypted = await service2.decrypt(encrypted!);
        expect(decrypted, isNull);
      });

      test('should fail to decrypt invalid data', () async {
        final decrypted = await service.decrypt('invalid-base64-data');
        expect(decrypted, isNull);
      });

      test('should encrypt message with OwnTracks format', () async {
        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        final encrypted = await service.encryptMessage(message);

        expect(encrypted, isNotNull);
        expect(encrypted!['_type'], equals('encrypted'));
        expect(encrypted['data'], isA<String>());
      });

      test('should decrypt OwnTracks encrypted message', () async {
        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        final encrypted = await service.encryptMessage(message);
        final decrypted = await service.decryptMessage(encrypted!);

        expect(decrypted, isNotNull);
        expect(decrypted!['_type'], equals('location'));
        expect(decrypted['lat'], equals(37.7749));
        expect(decrypted['lon'], equals(-122.4194));
      });

      test('should return plain message if not encrypted type', () async {
        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        final result = await service.decryptMessage(message);
        expect(result, equals(message));
      });

      test('should fail to decrypt message with missing data field', () async {
        final message = {
          '_type': 'encrypted',
          // Missing 'data' field
        };

        final result = await service.decryptMessage(message);
        expect(result, isNull);
      });
    });
  });
}
