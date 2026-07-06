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
import 'package:owntrack/data/services/app_launcher_service.dart';
import 'package:owntrack/data/services/battery_service.dart';
import 'package:owntrack/data/services/encryption_service.dart';
import 'package:owntrack/data/services/geofencing_service.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:owntrack/data/services/location_service.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:owntrack/data/services/permission_service.dart';
import 'package:owntrack/data/services/tracking_service.dart';

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
// Service Providers
// ============================================================================

/// Provides the permission service for managing app permissions
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Provides the battery service for battery monitoring
final batteryServiceProvider = Provider<BatteryService>((ref) {
  return BatteryService();
});

/// Provides the location service for GPS tracking
final locationServiceProvider = Provider<LocationService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return LocationService(settingsRepo);
});

/// Provides the geofencing service for region monitoring
final geofencingServiceProvider = Provider<GeofencingService>((ref) {
  final regionsRepo = ref.watch(regionsRepositoryProvider);
  return GeofencingService(regionsRepo);
});

/// Provides the encryption service for message encryption
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return EncryptionService(settingsRepo);
});

/// Provides the MQTT service for MQTT protocol communication
final mqttServiceProvider = Provider<MqttService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final stateRepo = ref.watch(endpointStateRepositoryProvider);
  return MqttService(settingsRepo, stateRepo);
});

/// Provides the HTTP service for HTTP protocol communication
final httpServiceProvider = Provider<HttpService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final stateRepo = ref.watch(endpointStateRepositoryProvider);
  return HttpService(settingsRepo, stateRepo);
});

/// Provides the message processor for coordinating MQTT/HTTP communication
final messageProcessorProvider = Provider<MessageProcessor>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final queueRepo = ref.watch(messageQueueRepositoryProvider);
  final mqttService = ref.watch(mqttServiceProvider);
  final httpService = ref.watch(httpServiceProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);
  return MessageProcessor(
    settingsRepo,
    queueRepo,
    mqttService,
    httpService,
    encryptionService,
  );
});

/// Provides the tracking service for coordinating location tracking
final trackingServiceProvider = Provider<TrackingService>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  final geofencingService = ref.watch(geofencingServiceProvider);
  final messageProcessor = ref.watch(messageProcessorProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final batteryService = ref.watch(batteryServiceProvider);
  return TrackingService(
    locationService,
    geofencingService,
    messageProcessor,
    settingsRepo,
    batteryService,
  );
});

/// Provides the app launcher service for launching mobile app from web
final appLauncherServiceProvider = Provider<AppLauncherService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return AppLauncherService(settingsRepo);
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
