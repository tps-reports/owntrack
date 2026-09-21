@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/bootstrap.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class RecoveryOutboxStore implements OutboxStore {
  RecoveryOutboxStore({this.failRead = false});

  final bool failRead;
  String? snapshot;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    if (failRead) throw StateError('Outbox is temporarily unavailable.');
    return snapshot;
  }

  @override
  Future<bool> compareAndSet(String? expected, String next) async {
    if (snapshot != expected) return false;
    snapshot = next;
    return true;
  }

  @override
  Future<void> close() async {}
}

class FailingLaterCleanupPreferences extends InMemorySharedPreferencesStore {
  FailingLaterCleanupPreferences(super.values) : super.withData();
  bool failCleanup = true;

  @override
  Future<bool> remove(String key) async {
    if (failCleanup && key == 'flutter.${AppConstants.prefKeyHttpUrl}') {
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  Future<void> clearSessionSecrets() async {
    final secrets = await openPlatformSecretStore();
    for (final key in SettingsRepository.secretKeys) {
      await secrets.delete(key);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearSessionSecrets();
  });

  tearDown(() async {
    await clearSessionSecrets();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'browser bootstrap retry retains migrated credentials after outbox failure',
    () async {
      const key = AppConstants.prefKeyEncryptionKey;
      const password = AppConstants.prefKeyMqttPassword;
      SharedPreferences.setMockInitialValues({
        key: 'synthetic-encryption-key',
        password: 'synthetic-password',
      });
      final preferences = await SharedPreferences.getInstance();
      await expectLater(
        initializeApplication(
          preferences: preferences,
          outboxStore: RecoveryOutboxStore(failRead: true),
        ),
        throwsStateError,
      );
      expect(preferences.getString(key), isNull);
      expect(preferences.getString(password), isNull);
      final recovered = await initializeApplication(
        preferences: preferences,
        outboxStore: RecoveryOutboxStore(),
      );
      try {
        expect(
          recovered.settings.getEncryptionKey(),
          'synthetic-encryption-key',
        );
        expect(recovered.settings.getMqttPassword(), 'synthetic-password');
      } finally {
        await recovered.queue.close();
      }
    },
  );

  test(
    'browser bootstrap retry retains earlier keys after later cleanup fails',
    () async {
      const key = AppConstants.prefKeyEncryptionKey;
      const endpoint = AppConstants.prefKeyHttpUrl;
      final platform = FailingLaterCleanupPreferences({
        'flutter.$key': 'synthetic-encryption-key',
        'flutter.$endpoint': 'https://example.invalid/owntracks',
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final untouchedOutbox = RecoveryOutboxStore();
      await expectLater(
        initializeApplication(
          preferences: preferences,
          outboxStore: untouchedOutbox,
        ),
        throwsStateError,
      );
      expect(untouchedOutbox.reads, 0);
      expect(preferences.getString(key), isNull);
      expect(
        (await platform.getAll())['flutter.$endpoint'],
        'https://example.invalid/owntracks',
      );
      platform.failCleanup = false;
      final recovered = await initializeApplication(
        preferences: preferences,
        outboxStore: RecoveryOutboxStore(),
      );
      try {
        expect(
          recovered.settings.getEncryptionKey(),
          'synthetic-encryption-key',
        );
        expect(
          recovered.settings.getHttpUrl(),
          'https://example.invalid/owntracks',
        );
        expect(preferences.getString(endpoint), isNull);
      } finally {
        await recovered.queue.close();
      }
    },
  );
}
