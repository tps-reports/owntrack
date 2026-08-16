// This is a basic Flutter widget test.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/app.dart';

void main() {
  testWidgets('App widget smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // Verify that the app loads
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that the map screen is shown (it's the initial route)
    await tester.pumpAndSettle();
    expect(find.text('OwnTracks'), findsOneWidget);
  });

  testWidgets('Navigation bar has correct items', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify navigation items
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Waypoints'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
