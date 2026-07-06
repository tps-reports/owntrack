import 'dart:async';
import 'dart:convert';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Web-specific implementation of app launcher service
class AppLauncherServiceWeb {
  final SettingsRepository _settingsRepository;

  AppLauncherServiceWeb(this._settingsRepository);

  /// App Store URLs
  static const String _iosAppStoreUrl =
      'https://apps.apple.com/app/owntracks/id692424691';
  static const String _androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=org.owntracks.android';

  /// Deep link URL scheme
  static const String _deepLinkScheme = 'owntracks';

  /// Launch the mobile app with current settings
  Future<bool> launchAppWithSettings() async {
    try {
      // Encode settings into a deep link
      final deepLinkUrl = _buildDeepLinkUrl();
      AppLogger.i('Attempting to launch app with URL: $deepLinkUrl');

      // Try to launch the app
      final uri = Uri.parse(deepLinkUrl);

      // Attempt to launch the deep link
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        AppLogger.i('Deep link launch attempted');

        // Wait a short time to see if the app opens
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if the page is still visible (app didn't open)
        if (!web.document.hidden) {
          // Page is still visible, app probably didn't open
          AppLogger.w('App did not open, showing app store options');
          await _showAppStoreOptions();
        }

        return true;
      }

      // If we get here, the deep link couldn't be launched at all
      AppLogger.w('Could not launch deep link, showing app store options');
      await _showAppStoreOptions();
      return true;
    } catch (e) {
      AppLogger.e('Error launching app: $e');
      await _showAppStoreOptions();
      return false;
    }
  }

  /// Build a deep link URL with current settings encoded
  String _buildDeepLinkUrl() {
    final settings = _encodeSettings();
    final encodedSettings = base64Url.encode(utf8.encode(jsonEncode(settings)));
    return '$_deepLinkScheme://import?config=$encodedSettings';
  }

  /// Encode current settings into a map
  Map<String, dynamic> _encodeSettings() {
    return {
      'connectionMode': _settingsRepository.getConnectionMode(),
      'deviceId': _settingsRepository.getDeviceId(),
      'trackerId': _settingsRepository.getTrackerId(),
      'monitoringMode': _settingsRepository.getMonitoringMode(),
      'mqttHost': _settingsRepository.getMqttHost(),
      'mqttPort': _settingsRepository.getMqttPort(),
      'mqttUseTls': _settingsRepository.getMqttUseTls(),
      'mqttUsername': _settingsRepository.getMqttUsername(),
      'mqttPassword': _settingsRepository.getMqttPassword(),
      'mqttClientId': _settingsRepository.getMqttClientId(),
      'httpUrl': _settingsRepository.getHttpUrl(),
      'encryptionKey': _settingsRepository.getEncryptionKey(),
    };
  }

  /// Show app store options when the app is not installed
  Future<void> _showAppStoreOptions() async {
    final isIOS = _isIOSUserAgent();
    final storeUrl = isIOS ? _iosAppStoreUrl : _androidPlayStoreUrl;

    AppLogger.i('Redirecting to app store: $storeUrl (iOS: $isIOS)');

    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Detect if user is on iOS based on user agent
  bool _isIOSUserAgent() {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
  }

  /// Get a shareable deep link URL (without launching)
  String getShareableDeepLink() {
    return _buildDeepLinkUrl();
  }

  /// Get the appropriate app store URL based on user agent
  String getAppStoreUrl() {
    return _isIOSUserAgent() ? _iosAppStoreUrl : _androidPlayStoreUrl;
  }
}

/// Factory function for creating the web implementation
AppLauncherServiceWeb createImplementation(SettingsRepository repository) {
  return AppLauncherServiceWeb(repository);
}
