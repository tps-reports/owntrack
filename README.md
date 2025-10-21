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

## Next Steps - Phase 1: Data Layer

- Define all message types (location, transition, waypoint, config)
- Implement Friend, Waypoint, and Region models
- Set up Drift database schema
- Create repositories for contacts, waypoints, regions, settings
- Implement JSON serialization with freezed

## Dependencies

### Core
- **flutter_riverpod**: State management
- **go_router**: Navigation
- **logger**: Logging framework

### Data
- **drift**: SQLite database
- **shared_preferences**: Settings storage
- **freezed**: Immutable models
- **json_serializable**: JSON serialization

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
