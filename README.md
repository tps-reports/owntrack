# OwnTracks Flutter

A unified Flutter implementation of OwnTracks for Android and iOS, combining both native apps into a single codebase.

## Architecture

This app uses a clean architecture pattern with:

- **State Management**: Riverpod with code generation
- **Navigation**: go_router
- **Database**: Drift (SQLite)
- **Maps**: flutter_map with OpenStreetMap tiles
- **Networking**: MQTT (mqtt_client) and HTTP (dio)

## Project Structure

```
lib/
├── core/               # Core utilities and infrastructure
│   ├── constants/      # App-wide constants
│   ├── errors/         # Error classes and failures
│   ├── extensions/     # Dart extensions
│   ├── router/         # Navigation configuration
│   └── utils/          # Utility classes (logger, etc.)
│
├── data/               # Data layer
│   ├── models/         # Data models
│   ├── repositories/   # Repository pattern implementations
│   ├── datasources/    # Local (DB/prefs) and remote data sources
│   └── services/       # Platform services
│
├── domain/             # Business logic layer
│   ├── providers/      # Riverpod providers
│   └── use_cases/      # Business logic use cases
│
├── presentation/       # UI layer
│   ├── screens/        # App screens
│   ├── widgets/        # Reusable widgets
│   └── theme/          # App theme
│
└── platform/           # Platform-specific code
    ├── android/        # Android-specific implementations
    └── ios/            # iOS-specific implementations
```

## Development Commands

### Setup

```bash
# Install dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs
```

### Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/errors/failures_test.dart
```

### Code Quality

```bash
# Analyze code
flutter analyze

# Format code
flutter format lib/ test/
```

### Building

```bash
# Run on connected device/emulator
flutter run

# Build Android APK
flutter build apk

# Build iOS (requires macOS and Xcode)
flutter build ios

# Build with specific flavor (future)
flutter run --flavor gms  # Google Play Services build
flutter run --flavor oss  # Open source build
```

## Phase 0 Completion Status

✅ Flutter project structure created
✅ Dependencies configured (Riverpod, flutter_map, Drift, etc.)
✅ Logging and error handling setup
✅ Navigation with go_router configured
✅ Material 3 theme implemented
✅ Initial tests written (16 tests passing)
✅ Code analysis passing with no issues

## Phase 1 Completion Status

✅ All OwnTracks message models implemented (7 types)
✅ Core data models implemented (Friend, Waypoint, Region, LocationUpdate)
✅ Manual toJson/fromJson serialization for all models
✅ Repositories implemented with persistence:
  - ContactsRepository (in-memory with Stream updates)
  - SettingsRepository (SharedPreferences)
  - WaypointsRepository (SharedPreferences with JSON)
  - RegionsRepository (SharedPreferences with JSON)
  - LocationRepository (current state management)
  - EndpointStateRepository (connection state tracking)
  - MessageQueueRepository (persistent queue with retry logic)
✅ Comprehensive test suite (59 tests passing)
✅ Code analysis passing with no issues
✅ Android & iOS builds successful

## Phase 2 Completion Status

✅ Network layer services implemented:
  - MqttService (connection, TLS/SSL, pub/sub, auto-reconnect)
  - HttpService (polling, POST endpoints)
  - EncryptionService (ChaCha20-Poly1305 AEAD encryption)
  - MessageProcessor (coordinates MQTT/HTTP, encryption, queue management)
✅ Retry logic with exponential backoff
✅ Comprehensive test suite (95 tests passing)
✅ Code analysis passing with no issues
✅ Android build successful

## Phase 3 Completion Status

✅ Platform services implemented:
  - LocationService (foreground/background tracking, monitoring modes)
  - PermissionService (location, notifications, background permissions)
  - GeofencingService (region monitoring with enter/exit events)
  - TrackingService (coordinator for location, geofencing, publishing)
  - BatteryService (battery level and charging state monitoring)
✅ Monitoring modes support (quiet, manual, significant, move)
✅ Smart location publishing (time/distance filters for battery optimization)
✅ Comprehensive test suite (120 tests passing)
✅ Code analysis passing with no issues
✅ Android build successful

## Phase 4 Completion Status

✅ UI layer implemented:
  - MapScreen with flutter_map and OpenStreetMap tiles
  - Bottom navigation (Map, Contacts, Waypoints, Settings)
  - Connection settings screen (MQTT/HTTP configuration)
  - Tracking settings screen (monitoring modes, permissions)
  - Identification settings screen (device/tracker IDs)
  - Placeholder views for Contacts and Waypoints (ready for data integration)
✅ Widget tests for settings screens (10 new tests)
✅ Comprehensive test suite (130 tests passing)
✅ Code analysis passing (2 deprecation warnings)
✅ Android build successful

## Phase 5 Completion Status

✅ State management integrated:
  - Riverpod providers for all repositories and services
  - FutureProvider for waypoints and regions
  - StreamProvider for contacts with real-time updates
  - State providers for UI state (navigation index, etc.)
✅ Fully functional screens:
  - ContactsScreen - displays friends with battery, location, timestamps
  - WaypointsScreen - full CRUD operations (add, edit, delete)
  - RegionsScreen - geofence management with enable/disable toggle
  - MapScreen - displays friend/waypoint markers and region circles
✅ Data integration:
  - Friend model uses lat/lon, battery, timestamp
  - Waypoint model uses description as display name
  - Region model uses displayDescription getter
  - All screens properly connected to repositories
✅ Code analysis passing (6 deprecation warnings)
✅ Android build successful

## Phase 6 Completion Status

✅ Settings persistence implemented:
  - SharedPreferences initialized in main.dart on app startup
  - SettingsLocalDataSource properly overridden with provider
  - All settings screens save/load from persistent storage
✅ Connection settings screen:
  - Saves/loads MQTT broker configuration (host, port, TLS, auth)
  - Saves/loads HTTP endpoint URL
  - Saves/loads connection mode preference
✅ Tracking settings screen:
  - Saves/loads monitoring mode to SharedPreferences
  - Updates trackingEnabledProvider state
  - Monitoring mode persists across app restarts
✅ Identification settings screen:
  - Saves/loads device ID and tracker ID
  - Settings persist across restarts
✅ Code analysis passing (6 deprecation warnings)
✅ Android build successful

## Phase 7 Completion Status

✅ Live services integration implemented:
  - Permission request flows in TrackingSettingsScreen
  - Real-time permission checking (location, background, notifications)
  - Permission dialog for permanently denied permissions
  - Tracking toggle connected to TrackingService
  - LocationService wired to TrackingService via providers
  - MQTT publishing via MessageProcessor
  - HTTP publishing via MessageProcessor
  - Background location support integrated
✅ Service providers created for all services:
  - LocationService, BatteryService, GeofencingService
  - MqttService, HttpService, EncryptionService
  - MessageProcessor, TrackingService, PermissionService
✅ Full tracking lifecycle:
  - Start/stop tracking from UI
  - Location updates published via MQTT/HTTP
  - Geofence transitions detected and published
  - Smart location filtering (time/distance)
  - Battery-optimized tracking modes
✅ Code analysis passing (no issues)
✅ Android build successful

## Next Steps - Phase 8: Final Polish

- Add manual location publish button
- Implement configuration import/export
- Add waypoint sharing
- Final testing on physical devices
- App store preparation

## Dependencies

### Core
- **flutter_riverpod**: State management
- **go_router**: Navigation
- **logger**: Logging framework

### Data
- **drift**: SQLite database (prepared for future use)
- **shared_preferences**: Settings storage

### Networking
- **mqtt_client**: MQTT protocol
- **dio**: HTTP client
- **connectivity_plus**: Network status

### Location
- **geolocator**: Location services
- **permission_handler**: Permissions
- **flutter_background_service**: Background tasks
- **workmanager**: Scheduled tasks

### Maps
- **flutter_map**: OpenStreetMap maps
- **latlong2**: Latitude/longitude calculations

### Security
- **cryptography**: Encryption (libsodium equivalent)
- **flutter_secure_storage**: Secure key storage

### UI/UX
- **cached_network_image**: Image caching
- **flutter_local_notifications**: Notifications
- **url_launcher**: Deep linking
- **share_plus**: Sharing

### Development
- **build_runner**: Code generation
- **riverpod_generator**: Riverpod code generation
- **mocktail**: Testing mocks
- **flutter_test**: Widget testing

## License

Same license as the original OwnTracks projects.
