import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';
import 'package:owntrack/presentation/screens/settings/settings_screen.dart';
import '../../../support/settings_harness.dart';

void main() {
  testWidgets('direct settings screen opens connection settings', (tester) async {
    await tester.pumpWidget(await settingsHarness(const SettingsScreen()));
    await tester.tap(find.text('Connection'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionSettingsScreen), findsOneWidget);
  });
}
