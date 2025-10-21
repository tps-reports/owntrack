import 'dart:async';

import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/battery_service.dart';
import 'package:owntrack/data/services/geofencing_service.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:owntrack/data/services/message_processor.dart';

/// Tracking service coordinator
///
/// Coordinates location tracking, geofencing, and message publishing.
/// Manages battery optimization through monitoring modes and smart updates.
class TrackingService {
  final LocationService _locationService;
  final GeofencingService _geofencingService;
  final MessageProcessor _messageProcessor;
  final SettingsRepository _settingsRepository;
  final BatteryService _batteryService;

  StreamSubscription<LocationUpdate>? _locationSubscription;
  StreamSubscription<GeofenceTransition>? _geofenceSubscription;

  DateTime? _lastPublishTime;
  LocationUpdate? _lastPublishedLocation;

  /// Minimum time between location publishes (seconds)
  static const int minPublishInterval = 30;

  /// Minimum distance for location publish (meters)
  static const int minPublishDistance = 50;

  TrackingService(
    this._locationService,
    this._geofencingService,
    this._messageProcessor,
    this._settingsRepository,
    this._batteryService,
  );

  /// Start tracking
  Future<bool> startTracking() async {
    try {
      AppLogger.i('Starting tracking service');

      // Start location tracking
      final started = await _locationService.startTracking();
      if (!started) {
        AppLogger.e('Failed to start location tracking');
        return false;
      }

      // Subscribe to location updates
      _locationSubscription = _locationService.locationUpdates.listen(
        _onLocationUpdate,
        onError: (error) {
          AppLogger.e('Location update error: $error');
        },
      );

      // Subscribe to geofence transitions
      _geofenceSubscription = _geofencingService.transitions.listen(
        _onGeofenceTransition,
        onError: (error) {
          AppLogger.e('Geofence transition error: $error');
        },
      );

      AppLogger.i('Tracking service started successfully');
      return true;
    } catch (e) {
      AppLogger.e('Error starting tracking service: $e');
      return false;
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    AppLogger.i('Stopping tracking service');

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _geofenceSubscription?.cancel();
    _geofenceSubscription = null;

    await _locationService.stopTracking();

    AppLogger.i('Tracking service stopped');
  }

  /// Handle location update
  Future<void> _onLocationUpdate(LocationUpdate location) async {
    try {
      // Check geofences
      await _geofencingService.checkLocation(
        location.latitude,
        location.longitude,
      );

      // Determine if we should publish this location
      if (_shouldPublishLocation(location)) {
        await _publishLocation(location);
      }
    } catch (e) {
      AppLogger.e('Error handling location update: $e');
    }
  }

  /// Handle geofence transition
  Future<void> _onGeofenceTransition(GeofenceTransition transition) async {
    try {
      AppLogger.i(
        'Geofence ${transition.event == GeofenceEvent.enter ? "enter" : "exit"}: '
        '${transition.region.displayDescription}',
      );

      // Publish transition message
      await _publishTransition(transition);
    } catch (e) {
      AppLogger.e('Error handling geofence transition: $e');
    }
  }

  /// Determine if location should be published
  bool _shouldPublishLocation(LocationUpdate location) {
    // Always publish if this is the first location
    if (_lastPublishTime == null || _lastPublishedLocation == null) {
      return true;
    }

    // Check time interval
    final now = DateTime.now();
    final timeSinceLastPublish = now.difference(_lastPublishTime!).inSeconds;
    if (timeSinceLastPublish < minPublishInterval) {
      AppLogger.d('Skipping publish - too soon ($timeSinceLastPublish < $minPublishInterval)');
      return false;
    }

    // Check distance moved
    final distance = _locationService.getDistanceBetween(
      _lastPublishedLocation!.latitude,
      _lastPublishedLocation!.longitude,
      location.latitude,
      location.longitude,
    );

    if (distance < minPublishDistance) {
      AppLogger.d('Skipping publish - too close ($distance < $minPublishDistance)');
      return false;
    }

    AppLogger.d('Publishing location - moved ${distance.toInt()}m in ${timeSinceLastPublish}s');
    return true;
  }

  /// Publish location update
  Future<void> _publishLocation(LocationUpdate location) async {
    try {
      final deviceId = _settingsRepository.getDeviceId();
      final trackerId = _settingsRepository.getTrackerId();

      // Get current regions
      final inRegions = _geofencingService.getCurrentRegions();

      // Create location message
      final message = {
        '_type': 'location',
        'tid': trackerId.isNotEmpty ? trackerId : 'XX',
        'lat': location.latitude,
        'lon': location.longitude,
        'tst': location.timestampSeconds,
        'acc': location.accuracy.toInt(),
        'alt': (location.altitude ?? 0).toInt(),
        'vel': (location.speedKmH ?? 0).toInt(),
        'cog': (location.heading ?? 0).toInt(),
        'batt': _batteryService.batteryLevel,
        if (inRegions.isNotEmpty) 'inregions': inRegions,
      };

      final topic = 'owntracks/$deviceId/$trackerId';
      await _messageProcessor.sendMessage(message, topic: topic);

      _lastPublishTime = DateTime.now();
      _lastPublishedLocation = location;

      AppLogger.i('Published location update');
    } catch (e) {
      AppLogger.e('Error publishing location: $e');
    }
  }

  /// Publish geofence transition
  Future<void> _publishTransition(GeofenceTransition transition) async {
    try {
      final deviceId = _settingsRepository.getDeviceId();
      final trackerId = _settingsRepository.getTrackerId();

      final message = {
        '_type': 'transition',
        'tid': trackerId.isNotEmpty ? trackerId : 'XX',
        'event': transition.event == GeofenceEvent.enter ? 'enter' : 'leave',
        'lat': transition.latitude,
        'lon': transition.longitude,
        'tst': transition.timestamp,
        'desc': transition.region.displayDescription,
        'wtst': transition.region.timestamp,
      };

      final topic = 'owntracks/$deviceId/$trackerId';
      await _messageProcessor.sendMessage(message, topic: topic);

      AppLogger.i('Published geofence transition');
    } catch (e) {
      AppLogger.e('Error publishing transition: $e');
    }
  }

  /// Publish current location on demand
  Future<void> publishCurrentLocation() async {
    try {
      AppLogger.i('Publishing current location on demand');
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        await _publishLocation(location);
      }
    } catch (e) {
      AppLogger.e('Error publishing current location: $e');
    }
  }

  /// Get current tracking status
  bool get isTracking => _locationSubscription != null;

  /// Clean up resources
  void dispose() {
    _locationSubscription?.cancel();
    _geofenceSubscription?.cancel();
  }
}
