import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// Stub implementation for non-web platforms
class AppLauncherServiceStub {
  // ignore: unused_field
  final SettingsRepository _settingsRepository;

  AppLauncherServiceStub(this._settingsRepository);

  Future<bool> launchAppWithSettings() async {
    AppLogger.w('AppLauncherService is only available on web platform');
    return false;
  }

  String getShareableDeepLink() {
    return '';
  }

  String getAppStoreUrl() {
    return '';
  }
}

/// Factory function for creating the platform-specific implementation
AppLauncherServiceStub createImplementation(SettingsRepository repository) {
  return AppLauncherServiceStub(repository);
}
