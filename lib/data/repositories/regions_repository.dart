import 'dart:convert';

import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/region.dart';

/// Repository for regions (geofences) with persistence
class RegionsRepository {
  static const String _regionsKey = 'regions_storage';

  final SettingsLocalDataSource _localDataSource;
  final Map<String, Region> _regions = {};

  RegionsRepository(this._localDataSource) {
    _loadRegions();
  }

  /// Load regions from storage
  void _loadRegions() {
    final jsonString = _localDataSource.getString(_regionsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        for (final json in jsonList) {
          final region = Region.fromJson(json as Map<String, dynamic>);
          _regions[region.id] = region;
        }
      } catch (e) {
        // Handle parsing errors
      }
    }
  }

  /// Save regions to storage
  Future<void> _saveRegions() async {
    final jsonList = _regions.values.map((r) => r.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _localDataSource.setString(_regionsKey, jsonString);
  }

  /// Get all regions
  List<Region> getAllRegions() => _regions.values.toList();

  /// Get enabled regions only
  List<Region> getEnabledRegions() =>
      _regions.values.where((r) => r.enabled).toList();

  /// Get region by ID
  Region? getRegion(String id) => _regions[id];

  /// Add region
  Future<void> addRegion(Region region) async {
    _regions[region.id] = region;
    await _saveRegions();
  }

  /// Update region
  Future<void> updateRegion(Region region) async {
    if (_regions.containsKey(region.id)) {
      _regions[region.id] = region;
      await _saveRegions();
    }
  }

  /// Delete region
  Future<void> deleteRegion(String id) async {
    if (_regions.remove(id) != null) {
      await _saveRegions();
    }
  }

  /// Clear all regions
  Future<void> clearAll() async {
    _regions.clear();
    await _saveRegions();
  }

  /// Get number of regions
  int get count => _regions.length;
}
