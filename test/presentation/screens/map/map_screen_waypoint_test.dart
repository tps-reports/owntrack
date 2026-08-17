import 'package:flutter_map/flutter_map.dart';
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
  group('Map screen add-waypoint flow', () {
    testWidgets('shows an Add waypoint FAB alongside the publish FAB',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      expect(_addWaypointFab, findsOneWidget);
      expect(find.byTooltip('Publish location'), findsOneWidget);
    });

    testWidgets('opens the form directly — no chooser sheet', (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      // Straight to the form.
      expect(find.byKey(const Key('waypoint-lat-field')), findsOneWidget);
      expect(find.byKey(const Key('waypoint-description-field')),
          findsOneWidget);
      // The old intermediaries are gone.
      expect(find.text('Enter coordinates'), findsNothing);
      expect(find.text('Pick on map'), findsNothing);
      expect(find.text('Manage waypoints'), findsNothing);
      expect(find.text('Tap the map to place the waypoint'), findsNothing);
    });

    testWidgets('a map tap fills the coordinate fields while the form is open',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      // Tap the visible map above the form panel. The map is centred on San
      // Francisco (37.7749, -122.4194), so a tap near the centre must land in
      // that neighbourhood.
      final mapRect = tester.getRect(find.byType(FlutterMap));
      await tester.tapAt(mapRect.center.translate(0, -150));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final lat = tester
          .widget<TextFormField>(find.byKey(const Key('waypoint-lat-field')))
          .controller!
          .text;
      final lon = tester
          .widget<TextFormField>(find.byKey(const Key('waypoint-lon-field')))
          .controller!
          .text;
      expect(double.tryParse(lat), isNotNull);
      expect(double.parse(lat), closeTo(37.77, 0.3));
      expect(double.parse(lon), closeTo(-122.42, 0.3));
    });

    testWidgets('a second map tap replaces the previous coordinates',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      final mapRect = tester.getRect(find.byType(FlutterMap));
      await tester.tapAt(mapRect.center.translate(0, -150));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final firstLat = tester
          .widget<TextFormField>(find.byKey(const Key('waypoint-lat-field')))
          .controller!
          .text;

      await tester.tapAt(mapRect.center.translate(60, -190));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final secondLat = tester
          .widget<TextFormField>(find.byKey(const Key('waypoint-lat-field')))
          .controller!
          .text;

      expect(secondLat, isNot(equals(firstLat)));
    });

    testWidgets('Save persists the waypoint and closes the form',
        (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(await _scoped(Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const MapScreen();
        },
      )));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('waypoint-description-field')), 'Trailhead');
      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '40.2141');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '-111.6711');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Waypoint added'), findsOneWidget);
      expect(find.byKey(const Key('waypoint-lat-field')), findsNothing);

      final saved =
          capturedRef.read(waypointsRepositoryProvider).getAllWaypoints();
      expect(saved, hasLength(1));
      expect(saved.single.description, 'Trailhead');
      expect(saved.single.lat, closeTo(40.2141, 1e-9));
    });

    testWidgets('invalid coordinates block Save with an inline message',
        (tester) async {
      await tester.pumpWidget(await _scoped(const MapScreen()));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '91');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '-111.6711');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Latitude must be between -90 and 90'), findsOneWidget);
      // Form stays open; nothing saved.
      expect(find.byKey(const Key('waypoint-lat-field')), findsOneWidget);
    });

    testWidgets('Cancel closes the form without saving', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(await _scoped(Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const MapScreen();
        },
      )));
      await tester.pump();

      await tester.tap(_addWaypointFab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('waypoint-lat-field')), findsNothing);
      expect(_addWaypointFab, findsOneWidget);
      expect(
        capturedRef.read(waypointsRepositoryProvider).getAllWaypoints(),
        isEmpty,
      );
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
