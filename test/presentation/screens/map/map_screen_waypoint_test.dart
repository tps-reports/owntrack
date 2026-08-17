import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/config/map_tiler_config.dart';
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
      // Tests run without a --dart-define, so supply a key explicitly;
      // otherwise the map renders its "tiles not configured" placeholder.
      mapTilerConfigProvider
          .overrideWithValue(const MapTilerConfig(apiKey: 'test-key')),
    ],
    child: MaterialApp(home: child),
  );
}

final _addWaypointFab = find.byTooltip('Add waypoint');

void main() {
  group('Map screen add-waypoint entry point', () {
    testWidgets('shows an Add waypoint FAB alongside the publish FAB',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      expect(_addWaypointFab, findsOneWidget);
      expect(find.byTooltip('Publish location'), findsOneWidget);
      expect(
        find.ancestor(
          of: _addWaypointFab,
          matching: find.byType(FloatingActionButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('places both FABs in the lower-right quadrant',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      final screen = tester.getSize(find.byType(MaterialApp));
      for (final finder in [
        _addWaypointFab,
        find.byTooltip('Publish location'),
      ]) {
        final center = tester.getCenter(finder);
        expect(center.dx, greaterThan(screen.width / 2),
            reason: 'FAB should sit right of centre');
        expect(center.dy, greaterThan(screen.height / 2),
            reason: 'FAB should sit below centre');
      }
    });

    testWidgets('offers manual entry, map selection and management when tapped',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      expect(find.text('Enter coordinates'), findsOneWidget);
      expect(find.text('Pick on map'), findsOneWidget);
      expect(find.text('Manage waypoints'), findsOneWidget);
    });

    testWidgets('opens the waypoint list from the sheet', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage waypoints'));
      await tester.pumpAndSettle();

      expect(find.byType(WaypointsScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('opens the coordinate form when manual entry is chosen',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
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

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick on map'));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place the waypoint'), findsOneWidget);
      // The add FAB is withheld while placing; the hint bar drives the flow.
      expect(_addWaypointFab, findsNothing);
    });

    testWidgets('leaves placement mode when cancelled', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick on map'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('waypoint-placement-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Tap the map to place the waypoint'), findsNothing);
      expect(_addWaypointFab, findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('bottom bar has no Waypoints tab', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Waypoints'),
        ),
        findsNothing,
      );
    });

    testWidgets('waypoints are managed from the Settings tab', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waypoints'), findsOneWidget);

      await tester.tap(find.text('Waypoints'));
      await tester.pumpAndSettle();

      expect(find.byType(WaypointsScreen), findsOneWidget);
      // Pushed as a route, so it must carry its own back affordance.
      expect(find.byType(BackButton), findsOneWidget);
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
