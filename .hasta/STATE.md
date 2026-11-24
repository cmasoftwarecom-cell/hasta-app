# Hasta — Project State

> Machine-managed. The agent reads this **first** and rewrites it in the **same PR** as its change.
> This file is why a one-line prompt works. Do not delete history; append and roll forward.

## Head
- SPEC: `1.0.1`            <!-- bump with: Hasta spec bump 1.0.2 -->
- DS: `1.0.1`
- app: `1.0.0` build `1` · API `/v1`
- updated: `2026-11-24` by `agent` in `PR #1` (`feature/HAS-0a-bootstrap`)

## Position
- current sprint: `S0 — scaffold` (in review)
- blocked by: S1 must branch from `main` after S0 is reviewed and merged; staging QA not run
- completed: none verified on `main` at scaffold branch point `514f138c`
- open PRs: `#1` (`feature/HAS-0a-bootstrap`, S0)
- merged: none verified on this repository
- reconciliation: imported state claimed S0/S1 shipped and PR #2 was open, but the actual `main` held only the skills/spec package and GitHub returned no PRs. Keep the imported entries below for provenance; do not issue gate or ADR credits from them.

## Gates currently enforced
S0 candidate: `T20` `T36` `T37` `T45` `T47` `T48`; T36/T37 fail closed while quick-test and OAuth are absent, and need artifact/behavioral coverage when those features land. T47 has no prior release tag to diff. `T46` is deferred to S1 with device-bound refresh.

## Open test IDs
`T40–T42`, `T46` (S1) · `T25–T30`, `T38–T39`, `T43–T44` (S2) · `T15–T18` (later).

## Imported decisions (not all present on this branch)
| Item | Status | ADR |
| --- | --- | --- |
| Prisma as ORM | accepted (spec recommended choice) | — |
| `profiles.field_hlc`, `sessions.revoked_reason`, `sessions.last_seen_at` | accepted; HLC merge test **now** | — |
| native device-id channel + `path_provider` for Drift | accepted | ADR-0004 |
| idempotency keyed by scope for pre-auth endpoints | accepted conditionally (device-scoped keys not replayable cross-device; tests both directions) | — |
| `text.link` → `bg.brand`/`bg.brandPressed`/`bg.brandDisabled` | accepted | ADR-0005 closed by ADR-0006 |
| S0 Prisma representation and build tooling | proposed on the S0 branch | [ADR-0007](../decisions/adr/ADR-0007-bootstrap-tooling.md) |

## `[PROPOSAL]` values — remote-config only (confirm key names in next report)
device token 365 d · refresh 30 d · guest-create 3/device/hour · device-register 10/hour · line-height floor on display/h1 · opener limit 3 · dormant 7 d · Super Like / Undo caps · feed + dating score weights · retention 30 d purge / 35 d backup / 30 d evidence · KPI targets

## Conditional / deadlines
- background outbox drain → **by S3**; until then no doc may say "offline-first"
- Zawgyi detect→convert → S3 (stub shipped in S1; legacy input must never be stored as Zawgyi)
- pepper re-hash / rotation job → S9, before any real user onboarding
- blocking before store submission: legal sign-off on retention windows (SPEC §20)

## Next one-line prompt
```
Hasta S1
```

## Changelog (append one line per merged PR)
- Imported, unverified: `PR #1` — bootstrap S0+S1, reported merged with 400-line rule waived once
- Imported, unverified: `PR #2` (planned) — T37 rewrite + T46/T47/T48 + device-bound refresh + brand tokens
- `2026-11-24` — reconciled imported state against `main`; actual S0 scaffold submitted for review.
