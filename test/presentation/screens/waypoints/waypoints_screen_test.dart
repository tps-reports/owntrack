import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/waypoints/waypoints_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the waypoints screen with [seeded] waypoints already persisted.
Future<void> _pump(WidgetTester tester,
    {required List<Map<String, Object>> seeded}) async {
  SharedPreferences.setMockInitialValues({
    'waypoints_storage': json.encode(seeded),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsLocalDataSourceProvider
            .overrideWithValue(SettingsLocalDataSource(prefs)),
      ],
      child: const MaterialApp(home: WaypointsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

const _home = {
  'id': 'wp-1',
  'lat': 40.2141,
  'lon': -111.6711,
  'timestamp': 1704110400,
  'description': 'Home',
  'radius': 100.0,
};

void main() {
  group('WaypointsScreen delete', () {
    testWidgets('removes the row from the list after confirming delete',
        (tester) async {
      await _pump(tester, seeded: [_home]);
      expect(find.text('Home'), findsOneWidget);

      // Row menu -> Delete -> confirm.
      await tester.tap(find.byIcon(Icons.adaptive.more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Waypoint deleted'), findsOneWidget);
      // The row must actually leave the list, not linger in a stale cache.
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('shows the empty state after the last waypoint is deleted',
        (tester) async {
      await _pump(tester, seeded: [_home]);

      await tester.tap(find.byIcon(Icons.adaptive.more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No Waypoints'), findsOneWidget);
    });
  });

  group('WaypointsScreen edit', () {
    testWidgets('shows the updated description after an edit', (tester) async {
      await _pump(tester, seeded: [_home]);

      await tester.tap(find.byIcon(Icons.adaptive.more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // First field in the edit dialog is the description.
      await tester.enterText(find.byType(TextField).first, 'Office');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });
  });
}
