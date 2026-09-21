import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:owntrack/bootstrap.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store_native.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/presentation/screens/settings/credential_conflict_screen.dart';

class _FailingRemovalPreferences extends InMemorySharedPreferencesStore {
  _FailingRemovalPreferences(super.values) : super.withData();
  bool failRemoval = true;

  @override
  Future<bool> remove(String key) async =>
      failRemoval ? false : super.remove(key);
}

class _RecordingOutboxStore implements OutboxStore {
  int reads = 0;
  String? value;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

  @override
  Future<bool> compareAndSet(String? expected, String next) async {
    if (value != expected) return false;
    value = next;
    return true;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'startup migrates legacy secrets before returning application dependencies',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyMqttPassword: 'synthetic-secret',
      });
      final preferences = await SharedPreferences.getInstance();
      final secrets = SessionSecretStore();
      final dependencies = await initializeApplication(
        preferences: preferences,
        openSecrets: () async => secrets,
        outboxStore: SqliteOutboxStore(NativeDatabase.memory()),
      );
      expect(dependencies.settings.getMqttPassword(), 'synthetic-secret');
      expect(preferences.getString(AppConstants.prefKeyMqttPassword), isNull);
      expect(
        secrets.read(AppConstants.prefKeyMqttPassword),
        'synthetic-secret',
      );
      await dependencies.queue.close();
    },
  );

  test(
    'startup retry reloads durable preferences after failed legacy removal',
    () async {
      const key = AppConstants.prefKeyMqttPassword;
      SharedPreferences.setMockInitialValues({});
      final platform = _FailingRemovalPreferences({
        'flutter.$key': 'restored-private-password',
      });
      SharedPreferencesStorePlatform.instance = platform;
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final preferences = await SharedPreferences.getInstance();
      final secrets = SessionSecretStore();
      await secrets.write(key, 'stored-private-password');
      final outbox = _RecordingOutboxStore();
      Future<ApplicationDependencies> initialize() => initializeApplication(
        preferences: preferences,
        openSecrets: () async => secrets,
        outboxStore: outbox,
      );
      CredentialMigrationConflict? conflict;
      try {
        await initialize();
      } on CredentialMigrationConflict catch (error) {
        conflict = error;
      }
      expect(conflict, isNotNull);
      await expectLater(
        conflict!.resolve({key: CredentialSource.legacy}),
        throwsStateError,
      );
      expect(
        preferences.getString(key),
        isNull,
        reason:
            'The actual SharedPreferences cache clears before failed platform removal.',
      );
      expect(
        (await platform.getAll())['flutter.$key'],
        'restored-private-password',
      );
      expect(secrets.read(key), 'restored-private-password');
      ApplicationDependencies? unexpected;
      try {
        await expectLater(() async {
          unexpected = await initialize();
        }, throwsStateError);
      } finally {
        await unexpected?.queue.close();
      }
      expect(
        outbox.reads,
        0,
        reason:
            'The outbox and runtime must remain unopened while plaintext cleanup fails.',
      );
      platform.failRemoval = false;
      final dependencies = await initialize();
      expect((await platform.getAll()).containsKey('flutter.$key'), isFalse);
      expect(
        dependencies.settings.getMqttPassword(),
        'restored-private-password',
      );
      await dependencies.queue.close();
    },
  );
  testWidgets(
    'startup failure is visible and retry runs initialization again',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ApplicationBootstrap(
          initialize: () async {
            attempts++;
            throw StateError('synthetic-secret must not be displayed');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to open secure settings or message storage.'),
        findsOneWidget,
      );
      expect(find.textContaining('synthetic-secret'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets('credential choice reruns initialization only after resolution', (
    tester,
  ) async {
    const key = AppConstants.prefKeyMqttPassword;
    SharedPreferences.setMockInitialValues({key: 'restored-private-password'});
    final preferences = await SharedPreferences.getInstance();
    final secrets = SessionSecretStore();
    await secrets.write(key, 'stored-private-password');
    final settings = SettingsRepository(
      SettingsLocalDataSource(preferences),
      secretStore: secrets,
    );
    var attempts = 0;
    var finishedMigration = false;
    await tester.pumpWidget(
      ApplicationBootstrap(
        initialize: () async {
          attempts++;
          await settings.migrateSecrets();
          finishedMigration = true;
          throw StateError('Storage is unavailable after migration');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CredentialConflictScreen), findsOneWidget);
    expect(attempts, 1);
    expect(finishedMigration, isFalse);
    expect(find.textContaining('private-password'), findsNothing);
    final selected = find.byKey(const ValueKey('credential-$key-legacy'));
    await tester.scrollUntilVisible(selected, 250);
    await tester.tap(selected);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review choices'), 250);
    await tester.tap(find.text('Review choices'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.tap(find.text('Use chosen credentials'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(finishedMigration, isTrue);
    expect(secrets.read(key), 'restored-private-password');
    expect(preferences.getString(key), isNull);
    expect(
      find.text('Unable to open secure settings or message storage.'),
      findsOneWidget,
    );
  });
}
