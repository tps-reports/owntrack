import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Platform detection utilities
///
/// Provides cross-platform detection for handling platform-specific code.
class PlatformUtils {
  PlatformUtils._();

  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on mobile (Android or iOS)
  static bool get isMobile => !kIsWeb && (isAndroid || isIOS);

  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if running on desktop (Windows, macOS, Linux)
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if background location tracking is supported
  ///
  /// Web browsers do not support background location tracking
  static bool get supportsBackgroundLocation => isMobile;

  /// Check if local notifications are supported
  ///
  /// Web has limited notification support
  static bool get supportsNotifications => isMobile;

  /// Check if the platform supports geofencing
  ///
  /// All platforms support geofencing:
  /// - Mobile: Works in foreground and background (with native APIs)
  /// - Web: Foreground-only geofencing (manual distance-based checking)
  static bool get supportsGeofencing => true;

  /// Check if battery status can be retrieved
  ///
  /// All platforms support battery status:
  /// - Mobile: Full battery status (TODO: integrate battery_plus)
  /// - Web: Battery Status API with feature detection (fallback to defaults)
  static bool get supportsBatteryStatus => true;

  /// Get platform name for logging
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
