import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/core/utils/platform_utils.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// Location service for tracking device location
///
/// Handles foreground and background location updates with support for
/// different monitoring modes (quiet, manual, significant, move).
///
/// **Web Platform Notes:**
/// - Uses browser's Geolocation API via geolocator_web
/// - No background location tracking (browser security limitation)
/// - Requires HTTPS for production deployments
/// - User must grant location permission via browser prompt
class LocationService {
  final SettingsRepository _settingsRepository;

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  Future<void> _lifecycle = Future<void>.value();
  bool _disposed = false;
  int? _activeMode;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _lifecycle = _lifecycle.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  final StreamController<LocationUpdate> _locationController =
      StreamController<LocationUpdate>.broadcast();

  /// Stream of location updates
  Stream<LocationUpdate> get locationUpdates => _locationController.stream;

  /// Last known position
  Position? get lastPosition => _lastPosition;

  /// Check if currently tracking
  bool get isTracking => _positionSubscription != null;

  LocationService(this._settingsRepository);

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current location once
  Future<LocationUpdate?> getCurrentLocation() async {
    try {
      AppLogger.i('Getting current location');

      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.e('Location services are disabled');
        return null;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.e('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.e('Location permission denied forever');
        return null;
      }

      final position = await _getPositionRetryingAuthorizationRace();

      _lastPosition = position;
      final update = _positionToLocationUpdate(position);
      AppLogger.d('Acquired current location');
      return update;
    } catch (e) {
      AppLogger.e('Error getting current location: $e');
      return null;
    }
  }

  /// Reads the current position, retrying the authorization race.
  ///
  /// On macOS the plugin gates every position read on
  /// `CLLocationManager.authorizationStatus`, which can still report the old
  /// status for a moment after the user clicks Allow in the permission
  /// dialog: `requestPermission()` resolves granted, yet the immediately
  /// following read throws [PermissionDeniedException]. Observed sequence:
  /// check=denied → request=always → read throws "User denied permissions",
  /// while the same read succeeds moments later.
  ///
  /// Retry only while a fresh [checkPermission] still reports granted — a
  /// genuine denial fails that check and is rethrown immediately. Bounded so
  /// a plugin that keeps refusing cannot loop forever.
  Future<Position> _getPositionRetryingAuthorizationRace() async {
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } on PermissionDeniedException {
        if (attempt >= maxAttempts) rethrow;

        final settled = await checkPermission();
        final granted =
            settled == LocationPermission.always ||
            settled == LocationPermission.whileInUse;
        if (!granted) rethrow;

        AppLogger.w(
          'Position read denied while permission reports granted '
          '(authorization race); retrying ($attempt/$maxAttempts)',
        );
        await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
      }
    }
  }

  /// Start location tracking based on monitoring mode
  Future<bool> startTracking() => _serialize(_startTracking);

  Future<bool> _startTracking() async {
    if (_disposed) return false;
    final monitoringMode = _settingsRepository.getMonitoringMode();
    if (_positionSubscription != null && _activeMode == monitoringMode) {
      return true;
    }
    await _stopTracking();
    if (monitoringMode == AppConstants.monitoringModeQuiet ||
        monitoringMode == AppConstants.monitoringModeManual) {
      return true;
    }
    try {
      // Web browser geolocation doesn't have a "service enabled" concept
      // Skip check on web to avoid false negatives
      if (!PlatformUtils.isWeb) {
        final serviceEnabled = await isLocationServiceEnabled();
        if (!serviceEnabled) {
          AppLogger.e('Location services are disabled');
          return false;
        }
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.e('Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.e('Location permission denied forever');
        return false;
      }

      if (_disposed) return false;
      final settings = _getLocationSettings(monitoringMode);

      if (PlatformUtils.isWeb) {
        AppLogger.i('Starting location tracking on web (foreground only)');
      } else {
        AppLogger.i('Starting location tracking with mode: $monitoringMode');
      }

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            _onLocationUpdate,
            onError: _onLocationError,
            onDone: () {
              if (!_disposed && _positionSubscription != null) {
                _onLocationError(
                  StateError(
                    'Location updates stopped. Restart tracking to retry.',
                  ),
                );
              }
            },
            cancelOnError: true,
          );

      _activeMode = monitoringMode;
      return true;
    } catch (e) {
      AppLogger.e('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() => _serialize(_stopTracking);

  Future<void> _stopTracking() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _activeMode = null;
    await subscription?.cancel();
  }

  /// Get location settings based on monitoring mode
  LocationSettings _getLocationSettings(int monitoringMode) {
    final moving = monitoringMode == AppConstants.monitoringModeMove;
    final accuracy = moving ? LocationAccuracy.best : LocationAccuracy.medium;
    // Distance filtering is a publication policy. A stationary stream must
    // remain capable of producing fresh fixes for the heartbeat.
    if (PlatformUtils.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: moving ? 10 : 60),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'OwnTrack location tracking',
          notificationText: 'Location sharing is active',
          enableWakeLock: true,
        ),
      );
    }
    if (PlatformUtils.isIOS ||
        (!PlatformUtils.isWeb && PlatformUtils.isDesktop)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: PlatformUtils.isIOS,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: 0);
  }

  /// Handle location update
  void _onLocationUpdate(Position position) {
    _lastPosition = position;
    final update = _positionToLocationUpdate(position);
    if (_disposed) return;
    AppLogger.d('Received location update');
    _locationController.add(update);
  }

  /// Handle location error
  void _onLocationError(Object error) {
    if (_disposed) return;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _activeMode = null;
    unawaited(subscription?.cancel());
    AppLogger.e('Location stream failed');
    _locationController.addError(error);
  }

  /// Convert Position to LocationUpdate
  LocationUpdate _positionToLocationUpdate(Position position) {
    return LocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      isMocked: position.isMocked,
    );
  }

  /// Get distance between two positions in meters
  double getDistanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Clean up resources
  void dispose() {
    _disposed = true;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationController.close();
  }
}
