import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/presentation/screens/settings/credential_conflict_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledSecrets extends SessionSecretStore {
  bool failWrites = false;
  Completer<void>? pending;
  int writes = 0;

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failWrites) throw StateError('Secret value must stay hidden: $value');
    await pending?.future;
    await super.write(key, value);
  }
}

void main() {
  const password = AppConstants.prefKeyMqttPassword;
  const encryption = AppConstants.prefKeyEncryptionKey;

  Future<
    ({
      CredentialMigrationConflict conflict,
      SharedPreferences preferences,
      _ControlledSecrets secrets,
    })
  >
  createConflict({bool includeEncryption = true}) async {
    SharedPreferences.setMockInitialValues({
      password: 'restored-private-password',
      if (includeEncryption) encryption: 'restored-private-key',
    });
    final preferences = await SharedPreferences.getInstance();
    final secrets = _ControlledSecrets();
    await secrets.write(password, 'stored-private-password');
    if (includeEncryption) {
      await secrets.write(encryption, 'stored-private-key');
    }
    final repository = SettingsRepository(
      SettingsLocalDataSource(preferences),
      secretStore: secrets,
    );
    try {
      await repository.migrateSecrets();
    } on CredentialMigrationConflict catch (conflict) {
      secrets.writes = 0;
      return (conflict: conflict, preferences: preferences, secrets: secrets);
    }
    throw StateError('Expected conflicting credentials');
  }

  Future<void> open(
    WidgetTester tester,
    CredentialMigrationConflict conflict, {
    required VoidCallback onReload,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: CredentialConflictScreen(conflict: conflict, onReload: onReload),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(
    WidgetTester tester,
    String key,
    CredentialSource source,
  ) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    final option = find.byKey(ValueKey('credential-$key-${source.name}'));
    await tester.scrollUntilVisible(option, 250);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioGroup<CredentialSource>>(
            find.ancestor(
              of: option,
              matching: find.byType(RadioGroup<CredentialSource>),
            ),
          )
          .groupValue,
      source,
    );
  }

  Future<void> review(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Review choices'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review choices'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'every credential needs a choice and review does not change storage',
    (tester) async {
      final fixture = await createConflict();
      var reloads = 0;
      await open(tester, fixture.conflict, onReload: () => reloads++);
      expect(
        tester
            .widgetList<RadioGroup<CredentialSource>>(
              find.byType(RadioGroup<CredentialSource>),
            )
            .every((group) => group.groupValue == null),
        isTrue,
      );
      await tester.scrollUntilVisible(find.text('Review choices'), 250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review choices'),
            )
            .onPressed,
        isNull,
      );
      await choose(tester, password, CredentialSource.secure);
      await tester.scrollUntilVisible(find.text('Review choices'), 250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review choices'),
            )
            .onPressed,
        isNull,
      );
      await choose(tester, encryption, CredentialSource.legacy);
      await review(tester);
      expect(find.textContaining('older queued messages'), findsOneWidget);
      expect(find.textContaining('stored-private-password'), findsNothing);
      expect(find.textContaining('restored-private-key'), findsNothing);
      expect(
        fixture.preferences.getString(password),
        'restored-private-password',
      );
      expect(fixture.preferences.getString(encryption), 'restored-private-key');
      expect(fixture.secrets.writes, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(reloads, 0);
      expect(
        fixture.preferences.getString(password),
        'restored-private-password',
      );
    },
  );

  testWidgets(
    'confirmation resolves the chosen sources before restarting bootstrap',
    (tester) async {
      final fixture = await createConflict();
      var reloads = 0;
      await open(
        tester,
        fixture.conflict,
        onReload: () {
          expect(fixture.secrets.read(password), 'stored-private-password');
          expect(fixture.secrets.read(encryption), 'restored-private-key');
          expect(fixture.preferences.getString(password), isNull);
          expect(fixture.preferences.getString(encryption), isNull);
          reloads++;
        },
      );
      await choose(tester, password, CredentialSource.secure);
      await choose(tester, encryption, CredentialSource.legacy);
      await review(tester);
      await tester.tap(find.text('Use chosen credentials'));
      await tester.pumpAndSettle();
      expect(reloads, 1);
    },
  );

  testWidgets(
    'resolution failure hides secrets and requires fresh settings before retry',
    (tester) async {
      final fixture = await createConflict(includeEncryption: false);
      fixture.secrets.failWrites = true;
      var reloads = 0;
      await open(tester, fixture.conflict, onReload: () => reloads++);
      await choose(tester, password, CredentialSource.legacy);
      await review(tester);
      await tester.tap(find.text('Use chosen credentials'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to update saved credentials'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Secret value must stay hidden'),
        findsNothing,
      );
      expect(
        fixture.preferences.getString(password),
        'restored-private-password',
      );
      expect(reloads, 0);
      await tester.scrollUntilVisible(find.text('Review choices'), 250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review choices'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.text('Reload saved settings'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reload saved settings'));
      await tester.pumpAndSettle();
      expect(reloads, 1);
    },
  );

  testWidgets('pending resolution disables duplicate submission', (
    tester,
  ) async {
    final fixture = await createConflict(includeEncryption: false);
    var reloads = 0;
    await open(tester, fixture.conflict, onReload: () => reloads++);
    await choose(tester, password, CredentialSource.legacy);
    await review(tester);
    final pending = Completer<void>();
    fixture.secrets.pending = pending;
    await tester.tap(find.text('Use chosen credentials'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Review choices'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Review choices'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Review choices'));
    await tester.pump();
    expect(fixture.secrets.writes, 1);
    expect(reloads, 0);
    pending.complete();
    await tester.pumpAndSettle();
    expect(reloads, 1);
    expect(fixture.secrets.writes, 1);
  });

  testWidgets('large text recovery and confirmation fit a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await createConflict(includeEncryption: false);
    await open(tester, fixture.conflict, onReload: () {}, textScale: 2);
    await choose(tester, password, CredentialSource.secure);
    await review(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Use chosen credentials'), findsOneWidget);
  });
}
