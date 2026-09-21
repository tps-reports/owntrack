import 'package:owntrack/data/services/permission_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/services/tracking_service.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/settings/tracking_settings_screen.dart';
import '../../../support/settings_harness.dart';

class MockTrackingService extends Mock implements TrackingService {}

void main() {
  testWidgets('selecting Manual while tracking reapplies the running source', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final permissions = MockPermissionService();
    when(
      permissions.checkLocationPermission,
    ).thenAnswer((_) async => AppPermissionStatus.denied);
    when(
      permissions.checkNotificationPermission,
    ).thenAnswer((_) async => AppPermissionStatus.denied);
    when(
      permissions.checkBackgroundLocationPermission,
    ).thenAnswer((_) async => false);
    final tracking = MockTrackingService();
    when(() => tracking.isTracking).thenReturn(true);
    when(() => tracking.reconfigure()).thenAnswer((_) async => true);
    final container = ProviderContainer(
      overrides: [
        settingsLocalDataSourceProvider.overrideWithValue(
          SettingsLocalDataSource(await SharedPreferences.getInstance()),
        ),
        permissionServiceProvider.overrideWithValue(permissions),
        trackingServiceProvider.overrideWithValue(tracking),
      ],
    );
    container.read(trackingEnabledProvider.notifier).setEnabled(true);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrackingSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    verify(() => tracking.reconfigure()).called(1);
    expect(
      container.read(settingsRepositoryProvider).getMonitoringMode(),
      AppConstants.monitoringModeManual,
    );
  });
}
