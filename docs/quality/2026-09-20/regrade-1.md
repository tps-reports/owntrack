# Repair loop — iteration 1

Date: 2026-09-20 (America/Denver). Base commit: `e59d7fcaa772faae674eef73172a28be462328d4`.
The evaluated changes are uncommitted. Existing README/CLAUDE/screenshot work was
preserved. This iteration resumes the task interrupted at its usage limit.
The fixed rubric is in [assessment.md](assessment.md); acceptance gates remain in
[repair-plan.md](repair-plan.md).

## Regrade

| Category | Unchanged criteria, each out of 25 | Total | Grade |
|---|---|---:|---|
| Architecture | Separation 22; end-to-end wiring 20; lifecycle/state ownership 19; platform isolation 22 | 83 | B |
| Security | Transport defaults 21; secret handling 20; protocol/input protection 21; privacy/data lifecycle 16 | 78 | C |
| Best practices | Test effectiveness 20; CI enforcement 19; error/data integrity 21; maintainability 20 | 80 | B |
| User experience | Navigation/task completion 21; truthful status/recovery 18; tracking semantics 19; accessibility/platform fit 18 | 76 | C |
| **Overall** | Equal category weighting | **79.25/100** | **C** |

These remain engineering judgments, not percentages derived from test counts.
**An A has not been earned.** Build success and mock-based tests cannot establish
background GPS reliability, native keychain behavior, or deployed WSS/TLS behavior.

## Implemented and exercised

- Startup opens the native secure store or explicit browser session store,
  migrates credentials, then opens the outbox. Storage failure renders a retry
  screen. Native writes/deletes verify keychain results; settings save failures
  stay on screen and remain retryable. Apple entitlements follow the installed
  secure-storage plugin's documented requirement.
- SQLite transactions and IndexedDB compare-and-swap protect durable queue
  acceptance and acknowledgement. Tests exercise restart, parallel writers,
  migration, malformed legacy preservation, cross-session refresh, and message
  identities that cannot be reused by late acknowledgements. Capacity rejection
  replaces silent eviction. Legacy destination-less records stay blocked.
- Application providers start delivery and route validated incoming locations
  into contacts. The composition test uses real repositories, services and
  providers with a mocked HTTP boundary; it exercises enqueue, POST response,
  acknowledgement removal, contact mutation and rejection of invalid coordinates.
- HTTP supports POST-only endpoints, authenticated identity headers, successful
  2xx responses, empty responses and validated response envelopes. A malformed
  response does not cause retransmission of an already accepted outgoing message.
- MQTT selects native TLS sockets or browser WSS, waits for the matching broker
  acknowledgement, omits payloads from logs, reconnects after idle disconnects,
  and cancels pending acknowledgements during teardown. A local Mosquitto test
  exercises actual QoS 1 acknowledgement and subscribed message reception.
- Secretbox follows the [OwnTracks encryption contract](https://owntracks.org/booklet/features/encrypt/) and matches an independently generated libsodium decryption vector.
  Invalid envelopes and authentication failures are rejected. Shared links omit
  credentials, encryption keys and potentially secret-bearing endpoints. Geofence
  diagnostics omit private region labels and coordinates.
- Quiet/Manual acquisition semantics and stationary stream survival have
  regression tests. Active mode selection reconfigures tracking. Stale manual
  fixes are rejected; concurrent manual actions enqueue once; stop cancels late
  manual acquisition. Native battery data is omitted when unavailable.
- Geofences establish initial occupancy without manufacturing a crossing and use
  accuracy margins. A regression test catches exit/reentry state loss. Region
  circles use metres. Manual publish reports “queued for delivery”; runtime
  delivery failures and backlog are visible.
- Test/analysis failures are blocking in the checked-in CI configuration. The
  toolchain is pinned and deployable map builds require the configured map key.
  This does not prove an actual hosted CI run; no changes were pushed.

## Verification

- Default VM/widget suite: **224 passed**, one optional broker test skipped.
- Separate Chrome IndexedDB and real local-broker tests: **one passed each**.
- `flutter analyze`: **no issues**.
- Final release compilation: **web, Wasm, Android, unsigned macOS and unsigned iOS passed**.
- Normal macOS release build: **blocked by ad-hoc signing with keychain entitlements**.

Final commands, summaries and build results are preserved in
[verification.txt](verification.txt). Regression failures were observed before
fixes for encryption format/envelope parsing, geofence reentry, outbox API and
identity persistence, destination isolation, encryption failure propagation,
MQTT acknowledgements, application runtime composition, live mode application,
manual-publication races, and private geofence diagnostics.

The Chrome storage and local-broker checks are separate from the default VM
suite. The broker test intentionally skips unless its local port is supplied.
No public MQTT broker, user credentials, or production deployment was used.

The Android merged release manifest contains background/fine/coarse location,
foreground-service-location permissions, and a nonexported
`com.baseflow.geolocator.GeolocatorLocationService` with service type `location`.
Unsigned Apple builds are compile checks, not installed-device evidence. The normal macOS release command is blocked by its existing ad-hoc signing configuration after adding the required keychain capability; a development signing configuration must be selected before native runtime acceptance.
Mapless compile checks do not verify live tile loading.

## Remaining gates and known limitations

| Gate | Current limitation / evidence required |
|---|---|
| A01 / A09 lifecycle | Provider-level delivery passes; full installed-app GPS → durable storage → server → UI fault/restart journeys remain unverified. |
| A04 native tracking | Only macOS and Chrome are connected. Android/iPhone permission revocation, lock/background endurance, process/reboot and energy runs remain required. |
| A05 secrets / TLS | Actual native keychain restart/migration and certificate-rejection integration tests remain required. Browser session policy is explicit; web storage is not claimed to be an OS keychain. |
| A06 interoperability | Independent inbound libsodium vector passes. Live Recorder/native OwnTracks interoperability in both directions is still required. Legacy ciphertext is preserved but has no automatic repair flow. |
| A08 / A10 recovery | Outbox never silently expires accepted data. Blocked legacy/destination records are visible, but a user-facing export/recovery workflow and configurable retention/publication policy remain outstanding. |
| A11 browser transport | Browser adapter compiles; actual WSS authentication, publish/receive and reconnect against a configured secure broker remain required. |
| GPS policy | Freshness/accuracy gates and fixed interval/distance/heartbeat exist; full injected-clock trajectory/heading tests, user-configurable policies and OS service-resume tests remain outstanding. |
| Native telemetry | Native battery is omitted, not simulated. Real native battery acquisition has not been added. |
| UI/accessibility | No completed screen-reader, large-text/contrast or full first-run browser/mobile journey audit. Contact routing currently supports location messages; remote commands remain disabled. |
| CI/release | Hosted CI has not run. Android builds warn that SDK 36 is below resolved plugin SDK 37 requirements and Kotlin 2.2.20 support is nearing deprecation. Existing Android debug signing is unsuitable for distribution. Apple compile checks are unsigned; macOS keychain capability requires a configured development signer for the normal release build. |

The initial overlapping Android build encountered generated integration-plugin
registration mismatch. Rebuilding Android alone succeeded. Final verification
runs Flutter commands sequentially to avoid generated-file races.

Next iteration should finish recoverable blocked-message handling and tracking
policy coverage, then execute the physical-device and secure-broker acceptance
matrix. Preserve the original A threshold; do not promote this score based on
unrun field tests.
