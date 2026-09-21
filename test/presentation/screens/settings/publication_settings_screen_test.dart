import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/presentation/screens/settings/publication_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/settings_harness.dart';

void main() {
  testWidgets('saving publication fields persists the actual policy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      await settingsHarness(
        const PublicationSettingsScreen(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('publication-interval')), '60');
    await tester.enterText(
      find.byKey(const Key('publication-distance')),
      '125',
    );
    await tester.enterText(
      find.byKey(const Key('publication-heartbeat')),
      '600',
    );
    await tester.enterText(find.byKey(const Key('publication-heading')), '45');
    await tester.ensureVisible(find.text('Save publication settings'));
    await tester.tap(find.text('Save publication settings'));
    await tester.pumpAndSettle();
    final policy = settings.getPublicationPolicy();
    expect(policy.minimumInterval.inSeconds, 60);
    expect(policy.minimumDistanceMeters, 125);
    expect(policy.heartbeatInterval.inSeconds, 600);
    expect(policy.minimumHeadingChangeDegrees, 45);
    expect(find.text('Publication settings saved'), findsOneWidget);
  });

  testWidgets('invalid heartbeat cannot replace the saved policy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    await tester.pumpWidget(
      await settingsHarness(
        const PublicationSettingsScreen(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('publication-interval')),
      '600',
    );
    await tester.enterText(
      find.byKey(const Key('publication-heartbeat')),
      '30',
    );
    await tester.ensureVisible(find.text('Save publication settings'));
    await tester.tap(find.text('Save publication settings'));
    await tester.pumpAndSettle();
    expect(settings.getPublicationPolicy().minimumInterval.inSeconds, 30);
    expect(
      find.text('Heartbeat must be at least the minimum interval'),
      findsOneWidget,
    );
  });
}
