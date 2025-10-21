import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/data/repositories/regions_repository.dart';

/// Geofence event type
enum GeofenceEvent {
  enter,
  exit,
}

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
class GeofencingService {
  final RegionsRepository _regionsRepository;

  final Map<String, bool> _regionStates = {}; // Track if we're inside each region
  final StreamController<GeofenceTransition> _transitionController =
      StreamController<GeofenceTransition>.broadcast();

  /// Stream of geofence transitions
  Stream<GeofenceTransition> get transitions => _transitionController.stream;

  GeofencingService(this._regionsRepository) {
    _initializeRegionStates();
  }

  /// Initialize region states from repository
  void _initializeRegionStates() {
    final regions = _regionsRepository.getAllRegions();
    for (final region in regions) {
      _regionStates[region.id] = false; // Assume outside initially
    }
  }

  /// Check location against all enabled regions
  Future<void> checkLocation(double latitude, double longitude) async {
    final regions = _regionsRepository.getEnabledRegions();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final region in regions) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        region.lat,
        region.lon,
      );

      final isInside = distance <= region.radiusMeters;
      final wasInside = _regionStates[region.id] ?? false;

      // Check for transitions
      if (isInside && !wasInside) {
        // Entered region
        AppLogger.i('Entered region: ${region.displayDescription}');
        _regionStates[region.id] = true;
        _transitionController.add(GeofenceTransition(
          region: region,
          event: GeofenceEvent.enter,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
        ));
      } else if (!isInside && wasInside) {
        // Exited region
        AppLogger.i('Exited region: ${region.displayDescription}');
        _regionStates[region.id] = false;
        _transitionController.add(GeofenceTransition(
          region: region,
          event: GeofenceEvent.exit,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
        ));
      }
    }
  }

  /// Add a new region to monitor
  Future<void> addRegion(Region region) async {
    await _regionsRepository.addRegion(region);
    _regionStates[region.id] = false;
    AppLogger.i('Added region for monitoring: ${region.displayDescription}');
  }

  /// Remove a region from monitoring
  Future<void> removeRegion(String regionId) async {
    await _regionsRepository.deleteRegion(regionId);
    _regionStates.remove(regionId);
    AppLogger.i('Removed region from monitoring: $regionId');
  }

  /// Update an existing region
  Future<void> updateRegion(Region region) async {
    await _regionsRepository.updateRegion(region);
    AppLogger.i('Updated region: ${region.displayDescription}');
  }

  /// Enable a region
  Future<void> enableRegion(String regionId) async {
    final region = _regionsRepository.getRegion(regionId);
    if (region != null) {
      final updated = region.copyWith(enabled: true);
      await _regionsRepository.updateRegion(updated);
      AppLogger.i('Enabled region: ${region.displayDescription}');
    }
  }

  /// Disable a region
  Future<void> disableRegion(String regionId) async {
    final region = _regionsRepository.getRegion(regionId);
    if (region != null) {
      final updated = region.copyWith(enabled: false);
      await _regionsRepository.updateRegion(updated);
      _regionStates[regionId] = false; // Reset state
      AppLogger.i('Disabled region: ${region.displayDescription}');
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
    AppLogger.i('Cleared all regions');
  }

  /// Clean up resources
  void dispose() {
    _transitionController.close();
  }
}
