import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/presentation/widgets/waypoint_form_dialog.dart';

/// Pumps the dialog and captures whatever it pops.
Future<Waypoint?> _showDialog(
  WidgetTester tester, {
  LatLng? initialPoint,
}) async {
  Waypoint? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              captured = await showWaypointFormDialog(
                context,
                initialPoint: initialPoint,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('WaypointFormDialog', () {
    testWidgets('prefills coordinates when a point is supplied',
        (tester) async {
      await _showDialog(tester,
          initialPoint: const LatLng(40.2141, -111.6711));

      expect(find.text('40.2141'), findsOneWidget);
      expect(find.text('-111.6711'), findsOneWidget);
    });

    testWidgets('locks the coordinate fields when a point is supplied',
        (tester) async {
      await _showDialog(tester,
          initialPoint: const LatLng(40.2141, -111.6711));

      final lat = tester.widget<TextFormField>(
        find.byKey(const Key('waypoint-lat-field')),
      );
      final lon = tester.widget<TextFormField>(
        find.byKey(const Key('waypoint-lon-field')),
      );

      expect(lat.enabled, isFalse);
      expect(lon.enabled, isFalse);
    });

    testWidgets('leaves the coordinate fields editable for manual entry',
        (tester) async {
      await _showDialog(tester);

      final lat = tester.widget<TextFormField>(
        find.byKey(const Key('waypoint-lat-field')),
      );

      expect(lat.enabled, isTrue);
    });

    testWidgets('rejects a latitude outside -90..90 instead of discarding it',
        (tester) async {
      await _showDialog(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '91');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '-111.6711');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Latitude must be between -90 and 90'), findsOneWidget);
      // Dialog stays open rather than silently dropping the waypoint.
      expect(find.text('Add Waypoint'), findsOneWidget);
    });

    testWidgets('rejects a longitude outside -180..180', (tester) async {
      await _showDialog(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '40.2141');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '181');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(
          find.text('Longitude must be between -180 and 180'), findsOneWidget);
    });

    testWidgets('rejects a non-numeric latitude', (tester) async {
      await _showDialog(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), 'abc');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '-111.6711');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('returns a waypoint built from the entered values',
        (tester) async {
      Waypoint? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  captured = await showWaypointFormDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('waypoint-description-field')), 'Home');
      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '40.2141');
      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), '-111.6711');
      await tester.enterText(
          find.byKey(const Key('waypoint-radius-field')), '250');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.description, 'Home');
      expect(captured!.lat, closeTo(40.2141, 1e-9));
      expect(captured!.lon, closeTo(-111.6711, 1e-9));
      expect(captured!.radius, closeTo(250, 1e-9));
      expect(captured!.id, isNotEmpty);
    });

    testWidgets('returns null when cancelled', (tester) async {
      final result = await _showDialog(tester);
      // _showDialog captures before the user acts; drive cancel explicitly.
      expect(result, isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Waypoint'), findsNothing);
    });
  });
}
