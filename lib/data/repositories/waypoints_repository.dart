import 'dart:convert';

import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/waypoint.dart';

/// Repository for waypoints with persistence
class WaypointsRepository {
  static const String _waypointsKey = 'waypoints_storage';

  final SettingsLocalDataSource _localDataSource;
  final Map<String, Waypoint> _waypoints = {};

  WaypointsRepository(this._localDataSource) {
    _loadWaypoints();
  }

  /// Load waypoints from storage
  void _loadWaypoints() {
    final jsonString = _localDataSource.getString(_waypointsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        for (final json in jsonList) {
          final waypoint = Waypoint.fromJson(json as Map<String, dynamic>);
          _waypoints[waypoint.id] = waypoint;
        }
      } catch (e) {
        // Handle parsing errors
      }
    }
  }

  /// Save waypoints to storage
  Future<void> _saveWaypoints() async {
    final jsonList = _waypoints.values.map((w) => w.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _localDataSource.setString(_waypointsKey, jsonString);
  }

  /// Get all waypoints
  List<Waypoint> getAllWaypoints() => _waypoints.values.toList();

  /// Get waypoint by ID
  Waypoint? getWaypoint(String id) => _waypoints[id];

  /// Add waypoint
  Future<void> addWaypoint(Waypoint waypoint) async {
    _waypoints[waypoint.id] = waypoint;
    await _saveWaypoints();
  }

  /// Update waypoint
  Future<void> updateWaypoint(Waypoint waypoint) async {
    if (_waypoints.containsKey(waypoint.id)) {
      _waypoints[waypoint.id] = waypoint;
      await _saveWaypoints();
    }
  }

  /// Delete waypoint
  Future<void> deleteWaypoint(String id) async {
    if (_waypoints.remove(id) != null) {
      await _saveWaypoints();
    }
  }

  /// Clear all waypoints
  Future<void> clearAll() async {
    _waypoints.clear();
    await _saveWaypoints();
  }

  /// Get number of waypoints
  int get count => _waypoints.length;
}
