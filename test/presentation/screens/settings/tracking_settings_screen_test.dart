import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/services/permission_service.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/settings_harness.dart';

void main() {
  Future<MockPermissionService> openPermissionScreen(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final permissions = MockPermissionService();
    when(
      permissions.checkLocationPermission,
    ).thenAnswer((_) async => AppPermissionStatus.granted);
    when(
      permissions.checkNotificationPermission,
    ).thenAnswer((_) async => AppPermissionStatus.granted);
    when(
      permissions.checkBackgroundLocationPermission,
    ).thenAnswer((_) async => false);
    when(permissions.openAppSettings).thenAnswer((_) async => true);
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(
            SettingsLocalDataSource(await SharedPreferences.getInstance()),
          ),
          permissionServiceProvider.overrideWithValue(permissions),
        ],
        child: const MaterialApp(home: TrackingSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return permissions;
  }

  testWidgets(
    'denied Always upgrade offers real Settings recovery and refreshes on return',
    (tester) async {
      final permissions = await openPermissionScreen(tester);
      var requests = 0;
      when(permissions.requestBackgroundLocationPermission).thenAnswer(
        (_) async => ++requests == 1
            ? AppPermissionStatus.denied
            : AppPermissionStatus.permanentlyDenied,
      );
      await tester.tap(find.text('Background Location'));
      await tester.pumpAndSettle();
      expect(
        find.text('Background location permission denied'),
        findsOneWidget,
      );
      await tester.tap(find.text('Background Location'));
      await tester.pumpAndSettle();
      expect(
        find.text('Background Location Permission Required'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      verify(permissions.openAppSettings).called(1);
      expect(requests, 2);
      when(
        permissions.checkBackgroundLocationPermission,
      ).thenAnswer((_) async => true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Granted - can track in background'), findsOneWidget);
    },
  );

  for (final throwsError in [false, true]) {
    testWidgets(
      'opening Settings ${throwsError ? 'exception' : 'failure'} is visible and retryable',
      (tester) async {
        final permissions = await openPermissionScreen(tester);
        when(
          permissions.requestBackgroundLocationPermission,
        ).thenAnswer((_) async => AppPermissionStatus.permanentlyDenied);
        if (throwsError) {
          when(
            permissions.openAppSettings,
          ).thenThrow(StateError('OS rejected the request'));
        } else {
          when(permissions.openAppSettings).thenAnswer((_) async => false);
        }
        await tester.tap(find.text('Background Location'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Unable to open app settings. Open Settings on your device and select OwnTracks.',
          ),
          findsOneWidget,
        );
        verify(permissions.openAppSettings).called(1);
        when(permissions.openAppSettings).thenAnswer((_) async => true);
        await tester.tap(find.text('Background Location'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();
        verify(permissions.openAppSettings).called(1);
        verify(permissions.requestBackgroundLocationPermission).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('TrackingSettingsScreen', () {
    testWidgets('should display tracking status', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const TrackingSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracking Stopped'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should display all monitoring modes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const TrackingSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quiet'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Significant'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
    });

    testWidgets('should display monitoring mode card', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const TrackingSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monitoring Mode'), findsOneWidget);
    });

    testWidgets('should display permissions card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const TrackingSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Permission'), findsOneWidget);
      expect(find.text('Notification Permission'), findsOneWidget);
      expect(find.text('Background Location'), findsOneWidget);
    });

    testWidgets('should have radio buttons for monitoring modes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        await settingsHarness(const TrackingSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RadioListTile<int>), findsNWidgets(4));
    });
  });
}
