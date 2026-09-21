import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecretStore extends SessionSecretStore {
  bool failWrites = false;
  bool ignoreWrites = false;
  Completer<void>? hold;

  Future<void> replaceFromAnotherSession(String key, String value) =>
      super.write(key, value);

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Secure storage unavailable');
    await hold?.future;
    if (!ignoreWrites) await super.write(key, value);
  }
}

class _Preferences extends SettingsLocalDataSource {
  _Preferences(super.preferences);
  bool failRemoval = false;
  @override
  Future<bool> remove(String key) async =>
      failRemoval ? false : super.remove(key);
}

void main() {
  const key = AppConstants.prefKeyEncryptionKey;
  late _Preferences preferences;
  late _SecretStore secure;
  late SettingsRepository settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = _Preferences(await SharedPreferences.getInstance());
    secure = _SecretStore();
    await secure.write(key, 'device-key');
    await preferences.setString(key, 'restored-key');
    settings = SettingsRepository(preferences, secretStore: secure);
  });

  Future<CredentialMigrationConflict> conflict() async {
    try {
      await settings.migrateSecrets();
    } on CredentialMigrationConflict catch (error) {
      return error;
    }
    fail('Expected a recoverable migration conflict');
  }

  test(
    'collects all conflicts before changing any legacy credential',
    () async {
      await preferences.setString(
        AppConstants.prefKeyMqttUsername,
        'restored-user',
      );
      await preferences.setString(
        AppConstants.prefKeyMqttPassword,
        'restored-password',
      );
      await secure.write(AppConstants.prefKeyMqttPassword, 'device-password');
      final error = await conflict();
      expect(error.conflicts.map((item) => item.key).toSet(), {
        key,
        AppConstants.prefKeyMqttPassword,
      });
      expect(error.toString(), isNot(contains('device-key')));
      expect(
        error.conflicts.map((item) => item.label).join(),
        isNot(contains('restored-key')),
      );
      expect(
        preferences.getString(AppConstants.prefKeyMqttUsername),
        'restored-user',
      );
      expect(secure.read(AppConstants.prefKeyMqttUsername), isNull);
    },
  );

  for (final source in CredentialSource.values) {
    test(
      'explicit $source choice verifies the selected value before removing legacy',
      () async {
        final error = await conflict();
        await error.resolve({key: source});
        expect(
          secure.read(key),
          source == CredentialSource.secure ? 'device-key' : 'restored-key',
        );
        expect(preferences.getString(key), isNull);
        await settings.migrateSecrets();
      },
    );
  }

  test('missing choices leave both versions untouched', () async {
    final error = await conflict();
    await expectLater(error.resolve({}), throwsArgumentError);
    expect(secure.read(key), 'device-key');
    expect(preferences.getString(key), 'restored-key');
  });

  test(
    'changed legacy values invalidate a previously reviewed choice',
    () async {
      final error = await conflict();
      await preferences.setString(key, 'newer-restored-key');
      await expectLater(
        error.resolve({key: CredentialSource.secure}),
        throwsStateError,
      );
      expect(preferences.getString(key), 'newer-restored-key');
      expect(secure.read(key), 'device-key');
    },
  );

  test(
    'changed secure values invalidate a previously reviewed choice',
    () async {
      final error = await conflict();
      await secure.write(key, 'newer-device-key');
      await expectLater(
        error.resolve({key: CredentialSource.legacy}),
        throwsStateError,
      );
      expect(preferences.getString(key), 'restored-key');
      expect(secure.read(key), 'newer-device-key');
    },
  );

  test(
    'failed or unverified secure writes never remove the legacy value',
    () async {
      final error = await conflict();
      secure.failWrites = true;
      await expectLater(
        error.resolve({key: CredentialSource.legacy}),
        throwsStateError,
      );
      secure.failWrites = false;
      secure.ignoreWrites = true;
      await expectLater(
        error.resolve({key: CredentialSource.legacy}),
        throwsStateError,
      );
      expect(secure.read(key), 'device-key');
      expect(preferences.getString(key), 'restored-key');
      secure.ignoreWrites = false;
      await error.resolve({key: CredentialSource.legacy});
      expect(secure.read(key), 'restored-key');
      expect(preferences.getString(key), isNull);
    },
  );

  test(
    'failed legacy cleanup can restart migration without losing the selected value',
    () async {
      final error = await conflict();
      preferences.failRemoval = true;
      await expectLater(
        error.resolve({key: CredentialSource.legacy}),
        throwsStateError,
      );
      expect(preferences.getString(key), 'restored-key');
      expect(secure.read(key), 'restored-key');
      preferences.failRemoval = false;
      await settings.migrateSecrets();
      expect(preferences.getString(key), isNull);
    },
  );

  test(
    'concurrent conflicting resolutions cannot overwrite the accepted choice',
    () async {
      final error = await conflict();
      secure.hold = Completer<void>();
      final first = error.resolve({key: CredentialSource.legacy});
      await expectLater(
        error.resolve({key: CredentialSource.secure}),
        throwsStateError,
      );
      secure.hold!.complete();
      await first;
      expect(secure.read(key), 'restored-key');
      expect(preferences.getString(key), isNull);
    },
  );

  test(
    'a changed later credential is preserved while an earlier choice is being verified',
    () async {
      const password = AppConstants.prefKeyMqttPassword;
      await secure.write(password, 'device-password');
      await preferences.setString(password, 'restored-password');
      final error = await conflict();
      secure.hold = Completer<void>();
      final resolution = error.resolve({
        password: CredentialSource.legacy,
        key: CredentialSource.legacy,
      });
      await secure.replaceFromAnotherSession(key, 'newer-device-key');
      final rejected = expectLater(resolution, throwsStateError);
      secure.hold!.complete();
      await rejected;
      expect(secure.read(key), 'newer-device-key');
      expect(preferences.getString(key), 'restored-key');
    },
  );
}
