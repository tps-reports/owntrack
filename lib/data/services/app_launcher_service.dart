import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/app_launcher_service_stub.dart'
    if (dart.library.html) 'package:owntrack/data/services/app_launcher_service_web.dart';

/// Service for launching the mobile app from the web with settings
///
/// This service is designed to be used on the web platform to:
/// 1. Encode current settings into a deep link
/// 2. Attempt to launch the installed mobile app
/// 3. Fall back to app store if the app is not installed
class AppLauncherService {
  final SettingsRepository _settingsRepository;
  late final dynamic _implementation;

  AppLauncherService(this._settingsRepository) {
    _implementation = createImplementation(_settingsRepository);
  }

  /// Launch the mobile app with current settings
  ///
  /// On web platform:
  /// - Encodes current settings into a deep link
  /// - Attempts to open the mobile app
  /// - Falls back to app store if app is not installed
  ///
  /// Returns true if the launch was attempted
  Future<bool> launchAppWithSettings() {
    return _implementation.launchAppWithSettings();
  }

  /// Get a shareable deep link URL (without launching)
  ///
  /// This can be used to generate a link that users can share
  /// or save for later use
  String getShareableDeepLink() {
    return _implementation.getShareableDeepLink();
  }

  /// Get the appropriate app store URL based on user agent
  String getAppStoreUrl() {
    return _implementation.getAppStoreUrl();
  }
}
