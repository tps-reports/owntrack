import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/config/map_tiler_config.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/map/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _scoped({required MapTilerConfig config}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      settingsLocalDataSourceProvider
          .overrideWithValue(SettingsLocalDataSource(prefs)),
      mapTilerConfigProvider.overrideWithValue(config),
    ],
    child: const MaterialApp(home: MapScreen()),
  );
}

void main() {
  group('Map tiles', () {
    testWidgets('serves tiles from MapTiler, not the OSM public servers',
        (tester) async {
      await tester.pumpWidget(
        await _scoped(config: const MapTilerConfig(apiKey: 'test-key')),
      );
      await tester.pump();

      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));

      expect(tileLayer.urlTemplate, contains('api.maptiler.com'));
      expect(tileLayer.urlTemplate, isNot(contains('tile.openstreetmap.org')));
    });

    testWidgets('attributes OpenStreetMap and MapTiler', (tester) async {
      await tester.pumpWidget(
        await _scoped(config: const MapTilerConfig(apiKey: 'test-key')),
      );
      await tester.pump();

      expect(find.textContaining('OpenStreetMap'), findsWidgets);
      expect(find.textContaining('MapTiler'), findsWidgets);
    });

    testWidgets('shows attribution without requiring interaction',
        (tester) async {
      await tester.pumpWidget(
        await _scoped(config: const MapTilerConfig(apiKey: 'test-key')),
      );
      await tester.pump();

      // hitTestable() fails for text collapsed inside a popup or covered by
      // another control — which is exactly how attribution silently stops
      // being attribution.
      expect(
        find.textContaining('OpenStreetMap').hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('MapTiler').hitTestable(), findsOneWidget);
    });

    testWidgets('explains itself instead of rendering a blank grid when the '
        'key is missing', (tester) async {
      await tester.pumpWidget(
        await _scoped(config: const MapTilerConfig(apiKey: '')),
      );
      await tester.pump();

      expect(find.textContaining('MAPS_API_KEY'), findsOneWidget);
      // No tile layer is built at all, so no keyless requests are issued.
      expect(find.byType(TileLayer), findsNothing);
    });

    testWidgets('hides waypoint creation when there is no map to place on',
        (tester) async {
      await tester.pumpWidget(
        await _scoped(config: const MapTilerConfig(apiKey: '')),
      );
      await tester.pump();

      // Map placement is meaningless without tiles, so the whole entry point
      // is withheld rather than offering a half-working chooser.
      expect(find.text('Add waypoint'), findsNothing);
    });
  });
}
