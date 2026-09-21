import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/presentation/screens/settings/identification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/settings_harness.dart';

class _ControlledDataSource extends SettingsLocalDataSource {
  _ControlledDataSource(super.preferences);

  String? failingKey;
  Completer<void>? pendingWrite;
  final List<String> writes = [];

  @override
  Future<bool> setString(String key, String value) async {
    writes.add(key);
    if (key == failingKey) throw StateError('Private device ID: $value');
    await pendingWrite?.future;
    return super.setString(key, value);
  }
}

void main() {
  Future<({SettingsRepository settings, _ControlledDataSource source})>
  initialize() async {
    SharedPreferences.setMockInitialValues({});
    final source = _ControlledDataSource(await SharedPreferences.getInstance());
    return (settings: SettingsRepository(source), source: source);
  }

  Future<void> open(WidgetTester tester, SettingsRepository settings) async {
    await tester.pumpWidget(
      await settingsHarness(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const IdentificationSettingsScreen(),
                ),
              ),
              child: const Text('Open identification'),
            ),
          ),
        ),
        settings: settings,
      ),
    );
    await tester.tap(find.text('Open identification'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'private-device');
    await tester.enterText(find.byType(TextField).last, 'P1');
  }

  testWidgets('device ID write failure stays open and succeeds on retry', (
    tester,
  ) async {
    final dependencies = await initialize();
    dependencies.source.failingKey = AppConstants.prefKeyDeviceId;
    await open(tester, dependencies.settings);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(IdentificationSettingsScreen), findsOneWidget);
    expect(
      find.text('Unable to save identification settings. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Private device ID:'), findsNothing);
    expect(dependencies.source.writes, [AppConstants.prefKeyDeviceId]);
    dependencies.source.failingKey = null;
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(IdentificationSettingsScreen), findsNothing);
    expect(
      find.text('Unable to save identification settings. Try again.'),
      findsNothing,
    );
    expect(dependencies.settings.getDeviceId(), 'private-device');
    expect(dependencies.settings.getTrackerId(), 'P1');
  });

  testWidgets('tracker ID write failure does not claim save success or exit', (
    tester,
  ) async {
    final dependencies = await initialize();
    dependencies.source.failingKey = AppConstants.prefKeyTrackerId;
    await open(tester, dependencies.settings);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(IdentificationSettingsScreen), findsOneWidget);
    expect(find.text('Settings saved'), findsNothing);
    expect(
      find.text('Unable to save identification settings. Try again.'),
      findsOneWidget,
    );
    expect(dependencies.settings.getDeviceId(), 'private-device');
    expect(dependencies.settings.getTrackerId(), isEmpty);
    dependencies.source.failingKey = null;
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(dependencies.settings.getTrackerId(), 'P1');
    expect(find.byType(IdentificationSettingsScreen), findsNothing);
  });

  testWidgets('pending save blocks duplicate writes and back navigation', (
    tester,
  ) async {
    final dependencies = await initialize();
    final pending = Completer<void>();
    dependencies.source.pendingWrite = pending;
    await open(tester, dependencies.settings);
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    expect(dependencies.source.writes, [AppConstants.prefKeyDeviceId]);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.enabled == false),
      isTrue,
    );
    final context = tester.element(find.byType(IdentificationSettingsScreen));
    await Navigator.of(context).maybePop();
    await tester.pump();
    expect(find.byType(IdentificationSettingsScreen), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(dependencies.source.writes, [
      AppConstants.prefKeyDeviceId,
      AppConstants.prefKeyTrackerId,
    ]);
    expect(find.byType(IdentificationSettingsScreen), findsNothing);
  });
}
