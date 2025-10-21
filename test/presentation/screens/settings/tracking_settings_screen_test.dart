import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';

void main() {
  group('TrackingSettingsScreen', () {
    testWidgets('should display tracking status', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingSettingsScreen(),
        ),
      );

      expect(find.text('Tracking Stopped'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should display all monitoring modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingSettingsScreen(),
        ),
      );

      expect(find.text('Quiet'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Significant'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
    });

    testWidgets('should display monitoring mode card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingSettingsScreen(),
        ),
      );

      expect(find.text('Monitoring Mode'), findsOneWidget);
    });

    testWidgets('should display permissions card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingSettingsScreen(),
        ),
      );

      expect(find.text('Location Permission'), findsOneWidget);
      expect(find.text('Notification Permission'), findsOneWidget);
      expect(find.text('Battery Optimization'), findsOneWidget);
    });

    testWidgets('should have radio buttons for monitoring modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingSettingsScreen(),
        ),
      );

      expect(find.byType(RadioListTile<int>), findsNWidgets(4));
    });
  });
}
