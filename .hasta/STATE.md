# Hasta — Project State

> Machine-managed. The agent reads this **first** and rewrites it in the **same PR** as its change.
> This file is why a one-line prompt works. Do not delete history; append and roll forward.

## Head
- SPEC: `1.0.1`            <!-- bump with: Hasta spec bump 1.0.2 -->
- DS: `1.0.1`
- app: `1.0.0` build `1` · API `/v1`
- updated: `2026-11-24` by `agent` in `PR #2`

## Position
- current sprint: `S2 — Gmail linking + QR transfer` (not started)
- blocked by: `PR #2 conformance patch must merge first`
- completed: `S0` (bootstrap) · `S1` (guest auth, device binding, sessions, welcome, test-mode panel)
- open PRs: `#2 conformance patch`
- merged: `#1 bootstrap (S0+S1)`

## Gates currently enforced
`T20` `T36` `T37` (narrowed: bans Google **sign-in routes** + weak ID-token verification; allows the Google auth library inside `modules/identity`) `T45` `T46` (cross-binding refresh → 401 + family revoke) `T47` (OpenAPI breaking-change diff vs previous tag, spectral lint, `docs/api/openapi.json`) `T48` (compose `postgres:16`)

## Open test IDs
`T25–T30` `T38–T44` (S2) · next mapped IDs after S2: `T15–T18`

## Deviations in force
| Item | Status | ADR |
| --- | --- | --- |
| Prisma as ORM | accepted (spec recommended choice) | — |
| `profiles.field_hlc`, `sessions.revoked_reason`, `sessions.last_seen_at` | accepted; HLC merge test **now** | — |
| native device-id channel + `path_provider` for Drift | accepted | ADR-0004 |
| idempotency keyed by scope for pre-auth endpoints | accepted conditionally (device-scoped keys not replayable cross-device; tests both directions) | — |
| `text.link` → `bg.brand`/`bg.brandPressed`/`bg.brandDisabled` | accepted | ADR-0005 closed by ADR-0006 |

## `[PROPOSAL]` values — remote-config only (confirm key names in next report)
device token 365 d · refresh 30 d · guest-create 3/device/hour · device-register 10/hour · line-height floor on display/h1 · opener limit 3 · dormant 7 d · Super Like / Undo caps · feed + dating score weights · retention 30 d purge / 35 d backup / 30 d evidence · KPI targets

## Conditional / deadlines
- background outbox drain → **by S3**; until then no doc may say "offline-first"
- Zawgyi detect→convert → S3 (stub shipped in S1; legacy input must never be stored as Zawgyi)
- pepper re-hash / rotation job → S9, before any real user onboarding
- blocking before store submission: legal sign-off on retention windows (SPEC §20)

## Next one-line prompt
```
Hasta fix <P0 from PR #2 review>   # then
Hasta S2
```

## Changelog (append one line per merged PR)
- `PR #1` — bootstrap S0+S1, merged with 400-line rule waived once
- `PR #2` (planned) — T37 rewrite + T46/T47/T48 + device-bound refresh + brand tokens
