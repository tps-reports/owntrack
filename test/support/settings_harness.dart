import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/services/permission_service.dart';
import 'package:owntrack/data/services/connection_probe.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPermissionService extends Mock implements PermissionService {}

Future<Widget> settingsHarness(
  Widget screen, {
  ConnectionProbe? probe,
  SettingsRepository? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
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
  return ProviderScope(
    overrides: [
      settingsLocalDataSourceProvider.overrideWithValue(
        SettingsLocalDataSource(prefs),
      ),
      permissionServiceProvider.overrideWithValue(permissions),
      if (settings != null)
        settingsRepositoryProvider.overrideWithValue(settings),
      if (probe != null) connectionProbeProvider.overrideWithValue(probe),
    ],
    child: MaterialApp(home: screen),
  );
}
