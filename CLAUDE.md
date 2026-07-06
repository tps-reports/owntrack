# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

OwnTracks Flutter is a unified Flutter implementation of OwnTracks for Android, iOS, and Web, replacing the separate native Android (Kotlin/Java) and iOS (Objective-C) codebases with a single cross-platform application.

**Architecture Pattern**: Clean Architecture with Riverpod state management

**Key Technologies**:
- State Management: Riverpod with provider pattern
- Navigation: go_router
- Database: Drift (SQLite) prepared, currently using SharedPreferences
- Maps: flutter_map with OpenStreetMap tiles
- Networking: mqtt_client and dio (HTTP)
- Location: geolocator with background tracking support

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Run code generation for Riverpod providers
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation during development
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/data/repositories/settings_repository_test.dart

# Run tests matching a pattern
flutter test --plain-name "SettingsRepository"
```

### Code Quality
```bash
# Analyze code (includes custom_lint and riverpod_lint)
flutter analyze

# Format code
dart format lib/ test/

# Fix auto-fixable issues
dart fix --apply
```

### Building and Running
```bash
# Run on connected device/emulator
flutter run

# Run on web browser
flutter run -d chrome

# Run with verbose logging
flutter run -v

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Build iOS (requires macOS and Xcode)
flutter build ios

# Build for web
flutter build web --release

# Build for web with custom base href
flutter build web --release --base-href /owntrack/

# Serve web build locally for testing
# After building, serve from build/web directory
python3 -m http.server 8000 --directory build/web

# Clean build artifacts
flutter clean
```

## Architecture Overview

### Layer Organization

```
lib/
├── core/               # Cross-cutting concerns
│   ├── constants/      # App-wide constants (connection modes, etc.)
│   ├── errors/         # Error classes and failures
│   ├── extensions/     # Dart extensions (DateTime, etc.)
│   ├── router/         # Navigation configuration (go_router)
│   └── utils/          # Utilities (app_logger)
│
├── data/               # Data layer (implements repositories)
│   ├── models/         # Data models with JSON serialization
│   │   └── message/    # OwnTracks message types
│   ├── repositories/   # Repository implementations
│   ├── datasources/    # Local data sources (SharedPreferences)
│   └── services/       # Platform and network services
│
├── domain/             # Business logic layer
│   └── providers/      # Riverpod provider definitions
│
├── presentation/       # UI layer
│   ├── screens/        # Full-page screens
│   │   ├── map/        # Map view with markers
│   │   ├── contacts/   # Friends list
│   │   ├── waypoints/  # Waypoint management
│   │   ├── regions/    # Geofence management
│   │   └── settings/   # Settings screens
│   ├── widgets/        # Reusable UI components
│   └── theme/          # Material 3 theme
│
└── platform/           # Platform-specific code (Android/iOS)
```

### Data Flow

**Location Updates Flow:**
```
LocationService → TrackingService → MessageProcessor → MQTT/HTTP Service
                       ↓
                GeofencingService (checks regions)
                       ↓
                  Smart filtering (time/distance)
                       ↓
              Publishes to broker/endpoint
```

**Incoming Messages Flow:**
```
MQTT/HTTP Service → MessageProcessor → Decrypt (if enabled)
                                            ↓
                                    ContactsRepository
                                            ↓
                                    UI (via StreamProvider)
```

**Settings Persistence:**
```
UI Screen → SettingsRepository → SettingsLocalDataSource → SharedPreferences
```

### Key Services

**TrackingService** (`data/services/tracking_service.dart`)
- Coordinates all tracking functionality
- Manages LocationService, GeofencingService, and MessageProcessor
- Implements smart location filtering (min time: 30s, min distance: 50m)
- Handles both location updates and geofence transitions
- Battery optimization through monitoring modes

**MessageProcessor** (`data/services/message_processor.dart`)
- Central message routing for MQTT and HTTP modes
- Handles encryption/decryption via EncryptionService
- Manages persistent message queue with retry logic (exponential backoff)
- Coordinates between multiple endpoints
- Supports QoS levels for MQTT

**LocationService** (`data/services/location_service.dart`)
- Wraps geolocator for GPS tracking
- Supports 4 monitoring modes:
  - Quiet (0): No automatic updates
  - Manual (1): User-initiated only
  - Significant (2): Significant location changes
  - Move (3): Continuous tracking
- Foreground and background location support

**GeofencingService** (`data/services/geofencing_service.dart`)
- Region monitoring for enter/exit events
- Manual distance-based checking against active regions
- Publishes transition messages via MessageProcessor
- **Cross-platform support:**
  - **Mobile**: Foreground and background geofencing
  - **Web**: Foreground-only geofencing (while app is running)
    - Automatically checks location updates against defined regions
    - Fires enter/exit events when transitions occur
    - Works perfectly for active tracking use cases

**BatteryService** (`data/services/battery_service.dart`)
- Monitors device battery level and charging state
- Provides battery information for location messages
- Platform-specific implementations:
  - **Web**: Uses Battery Status API with feature detection (`battery_service_web.dart`)
    - Checks `navigator.getBattery()` availability before use
    - Subscribes to `levelchange` and `chargingchange` events
    - Falls back to default values if API unavailable
  - **Mobile**: Simulated data (TODO: integrate battery_plus package)
- Uses conditional imports to load platform-specific code
- Periodic polling (5 min) with event-driven updates on web

### Platform Detection

**PlatformUtils** (`core/utils/platform_utils.dart`)
- Cross-platform detection utility class
- Static methods for checking current platform:
  - `isWeb` - Running in web browser
  - `isMobile` - Android or iOS
  - `isAndroid` - Android platform
  - `isIOS` - iOS platform
  - `isDesktop` - Windows, macOS, or Linux
- Feature capability detection:
  - `supportsBackgroundLocation` - Background tracking available (mobile only)
  - `supportsNotifications` - Local notifications available (mobile only)
  - `supportsGeofencing` - Geofencing/region monitoring available (all platforms)
  - `supportsBatteryStatus` - Battery API available (all platforms)
- Use these checks to conditionally enable features or provide fallbacks
- Example usage:
  ```dart
  if (PlatformUtils.isWeb) {
    // Web-specific logic
  } else if (PlatformUtils.isMobile) {
    // Mobile-specific logic
  }
  ```

### Riverpod Provider Architecture

All services and repositories are provided via Riverpod providers in `domain/providers/app_providers.dart`.

**Provider Hierarchy:**
1. **Local Data Sources** - `settingsLocalDataSourceProvider` (overridden in main.dart)
2. **Repositories** - Use data sources, provide domain data
3. **Services** - Use repositories, implement business logic
4. **Stream/Future Providers** - Reactive data for UI consumption
5. **State Providers** - UI state (navigation, toggles, etc.)

**Important Provider Pattern:**
- Services depend on repositories via `ref.watch()`
- UI screens use `ref.read()` for one-time access
- UI screens use `ref.watch()` for reactive updates
- Providers are disposed automatically by Riverpod

### State Management

**Data Repositories:**
- `ContactsRepository` - In-memory with Stream-based change notification
- `SettingsRepository` - SharedPreferences-backed configuration
- `WaypointsRepository` - SharedPreferences with JSON serialization
- `RegionsRepository` - SharedPreferences with JSON serialization
- `LocationRepository` - Current location state
- `EndpointStateRepository` - Connection state tracking
- `MessageQueueRepository` - Persistent message queue

**UI State:**
- Bottom navigation index via `selectedNavigationIndexProvider`
- Tracking enabled/disabled via `trackingEnabledProvider`
- Monitoring mode via `monitoringModeProvider`
- Connection mode via `connectionModeProvider`

### OwnTracks Protocol

**Message Types** (in `data/models/message/`)
- `MessageLocation` - GPS location updates
- `MessageTransition` - Geofence enter/exit events
- `MessageWaypoint` - Waypoint definitions
- `MessageConfiguration` - Settings/config
- `MessageCmd` - Commands (e.g., "reportLocation")
- `MessageLwt` - Last will and testament
- `MessageCard` - Contact cards

**MQTT Topics:**
- Publish: `owntracks/{deviceId}/{trackerId}`
- Subscribe: `owntracks/{deviceId}/{trackerId}/+` (own commands)
- Subscribe: `owntracks/+/+` (all users)

**HTTP Mode:**
- POST location updates to configured endpoint
- Polling for incoming messages

### Important Implementation Details

**Initialization Sequence** (in `main.dart`):
1. Initialize Flutter bindings
2. Initialize SharedPreferences
3. Create SettingsLocalDataSource
4. Override `settingsLocalDataSourceProvider`
5. Launch app with ProviderScope

**Permission Handling:**
- Location permissions checked via PermissionService
- Background location requires additional permission
- Notification permission for foreground service
- Permissions requested in TrackingSettingsScreen

**Background Tracking:**
- Uses flutter_background_service for continuous tracking
- Foreground service notification on Android
- Background location permission required
- Battery optimized via monitoring modes and smart filtering

**Encryption:**
- ChaCha20-Poly1305 AEAD encryption via cryptography package
- Keys stored in flutter_secure_storage
- Encryption enabled/disabled per configuration
- Applied to both MQTT and HTTP messages

### Common Development Tasks

**Adding a New Screen:**
1. Create screen file in `presentation/screens/`
2. Add route in `core/router/app_router.dart`
3. Wire up navigation in UI components
4. Connect to providers via `ref.watch()` or `ref.read()`

**Adding a New Repository:**
1. Create repository class in `data/repositories/`
2. Define provider in `domain/providers/app_providers.dart`
3. Inject into services/screens via provider dependency
4. Write unit tests in `test/data/repositories/`

**Adding a New Service:**
1. Create service class in `data/services/`
2. Define dependencies (repositories, other services)
3. Create provider in `domain/providers/app_providers.dart`
4. Wire dependencies using `ref.watch()`
5. Write unit tests with mocktail

**Modifying Settings:**
1. Add getter/setter to SettingsRepository
2. Add persistence in SettingsLocalDataSource
3. Update UI in appropriate settings screen
4. Settings automatically persist to SharedPreferences

### Testing Strategy

**Test Structure:**
```
test/
├── core/               # Core utilities tests
├── data/
│   ├── repositories/   # Repository unit tests
│   └── services/       # Service unit tests
└── presentation/       # Widget tests
```

**Testing with Riverpod:**
- Use `ProviderContainer` for provider testing
- Override providers with test implementations
- Use `mocktail` for mocking dependencies
- Widget tests use `ProviderScope` with overrides

**Current Test Count:** 130 tests passing

### Code Generation

`build.yaml` configures json_serializable, freezed, and riverpod_generator. Currently providers are defined manually in `app_providers.dart`. Run `flutter pub run build_runner build --delete-conflicting-outputs` after changes to generated code.

### Linting Rules

**Key Rules** (from `analysis_options.yaml`):
- `prefer_single_quotes: true`
- `avoid_print: true` (use AppLogger instead)
- `prefer_const_constructors: true`
- `always_use_package_imports: true`
- Generated files excluded: `**/*.g.dart`, `**/*.freezed.dart`

**Custom Linting:**
- `riverpod_lint` enabled for provider best practices
- `custom_lint` plugin enabled

### Logging

**AppLogger** (`core/utils/app_logger.dart`):
- Wraps the logger package
- Use `AppLogger.i()`, `AppLogger.d()`, `AppLogger.w()`, `AppLogger.e()`
- Never use `print()` or `debugPrint()` directly

### Known Issues and Future Work

**Phase 7 Complete** - Live services integrated:
- Tracking lifecycle (start/stop) functional
- Location publishing via MQTT/HTTP works
- Geofence transitions detected and published
- Permission flows implemented

**Phase 8 - Next Steps:**
- Add manual location publish button
- Implement configuration import/export
- Add waypoint sharing
- Final device testing
- App store preparation

**Dependencies Note:**
- `workmanager` commented out due to compatibility issues
- `qr_code_scanner` commented out due to AGP 8+ namespace issues
- Drift database prepared but not yet used (using SharedPreferences)

### Platform-Specific Notes

**Android:**
- MinSDK: Check `android/app/build.gradle`
- Uses Android location APIs via geolocator
- Foreground service for background tracking
- Flutter background service for persistent tracking

**iOS:**
- Check `ios/Runner/Info.plist` for required permissions:
  - NSLocationWhenInUseUsageDescription
  - NSLocationAlwaysAndWhenInUseUsageDescription
  - NSLocationAlwaysUsageDescription
- Background modes: location, fetch
- Uses iOS Core Location via geolocator

**Web:**
- Uses browser's Geolocation API via geolocator_web
- **Requires HTTPS** for location access in production (browsers block geolocation on HTTP except localhost)
- No background location tracking (browser security limitation)
- Location permission handled via browser's built-in permission prompt
- **Battery Status API** with feature detection:
  - Uses native browser Battery Status API when available
  - Automatically detects API support before using it
  - Falls back to default values (100%) if API is deprecated/unavailable
  - Real-time battery events when supported (levelchange, chargingchange)
  - Implementation in `data/services/battery_service_web.dart`
- **Geofencing/Region Monitoring**:
  - ✅ Fully supported (foreground only)
  - Manual distance-based checking on each location update
  - Create, edit, enable/disable regions via UI
  - Automatic enter/exit event detection
  - Transition messages published via MQTT/HTTP
  - Works perfectly while app is running/visible
  - No background geofence triggers (browser limitation)
- No local notifications support in background
- Storage: SharedPreferences uses browser's localStorage
- Secure storage uses localStorage (less secure than mobile platforms)
- MQTT/HTTP protocols work the same as mobile
- Responsive UI works on desktop and mobile browsers
- Configuration:
  - `web/index.html` - Main HTML template
  - `web/manifest.json` - PWA manifest (installable web app)
  - Icons in `web/icons/` for PWA installation
- Deployment:
  - Build with `flutter build web --release`
  - Deploy to any static web host (Nginx, Apache, Firebase Hosting, etc.)
  - Set appropriate CORS headers for MQTT/HTTP endpoints if needed
- Known Limitations:
  - Flutter secure storage has limited Wasm support (warnings during build, but still works)
  - Background service packages (flutter_background_service) not supported
  - Push notifications limited to foreground only
