# Hasta — Project State

> Machine-managed. The agent reads this **first** and rewrites it in the **same PR** as its change.
> This file is why a one-line prompt works. Do not delete history; append and roll forward.

## Head
- SPEC: `1.0.1`            <!-- bump with: Hasta spec bump 1.0.2 -->
- DS: `1.0.2` (canonical DTCG)
- app: `1.0.0` build `1` · API `/v1`
- updated: `2026-11-25` by `agent` on `fix/flutter-ci-sdk`

## Position
- current sprint: `S2 — Gmail linking and device change` (linking, sessions and recovery core, Android T30 harness, QR transfer core and opt-in Android debug QR display/scanner with a physical-device T28 harness; sprint remains open)
- blocked by: explicit recovery entry outside Welcome, native Android/iOS recovery and signed HTTPS association QA, iOS QR capture policy, physical Android T28, realtime transfer notifications, mobile Linked Accounts and Security/Devices flows, and SPEC §17.2 friends. Keep Gmail linking, recovery and QR transfer disabled by default; do not start S3 or Premium.
- active QA scope: local only, using mock data or isolated local databases. Remote staging is outside this QA sequence and does not block S2; prior staging evidence and the runbook are retained below. This does not waive release QA or change any test gate.
- completed and merged: `#1` (S0 only; `c97e973`; staging QA was not run); [#2](https://github.com/cmasoftwarecom-cell/hasta-app/pull/2) (S1 plus partial S2; `16282e5`)
- open PRs: [#3](https://github.com/cmasoftwarecom-cell/hasta-app/pull/3) (Gmail Link); [#4](https://github.com/cmasoftwarecom-cell/hasta-app/pull/4) (Security & Devices)
- reconciliation: imported state claimed S0/S1 shipped and PR #2 was open, but the actual `main` held only the skills/spec package and GitHub returned no PRs. Keep the imported entries below for provenance; do not issue gate or ADR credits from them.

## Gates currently enforced
`T20`, `T36`, `T37`, `T45`, `T47`, `T48` and design token checks. S1 adds `T40` guest app/repository and server lifecycle tests, plus `T41`, `T42`, and `T46` HTTP/DB tests. `T36` adds default/opted-in widget checks and a QA-positive Android debug APK vs release APK check. `T47` lints and diffs the OpenAPI contract against a release tag from the base history or the pinned S1 bootstrap under ADR-0010.

## Open test IDs
T37 uses a route and identity-module boundary check with local behavioural fixtures for signature, issuer, audience, expiry, nonce, and verified email. S1 had no Google runtime integration. S2 wires the server verifier into the existing fail-closed gate and uses locally signed tokens; HTTP tests map T37/T38/T39 for authenticated linking, no merge, and server proof verification. The sessions tests cover account scope, family revocation, current-session replay, and other-device revocation. These do not qualify the S2 mobile or recovery gates.

P1-T37-MOBILE-GATE adds a CI widget allowlist of unauthenticated accessibility tap/hold actions in English and Myanmar during restore, on welcome, after an offline guest attempt, and after sign-out. Only Guest (when enabled) and Privacy are allowed; the separate build-gated QA hold remains covered by T36. Local temporary Google outlined and Apple icon actions on welcome both caused failures. A temporary Connect Gmail action in signed-in Settings passed; no linking UI or integration ships in S1.

T46 exercises an active refresh token on a different enrolled binding and checks HTTP 401, committed revocation of the entire family, and survival of unrelated sessions in isolated PostgreSQL 16.

P0-DESIGN-TOKENS-GATE: `assets/design-tokens.json` is the canonical DS 1.0.2 DTCG source. The Section 2.3 gate was RED before the fix; committed fixtures reject a misplaced source, broken/circular aliases, missing brand states, low Myanmar line height, missing Myanmar fonts, missing CI wiring and generated Dart drift. A hard-coded pressed fill failed the static and EN/MM widget checks; removing the workflow check failed the CI wiring fixture. DTCG fills replace the old opacity overrides; legacy theme variants, spacing and text roles not supplied by DTCG remain compatibility data.

P1-FLUTTER-CI-SDK: dependency resolution failed with `intl 0.20.3` on the pinned Flutter 3.24.5/Dart 3.5.4 SDK. Restored the SDK's `intl 0.19.0` pin and the corresponding app lockfile; Flutter and the CI lockfile checks are unchanged. Strict local dependency resolution and localization generation are green. This does not grant native or staging QA credit.

The S1 T40 widget suite includes a local 320×568, 200%-text-scale regression for English and Myanmar Guest Profile and Settings. The title row grows beyond its token-based minimum and the profile copy wraps without a line cap. This is separate from native and staging QA.

`T40/T41` iOS Simulator uses real device-channel, Keychain and HTTP code against an isolated PostgreSQL 16 API. The first native run did not reach the guest profile; the [diagnostic rerun](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45393944704/job/138444624882) timed out while loading the test suite after building the app, so it did not verify either ID. `T36` passed the iOS debug/unsigned release artifact comparison. Deployed staging QA is separate: HTTPS `/health` has not been verified, and no staging fixtures were seeded. See the [origin runbook and 12 checks](../docs/qa/s1-staging.md). Physical-device and signed distribution testing are not implied. · `T25–T30`, `T38–T39`, `T43–T44` (S2) · `T15–T18` (later).

P0-T40-T41-IOS-AUTH-503: the [failing simulator job](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45593586792/job/139133766537) logged a broken pipe while loading policy values, then `/health` passed but the first Guest tap returned 503. The isolated test launcher now validates allowed policy values before listening and generates ephemeral credentials in the server process. A committed test rejects an empty policy input and exercises iOS-shaped enrollment, creation, and same-device resume over loopback HTTP. Native T40/T41 still require a green simulator run with the existing database assertions.

P0-T40-T41-IOS-NATIVE-FAIL: the [failed run](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45596133520/job/139142558785) built successfully, then timed out loading the Dart suite. CI now runs the same Dart target through hosted XCTest and requires one explicit passing scenario from Flutter's native results bridge. The bridge wait is bounded, and the isolated PostgreSQL assertions still run after the simulator test. A green macOS simulator run is still required.

S1 verification update: [CI for `4d4220c`](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45602004923) passed, including [hosted T40/T41 XCTest](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45602004923/job/139163019376) and its isolated PostgreSQL assertions. This clears the previous simulator prerequisite, not signed distribution or physical-device QA. `T25–T30`, `T43–T44` remain open for S2. No local QA APK has been produced.

S2 recovery: T30 backend and Flutter repository tests cover returning the same account on a proved fresh installation, retiring old credentials and bindings, rejecting an unlinked subject even when its email matches, and preserving retry scope. T37/T39 also exercise code-only recovery with locally signed Google proofs. T30 native reinstall/browser callback and full mobile QA remain open; no native entry, HTTPS app-link association, or live OAuth flow was tested.

S2 native recovery follow-up: Android App Link and iOS Universal Link handlers now connect to the Flutter recovery coordinator. The [Android T30 runbook](../docs/qa/t30-native-recovery.md) adds an opt-in two-emulator reinstall and external Chrome callback against a disposable local database. Flutter callback/channel tests, the loopback fixture and database postcondition, and the T37 Welcome gate passed locally. This Linux workspace has no mobile emulator attached; the Android native run, signed HTTPS associations, iOS reinstall, and the recovery entry outside Welcome remain open.

S2 QR transfer: T25 expiry, T26 concurrent single-use, T27 old-device signed approval, and T29 occupied-target protection are covered by isolated PostgreSQL HTTP tests. T28 server-side revocation and Flutter repository credential/cache removal are covered; the native two-device user journey remains open. The server and Flutter repository implement a start → scan → signed confirm → claim sequence; the release flag stays off. See ADR-0015 for the native and presentation limits.

S2 QR presentation: opt-in Android debug Settings and launcher shortcut use `FLAG_SECURE` and an on-device QR-only camera decoder. Flutter widget checks cover protection before issuance, camera denial, hiding the QR on background or scan, and the Myanmar receiver at 320×568 with 200% text scale. The local HTTP fixture confirmed the binding/session postconditions in disposable PostgreSQL 16. The [local T28 runbook](../docs/qa/t28-native-transfer.md) checks the secure window, optical scan and OS approval, old-device Welcome after relaunch and the database postconditions. The native runner stopped at preflight because no authorized Android devices were connected; native T28 remains open. ADR-0016 records debug-only scope and the iOS hold.

S2 local build verification: Flutter analysis and 22 tests passed in both default and QA configurations. Local Android debug and release APKs passed the T36 artifact check with the same QA feature defines: debug includes the scanner and camera permission; release excludes both and the quick-test fixtures. Neither artifact verifies physical T28 or signed distribution.

P0-QR-ROLLOUT-GATE: The regular server cannot enable QR transfer via its feature flag. ADR-0015 now requires explicit native QR QA launcher opt-in, `HASTA_ENV=test`, a loopback HTTP listener, and a disposable loopback `hasta_test` PostgreSQL URL. T27 rollout regression covers all six transfer endpoints in blocked configurations and retains the existing positive local transfer journey. Server-verifiable hardware approval and native T28 remain open.

P1-QR-BACK-CANCEL: Android Back and Close now share the sender's rejection path for a live, unsigned offer. The QR disappears immediately; a failed rejection leaves the screen open to retry without regenerating it. T27 widget regressions cover waiting, repeated Back while in flight, and retry via Close. See ADR-0016; physical T28 remains open.

P1-QR-CLAIM-EXPIRY: After a registered scan, both local timeout and a server claim-expiry response show conditional en/my guidance: if approved, close and use the existing Welcome action on the replacement; otherwise start a new transfer on the old device. No automatic sign-in, TTL extension, or API change. T25/T28 widgets cover both expiry paths and expiry before a registered scan; the loopback PostgreSQL regression checks that the replacement resumes the same account after a confirmed transfer without creating a second account. Physical T28 remains open.

P2-QR-TITLE-SCALE: Sender and receiver titles are wrapping accessibility headings inside the safe, scrollable content, using the existing screen-title token. Four T28/DS widget cases (en/my at 320×568 and 200%) failed with the old AppBar's scale cap and passed with full scaling, safe-area bounds, and ≥1.65 line height. QR contents and actions are unchanged. The local native T28 runner still requires two authorized Android phones.

P1-QR-START-RETRY: The mobile repository now scopes the pending QR-start key to the source account and enrollment request, not the rotating access token. A T25/T27/T28/T29 loopback repository regression first records a committed offer with an ambiguous 503 response, then refreshes access and checks that the retry sends the same key, receives the original offer and expiry, and clears the pending record. The server, API, 120-second TTL, and local-only rollout gate are unchanged. Native T28 remains open.

P2-WELCOME-RECOVERY-COPY: Welcome now renders the guest account-loss warning as plain text. English states that an account cannot be recovered if the device is lost without Gmail linked; Myanmar uses the normative SPEC §14.7 copy. T30/T40 widget regressions cover both locales at 320×568 and 200% text scale; T37 still permits only Guest and Privacy actions on Welcome. This does not expose recovery or qualify native T30.

## Imported decisions (not all present on this branch)
| Item | Status | ADR |
| --- | --- | --- |
| Prisma as ORM | accepted (spec recommended choice) | — |
| `profiles.field_hlc`, `sessions.revoked_reason`, `sessions.last_seen_at` | accepted; HLC merge test **now** | — |
| native device-id channel + `path_provider` for Drift | accepted | ADR-0004 |
| idempotency keyed by scope for pre-auth endpoints | accepted conditionally (device-scoped keys not replayable cross-device; tests both directions) | — |
| `text.link` → `bg.brand`/`bg.brandPressed`/`bg.brandDisabled` | accepted | ADR-0005 closed by ADR-0006 |
| S0 Prisma representation and build tooling | proposed on the S0 branch | [ADR-0007](../decisions/adr/ADR-0007-bootstrap-tooling.md) |
| S1 pre-auth replay, credentials, policy injection and draft scope | draft | [ADR-0008](../decisions/adr/ADR-0008-guest-auth.md) |
| S1 installation proof; replay retention and state; secure storage dependencies and QA fixture scope | proposed in PR #2 | [ADR-0009](../decisions/adr/ADR-0009-s1-enrollment-and-mobile.md) |
| T47 frozen S1 contract until a previous release tag exists | proposed in PR #2 | [ADR-0010](../decisions/adr/ADR-0010-openapi-bootstrap-baseline.md) |
| Primary-button semantic fills and canonical DS 1.0.1 source | proposed in PR #2 | [ADR-0011](../decisions/adr/ADR-0011-primary-button-token-source.md) |
| S2 code-only Google consent, device proof, encrypted short-lived intent, rollout hold | proposed in PR #2 | [ADR-0012](../decisions/adr/ADR-0012-s2-google-link-boundary.md) |
| S2 lost-device recovery and inactive historical bindings, with a proved target installation | proposed in PR #2 | [ADR-0013](../decisions/adr/ADR-0013-s2-lost-device-recovery.md) |
| S2 native callback bridge and Android reinstall QA fixture | proposed in PR #2 | [ADR-0014](../decisions/adr/ADR-0014-s2-native-recovery-callback.md) |
| S2 hashed QR token, signed approval, atomic binding move and claim | proposed in PR #2 | [ADR-0015](../decisions/adr/ADR-0015-s2-qr-transfer.md) |
| S2 protected Android debug QR screen and scanner; physical T28 harness | proposed in PR #2 | [ADR-0016](../decisions/adr/ADR-0016-s2-protected-qr-ui.md) |

## `[PROPOSAL]` values — remote-config only (confirm key names in next report)
device token 365 d · refresh 30 d · guest-create 3/device/hour · device-register 10/hour · line-height floor on display/h1 · opener limit 3 · dormant 7 d · Super Like / Undo caps · feed + dating score weights · retention 30 d purge / 35 d backup / 30 d evidence · KPI targets

## Conditional / deadlines
- background outbox drain → **by S3**; until then no doc may say "offline-first"
- Zawgyi detect→convert → S3 (stub shipped in S1; legacy input must never be stored as Zawgyi)
- pepper re-hash / rotation job → S9, before any real user onboarding
- blocking before store submission: legal sign-off on retention windows (SPEC §20)

## Next one-line prompt
```
Hasta test T28 on two dedicated local Android phones
```

## Changelog (append one line per merged PR)
- Imported, unverified: `PR #1` — bootstrap S0+S1, reported merged with 400-line rule waived once
- Imported, unverified: `PR #2` (planned) — T37 rewrite + T46/T47/T48 + device-bound refresh + brand tokens
- `2026-11-24` — reconciled imported state against `main`; actual S0 scaffold submitted for review.
- `PR #1` — S0 scaffold merged; S1 backend work starts on a new branch.
