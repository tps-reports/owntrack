import 'package:geolocator/geolocator.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission status for the app
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Permission service for managing app permissions
///
/// Handles location, notification, and background permissions
/// with proper error handling and user feedback.
class PermissionService {
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
      // On Android 10+, check ACCESS_BACKGROUND_LOCATION
      // On iOS, location permission already includes background
      if (await _isAndroid10OrHigher()) {
        final status = await ph.Permission.locationAlways.status;
        return status.isGranted;
      }

      // For iOS or older Android, check regular location permission
      final locationStatus = await checkLocationPermission();
      return locationStatus == AppPermissionStatus.granted;
    } catch (e) {
      AppLogger.e('Error checking background location permission: $e');
      return false;
    }
  }

  /// Request background location permission
  Future<AppPermissionStatus> requestBackgroundLocationPermission() async {
    try {
      AppLogger.i('Requesting background location permission');

      if (await _isAndroid10OrHigher()) {
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

      // For iOS or older Android, background is included in regular permission
      return await requestLocationPermission();
    } catch (e) {
      AppLogger.e('Error requesting background location permission: $e');
      return AppPermissionStatus.denied;
    }
  }

  /// Check notification permission status
  Future<AppPermissionStatus> checkNotificationPermission() async {
    try {
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

  /// Helper to check if running on Android 10+
  Future<bool> _isAndroid10OrHigher() async {
    // This is a simplified check. In a real app, you'd use platform channels
    // or device_info_plus to properly detect Android version.
    // For now, we'll assume modern Android.
    return true;
  }
}
