import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/core/utils/platform_utils.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission status for the app
enum AppPermissionStatus { granted, denied, permanentlyDenied, restricted }

/// Permission service for managing app permissions
///
/// Handles location, notification, and background permissions
/// with proper error handling and user feedback.
///
/// **Web Platform Notes:**
/// - Uses browser's permission API via geolocator
/// - Background location not supported (browser security)
/// - Notification permission handled via browser's Notification API
/// - No app settings to open (returns false on web)
class PermissionService {
  bool get _supportsBackgroundLocation =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Check location permission status
  Future<AppPermissionStatus> checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return AppPermissionStatus.granted;
        case LocationPermission.denied:
          return AppPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return AppPermissionStatus.permanentlyDenied;
        case LocationPermission.unableToDetermine:
          return AppPermissionStatus.restricted;
      }
    } catch (e) {
      AppLogger.e('Error checking location permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Request location permission
  Future<AppPermissionStatus> requestLocationPermission() async {
    try {
      AppLogger.i('Requesting location permission');
      final permission = await Geolocator.requestPermission();

      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          AppLogger.i('Location permission granted');
          return AppPermissionStatus.granted;
        case LocationPermission.denied:
          AppLogger.w('Location permission denied');
          return AppPermissionStatus.denied;
        case LocationPermission.deniedForever:
          AppLogger.w('Location permission permanently denied');
          return AppPermissionStatus.permanentlyDenied;
        case LocationPermission.unableToDetermine:
          AppLogger.w('Location permission unable to determine');
          return AppPermissionStatus.restricted;
      }
    } catch (e) {
      AppLogger.e('Error requesting location permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Check if background location is enabled (Android 10+, iOS always)
  Future<bool> checkBackgroundLocationPermission() async {
    try {
      // Only mobile platforms support background location. Web browsers
      // block it outright, and desktop has no permission_handler backend.
      if (!_supportsBackgroundLocation) {
        return false;
      }

      // Android gates background location behind a separate
      // ACCESS_BACKGROUND_LOCATION grant.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await ph.Permission.locationAlways.status;
        return status.isGranted;
      }

      // Foreground authorization also maps to AppPermissionStatus.granted, so
      // background access must inspect Core Location's uncollapsed result.
      return await Geolocator.checkPermission() == LocationPermission.always;
    } catch (e) {
      AppLogger.e('Error checking background location permission: $e');
      return false;
    }
  }

  /// Request background location permission
  Future<AppPermissionStatus> requestBackgroundLocationPermission() async {
    try {
      AppLogger.i('Requesting background location permission');

      // Only mobile platforms support background location.
      if (!_supportsBackgroundLocation) {
        AppLogger.w(
          'Background location not supported on ${PlatformUtils.platformName}',
        );
        return AppPermissionStatus.denied;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await ph.Permission.locationAlways.request();

        if (status.isGranted) {
          AppLogger.i('Background location permission granted');
          return AppPermissionStatus.granted;
        } else if (status.isPermanentlyDenied) {
          AppLogger.w('Background location permission permanently denied');
          return AppPermissionStatus.permanentlyDenied;
        } else {
          AppLogger.w('Background location permission denied');
          return AppPermissionStatus.denied;
        }
      }

      var locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
      switch (locationPermission) {
        case LocationPermission.always:
          return AppPermissionStatus.granted;
        case LocationPermission.denied:
          return AppPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return AppPermissionStatus.permanentlyDenied;
        case LocationPermission.unableToDetermine:
          return AppPermissionStatus.restricted;
        case LocationPermission.whileInUse:
          break;
      }

      // geolocator_apple returns an existing when-in-use authorization without
      // upgrading it. permission_handler issues requestAlwaysAuthorization once
      // foreground access exists; a completed request alone is not proof of it.
      final status = await ph.Permission.locationAlways.request();
      final actual = await Geolocator.checkPermission();
      if (actual == LocationPermission.always) {
        return AppPermissionStatus.granted;
      }
      if (actual == LocationPermission.deniedForever ||
          status.isPermanentlyDenied) {
        return AppPermissionStatus.permanentlyDenied;
      }
      if (actual == LocationPermission.unableToDetermine ||
          status.isRestricted) {
        return AppPermissionStatus.restricted;
      }
      return AppPermissionStatus.denied;
    } catch (e) {
      AppLogger.e('Error requesting background location permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Check notification permission status
  Future<AppPermissionStatus> checkNotificationPermission() async {
    try {
      // permission_handler only ships a notification backend on Android/iOS.
      // Web delegates to the browser's Notification API; desktop has no
      // backend at all, so calling through would throw MissingPluginException.
      if (!PlatformUtils.supportsNotifications) {
        return AppPermissionStatus.granted;
      }

      final status = await ph.Permission.notification.status;

      if (status.isGranted) {
        return AppPermissionStatus.granted;
      } else if (status.isPermanentlyDenied) {
        return AppPermissionStatus.permanentlyDenied;
      } else if (status.isRestricted) {
        return AppPermissionStatus.restricted;
      } else {
        return AppPermissionStatus.denied;
      }
    } catch (e) {
      AppLogger.e('Error checking notification permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Request notification permission
  Future<AppPermissionStatus> requestNotificationPermission() async {
    try {
      AppLogger.i('Requesting notification permission');

      // Web delegates to the browser's Notification API; desktop has no
      // permission_handler backend.
      if (!PlatformUtils.supportsNotifications) {
        AppLogger.i(
          'Notification permission handled by platform on '
          '${PlatformUtils.platformName}',
        );
        return AppPermissionStatus.granted;
      }

      final status = await ph.Permission.notification.request();

      if (status.isGranted) {
        AppLogger.i('Notification permission granted');
        return AppPermissionStatus.granted;
      } else if (status.isPermanentlyDenied) {
        AppLogger.w('Notification permission permanently denied');
        return AppPermissionStatus.permanentlyDenied;
      } else {
        AppLogger.w('Notification permission denied');
        return AppPermissionStatus.denied;
      }
    } catch (e) {
      AppLogger.e('Error requesting notification permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      AppLogger.e('Error checking location service: $e');
      return false;
    }
  }

  /// Open app settings (for when permission is permanently denied)
  Future<bool> openAppSettings() async {
    try {
      // ph.openAppSettings() is only implemented on Android/iOS.
      if (!PlatformUtils.isMobile) {
        AppLogger.w(
          'Cannot open app settings on ${PlatformUtils.platformName}',
        );
        return false;
      }

      AppLogger.i('Opening app settings');
      return await ph.openAppSettings();
    } catch (e) {
      AppLogger.e('Error opening app settings: $e');
      return false;
    }
  }

  /// Request all required permissions
  Future<Map<String, AppPermissionStatus>> requestAllPermissions() async {
    AppLogger.i('Requesting all required permissions');

    final results = <String, AppPermissionStatus>{};

    // Request location permission
    results['location'] = await requestLocationPermission();

    // Request background location if foreground was granted
    if (results['location'] == AppPermissionStatus.granted) {
      results['backgroundLocation'] =
          await requestBackgroundLocationPermission();
    }

    // Request notification permission
    results['notification'] = await requestNotificationPermission();

    AppLogger.i('Permission request results: $results');
    return results;
  }

  /// Check if all required permissions are granted
  Future<bool> areAllPermissionsGranted() async {
    final locationStatus = await checkLocationPermission();
    final backgroundLocationStatus = await checkBackgroundLocationPermission();
    final notificationStatus = await checkNotificationPermission();

    return locationStatus == AppPermissionStatus.granted &&
        backgroundLocationStatus &&
        notificationStatus == AppPermissionStatus.granted;
  }
}
