import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/map/map_screen.dart';
import 'package:owntrack/presentation/screens/waypoints/waypoints_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderScope> _scoped(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      settingsLocalDataSourceProvider
          .overrideWithValue(SettingsLocalDataSource(prefs)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('Map screen add-waypoint entry point', () {
    testWidgets('shows an Add waypoint action chip on the map',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      expect(find.text('Add waypoint'), findsOneWidget);
    });

    testWidgets('offers manual entry and map selection when tapped',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(find.text('Add waypoint'));
      await tester.pumpAndSettle();

      expect(find.text('Enter coordinates'), findsOneWidget);
      expect(find.text('Pick on map'), findsOneWidget);
    });

    testWidgets('opens the coordinate form when manual entry is chosen',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(find.text('Add waypoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter coordinates'));
      await tester.pumpAndSettle();

      expect(find.text('Add Waypoint'), findsOneWidget);
      expect(find.byKey(const Key('waypoint-lat-field')), findsOneWidget);
    });

    testWidgets('enters placement mode when map selection is chosen',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(find.text('Add waypoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick on map'));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place the waypoint'), findsOneWidget);
      // The chip is replaced by the placement hint while placing.
      expect(find.text('Add waypoint'), findsNothing);
    });

    testWidgets('leaves placement mode when cancelled', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(find.text('Add waypoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick on map'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('waypoint-placement-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place the waypoint'), findsNothing);
      expect(find.text('Add waypoint'), findsOneWidget);
    });
  });

  group('Waypoints screen', () {
    testWidgets('no longer offers its own add button', (tester) async {
      await tester.pumpWidget(await _scoped(const WaypointsScreen()));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Add Waypoint'), findsNothing);
    });
  });
}
