import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/data/repositories/regions_repository.dart';

/// Geofence event type
enum GeofenceEvent { enter, exit }

/// Geofence transition
class GeofenceTransition {
  final Region region;
  final GeofenceEvent event;
  final double latitude;
  final double longitude;
  final int timestamp;

  const GeofenceTransition({
    required this.region,
    required this.event,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

/// Geofencing service for region monitoring
///
/// Monitors when the device enters or exits defined geographic regions.
/// Uses distance-based monitoring for cross-platform compatibility.
///
/// **Platform Support:**
/// - **Mobile (Android/iOS)**: Foreground and background monitoring
/// - **Web**: Foreground-only monitoring (while app is running)
///   - Manual distance checking on each location update
///   - Works perfectly for active tracking scenarios
///   - No background geofence triggers (browser limitation)
///
/// The service automatically checks each location update against all enabled
/// regions and fires enter/exit events when transitions occur.
class GeofencingService {
  final RegionsRepository _regionsRepository;

  final Map<String, bool> _regionStates =
      {}; // Track if we're inside each region
  final Map<String, Region> _observedRegions = {};
  final Map<String, GeofenceTransition> _pendingTransitions = {};
  Future<void> _checks = Future<void>.value();
  bool _disposed = false;
  final StreamController<GeofenceTransition> _transitionController =
      StreamController<GeofenceTransition>.broadcast();

  /// Observed transitions, emitted after the optional acceptance callback succeeds.
  Stream<GeofenceTransition> get transitions => _transitionController.stream;

  GeofencingService(this._regionsRepository);

  /// Check location against all enabled regions
  ///
  /// With [acceptTransition], a crossing is committed only after the callback
  /// accepts it into durable delivery. A failed crossing retains its original
  /// fix and is retried before processing a later crossing for that region.
  /// Without a callback, this service provides local transition observation.
  Future<void> checkLocation(
    double latitude,
    double longitude, {
    double accuracy = 0,
    int? timestamp,
    Future<void> Function(GeofenceTransition)? acceptTransition,
  }) {
    final result = Completer<void>();
    _checks = _checks.then((_) async {
      try {
        if (_disposed) throw StateError('Geofencing has been disposed.');
        await _checkLocation(
          latitude,
          longitude,
          accuracy: accuracy,
          timestamp: timestamp,
          acceptTransition: acceptTransition,
        );
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> _checkLocation(
    double latitude,
    double longitude, {
    required double accuracy,
    int? timestamp,
    Future<void> Function(GeofenceTransition)? acceptTransition,
  }) async {
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }
    final regions = _regionsRepository.getEnabledRegions();
    final fixTimestamp =
        timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final activeIds = regions.map((region) => region.id).toSet();
    _regionStates.removeWhere((id, _) => !activeIds.contains(id));
    _observedRegions.removeWhere((id, _) => !activeIds.contains(id));
    _pendingTransitions.removeWhere((id, _) => !activeIds.contains(id));

    Object? firstError;
    StackTrace? firstStack;
    for (final region in regions) {
      if (_disposed) break;
      try {
        await _checkRegion(
          region,
          latitude,
          longitude,
          accuracy: accuracy,
          timestamp: fixTimestamp,
          acceptTransition: acceptTransition,
        );
      } catch (error, stack) {
        // Process every region for this fix even when an earlier region cannot
        // enter the outbox. Surface failure after the full scan.
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  Future<void> _checkRegion(
    Region region,
    double latitude,
    double longitude, {
    required double accuracy,
    required int timestamp,
    Future<void> Function(GeofenceTransition)? acceptTransition,
  }) async {
    if (!identical(_regionsRepository.getRegion(region.id), region)) return;
    // Screens can edit the repository directly. A changed definition starts
    // with a new occupancy baseline instead of replaying an old crossing.
    if (!identical(_observedRegions[region.id], region)) {
      _regionStates.remove(region.id);
      _pendingTransitions.remove(region.id);
      _observedRegions[region.id] = region;
    }
    final pending = _pendingTransitions[region.id];
    if (pending != null) {
      await _acceptPending(pending, acceptTransition);
      if (_disposed ||
          !identical(_regionsRepository.getRegion(region.id), region)) {
        return;
      }
    }
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      region.lat,
      region.lon,
    );

    final margin = accuracy > 10 ? accuracy : 10.0;
    final previous = _regionStates[region.id];
    if (distance > region.radiusMeters - margin &&
        distance < region.radiusMeters + margin) {
      return;
    }
    final isInside = distance <= region.radiusMeters - margin;
    if (previous == null) {
      // The first confident fix establishes occupancy; it is not a crossing.
      _regionStates[region.id] = isInside;
      return;
    }
    if (isInside == previous) return;
    final transition = GeofenceTransition(
      region: region,
      event: isInside ? GeofenceEvent.enter : GeofenceEvent.exit,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
    _pendingTransitions[region.id] = transition;
    await _acceptPending(transition, acceptTransition);
  }

  Future<void> _acceptPending(
    GeofenceTransition transition,
    Future<void> Function(GeofenceTransition)? acceptTransition,
  ) async {
    if (acceptTransition != null) await acceptTransition(transition);
    if (_disposed) return;
    if (identical(_pendingTransitions[transition.region.id], transition)) {
      _pendingTransitions.remove(transition.region.id);
    }
    if (identical(
      _regionsRepository.getRegion(transition.region.id),
      transition.region,
    )) {
      _regionStates[transition.region.id] =
          transition.event == GeofenceEvent.enter;
    }
    AppLogger.i('Accepted geofence transition');
    _transitionController.add(transition);
  }

  /// Add a new region to monitor
  Future<void> addRegion(Region region) async {
    await _regionsRepository.addRegion(region);
    _regionStates.remove(region.id);
    _pendingTransitions.remove(region.id);
    _observedRegions.remove(region.id);
    AppLogger.i('Added region for monitoring');
  }

  /// Remove a region from monitoring
  Future<void> removeRegion(String regionId) async {
    await _regionsRepository.deleteRegion(regionId);
    _regionStates.remove(regionId);
    _pendingTransitions.remove(regionId);
    _observedRegions.remove(regionId);
    AppLogger.i('Removed region from monitoring');
  }

  /// Update an existing region
  Future<void> updateRegion(Region region) async {
    await _regionsRepository.updateRegion(region);
    _regionStates.remove(region.id);
    _pendingTransitions.remove(region.id);
    _observedRegions.remove(region.id);
    AppLogger.i('Updated monitored region');
  }

  /// Enable a region
  Future<void> enableRegion(String regionId) async {
    final region = _regionsRepository.getRegion(regionId);
    if (region != null) {
      final updated = region.copyWith(enabled: true);
      await _regionsRepository.updateRegion(updated);
      AppLogger.i('Enabled monitored region');
    }
  }

  /// Disable a region
  Future<void> disableRegion(String regionId) async {
    final region = _regionsRepository.getRegion(regionId);
    if (region != null) {
      final updated = region.copyWith(enabled: false);
      await _regionsRepository.updateRegion(updated);
      _regionStates.remove(regionId);
      _pendingTransitions.remove(regionId);
      _observedRegions.remove(regionId);
      AppLogger.i('Disabled monitored region');
    }
  }

  /// Get all monitored regions
  List<Region> getAllRegions() {
    return _regionsRepository.getAllRegions();
  }

  /// Get enabled regions
  List<Region> getEnabledRegions() {
    return _regionsRepository.getEnabledRegions();
  }

  /// Check if currently inside a specific region
  bool isInsideRegion(String regionId) {
    return _regionStates[regionId] ?? false;
  }

  /// Get all regions the device is currently inside
  List<String> getCurrentRegions() {
    return _regionStates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Clear all regions
  Future<void> clearAllRegions() async {
    await _regionsRepository.clearAll();
    _regionStates.clear();
    _pendingTransitions.clear();
    _observedRegions.clear();
    AppLogger.i('Cleared all regions');
  }

  /// Clean up resources
  void dispose() {
    _disposed = true;
    _transitionController.close();
  }
}
