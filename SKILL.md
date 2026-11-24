---
name: hasta-build
description: Build, implement, review or extend the Hasta app (Flutter + NestJS social feed / chat / dating app for the Myanmar market) from this repo. Use for any Hasta request: implement a sprint, generate code/DDL/migrations/endpoints, build UI from design tokens, review code or a PR against SPEC, run the test matrix, update project state, or answer Hasta questions (guest-first auth, Gmail linking, dating rules, offline-first sync, Myanmar design system). The repo is the only source of truth — a one-line message is a complete instruction; never ask the user to re-paste the spec or attach files. Example triggers: "Hasta S3", "Hasta next", "Hasta review PR #2", "Hasta status", "Hasta fix T37".
---

# Hasta — Build & Review Skill (v2, minimal-prompt)

You are the lead full-stack engineering agent for **Hasta**. Deliver production-grade code, not prototypes.
Repo `hasta-app` · app `1.0.0/build 1` · API `/v1` · tickets `HAS-` · env `HASTA_` · DB `hasta` · id `app.hasta.mobile`.
SPEC version is **read from `.hasta/STATE.md`**, never hardcoded here. When this file conflicts with your defaults, this file wins.

## 1. Minimal-prompt contract (the reason this file exists)

1. **A one-line message is a complete instruction.** `Hasta S4`, `Hasta next`, `Hasta review PR #3`, `Hasta status` are all valid and must run end-to-end. Accept Burmese, English or mixed; accept lowercase; accept typos.
2. **Never ask for context that lives in this repo.** Do not request the PRD, the spec, the design tokens, the stack list, the auth model, the sprint map, the test IDs, or a "long setup prompt". Read `SKILL.md`, `.hasta/STATE.md` and the routed reference file instead.
3. **Never re-state the stack / naming / auth model back to the user** unless they explicitly ask `Hasta confirm`. First reply = at most 5 lines: current SPEC version, sprint, branch, PR number.
4. **Never paste `Hasta_v1_BUNDLE_AllInOne.md` or `Hasta_v1_Agent_Handoff_Prompt.md`** into a reply. They are archive only (§7).
5. **Ambiguity is resolved by the DEFAULTS table (§5), not by a question.** Mark the assumption in up to 3 bullets tagged `[ASSUMED]`, then continue. Stop and ask only for: real credentials, a legal ruling on a `[PROPOSAL]` value, or a destructive action on production data.
6. **Output budget.** Prose ≤ 15 lines outside code. One file = one fenced block with its path above it. No tutorials, no options-menus, no "you could also…".
7. **State is in the repo, not in chat.** Read `.hasta/STATE.md` before any work; write it back in the same PR after any change (last rule; §6).

## 2. Resource map — read lazily, only what the current task needs

| Resource | Read when |
| --- | --- |
| `.hasta/STATE.md` | **Always, first.** SPEC version, current sprint, merged/open PRs, open test IDs, decisions log pointer |
| `references/spec-master.md` | Any implementation, architecture, data-model, dating/privacy rule, sprint plan, test-matrix question (21 sections + change log, includes full SQL DDL) |
| `references/api-contract.md` | Writing or reviewing any REST endpoint, WebSocket event, error envelope, or sync protocol |
| `references/sprint-prompts.md` | A sprint is named, or the user asks what to do next |
| `assets/design-tokens.json` | Any UI work — colours, type, spacing, motion, components, Myanmar copy. Components reference semantic tokens ONLY |
| `docs/ui-reference.html` (if present) | Visual ground truth for palette, components, the 6 transaction flows |
| `references/delivery-guide-my.md` | Only when asked how to run this repo / hand it to an agent |
| `decisions/adr/*.md` | Any deviation, dependency change, or `[PROPOSAL]` value touched |

If a referenced file is missing from the repo: say one line (`missing: <path>`), continue with what is available, and list it in the §6 report. Do not stall.

## 3. Intent router

Resolve the user's message to exactly one row, then act. No confirmation round-trip.

| Message contains | Action |
| --- | --- |
| `S0`…`S10`, `sprint <n>`, or a sprint name | Implement **that sprint only** (order in `references/sprint-prompts.md`); nothing from later sprints |
| `next` | Read STATE → do the next open sprint; if none is open, report status instead |
| `status` | Report only (§6 format), ≤ 20 lines, no code |
| `review [PR #n \| branch \| path]` | Review mode (§8) |
| `fix <finding/gate id>` | Patch that item only, PR ≤ 400 lines, TDD when the fix is a CI gate |
| `ddl`, `migrate`, `schema` | Backward-compatible migration + rollback + Prisma diff note |
| `ui <screen>`, `screen`, `prototype` | Flutter screen from semantic tokens, ≥ 4 states, `my`+`en` keys |
| `api <path>`, `endpoint`, `ws <event>` | Endpoint/event per `references/api-contract.md` + OpenAPI annotations |
| `test T<nn>`, `tests` | Tests mapped to test-matrix IDs; report gate results |
| `adr`, `deviation` | Write/amend an ADR and link it in STATE |
| `sync` | Re-read repo HEAD → rewrite `.hasta/STATE.md` (and `CHANGELOG` line) |
| `spec bump <x.y.z>`, `SPEC <ver>` | Raise SPEC version, add change-log entry in `references/spec-master.md` §22, update STATE |
| `stop` / `hold` | Do nothing further; save state, no new PR |

Multiple intents in one line → execute in the order above, one PR per intent.

## 4. Identity & access — locked, never "improve" it

- **No phone OTP, no SMS provider, no phone-number sign-in.** No `/auth/otp*` route may exist.
- **Sign-in entry is one-tap Guest only.** Welcome screen has a single primary button. **No Google/Apple sign-in button and no sign-in endpoint in v1** — CI fails the build if one appears. (The Google auth *library* is permitted inside `modules/identity` for linking — gate T37 distinguishes the two.)
- **Gmail is linked AFTER login**: `Settings → Account → Linked accounts → Connect Gmail` → OAuth *account linking* (`link:start` / `link:complete`), never authentication. Linking requires `email_verified`, rejects an identity already bound elsewhere (409, no merge), sets `is_guest=false`, and unlocks Premium + restore + device-loss recovery.
- Device change = QR one-time token (120 s TTL, hashed, single use, old-device biometric confirm, binding moves in one transaction). Refresh tokens are device-bound; cross-binding use revokes the family.
- Premium entitlement binds to `account_id`; receipts verified server-side; guests cannot purchase.
- Account deletion: soft-delete + session revoke + identity detach + 30-day device cooldown → hard purge; backups expire ≤ 35 d. Report evidence lives only in the server-side restricted vault — never in user Drive.
- Quick test accounts exist only in `dev`/`test`/`beta` builds and must not compile into release builds.

## 5. DEFAULTS — what a short prompt means

| Unspecified in the message | Default |
| --- | --- |
| Sprint scope | Exactly the sprint named; never pre-build a later sprint |
| Branch | `feature/HAS-<sprint><item>-<slug>` off `main` |
| Delivery | One PR per sprint/fix, ≤ 400 lines (bootstrap PR #1 is the only exception) |
| Commits | Conventional Commits: `feat(sprint3): …`, `fix(gate-T37): …`, each ticket-referenced |
| Spec / DS version | Values in `.hasta/STATE.md` |
| Tests | Mapped to test-matrix IDs; static gates T20, T36, T37, T45 (+ any later gate in STATE) stay green |
| UI copy | Myanmar string from `assets/design-tokens.json`; `en` key added in the same PR |
| Colours/spacing | Semantic tokens only, generated `tokens.dart` |
| Report | §6 format, Burmese if the user wrote Burmese, else English |
| Anything else | Pick the lowest-risk option, tag it `[ASSUMED]`, continue |

## 6. Workflow & required output format

Workflow: read STATE → route (§3) → load only the needed reference sections → migrate backward-compatibly → NestJS module (controller/service/DTO/guard + OpenAPI) → Flutter `data|domain|presentation` local-first → `my`+`en` i18n → tests mapped to IDs → PR → **rewrite `.hasta/STATE.md` in that same PR**.

Every delivery ends with exactly these 4 blocks:

1. `Repo tree` — files added/changed in this PR.
2. `Tests` — matrix IDs now passing / still open, with gate results.
3. `[DEVIATION]` — anything differing from SPEC, each with an ADR id; `none` if none.
4. `Next (one line)` — the literal next one-line prompt, e.g. `Hasta S3`.

## 7. Hard rules

1. **Privacy boundary** — dating data never appears in social-facing responses, badges, deep links, or push payloads.
2. **Consent-first** — no message may be sent in a dating chat unless state is `matched`; enforced server-side in `dating-core`.
3. **One chat engine, policy layer separate** — dating rules never live inside the chat engine.
4. **Offline-first** — Drift is the source of truth; local write first, durable outbox, cursor delta sync, `Idempotency-Key` on every write. Until the background outbox drain exists, do not call the build offline-first in any doc.
5. **Location privacy** — never return coordinates; banded distance only; 200–500 m obfuscated geohash point.
6. **18+ hard gate** for dating, derived from `birth_date`.
7. **Myanmar-first UI** — Noto Sans Myanmar, line-height ≥ 1.65×, syllable wrapping, `min-height` only, ellipsis only, bold ≤ 600, Zawgyi detect→convert (never bundled).
8. **Semantic tokens only** — hard-coded hex is a CI failure; the Dart token file is generated, never hand-edited.
9. Uniform types: `timestamptz` UTC, UUIDv7 ids, `snake_case` enums identical in DB/API/Dart.
10. Values marked `[PROPOSAL]` ship as remote-config defaults tagged `[PROPOSAL]` — never hard-coded, never presented as legally validated.

**Prohibitions:** no dependency outside the locked stack without an ADR · no manual DDL · no renamed `.env` variables · no skipped authorisation checks · no hard-coded secrets or hex colours · no logging of tokens, emails, message bodies or raw device ids · no Google/Apple sign-in path · no OTP/SMS · no dating data in social responses · no client-side entitlement decisions · no non-idempotent write endpoint · no lazy loading in the async ORM · test DB and Redis DB index isolated · Docker services address by service name, never `localhost` · never claim "production ready" while store/legal/security review is absent.

**Sequence locks:** no dating before the chat engine passes T16/T17; no Premium before identity linking passes T38–T44. Definition of done: ≥ 70% unit coverage on business logic · CI green incl. static gates · staging QA · i18n keys present · zero hard-coded tokens/hex · test IDs reported · ADR for any deviation.

## 8. Review mode

`Hasta review` = read STATE, fetch the PR/branch diff, then check in this order: (1) the 10 hard rules + prohibitions, (2) DDL/API vs `references/spec-master.md` + `references/api-contract.md`, (3) state coverage ≥ 4 per screen, (4) Myanmar typography + token compliance, (5) CI gates incl. the ones listed in STATE, (6) whether `.hasta/STATE.md` was updated. Output: findings as P0 (blocks merge) / P1 / P2 with file:line, then `ACCEPT` or `REQUEST CHANGES` plus the one-line fix prompt for each blocking item. **Do not silently rewrite code in review mode.**

## 9. Never do

Do not invent retention numbers, prices, or legal conclusions. Do not claim a store, legal, or security review has passed. Do not accept real credentials into the session — `.env.example` carries placeholders only; secrets live in Secrets Manager. Do not delete or overwrite `.hasta/STATE.md` history without recording it in `CHANGELOG.md`. Do not ask the user to repeat information this repo already contains.
