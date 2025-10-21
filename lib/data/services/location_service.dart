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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastPosition = position;
      final update = _positionToLocationUpdate(position);
      AppLogger.d('Got current location: ${position.latitude}, ${position.longitude}');
      return update;
    } catch (e) {
      AppLogger.e('Error getting current location: $e');
      return null;
    }
  }

  /// Start location tracking based on monitoring mode
  Future<bool> startTracking() async {
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

      final monitoringMode = _settingsRepository.getMonitoringMode();
      final settings = _getLocationSettings(monitoringMode);

      if (PlatformUtils.isWeb) {
        AppLogger.i('Starting location tracking on web (foreground only)');
      } else {
        AppLogger.i('Starting location tracking with mode: $monitoringMode');
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _onLocationUpdate,
        onError: _onLocationError,
      );

      return true;
    } catch (e) {
      AppLogger.e('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    AppLogger.i('Stopping location tracking');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Get location settings based on monitoring mode
  LocationSettings _getLocationSettings(int monitoringMode) {
    switch (monitoringMode) {
      case AppConstants.monitoringModeQuiet:
        // Quiet mode - no tracking
        return const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 1000, // 1km
        );

      case AppConstants.monitoringModeManual:
        // Manual mode - only on demand
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );

      case AppConstants.monitoringModeSignificant:
        // Significant changes - balance between accuracy and battery
        return const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100, // 100m
          timeLimit: Duration(minutes: 5),
        );

      case AppConstants.monitoringModeMove:
        // Move mode - high accuracy, frequent updates
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10, // 10m
          timeLimit: Duration(seconds: 30),
        );

      default:
        // Default to significant changes
        return const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,
        );
    }
  }

  /// Handle location update
  void _onLocationUpdate(Position position) {
    _lastPosition = position;
    final update = _positionToLocationUpdate(position);
    AppLogger.d('Location update: ${position.latitude}, ${position.longitude}, acc: ${position.accuracy}m');
    _locationController.add(update);
  }

  /// Handle location error
  void _onLocationError(Object error) {
    AppLogger.e('Location error: $error');
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
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
