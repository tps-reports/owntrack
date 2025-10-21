import 'package:owntrack/data/models/location_update.dart';

/// Repository for current location state
class LocationRepository {
  LocationUpdate? _currentLocation;
  int _viewMode = 0; // 0 = follow, 1 = free

  /// Get current location
  LocationUpdate? get currentLocation => _currentLocation;

  /// Update current location
  void updateLocation(LocationUpdate location) {
    _currentLocation = location;
  }

  /// Clear current location
  void clearLocation() {
    _currentLocation = null;
  }

  /// Get view mode
  int get viewMode => _viewMode;

  /// Set view mode
  void setViewMode(int mode) {
    _viewMode = mode;
  }

  /// Check if location is available
  bool get hasLocation => _currentLocation != null;

  /// Get last update timestamp
  DateTime? get lastUpdateTime => _currentLocation?.timestamp;
}
