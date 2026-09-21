import 'dart:async';

import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/models/location_update.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/battery_service.dart';
import 'package:owntrack/data/services/geofencing_service.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/data/services/tracking_publication_policy.dart';

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

  final DateTime Function() _now;
  final Duration Function() _monotonicNow;
  final TrackingPublicationPolicy Function() _publicationPolicy;
  Duration? _lastPublishElapsed;
  Future<void> _lifecycle = Future<void>.value();
  Future<void> _updates = Future<void>.value();
  Future<void>? _manualPublication;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;
  int _stopRevision = 0;
  final _statusController = StreamController<String?>.broadcast();
  String? lastError;
  Stream<String?> get statusChanges => _statusController.stream;

  void _reportError(Object error) {
    if (_disposed) return;
    lastError = error.toString();
    AppLogger.e('Tracking operation failed: $error');
    _statusController.add(lastError);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _lifecycle = _lifecycle.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  LocationUpdate? _lastPublishedLocation;

  TrackingService(
    this._locationService,
    this._geofencingService,
    this._messageProcessor,
    this._settingsRepository,
    this._batteryService, {
    DateTime Function()? now,
    Duration Function()? monotonicNow,
    TrackingPublicationPolicy Function()? publicationPolicy,
  }) : _now = now ?? DateTime.now,
       _monotonicNow = monotonicNow ?? _startMonotonicClock(),
       _publicationPolicy = publicationPolicy ?? TrackingPublicationPolicy.new;

  static Duration Function() _startMonotonicClock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  void _resetPublicationHistory() {
    _lastPublishElapsed = null;
    _lastPublishedLocation = null;
  }

  void _clearError() {
    if (_disposed || lastError == null) return;
    lastError = null;
    _statusController.add(null);
  }

  /// Start tracking
  Future<bool> startTracking() {
    final stopRevision = _stopRevision;
    return _serialize(() async {
      if (_disposed || stopRevision != _stopRevision) return false;
      if (!_running) {
        _resetPublicationHistory();
        _running = true;
        _locationSubscription = _locationService.locationUpdates.listen(
          (location) {
            final generation = _generation;
            _updates = _updates.then((_) async {
              if (!_running || generation != _generation || _disposed) return;
              await _onLocationUpdate(location);
            });
          },
          onError: (Object error) {
            _running = false;
            _generation++;
            _reportError(error);
            unawaited(_locationSubscription?.cancel());
            _locationSubscription = null;
          },
        );
      }
      final started = await _locationService.startTracking();
      if (_disposed || stopRevision != _stopRevision || !_running) {
        await _stopTracking();
        return false;
      }
      if (!started) {
        await _stopTracking();
        _reportError(
          StateError(
            'Location unavailable. Check permissions and location services.',
          ),
        );
        return false;
      }
      lastError = null;
      _statusController.add(null);
      return true;
    });
  }

  /// Calling start again reapplies the persisted mode without duplicating listeners.
  Future<bool> reconfigure() => startTracking();

  Future<void> stopTracking() {
    _running = false;
    _stopRevision++;
    _generation++;
    return _serialize(_stopTracking);
  }

  Future<void> _stopTracking() async {
    _running = false;
    _generation++;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationService.stopTracking();
    await _updates;
    _resetPublicationHistory();
    if (!_disposed) _statusController.add(null);
  }

  bool _acceptable(LocationUpdate location) =>
      _publicationPolicy().isAcceptable(location, now: _now());

  /// Handle location update
  Future<void> _onLocationUpdate(LocationUpdate location) async {
    final generation = _generation;
    try {
      final mode = _settingsRepository.getMonitoringMode();
      if (!_running ||
          mode == AppConstants.monitoringModeQuiet ||
          mode == AppConstants.monitoringModeManual) {
        return;
      }
      if (!_acceptable(location)) {
        _reportError(
          StateError(
            'Location fix rejected: stale, inaccurate, mocked or invalid.',
          ),
        );
        return;
      }
      // Check geofences
      await _geofencingService.checkLocation(
        location.latitude,
        location.longitude,
        accuracy: location.accuracy,
        timestamp: location.timestampSeconds,
        acceptTransition: (transition) async {
          if (!_running || _disposed || generation != _generation) {
            throw StateError('Geofence publication cancelled.');
          }
          await _publishTransition(transition);
        },
      );
      if (!_running || _disposed || generation != _generation) return;
      _clearError();

      // Determine if we should publish this location
      if (_running && _shouldPublishLocation(location)) {
        await _publishLocation(location);
      }
    } catch (e) {
      if (_running && generation == _generation) _reportError(e);
    }
  }

  /// Determine if location should be published
  bool _shouldPublishLocation(LocationUpdate location) {
    return _publicationPolicy().shouldPublish(
      location,
      now: _now(),
      elapsedSincePublication: _lastPublishElapsed == null
          ? Duration.zero
          : _monotonicNow() - _lastPublishElapsed!,
      lastPublishedLocation: _lastPublishedLocation,
    );
  }

  /// Publish location update
  /// Publish a location from the automatic tracking stream.
  ///
  /// Failures are logged but not propagated: a single failed publish must not
  /// tear down the long-running location subscription. The message queue in
  /// [MessageProcessor] is responsible for retrying.
  Future<void> _publishLocation(LocationUpdate location) async {
    try {
      await _sendLocationMessage(location);
      AppLogger.i('Queued location update');
    } catch (e) {
      _reportError(e);
    }
  }

  /// Build and send the OwnTracks location message.
  ///
  /// Throws if the message cannot be handed to the message processor.
  Future<void> _sendLocationMessage(LocationUpdate location) async {
    final generation = _generation;
    final deviceId = _settingsRepository.getDeviceId();
    final trackerId = _settingsRepository.getTrackerId();

    // Get current regions
    final inRegions = _geofencingService.getCurrentRegions();
    final altitude = location.altitude;
    final speedKmH = location.speedKmH;
    final heading = location.heading;

    // Create location message
    final message = {
      '_type': 'location',
      'tid': trackerId.isNotEmpty ? trackerId : 'XX',
      'lat': location.latitude,
      'lon': location.longitude,
      'tst': location.timestampSeconds,
      'acc': location.accuracy.toInt(),
      if (altitude != null && altitude.isFinite) 'alt': altitude.toInt(),
      if (speedKmH != null && speedKmH.isFinite && speedKmH >= 0)
        'vel': speedKmH.toInt(),
      if (heading != null && heading.isFinite && heading >= 0 && heading < 360)
        'cog': heading.toInt(),
      if (_batteryService.batteryLevel != null)
        'batt': _batteryService.batteryLevel,
      if (inRegions.isNotEmpty) 'inregions': inRegions,
    };

    final topic = 'owntracks/$deviceId/$trackerId';
    await _messageProcessor.sendMessage(message, topic: topic);

    if (!_disposed && generation == _generation) {
      _lastPublishElapsed = _monotonicNow();
      _lastPublishedLocation = location;
      _clearError();
    }
  }

  /// Publish geofence transition
  Future<void> _publishTransition(GeofenceTransition transition) async {
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

    AppLogger.i('Queued geofence transition');
  }

  /// Publish current location on demand
  /// Publish the current location on demand.
  ///
  /// Unlike the automatic tracking path this propagates failures, so a caller
  /// driving it from the UI can tell the user what went wrong. Throws
  /// [StateError] when the current position cannot be determined.
  Future<void> publishCurrentLocation() {
    return _manualPublication ??= _publishCurrentLocation().whenComplete(() {
      _manualPublication = null;
    });
  }

  Future<void> _publishCurrentLocation() async {
    final generation = _generation;
    AppLogger.i('Publishing current location on demand');

    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      AppLogger.e('Cannot publish: current location unavailable');
      throw StateError(
        'Location unavailable. Check that location services are enabled and '
        'permission is granted.',
      );
    }

    if (!_acceptable(location)) {
      throw StateError('Location fix is stale, inaccurate, mocked or invalid.');
    }
    if (_disposed || generation != _generation) {
      throw StateError('Location publication cancelled.');
    }
    await _sendLocationMessage(location);
    AppLogger.i('Queued location on demand');
  }

  /// Get current tracking status
  bool get isTracking => _running;

  /// Clean up resources
  void dispose() {
    _disposed = true;
    _running = false;
    _stopRevision++;
    _generation++;
    _locationSubscription?.cancel();
    _statusController.close();
  }
}
