# OwnTrack application assessment

Date: 2026-09-20. OwnTrack HEAD: `e59d7fcaa772faae674eef73172a28be462328d4`. GPS comparison: local traccar_flutter HEAD `089249a159c02c93ff5aadcb5ab6b04a09ccdbad`.

Scope: source review of application composition, location acquisition, tracking, permissions, transports, queue, encryption, persistence, settings/map UI, tests and CI; comparison with Traccar's Dart, Kotlin and Swift tracking paths. OwnTrack's existing working-tree documentation/screenshot changes were preserved. This is an engineering production-readiness assessment, not a penetration test or a measured field GPS benchmark. No application fixes were made during this assessment.

## Baseline grade

Each category has four equally weighted criteria, each out of 25. Overall is the equally weighted mean of the four category totals. A = 90–100, B = 80–89, C = 70–79, D = 60–69, F <60. Scores are reviewer judgments supported by the evidence below, not test-pass percentages. Keep this rubric fixed for regrades.

| Category | Criteria and points | Total | Grade |
|---|---|---:|---|
| Architecture | Separation 20; end-to-end wiring 8; lifecycle/state ownership 12; platform isolation 20 | 60 | D |
| Security | Transport defaults 10; secret handling 5; protocol/input protection 12; privacy/data lifecycle 8 | 35 | F |
| Best practices | Test effectiveness 15; CI enforcement 5; error/data integrity 10; maintainability 20 | 50 | F |
| User experience | Navigation/task completion 18; truthful status/recovery 7; tracking semantics 10; accessibility/platform fit 20 | 55 | F |
| **Overall** | Equal category weighting | **50/100** | **F** |

An A requires **every category ≥90**, no open critical/high findings, and the acceptance evidence in the repair plan. Accessibility and field reliability are not fully verified; visual polish does not compensate for a broken tracking path.

Strengths: recognizable repository/service/UI separation, Riverpod injection, real waypoint persistence and reactive waypoint updates, useful map/waypoint regression tests, bounded handling of a macOS permission race, TLS certificate validation when enabled, and authenticated encryption primitives rather than homegrown cryptography. The principal problem is completing and validating the connections between these pieces.

## Executed verification

- `flutter test --reporter compact`: exit 1; **161 passed, 20 failed**, 181 total. Preserved output: [tests.log](tests.log).
- `flutter analyze`: exit 1; one warning, `analysis_options_deprecated_plugins` at `analysis_options.yaml:7:3`. Preserved output: [analyze.log](analyze.log).
- Failure distribution: MQTT service 1; HTTP service 9; tracking settings widgets 5; connection settings widgets 5. Some failures are stale expectations/test setup, not proof of a corresponding production defect. For example, the missing-host test expects idle while the implementation correctly reports error.
- MQTT tests attempt real network connections; credential/TLS tests merely expect failure, which does not prove credentials or TLS were configured correctly.
- No application integration_test suite was found. No release builds, physical-device drives, background endurance measurements, accessibility session, or Traccar test execution were performed. Traccar does contain Android test files; its documentation saying zero Android tests is stale.

## Findings and required fixes

Paths below are relative to the OwnTrack root; line references identify the assessed source snapshot. P0 = core functionality or location privacy blocker; P1 = high-priority reliability/security issue; P2 = quality issue. These are remediation priorities, not CVSS scores.

| ID | Priority | Evidence | Impact and required repair |
|---|---|---|---|
| A01 | P0 | `lib/main.dart:10`, `lib/domain/providers/app_providers.dart:140`, `lib/data/services/tracking_service.dart:43`, `lib/data/services/message_processor.dart:49` | No application caller starts MessageProcessor, and no application subscriber consumes incomingMessages. Starting tracking only starts GPS/subscriptions. Add a lifecycle coordinator that initializes transport/delivery and routes incoming typed messages to repositories, preserving MQTT topic identity. Test actual app composition through publish/receive/UI. |
| A02 | P0 | `lib/data/services/location_service.dart:132`, especially 191–218 | Quiet and Manual still create automatic position streams, and TrackingService publishes their events. Define exact mode semantics; Quiet must suppress automatic publishes and Manual must acquire only on user action. Apply changes to an active session immediately. |
| A03 | P1 | `lib/data/services/location_service.dart:210`, `:218`, `:239` | Significant/Move use stream timeLimit of five minutes/30 seconds; this is an inactivity timeout, not a sampling interval. A quiet device can lose its stream while status remains active. Remove this misuse, report terminal stream errors and recover deliberately. One-shot acquisition also needs a finite deadline. |
| A04 | P0 | `android/app/src/main/AndroidManifest.xml:1`, `ios/Runner/Info.plist:1`; no FlutterBackgroundService initialization in lib | App manifest lacks location permission declarations; iOS plist lacks location purpose strings/background mode. Generic LocationSettings do not establish an app-owned background lifecycle. Configure and verify native permissions, foreground service and background execution; inspect merged Android release manifest before claiming exact installed permissions. |
| A05 | P0 | `lib/data/repositories/settings_repository.dart:32`, `:44`, `:91`; `lib/data/services/app_launcher_service_web.dart:27`, `:71` | TLS defaults off; MQTT password/encryption secret live in SharedPreferences; base64 deep links include both and are logged. Move native secrets to secure storage with migration/removal of old values, establish explicit browser persistence policy, require secure transport by default, remove secrets from URLs/logs. Base64 is reversible encoding. |
| A06 | P1 | `lib/data/services/encryption_service.dart:14`, `:107` | ChaCha20-Poly1305 plus SHA-256 key derivation does not match OwnTracks' documented key padding and Recorder secretbox format. Local round trips cannot establish interoperability. Implement protocol-compatible encryption with upstream vectors; do not silently reinterpret queued legacy ciphertext. |
| A07 | P1 | `lib/data/services/http_service.dart:35`, `:94`, `:143` | GET reachability is required, periodic GET polling is used, POST response messages are ignored, and only 200/201 count as success. OwnTracks HTTP is POST-based with inbound data in responses and 2xx success. Implement compatible authentication/identity and typed response processing. |
| A08 | P0 | `lib/data/services/message_processor.dart:92`, `:205`, `:233`; `lib/data/services/mqtt_service.dart:147`; `lib/presentation/screens/map/map_screen.dart:561` | sendMessage swallows failures; UI says “Location published” after only enqueueing. MQTT publish returns before broker acknowledgment and the queue then deletes the item. Retry exhaustion deletes data. Distinguish durable queue acceptance from delivered state; retain until acknowledgment, expose errors/dead letters, and make retention explicit. |
| A09 | P1 | `lib/data/services/message_processor.dart:49`, `:60`, `:65`; `lib/domain/providers/app_providers.dart:67`; tracking/location start methods | Repeated starts can overwrite subscription handles; receive subscriptions are not retained for cancellation; nearly all disposable service providers omit disposal hooks. Failed initial connection never starts queue processing. Serialize lifecycle transitions, own every subscription/timer, and recover from offline startup. |
| A10 | P1 | `lib/data/repositories/message_queue_repository.dart:78`, `:95`; `lib/data/services/tracking_service.dart:124` | Whole-queue preference rewrites, silent corrupt-load handling, no transactional outbox/retention bounds. Tracking requires both 30 seconds and 50m after the first publish; stationary users have no heartbeat. Introduce durable transactions, explicit retry scheduling and configurable sampling/publishing policies. |
| A11 | P1 | `lib/data/services/mqtt_service.dart:1`, `:27`, `:54` | All platforms use dart:io/MqttServerClient; there is no browser MQTT adapter. Add platform selection and a browser WebSocket client. Verify real WSS publish/receive; a web build alone is insufficient. |
| A12 | P1 | `lib/data/services/battery_service.dart:107`; `lib/data/services/location_service.dart:230`; `lib/data/services/geofencing_service.dart:68` | Native battery is simulated (85%) or defaults to 100%; no accuracy/age acceptance policy or geofence hysteresis. Stop publishing invented battery readings. Reject/label stale or poor fixes and prevent boundary flapping; persist or explicitly define initial geofence state. |
| A13 | P1 | `lib/presentation/screens/settings/connection_settings_screen.dart:271`; `lib/presentation/screens/settings/settings_screen.dart:24`; `lib/core/router/app_router.dart` | Test Connection only shows a snackbar; direct /settings route reaches placeholder handlers. Main map Settings tab is separately wired and functional. Consolidate settings navigation and implement a real connection test with actionable failures. |
| A14 | P2 | `lib/presentation/screens/map/map_screen.dart:384`; `lib/domain/providers/app_providers.dart:181`, `:199` | Region CircleMarker radius is passed without meter mode; visual radius can differ from geofencing radius. Friends stream lacks an initial snapshot. Consolidate reactive state, render region radius in meters, and surface map-data errors rather than empty overlays. |
| A15 | P1 | `.github/workflows/web-build.yml`; `test/data/services/mqtt_service_test.dart:52` | CI explicitly ignores test failure, omits analysis, and builds without MAPS_API_KEY even though map configuration requires a compile-time value. Make quality checks blocking, use configured build inputs and smoke-test artifact capabilities. Add meaningful transport and lifecycle tests. |

Security scope note: payload/coordinate logging is present in transport and location services. Exact production log exposure depends on the logger filter/build environment; do not claim every debug log ships in release. Remove sensitive fields at the call sites regardless. Broker authorization/ACLs and deployed infrastructure were not audited.

## GPS comparison with traccar_flutter

Traccar is a tracking plugin, not a complete equivalent OwnTracks UI. The comparison below grades implementation capabilities, not presumed precision or battery performance.

| Concern | OwnTrack | Local Traccar implementation | Decision |
|---|---|---|---|
| Acquisition | Geolocator wrapper with generic settings | Android fused provider with LocationManager fallback; native CoreLocation on iOS | Both can use native fused/CoreLocation APIs. No evidence that a package swap alone improves GPS precision. |
| Android background | Dependency declared; lifecycle/configuration incomplete | TrackingService starts a foreground notification, manages wake lock and returns START_STICKY | Borrow explicit lifecycle ownership; do not promise survival after force-stop. |
| iOS background | Missing plist setup; generic stream | PositionProvider enables background location; TrackingController also starts significant-change monitoring | Use explicit CoreLocation policies and physical-device validation. |
| Sampling/publishing | Fixed 30s AND 50m; incorrect Quiet/Manual; timeout misuse | Configurable time OR distance OR heading triggers; fused request settings also affect event availability | Separate acquisition, publish minimum interval, distance/heading triggers and stationary heartbeat. |
| Offline operation | Preference-backed queue, five-attempt deletion, premature MQTT dequeue | Android Room and iOS Core Data; reconnect replay; Android age/count cleanup | Adopt transactional outbox and retry-until-ack within explicit retention policy. |
| Status/error feedback | Independent UI booleans; errors frequently only logged | Android sends status/position events; Android onPositionError and iOS didFailWithError are empty | Use one observable state machine; do not copy silent native error handling. |
| Battery | Simulated/default values | Native OS battery reads, but iOS unknown-state fallback is misleading | Represent unsupported/unknown honestly. Measure energy use. |
| Web | Browser geolocation; MQTT server client mismatch | dart:html geolocation; in-memory offline buffer; callback registration is a no-op | Keep a dedicated browser adapter; neither is proven production-ready across the advertised surface. |

Traccar evidence under `/Users/michael/webdav/coyote_forge/mhunter/traccar_flutter`:

- `android/src/main/kotlin/dev/mostafamovahhed/traccar_flutter/client/PositionProviderFactory.kt`: provider selection.
- Same directory, `FusedPositionProvider.kt`: LocationRequest settings and single-fix cached-location branch. The cached branch lacks an age check, even though the separate current-location request has one.
- `PositionProvider.kt`: time/distance/angle OR policy. Raw angle subtraction mishandles wraparound, e.g. 359° to 1°; interval units also need contract tests before reuse.
- `TrackingService.kt`: foreground service and wake lock; reports running before checking fine-location permission.
- `TrackingController.kt`: Room write/send/delete/retry and Flutter position forwarding; empty onPositionError.
- `DatabaseHelper.kt:288`: Android cleanup; defaults seven days/1,000 positions. This can discard undelivered data, so retention needs a visible policy.
- `ios/Classes/PositionProvider.swift`: background settings, permission request, force unwrap, empty error callback. This contradicts documentation claiming permissions are exclusively handled by the host.
- `ios/Classes/TrackingController.swift`: significant-change monitoring, Core Data buffering and retry; save uses try?, hiding failures. Starting significant-change monitoring alone does not prove its events are fully handled.
- `lib/web/traccar_flutter_web.dart`: memory-only buffer and deprecated browser imports.

**Recommendation:** retain OwnTrack's transport/domain model and introduce a LocationSource boundary. First correct Geolocator configuration and lifecycle; compare it against a hardened Traccar native acquisition adapter if background/device evidence demands it. Traccar currently owns its own protocol delivery, so dropping the entire plugin in would create competing queues/transports and would not fix OwnTracks compatibility. Reuse native design selectively, with license attribution and tests.

## External contract checks

- [Geolocator documentation](https://pub.dev/packages/geolocator): native provider mapping, platform configuration, and stream timeLimit semantics. Inactivity expiry cancels the stream; it is not an update interval.
- [OwnTracks HTTP protocol](https://owntracks.org/booklet/tech/http/): POST delivery, response messages, authentication and successful 2xx responses.
- [OwnTracks payload encryption](https://owntracks.org/booklet/features/encrypt/) and [Recorder implementation](https://github.com/owntracks/recorder/blob/master/http.c): key padding and secretbox interoperability.
- [CircleMarker units](https://pub.dev/documentation/flutter_map/latest/flutter_map/CircleMarker/useRadiusInMeter.html): configure meter-based radii explicitly.

Regrade execution and evidence requirements are in [repair-plan.md](repair-plan.md). This baseline remains F until changes and verification justify new scores.
