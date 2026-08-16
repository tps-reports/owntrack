import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';

void main() {
  group('ConnectionSettingsScreen', () {
    testWidgets('should display connection mode selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionSettingsScreen(),
        ),
      );

      expect(find.text('Connection Mode'), findsOneWidget);
      expect(find.text('MQTT'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
    });

    testWidgets('should display MQTT settings by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionSettingsScreen(),
        ),
      );

      expect(find.text('MQTT Broker'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Use TLS/SSL'), findsOneWidget);
    });

    testWidgets('should switch to HTTP settings when HTTP is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionSettingsScreen(),
        ),
      );

      // Tap on HTTP button
      await tester.tap(find.text('HTTP'));
      await tester.pumpAndSettle();

      expect(find.text('HTTP Endpoint'), findsOneWidget);
      expect(find.text('URL'), findsOneWidget);
    });

    testWidgets('should have save button in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionSettingsScreen(),
        ),
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should have test connection button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectionSettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.scrollUntilVisible(
        find.text('Test Connection'),
        100,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Test Connection'), findsOneWidget);
    });
  });
}
