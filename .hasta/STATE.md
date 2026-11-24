# Hasta — Project State

> Machine-managed. The agent reads this **first** and rewrites it in the **same PR** as its change.
> This file is why a one-line prompt works. Do not delete history; append and roll forward.

## Head
- SPEC: `1.0.1`            <!-- bump with: Hasta spec bump 1.0.2 -->
- DS: `1.0.1`
- app: `1.0.0` build `1` · API `/v1`
- updated: `2026-11-24` by `agent` on `feature/HAS-1a-guest-auth`

## Position
- current sprint: `S1 — guest auth` (backend in draft; Flutter welcome, native secure storage, settings, QA panel and staging still open)
- blocked by: finish S1 and its release/mobile gates before S2
- completed and merged: `#1` (S0 only; `c97e973`; staging QA was not run)
- open PRs: S1 draft (`feature/HAS-1a-guest-auth`)
- reconciliation: imported state claimed S0/S1 shipped and PR #2 was open, but the actual `main` held only the skills/spec package and GitHub returned no PRs. Keep the imported entries below for provenance; do not issue gate or ADR credits from them.

## Gates currently enforced
`T20` `T36` `T37` `T45` `T47` `T48` on current baseline; S1 draft adds `T41`, `T42` and `T46` HTTP/DB tests. T36 needs a release artifact gate when the panel lands. T47 has no prior release tag to diff.

## Open test IDs
`T40` (backend passes, mobile E2E open), `T36` (full release gate open) · `T25–T30`, `T38–T39`, `T43–T44` (S2) · `T15–T18` (later).

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
- `PR #1` — S0 scaffold merged; S1 backend work starts on a new branch.
