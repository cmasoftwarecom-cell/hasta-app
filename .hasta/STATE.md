# Hasta — Project State

> Machine-managed. The agent reads this **first** and rewrites it in the **same PR** as its change.
> This file is why a one-line prompt works. Do not delete history; append and roll forward.

## Head
- SPEC: `1.0.1`            <!-- bump with: Hasta spec bump 1.0.2 -->
- DS: `1.0.1`
- app: `1.0.0` build `1` · API `/v1`
- updated: `2026-11-25` by `agent` on `feature/HAS-1a-guest-auth`

## Position
- current sprint: `S1 — guest auth` (five review fixes implemented in draft PR #2)
- blocked by: iOS native CI verification, a verified staging HTTPS `/health` response, deployed staging QA, and review of PR #2 before S2
- completed and merged: `#1` (S0 only; `c97e973`; staging QA was not run)
- open PRs: [#2](https://github.com/cmasoftwarecom-cell/hasta-app/pull/2), S1 draft (`feature/HAS-1a-guest-auth`)
- reconciliation: imported state claimed S0/S1 shipped and PR #2 was open, but the actual `main` held only the skills/spec package and GitHub returned no PRs. Keep the imported entries below for provenance; do not issue gate or ADR credits from them.

## Gates currently enforced
`T20`, `T36`, `T37`, `T45`, `T47`, `T48` and design token checks. S1 adds `T40` guest app/repository and server lifecycle tests, plus `T41`, `T42`, and `T46` HTTP/DB tests. `T36` adds default/opted-in widget checks and a QA-positive Android debug APK vs release APK check. `T47` lints and diffs the OpenAPI contract against a release tag from the base history or the pinned S1 bootstrap under ADR-0010.

## Open test IDs
T37 uses a route and identity-module boundary check with local behavioural fixtures for signature, issuer, audience, expiry, nonce, and verified email. The CI entry point fails closed on linking/recovery completion or raw ID-token verification until S2 wires the real server verifier; S1 adds no Google routes, dependency, or runtime integration.

T46 exercises an active refresh token on a different enrolled binding and checks HTTP 401, committed revocation of the entire family, and survival of unrelated sessions in isolated PostgreSQL 16.

The S1 T40 widget suite includes a local 320×568, 200%-text-scale regression for English and Myanmar Guest Profile and Settings. The title row grows beyond its token-based minimum and the profile copy wraps without a line cap. This is separate from native and staging QA.

`T40/T41` iOS Simulator uses real device-channel, Keychain and HTTP code against an isolated PostgreSQL 16 API. The first native run did not reach the guest profile; the [diagnostic rerun](https://github.com/cmasoftwarecom-cell/hasta-app/actions/runs/45393944704/job/138444624882) timed out while loading the test suite after building the app, so it did not verify either ID. `T36` passed the iOS debug/unsigned release artifact comparison. Deployed staging QA is separate: HTTPS `/health` has not been verified, and no staging fixtures were seeded. See the [origin runbook and 12 checks](../docs/qa/s1-staging.md). Physical-device and signed distribution testing are not implied. · `T25–T30`, `T38–T39`, `T43–T44` (S2) · `T15–T18` (later).

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

## `[PROPOSAL]` values — remote-config only (confirm key names in next report)
device token 365 d · refresh 30 d · guest-create 3/device/hour · device-register 10/hour · line-height floor on display/h1 · opener limit 3 · dormant 7 d · Super Like / Undo caps · feed + dating score weights · retention 30 d purge / 35 d backup / 30 d evidence · KPI targets

## Conditional / deadlines
- background outbox drain → **by S3**; until then no doc may say "offline-first"
- Zawgyi detect→convert → S3 (stub shipped in S1; legacy input must never be stored as Zawgyi)
- pepper re-hash / rotation job → S9, before any real user onboarding
- blocking before store submission: legal sign-off on retention windows (SPEC §20)

## Next one-line prompt
```
Hasta fix Tokens
```

## Changelog (append one line per merged PR)
- Imported, unverified: `PR #1` — bootstrap S0+S1, reported merged with 400-line rule waived once
- Imported, unverified: `PR #2` (planned) — T37 rewrite + T46/T47/T48 + device-bound refresh + brand tokens
- `2026-11-24` — reconciled imported state against `main`; actual S0 scaffold submitted for review.
- `PR #1` — S0 scaffold merged; S1 backend work starts on a new branch.
