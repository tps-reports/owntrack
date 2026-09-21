# Repair and regrade plan

Baseline: [assessment.md](assessment.md), 50/100 F. Objective: at least 90 in **each** of architecture, security, best practices and user experience, with no open critical/high defects. This document is an implementation plan; future scores are not earned yet.

## Sequence and acceptance gates

### 1. Establish an honest, reproducible baseline

Addresses A13/A15 and prevents later fixes from hiding behind weak tests.

- Classify all 20 failures: stale expectation, missing provider/mock setup, or production bug. Correct expectations only against defined behavior; never weaken assertions to obtain green tests.
- Inject a transport/client factory into MQTT. Replace public-network unit tests with deterministic mocks and separate local-broker integration tests. Assert TLS, authentication, subscriptions and acknowledgment behavior directly.
- Fix analyzer configuration and make tests/analysis blocking in CI. Pin the tested Flutter toolchain. Configure map key delivery and validate the deployed artifact's map configuration without printing keys.
- Preserve tests of the actual settings widgets and interactions. Resolve the duplicated /settings route and implement the connection-test action.
- Record commands, exit codes and failures in a regrade ledger, retaining this baseline.

Acceptance: all existing valid behavior tests pass; deliberate transport/auth misconfiguration causes the appropriate tests to fail; CI refuses an intentionally failing test; settings navigation and Test Connection have real outcomes. Regrade best practices and UX; do not infer an A from this phase.

### 2. Protect location data and fix protocol contracts

Addresses A05/A06/A07/A11. Perform storage/schema migration before consumers.

- Introduce a SecretStore interface, native secure storage implementation and explicit browser session/persistence policy. Migrate existing secrets, verify writes, then remove old preference values; make failure recoverable.
- Use TLS/WSS/HTTPS by default, validating certificates and hostnames. Any explicit local-development exception must be visible and must not silently enable insecure production transport.
- Remove passwords, encryption keys, location payloads and credential-bearing URLs from logs, exports and deep links. Preserve only approved nonsecret configuration in shareable links.
- Implement the OwnTracks encryption wire contract and upstream interoperability vectors. Define an explicit migration for already queued ciphertext and key changes; never discard it silently.
- Repair HTTP POST behavior, identity/authentication and response dispatch, including 204, empty bodies, arrays and malformed input. Select an MQTT browser client for WSS and a native client for sockets/TLS.
- Validate incoming envelopes and coordinate/type/range bounds before repository mutation; define payload size limits and a command authorization policy before enabling remote commands.

Acceptance: native preference migration and browser persistence tests pass; synthetic secrets cannot be found in captured logs/URLs; invalid certificates are rejected; encryption vectors work both directions with Recorder/native OwnTracks; a POST-only endpoint and real browser WSS publish/receive pass. Regrade security and protocol-related architecture.

### 3. Complete lifecycle and durable delivery

Addresses A01/A08/A09/A10. Database migration and repository first, then services/providers, then UI.

- Add a transactional outbox (evaluate the already declared Drift dependency, including browser persistence) with explicit message identity, destination/configuration identity, creation time, retry schedule and delivery state.
- Migrate preference queue records transactionally. Preserve malformed records for recoverable diagnostics rather than silently dropping them. Define count/age/storage limits and user-visible expiry/dead-letter handling.
- Introduce an application coordinator that owns transport startup, connectivity recovery, incoming routing, battery acquisition and tracking lifecycle. Start receive subscriptions before acquisition; release all resources deterministically.
- Make start/stop/reconfigure idempotent and serialized. Stop/cancel pending retries on disposal and prevent late callbacks from mutating closed state. Test offline startup and configuration changes while messages remain queued.
- Keep outbox records until HTTP success or MQTT acknowledgment appropriate to QoS. Expect at-least-once delivery and explicitly tolerate duplicates; do not promise exactly-once across process death.
- Route incoming message types into contacts/waypoints/regions as supported, preserving sender identity. Provide initial repository snapshots and observable status.
- Return typed outcomes: acquisition failed, queued durably, sending, delivered, retrying, blocked. UI must report the actual state.

Acceptance: app-level integration test covers user publish → GPS → persisted outbox → real test endpoint/broker → acknowledgment → UI; inbound message → repository → contact marker works. Restart between enqueue and acknowledgment loses zero accepted records. Offline recovery drains correctly; double start does not duplicate publishes; stop prevents late publication. Regrade architecture, reliability and UX.

### 4. Make GPS behavior predictable on each platform

Addresses A02/A03/A04/A10/A12. Define and test a LocationSource interface and injected clock before adapter changes.

- Quiet: zero automatic acquisition/publishing; Manual: no persistent stream, explicit request only. Define whether Quiet allows explicit publication and document that choice. Significant and Move use distinct configurable acquisition/publishing policies.
- Separate minimum publication interval from motion/heading triggers and stationary heartbeat. Use location timestamps for freshness and a monotonic/injected clock for scheduling. Do not reuse stream timeLimit as a sampling frequency.
- Define behavior for invalid coordinates, stale timestamps, poor accuracy, approximate permission and mock fixes. Provide bounded one-shot acquisition, cancellation and actionable error state.
- Apply mode changes atomically to the running source. Handle service disable/re-enable, permission revocation, stream error/done and resume from OS settings.
- Android: implement foreground execution and notification lifecycle, required permissions and merged-manifest verification. iOS: purpose strings, background location capability and explicit CoreLocation settings. Validate OS constraints instead of claiming unconditional background survival.
- Replace simulated battery with OS readings; omit or label unavailable values.
- Add geofence hysteresis/accuracy handling and a defined initial-state policy. Render map circles in meters.

Acceptance: regression tests cover every mode, stationary stream survival, timeout/error recovery, live mode switching, start/stop races, noisy boundary traces, 359°→1° heading changes and stale fixes. Mobile/background acceptance requires the physical-device matrix below. Regrade all affected categories.

### 5. Finish user recovery and release verification

Addresses remaining A12–A15 and establishes release evidence.

- Show permission, location service, fix freshness/accuracy, transport, queue backlog and last confirmed delivery distinctly. Offer actionable recovery for each failure without technical stack traces.
- Disable duplicate in-flight actions. Keep tracking preferences and runtime status synchronized across navigation/restarts. Show an honest missing-map configuration state.
- Exercise first-run setup, connection edits, manual publish, tracking toggle, contact arrival, region/waypoint CRUD, offline use and recovery on narrow screens and browser.
- Verify keyboard navigation, screen-reader names/order, touch targets, contrast and large text. Fix defects with meaningful widget/semantics regression tests.
- Build supported release targets, run installed-app/browser smoke tests and publish no release whose platform claims exceed measured evidence. Update README/architecture claims to match behavior.

Acceptance: all advertised primary journeys succeed; failure paths are understandable and recoverable; no interactive placeholder or fabricated telemetry remains; release builds and field tests pass.

## Physical-device GPS comparison protocol

Compare candidate OwnTrack and the pinned Traccar build on the same hardware/OS/settings and repeat comparable routes. Prefer alternating runs to avoid one app's GPS requests helping another's passive provider. Record device model, OS, power mode, permissions, accuracy policy, app/build SHA and route/weather conditions. Traccar is a reference implementation, not ground truth.

| Scenario | Required observation |
|---|---|
| Foreground walking/driving | Time to first accepted fix, reported accuracy, route continuity, accepted/published counts and server timestamps |
| Stationary 30 minutes | Stream remains healthy; heartbeat meets configured policy; no false movement/geofence flapping |
| Screen locked/background 60 minutes | Notification/indicator correct, no unexplained gap beyond configured heartbeat plus documented OS tolerance |
| Network offline 30 minutes then restored | Every durably accepted record delivered or explicitly expired under policy; backlog visible; no silent loss |
| Permission denied/revoked/approximate; GPS off/on | Accurate state and actionable recovery, no stale “running” status |
| Process termination/relaunch and Android reboot | Durable queue/state behavior verified; respect force-stop restrictions and disclose restart requirements |
| Quiet/Manual during movement | Zero automatic publishes; one explicit Manual action produces at most one queued application message |
| Android without Play Services, supported iPhone | Fallback/provider and background behavior actually exercised |
| HTTPS browser: foreground/background/reload | Foreground behavior works, browser restrictions stated accurately, queue persistence follows declared policy |
| Energy runs: stationary and moving | Battery drain and wakeups measured over repeated comparable runs; investigate >10% relative regression against reference before choosing adapter |

Proposed field targets: zero silent loss of durably accepted messages in controlled fault tests; no unintended automatic publication in Quiet/Manual; status reflects injected terminal errors within one UI update cycle; no unexplained delivery gap over twice the configured heartbeat during controlled background runs. Fix acquisition time/accuracy thresholds per supported device/use case before testing, and preserve them across comparisons. Energy target is provisional until measurement establishes variance.

## Regrade loop — repeat until A, without changing the bar

1. Select the highest-priority open finding and write a regression test that demonstrates it. Add integration/native tests where mocks cannot prove the behavior.
2. Implement the complete path, including error reporting, migration and disposal. Run focused checks, then the required suite and affected release targets.
3. Re-review changed code against all four categories and verify the original finding is actually closed. A passing test of a mocked coordinator is not evidence that the real app wires that coordinator.
4. Append a dated regrade with commit, dirty-tree description, finding IDs closed/open, per-criterion scores, commands/results and links to field evidence. Never overwrite earlier grades or award projected points.
5. Fix regressions/new findings and repeat. If required hardware/service access is missing, record the evidence gap and withhold the A claim; do not treat elapsed time or an unrun check as success.
6. Finish only when each category is ≥90, all P0/P1 findings are closed, CI is blocking and green, supported release artifacts pass smoke tests, protocol interoperability passes, and physical-device/accessibility evidence satisfies the gates above.

Execution record starts at iteration 0: architecture 60, security 35, best practices 50, UX 55; overall 50/F. Subsequent execution records follow below.


## Iteration 1 execution record

The interrupted implementation was resumed on 2026-09-20. See
[regrade-1.md](regrade-1.md) for changes, exercised regression paths, unchanged
rubric scoring and remaining gates. The iteration 1 provisional score was 79.25/C
(architecture 83, security 78, best practices 80, UX 76). The A objective is still
open; no physical Android/iPhone devices were available for field acceptance.

## Iteration 2 execution record

The continuation adds selected-message export/discard/retry, migration conflict
preservation, browser storage lifecycle recovery, configurable publication with
monotonic-clock coverage, independent geofence acceptance retries, and visible
settings persistence failures. Independent review identified stale delivery
snapshots after discard and overlapping-region failure loss; both have failing-
before/passing-after regressions and were re-reviewed.

See [regrade-2.md](regrade-2.md) and [verification-2.txt](verification-2.txt).
The provisional grade is **85.75/B** (architecture 88, security 83, best practices
87, UX 85). The full suite passes 293 tests; six real Chrome storage tests and a
real loopback broker check pass. Analysis and release Wasm compilation pass.
The A objective remains open pending the unchanged acceptance gates, including
physical devices, secure transports, native secrets and accessibility.

## Iteration 3 execution record

This continuation adds explicit startup credential-conflict recovery, verified
cleanup with durable-preferences reload, browser session-secret retention across
startup failures, real native TLS and authenticated Chrome WSS integration, and
correct iOS Always authorization with OS Settings recovery. Independent review
found stale MQTT callbacks completing replacement deliveries and a native socket
leak after a late TLS handshake; both have observed failing-before/passing-after
regressions. The browser handshake now uses the single MQTT subprotocol required
by the exercised Mosquitto broker.

See [regrade-3.md](regrade-3.md) and [verification-3.txt](verification-3.txt).
The provisional grade is **88/B** (architecture 89, security 87, best practices
89, UX 87). Verification passes 333 VM/widget tests, eight Chrome storage/startup
tests, six authenticated WSS tests and two native TLS tests. Analysis, release
Wasm and unsigned iOS compilation pass. The original A objective remains open;
device discovery still finds only macOS and Chrome, and physical-device,
installed-keychain, deployed-broker/Recorder, accessibility and hosted-CI
acceptance evidence is still required.
