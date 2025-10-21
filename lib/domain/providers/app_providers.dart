import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/models/friend.dart';
import 'package:owntrack/data/models/region.dart';
import 'package:owntrack/data/models/waypoint.dart';
import 'package:owntrack/data/repositories/contacts_repository.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/location_repository.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/repositories/regions_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/repositories/waypoints_repository.dart';

// ============================================================================
// Local Data Sources
// ============================================================================

/// Provides the settings local data source
/// This is overridden in main.dart with a real SharedPreferences instance
final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((ref) {
  throw UnimplementedError(
    'SettingsLocalDataSource must be overridden in main.dart with SharedPreferences',
  );
});

// ============================================================================
// Repository Providers
// ============================================================================

/// Provides the settings repository for app configuration
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final localDataSource = ref.watch(settingsLocalDataSourceProvider);
  return SettingsRepository(localDataSource);
});

/// Provides the contacts repository for managing friends
final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository();
});

/// Provides the waypoints repository for managing waypoints
final waypointsRepositoryProvider = Provider<WaypointsRepository>((ref) {
  final localDataSource = ref.watch(settingsLocalDataSourceProvider);
  return WaypointsRepository(localDataSource);
});

/// Provides the regions repository for managing geofence regions
final regionsRepositoryProvider = Provider<RegionsRepository>((ref) {
  final localDataSource = ref.watch(settingsLocalDataSourceProvider);
  return RegionsRepository(localDataSource);
});

/// Provides the location repository for current location state
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

/// Provides the endpoint state repository for connection status
final endpointStateRepositoryProvider =
    Provider<EndpointStateRepository>((ref) {
  return EndpointStateRepository();
});

/// Provides the message queue repository for reliable message delivery
final messageQueueRepositoryProvider = Provider<MessageQueueRepository>((ref) {
  final localDataSource = ref.watch(settingsLocalDataSourceProvider);
  return MessageQueueRepository(localDataSource);
});

// ============================================================================
// Stream/Future Providers for Reactive Data
// ============================================================================

/// Provides a stream of friends/contacts
final friendsStreamProvider = StreamProvider<List<Friend>>((ref) {
  final repository = ref.watch(contactsRepositoryProvider);
  // Convert the change stream to a stream of friend lists
  return repository.changes.map((_) => repository.getAllContacts());
});

/// Provides waypoints as a future
final waypointsStreamProvider = FutureProvider<List<Waypoint>>((ref) async {
  final repository = ref.watch(waypointsRepositoryProvider);
  return repository.getAllWaypoints();
});

/// Provides regions as a future
final regionsStreamProvider = FutureProvider<List<Region>>((ref) async {
  final repository = ref.watch(regionsRepositoryProvider);
  return repository.getAllRegions();
});

// ============================================================================
// State Providers for UI State
// ============================================================================

/// Provides the current monitoring mode
final monitoringModeProvider = StateProvider<int>((ref) {
  return 1; // Default to Significant mode
});

/// Provides the tracking enabled state
final trackingEnabledProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provides the connection mode (MQTT or HTTP)
final connectionModeProvider = StateProvider<String>((ref) {
  return 'mqtt'; // Default to MQTT
});

/// Provides the selected bottom navigation index
final selectedNavigationIndexProvider = StateProvider<int>((ref) {
  return 0; // Default to Map view
});
