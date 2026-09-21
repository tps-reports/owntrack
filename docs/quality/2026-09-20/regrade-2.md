# Repair loop — iteration 2

Date: 2026-09-20 (America/Denver). Base commit remains
`e59d7fcaa772faae674eef73172a28be462328d4`. Changes remain uncommitted;
pre-existing documentation, screenshots and implementation work were preserved.
This continues [iteration 1](regrade-1.md) under the unchanged
[assessment rubric](assessment.md).

## Regrade

| Category | Unchanged criteria, each out of 25 | Total | Grade |
|---|---|---:|---|
| Architecture | Separation 23; end-to-end wiring 22; lifecycle/state ownership 21; platform isolation 22 | 88 | B |
| Security | Transport defaults 21; secret handling 21; protocol/input protection 21; privacy/data lifecycle 20 | 83 | B |
| Best practices | Test effectiveness 22; CI enforcement 21; error/data integrity 23; maintainability 21 | 87 | B |
| User experience | Navigation/task completion 23; truthful status/recovery 22; tracking semantics 22; accessibility/platform fit 18 | 85 | B |
| **Overall** | Equal category weighting | **85.75/100** | **B** |

These are evidence-based engineering judgments, not test-pass percentages.
Independent review proposed these scores and identified two additional failure
cases, both repaired and re-reviewed. **The A objective remains open.** No
physical-device, deployed WSS, keychain, or accessibility acceptance is inferred
from automated tests or compilation.

## Changes and exercised paths

- **Outbox recovery:** Settings and the delivery banner open a real recovery
  screen. It refreshes durable records, distinguishes legacy/other/current
  destinations, and exports selected original envelopes through the platform
  share service after a privacy confirmation. Discard confirms a snapshot of
  IDs, preserves concurrent arrivals, and cannot recall an in-flight delivery.
  Failed operations remain visible and retryable. No automatic rerouting,
  decryption, conversion or import was added.
- **Discard race:** delivery revalidates durable membership before each
  transmission. A regression holds the first acknowledgement, discards a later
  record, then verifies that later record never publishes. A successful newer
  delivery also no longer clears the warning for older blocked records.
- **Migration integrity:** restored legacy queues merge into an existing durable
  outbox without overwriting records or colliding IDs. Identical records retain
  their multiplicity; retrying migration does not duplicate them. Conflicting
  secure/legacy credentials stop migration and retain both copies rather than
  deleting an unverified original.
- **Browser lifecycle:** real Chrome IndexedDB tests reproduce and verify
  recovery from blocked upgrades, failed opens, close-during-open and late
  callbacks. Closed stores reject new reads, and open connections release their
  database on another tab's version change.
- **Publication policy:** Tracking settings now persist interval, movement,
  heartbeat and optional heading thresholds together. The actual tracking
  provider reads the saved policy on each fix. An injected monotonic clock
  permits deterministic movement, stationary heartbeat, clock-correction,
  heading-wrap, quality and lifecycle tests. A provider integration test runs
  GPS events through changed settings, durable acceptance and a mocked HTTP
  boundary. Missing/nonfinite optional telemetry is omitted.
- **Geofence acceptance:** each failed queue insertion retains the original
  crossing for retry before a later crossing. Occupancy and observer events
  advance after acceptance. Failures are isolated per region so overlapping
  crossings are preserved. Actual region-edit paths invalidate old definitions.
  Pending, unaccepted crossings are still in memory; process death before
  durable acceptance can lose them.
- **Settings and UI:** rejected preference writes propagate errors. Identification
  saves prevent duplicate submission and back navigation while pending, report
  failures and allow retry. Widget tests exercise export/discard and errors,
  a narrow viewport with doubled text, and navigation from the constrained
  delivery banner. This is not a screen-reader or full accessibility audit.
- **CI:** the checked-in workflow adds blocking real Chrome storage and isolated
  loopback Mosquitto tests, with bounded readiness checks and broker cleanup.
  YAML and shell syntax were checked; hosted CI has not been run.

## Verification

- Default VM/widget suite: **293 passed**, one optional broker test skipped.
- Real Chrome IndexedDB suite: **6 passed**.
- Real loopback Mosquitto QoS 1 publish/receive: **1 passed**.
- Final `flutter analyze`: **no issues**.
- Final release web/Wasm compilation: **passed** (no map key; no live tiles tested).
- Workflow YAML/shell syntax and `git diff --check`: **passed**.

Command results and observed regression failures are recorded in
[verification-2.txt](verification-2.txt). Native platform configuration and
dependencies did not change in this iteration; the previous native compile
results are historical evidence, not a new installed-device test.

## Remaining acceptance and limitations

- Physical Android/iPhone permission grant/revoke, lock/background endurance,
  service-resume, process/reboot and energy tests remain required. OS fix timing
  controls heartbeat availability; a stale cached fix is never fabricated to
  satisfy a deadline. The final device discovery still found only macOS and
  Chrome, with no connected or wireless Android/iPhone devices.
- Native secure-store restart/migration and certificate-rejection integration,
  actual authenticated browser WSS reconnect/pub/sub, and live Recorder/native
  encryption interoperability in both directions remain unverified.
- Export preserves legacy ciphertext for external recovery; it does not make
  unknown legacy formats deliverable. Conflicting secure/legacy credentials
  require reconciliation before startup; there is no conflict-selection UI.
  Automatic expiry remains disabled: records stay until acknowledgement or
  explicit selected discard, subject to the existing capacity limit.
- Settings for connection and identification still span multiple persisted
  fields. Failed saves now report errors, but these settings groups are not
  transactional configuration snapshots.
- Native battery acquisition, complete first-run/device accessibility review,
  screen-reader/contrast sessions and hosted CI evidence remain outstanding.
- Android SDK/Kotlin warnings and development signing remain as documented in
  iteration 1. macOS keychain entitlements require an appropriate development
  signer; prior Apple builds were unsigned compile checks. No release was
  signed for distribution, deployed, committed or pushed during this iteration.

The next acceptance run should prioritize real devices and secure transport
interoperability, then address conflict recovery and remaining lifecycle/UI
gaps found by those runs. The fixed A threshold is unchanged.
