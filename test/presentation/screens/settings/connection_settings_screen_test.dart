import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/services/connection_probe.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/presentation/screens/settings/connection_settings_screen.dart';

import '../../../support/settings_harness.dart';

class MockProbe extends Mock implements ConnectionProbe {}

class FailingSecretStore extends SessionSecretStore {
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('Keychain locked');
}

void main() {
  testWidgets(
    'credential storage failure keeps settings open and offers retry',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        SettingsLocalDataSource(await SharedPreferences.getInstance()),
        secretStore: FailingSecretStore(),
      );
      await tester.pumpWidget(
        await settingsHarness(
          const ConnectionSettingsScreen(),
          settings: settings,
        ),
      );
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to save settings. Unlock your device and try again.'),
        findsOneWidget,
      );
      expect(find.text('Connection'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton).first).onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'connection test probes draft URL and reports success without saving',
    (tester) async {
      final probe = MockProbe();
      when(
        () => probe.testHttp('https://draft.example/pub'),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen(), probe: probe),
      );
      await tester.tap(find.text('HTTP'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://draft.example/pub',
      );
      await tester.ensureVisible(find.text('Test Connection'));
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      verify(() => probe.testHttp('https://draft.example/pub')).called(1);
      expect(find.text('Connection successful'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('http_url'),
        isNull,
      );
    },
  );
  testWidgets('connection test displays a recoverable failure', (tester) async {
    final probe = MockProbe();
    when(
      () => probe.testHttp(any()),
    ).thenThrow(StateError('Endpoint unavailable'));
    await tester.pumpWidget(
      await settingsHarness(const ConnectionSettingsScreen(), probe: probe),
    );
    await tester.tap(find.text('HTTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://draft.example/pub');
    await tester.ensureVisible(find.text('Test Connection'));
    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();
    expect(find.text('Endpoint unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Test Connection'),
          )
          .onPressed,
      isNotNull,
    );
  });
  group('ConnectionSettingsScreen', () {
    testWidgets('should display connection mode selector', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection Mode'), findsOneWidget);
      expect(find.text('MQTT'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
    });

    testWidgets('should display MQTT settings by default', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('MQTT Broker'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Use TLS/SSL'), findsOneWidget);
    });

    testWidgets('should switch to HTTP settings when HTTP is selected', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen()),
      );

      // Tap on HTTP button
      await tester.tap(find.text('HTTP'));
      await tester.pumpAndSettle();

      expect(find.text('HTTP Endpoint'), findsOneWidget);
      expect(find.text('URL'), findsOneWidget);
    });

    testWidgets('should have save button in app bar', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should have test connection button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const ConnectionSettingsScreen()),
      );
      await tester.pumpAndSettle();

      // Scroll to find the button
      await tester.scrollUntilVisible(
        find.text('Test Connection'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Connection'), findsOneWidget);
    });
  });
}
