import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/presentation/widgets/waypoint_form_dialog.dart';

const _original = Waypoint(
  id: 'wp-1',
  lat: 40.2141,
  lon: -111.6711,
  timestamp: 1704110400,
  description: 'Home',
  radius: 150,
);

/// Opens the edit dialog for [_original] and captures whatever it pops.
Future<Waypoint? Function()> _open(WidgetTester tester) async {
  Waypoint? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              captured = await showWaypointFormDialog(
                context,
                initialWaypoint: _original,
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
  return () => captured;
}

void main() {
  group('WaypointFormDialog (edit)', () {
    testWidgets('prefills every field from the waypoint', (tester) async {
      await _open(tester);

      expect(find.text('Edit Waypoint'), findsOneWidget);
      // 'Home' also happens to be the description field's example hint, so
      // assert on the editable value rather than raw text.
      final desc = tester.widget<TextFormField>(
        find.byKey(const Key('waypoint-description-field')),
      );
      expect(desc.controller?.text, 'Home');
      expect(find.text('40.2141'), findsOneWidget);
      expect(find.text('-111.6711'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('saves edits onto the original, preserving identity',
        (tester) async {
      final result = await _open(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-description-field')), 'Office');
      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '40.25');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = result();
      expect(captured, isNotNull);
      expect(captured!.description, 'Office');
      expect(captured.lat, closeTo(40.25, 1e-9));
      // Identity and history survive the edit.
      expect(captured.id, 'wp-1');
      expect(captured.timestamp, 1704110400);
    });

    testWidgets('rejects an out-of-range latitude instead of discarding the '
        'edit', (tester) async {
      await _open(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-lat-field')), '91');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Latitude must be between -90 and 90'), findsOneWidget);
      // Dialog stays open rather than silently dropping the edit.
      expect(find.text('Edit Waypoint'), findsOneWidget);
    });

    testWidgets('rejects a non-numeric longitude', (tester) async {
      await _open(tester);

      await tester.enterText(
          find.byKey(const Key('waypoint-lon-field')), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('returns null when cancelled', (tester) async {
      final result = await _open(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result(), isNull);
      expect(find.text('Edit Waypoint'), findsNothing);
    });
  });
}
