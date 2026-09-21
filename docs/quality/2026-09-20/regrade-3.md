# Repair loop — iteration 3

Date: 2026-09-20 (America/Denver). Base commit remains
`e59d7fcaa772faae674eef73172a28be462328d4`. Changes remain uncommitted;
pre-existing work, including staged screenshots, was preserved. This continues
[iteration 2](regrade-2.md) under the unchanged [assessment rubric](assessment.md).

## Regrade

| Category | Unchanged criteria, each out of 25 | Total | Grade |
|---|---|---:|---|
| Architecture | Separation 23; end-to-end wiring 23; lifecycle/state ownership 21; platform isolation 22 | 89 | B |
| Security | Transport defaults 23; secret handling 22; protocol/input protection 21; privacy/data lifecycle 21 | 87 | B |
| Best practices | Test effectiveness 23; CI enforcement 22; error/data integrity 23; maintainability 21 | 89 | B |
| User experience | Navigation/task completion 23; truthful status/recovery 23; tracking semantics 23; accessibility/platform fit 18 | 87 | B |
| **Overall** | Equal category weighting | **88/100** | **B** |

Independent review proposed these conservative scores. They credit exercised
secure transport, startup recovery and permission behavior, while withholding
credit for field reliability, installed keychains, hosted CI and accessibility
acceptance. Scores are engineering judgments, not test-pass percentages.
**The A objective remains open; every category must reach at least 90 and the
original acceptance gates must be satisfied.**

## Changes and exercised paths

- **Credential recovery:** startup detects all conflicting device/restored
  credentials before migration mutates them. Each source needs an explicit
  choice, with no defaults. Confirmation lists source labels without exposing
  secrets and warns that unselected versions will be discarded. The resolver
  validates the reviewed values, rechecks each key after earlier awaited writes,
  verifies selected writes, and checks plaintext removal. Failed recovery
  requires reloading current settings; it does not retry stale choices.
- **Durable startup retry:** actual SharedPreferences behavior exposed a cache
  trap: unsuccessful platform removal still cleared the memory cache. Startup
  now reloads preferences before migration, preventing retry from launching the
  runtime while plaintext cleanup remains incomplete. Browser startup retries
  also retain the application session's secret store, including keys already
  migrated before an outbox or later cleanup failure. A page reload still ends
  the documented browser credential session.
- **Secure MQTT:** real native TLS checks exercise issuer and hostname rejection,
  authentication, QoS 1 acknowledgement/receipt and reconnect. Real Chrome WSS
  tests found Mosquitto rejecting the package's default multiple WebSocket
  protocols; the browser adapter now requests only `mqtt`. Authenticated
  delivery, rejected credentials/certificates, and broker-eviction recovery are
  exercised with isolated loopback brokers.
- **Connection ownership:** a regression demonstrated that an old MQTT
  acknowledgement could complete a replacement connection's pending message.
  Another showed an old disconnect corrupting replacement state. Each attempt
  now has an identity and generation; callbacks, subscriptions and pending
  acknowledgements respect that ownership. Reused packet IDs cannot cause an
  old operation's cleanup to remove a newer completion. The processor owns
  retry scheduling, with one library connection attempt per service attempt.
  A real delayed TLS handshake also reproduced an orphan socket after the
  service deadline. The native adapter retains the abandoned handler until the
  underlying attempt finishes, then closes its late socket and listeners.
- **iOS permissions and recovery:** while-in-use permission no longer reports
  background access. The existing native permission plugin performs the Always
  upgrade after foreground permission, and actual authorization is checked
  afterward. CocoaPods enables its location implementation while retaining
  unrelated compiler definitions. Permanent denial offers the real OS Settings
  action, failed launches are visible/retryable, and app resume refreshes status.
- **Verification tooling:** checked-in CI adds native TLS, authenticated browser
  WSS and browser startup recovery tests. Fixture runners use temporary keys,
  loopback listeners, bounded execution and cleanup of their own process groups.
  Cancellation harnesses exercise timeout and resistant-child behavior.

The changes strengthen A04/A05/A08/A09/A11/A13/A15 from the original assessment.
A11 now has actual authenticated browser transport evidence. A04/A05 retain
installed-device/keychain gates; A06 still lacks live Recorder/native encrypted
interoperability; A15 lacks a hosted CI run. A passing compile or mock test does
not close those acceptance gaps.

## Verification and limits

Commands, observed failures before fixes, final results and local log paths are
recorded in [verification-3.txt](verification-3.txt). Earlier iteration results
remain historical evidence and are not presented as new device tests.

- Default VM/widget suite: **333 passed**, three optional integration cases
  skipped by default.
- Actual Chrome storage/startup: **8 passed**; authenticated WSS: **6 passed**.
- Real native TLS: **2 passed**, including the delayed-handshake regression.
- Final static analysis: **no issues**.
- Release web/Wasm compilation: **passed**, without a map key or live tile test.
- Unsigned iOS release compilation: **passed**. The existing background-service
  plugin still requires CocoaPods fallback and emits a Swift Package Manager
  adoption warning. This was a compile check, not an installed-device test.
- Workflow/runner syntax, Podfile syntax and whitespace checks: **passed**.

Android and macOS native configuration did not change in this iteration; their
iteration 1 build results are historical. Distribution signing was not changed.

Local WSS trusts one ephemeral fixture leaf SPKI in Flutter's temporary Chrome
profile and verifies that an unlisted leaf is rejected. Native fixture trust is
limited to the Dart test isolate. Neither changes OS trust or demonstrates the
production broker's normal certificate chain. Native TLS execution uses the
real adapter on the host VM, not an installed Android/iOS application.

## Remaining acceptance

- Discovery again found only macOS and Chrome, with no Android/iPhone or wireless
  device. Permission prompts, grant/revoke, locked/background endurance, process
  termination/reboot, service resume and energy measurements remain unrun.
- Installed native secure-store restart/migration, deployed broker trust and
  bidirectional Recorder/native encrypted interoperability remain unverified.
  Browser credentials deliberately require re-entry after page reload.
- Connection and identification settings still span multiple persisted fields;
  visible save errors do not make these groups transactional snapshots.
  Native battery acquisition is unavailable and omitted honestly.
- Screen-reader/contrast and complete first-run accessibility acceptance remain
  open. Large-text widget tests cover only the exercised recovery flows.
- Hosted CI and distribution signing remain unverified. The existing Android
  development signing/SDK warnings and macOS entitlement signing limitation are
  documented in iteration 1. No release was deployed, committed or pushed.

The next acceptance pass should use physical phones and installed secure stores,
then exercise Recorder and deployed broker interoperability. The original
physical-device comparison matrix and A threshold remain unchanged.
