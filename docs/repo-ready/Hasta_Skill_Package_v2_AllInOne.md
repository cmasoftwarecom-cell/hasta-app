# Hasta — Agent Skill Package v2 (Minimal Prompt) — All-In-One

ဖိုင် ၈ ခု ပါဝင်သည်။ GitHub မှာ တစ်ဖိုင်စီ တင်ရန် မလိုက်ပါလျှင် ဒီဖိုင်ကို ဖွင့်ပြီး
အပေါ်ကနေ အောက်ကို စာတိုင်း copy ပaste လုပ်ကာ path အတိုင်း ဖိုင်ဖွင့်ထည့်ပါ။
(Or: keep this file as the human-readable master and let the agent split it —
send `Hasta split package into repo files per README layout`.)

| # | Repo path | Purpose |
| --- | --- | --- |
| 1 | `SKILL.md` | rules, defaults, intent router — the long prompt, replaced |
| 2 | `PROMPTS.md` | the one-line prompts you send |
| 3 | `README.md` | repo layout + 5-minute setup |
| 4 | `.gitignore` | Flutter/Nest/Terraform/secrets |
| 5 | `.hasta/STATE.md` | current SPEC version, sprint, PRs, gates, deviations |
| 6 | `references/sprint-prompts.md` | S0–S10 condensed |
| 7 | `references/delivery-guide-my.md` | Burmese usage + connector guide |
| 8 | `decisions/adr/ADR-0000-template.md` | deviation record template |

**Not included here (place from your existing files, exact names):**
`references/spec-master.md` ← `Hasta_v1_Master_PRD.md` ·
`references/api-contract.md` ← `Hasta_v1_API_Contract.md` ·
`assets/design-tokens.json` ← `Hasta_v1_Design_Tokens.json` ·
`docs/ui-reference.html` ← `Hasta_v1_UI_Reference.html`

---


## ┌ SKILL.md

```markdown
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
```


## ┌ PROMPTS.md

````markdown
# Hasta — Minimal Prompt Library (v2)

ဒီဖိုင်တစ်ခုတည်းသောက်ရုံနဲ့ GitHub repo ကို အသုံးပြုနိုင်ပါတယ်။ **အရှည်ဆုံး prompt = စာကြောင်း ၁ ကြောင်း။**
You only ever need one line. The repo (SKILL.md + references/ + .hasta/STATE.md) carries all the context.

---

## 0. First message in a brand-new thread (the only prompt that is 3 lines)

```
Hasta init. Read SKILL.md and .hasta/STATE.md, then implement the next open sprint.
Branch off main, one PR, mapped test IDs. Reply ≤ 5 lines then the code.
```

ရetrofit: အသစ်ဖွင့် thread တိုင်းမှာ `Hasta init` တစ်ကြောင်းတည်း။ ဘာ spec မှ ပြန် attach မတင်ရ။

---

## 1. Daily one-liners

| လုပ်ချင်တာ | Prompt (copy ပါ) |
| --- | --- |
| Sprint 0 scaffold | `Hasta S0` |
| Sprint N ပြီးမြောက်အောင် | `Hasta S3` (S0–S10) |
| နောက် sprint သို့ | `Hasta next` |
| ဘယ်အခြေအနေရောက်လဲ | `Hasta status` |
| PR/branch သုံးသပ် | `Hasta review PR #2` |
| Gate တစ်ခု ပြင် | `Hasta fix T37` |
| DDL / migration | `Hasta migrate accounts` |
| Screen တစ်ခု UI | `Hasta ui welcome` |
| Endpoint | `Hasta api POST /v1/auth/guest` |
| WS event | `Hasta ws chat.message` |
| Test | `Hasta test T46` |
| ADR | `Hasta adr 0007 token bg.brand` |
| State ကို repo နှင့် ချိန် | `Hasta sync` |
| SPEC version တင် | `Hasta spec bump 1.0.2` |
| ရပ် | `Hasta stop` |

---

## 2. Sprint 0–10 အစဉ် (အလိုအလျောက် `next` ဖြင့် တက်နိုင်)

```
Hasta S0
Hasta S1
Hasta S2
Hasta S3
...
Hasta S10
```
Exit criteria မှာ PR merge ဖြစ်ပြီး mapped test IDs စိမ်းနေရမည် — agent ကို သတ်မှတ်ခိုင်းစရာမလိုအောင် `SKILL.md` §5/§7 တွင် ဖတ်ထားသည်။

---

## 3. Review → Fix → Next (အကျဆုံး စာကြောင်း ၃ ဆင့်)

```
Hasta review PR #2
Hasta fix <P0 id>            (အကြိမ်အရေအတွက် လိုသလောက်)
Hasta next
```

`Hasta_Sprint1_Review_Sprint2.md` လို ဖိုင်ကြီး paste လုပ်စရာ မလိုတော့ပါ — rulings များကို
`decisions/adr/` + `.hasta/STATE.md` ထဲ သိမ်းထားသဖြင့် `Hasta review PR #2` တစ်ကြောင်းတည်း ဖြစ်ပြီးပါတယ်။

---

## 4. ဘယ်အခါမှ လိုအပ်တော့မည့်အရာများ (removed)

| အဟောင်း (ဖျက်ပြီး) | အစားထိုး |
| --- | --- |
| `=== PROMPT START … END ===` block (~15 KB paste) | `SKILL.md` repo တွင်ရှိ → `Hasta init` |
| `Hasta_v1_BUNDLE_AllInOne.md` attach (154 KB) | `references/spec-master.md` ကို agent က ဖတ်သည် |
| Sprint per-paragraph instructions | `references/sprint-prompts.md` 1-liner |
| "Sprint N သာ လုပ်ပါ" ကို ထပ်ထပ်သတိပေးခြင်း | `SKILL.md` §5 sprint-scope default |
| Context ပျောက်တိုင်း အသစ်ပြန်ရေး | `.hasta/STATE.md` |

---

## 5. Agent က context တောင်းလာရင် (guard rail)

```
SKILL.md §1 read လုပ်ပါ။ repo ထဲမှာပဲ အဖြေရှိတယ်။
```
(English: "Read SKILL.md §1. The answer is already in the repo.")

---

## 6. အဆုံးစွန် cheat sheet (ဖုန်းမှတ်ထားလောက်အောင်)

`init` · `S<n>` · `next` · `status` · `review PR #n` · `fix <x>` · `migrate` · `ui` · `api` · `ws` · `test` · `adr` · `sync` · `spec bump` · `stop`
````


## ┌ README.md

````markdown
# hasta-app — agent skill package (minimal-prompt v2)

**Problem fixed:** every new thread used to need a ~15 KB pasted prompt plus a 154 KB bundle re-attach.
**Fix:** all durable context now lives in this repo. A one-line message is a complete instruction.

> ဖိုင် ၄ ခု (`SKILL.md`, `PROMPTS.md`, `.hasta/STATE.md`, `references/delivery-guide-my.md`) ကို repo ထဲ တင်ပြီးနောက်
> message တစ်ကြောင်းတည်း (`Hasta S3`) ဖြင့် အသုံးပြုနိုင်ပါသည်။

## Layout

```
hasta-app/
├── SKILL.md                      # rules + defaults + intent router  (agent reads first)
├── PROMPTS.md                    # the only prompts you will ever send
├── README.md                     # this file
├── .gitignore
├── .hasta/STATE.md               # where we are: SPEC ver, sprint, PRs, gates, deviations
├── decisions/adr/ADR-000x-*.md   # one file per accepted deviation
├── references/
│   ├── spec-master.md            # = Hasta_v1_Master_PRD.md      (rename on upload)
│   ├── api-contract.md           # = Hasta_v1_API_Contract.md
│   ├── sprint-prompts.md         # S0–S10, one line each
│   └── delivery-guide-my.md      # Burmese how-to (connector + usage)
├── assets/design-tokens.json     # = Hasta_v1_Design_Tokens.json
└── docs/ui-reference.html        # = Hasta_v1_UI_Reference.html
```

## 5-minute setup

```bash
# 1. create a PRIVATE repo named hasta-app on GitHub, then:
git clone https://github.com/<you>/hasta-app.git && cd hasta-app

# 2. drop the four new files from this package into place
mkdir -p references assets .hasta decisions/adr docs
cp SKILL.md PROMPTS.md README.md .gitignore ./
cp references/sprint-prompts.md references/delivery-guide-my.md references/
cp .hasta/STATE.md .hasta/

# 3. rename + place your existing spec files (exact names matter)
cp <uploads>/Hasta_v1_Master_PRD.md        references/spec-master.md
cp <uploads>/Hasta_v1_API_Contract.md      references/api-contract.md
cp <uploads>/Hasta_v1_Design_Tokens.json   assets/design-tokens.json
cp <uploads>/Hasta_v1_UI_Reference.html    docs/ui-reference.html

# 4. ship it
git add -A && git commit -m "chore: minimal-prompt skill package v2" && git push
```

Web-UI upload works too — just keep the paths above identical.

## Connect the agent

1. Perplexity → **Connectors → GitHub** → authorize → select `hasta-app` (private read access).
2. Open a thread with that connector enabled and send the single bootstrap line:

   ```
   Hasta init
   ```

3. That is the whole protocol. From then on: `Hasta S<n>` · `Hasta next` · `Hasta status` ·
   `Hasta review PR #n` · `Hasta fix <gate>` · `Hasta migrate` · `Hasta ui <screen>` ·
   `Hasta api <path>` · `Hasta test T<nn>` · `Hasta sync` · `Hasta spec bump <x.y.z>`.

## Why it stays short

| Mechanism | Where |
| --- | --- |
| One-line messages are valid instructions; no re-asking allowed | `SKILL.md` §1 |
| Short-prompt defaults (branch, PR size, scope, report shape) | `SKILL.md` §5 |
| Progress held in the repo, not the chat → thread loss is harmless | `.hasta/STATE.md` |
| Review rulings converted into gates + ADRs | `SKILL.md` §8 + `decisions/` |
| Archive files (`Agent_Handoff_Prompt.md`, `BUNDLE_AllInOne.md`) barred from pasting | `SKILL.md` §1.4 |

## House rules

- One PR per sprint or fix, ≤ 400 lines (bootstrap PR #1 is the only waiver).
- A PR is not merged until its mapped test IDs (T1–T48) are green.
- `[PROPOSAL]` numbers ship as remote-config defaults only, tagged in code.
- Never send real secrets to the agent: OAuth client, FCM/APNs keys, AWS creds stay in Secrets Manager; `.env.example` carries placeholders.
- Do not call the build "production ready" while store, legal or security review is absent.
````


## ┌ .gitignore

```yaml
# ---- Flutter / Dart ----
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
pubspec.lock.bak
coverage/
*.png.original
ios/Pods/
ios/.symlinks/
android/.gradle/
android/app/google-services.json.debug
**/generated/
lib/gen/tokens.dart          # generated from assets/design-tokens.json — never hand-edited

# ---- Node / Nest ----
node_modules/
dist/
*.tsbuildinfo
nest-cli.json.local
coverage/
.nyc_output/

# ---- Prisma / DB ----
prisma/migrations/**/drop.sql.local
/db-backups/

# ---- Terraform ----
**/.terraform/
*.tfstate
*.tfstate.*
crash.log
override.tf
override.tf.json

# ---- Secrets: never commit ----
.env
.env.*
!.env.example
*.pem
*.p12
*.key
secrets/
service-account*.json
GoogleService-Info.plist
key.properties
local.properties

# ---- CI / tool caches ----
.github-workspace/
.cache/
tmp/
out/
*.log

# ---- Agent scratch (state IS committed; only scratch is ignored) ----
.hasta/scratch/
.hasta/*.tmp
```


## ┌ .hasta/STATE.md

````markdown
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
````


## ┌ references/sprint-prompts.md

```markdown
# Hasta — Sprint Prompts (one line each)

Scope, exit criteria and prohibitions come from `SKILL.md` + `references/spec-master.md` §17 and §16.
Send only the line in the right-hand column. **One sprint per PR.**

| ID | Deliverable | Prompt |
| --- | --- | --- |
| S0 | Monorepo skeleton, docker-compose, Terraform baseline, CI static gates (T20/T36/T37/T45), Prisma identity schema, generated `tokens.dart`, i18n `my`/`en` scaffold, `.hasta/STATE.md` | `Hasta S0` |
| S1 | Guest-first auth: `POST /v1/auth/device/register`, `/auth/guest`, `/auth/refresh`, `/auth/logout`, `GET /v1/me`; HMAC device hash w/ pepper; refresh rotation + family reuse detection; cooldown; abuse log (device hash only); welcome screen single primary button; long-press quick-test panel behind `HASTA_QUICK_TEST_ACCOUNTS_ENABLED`; profile basics, settings shell | `Hasta S1` |
| S2 | Gmail linking (`link:start`/`link:complete`, state+nonce, server ID-token verify, `email_verified`, 409 no-merge, unlink guard), lost-device recovery, QR device transfer (120 s hashed single-use, `FLAG_SECURE`, ≤2/3 min rate limit, guest-on-target reject), linked-accounts sheet 5 states, active sessions + sign-out-everywhere | `Hasta S2` |
| S3 | Feed + social: posts, weighted ranking as pure injectable fn (remote-config weights), reactions, comments depth 2, groups/pages, notifications w/ social↔dating badge separation, Meilisearch, **background outbox drain**, Zawgyi converter (beyond the Sprint 1 stub) | `Hasta S3` |
| S4 | Chat engine core: 1:1 chats, Socket.IO, `pending→sent→delivered→read`, per-chat `seq`, durable outbox, cursor delta sync, push (FCM/APNs) privacy-safe payloads — must clear T16/T17 | `Hasta S4` |
| S5 | Chat surfaces: group/channel/saved/folders (incl. dating folder), resumable chunked media, WebP thumbs + BlurHash | `Hasta S5` |
| S6 | Dating profile + 18+ hard gate, selfie verification states, pause; candidate pipeline (hard filters → scoring → dedupe/shuffle); swipe/like/pass/super-like with quota + undo; transactional mutual match `UNIQUE(user_a,user_b)` canonical order; Likes You / Matches | `Hasta S6` |
| S7 | Radar + location privacy (banded distance, 200–500 m obfuscation), dating chat rules R1–R8 server-side (opener limit, icebreaker, media blur NSFW 0.5/0.8, no forward/export, receipts off, unmatch 30-d evidence, 7-d dormant → read-only + reopen), safety banner, block/report + moderation queue 24 h SLA | `Hasta S7` |
| S8 | Premium: entitlement on `account_id`, server-side receipt verify, `appAccountToken`/`obfuscatedAccountId`, `UNIQUE(store, store_txn_hash)`, restore (online only, visible iOS button), renewal/cancel/refund webhooks, guest purchase block → Connect-Gmail prompt | `Hasta S8` |
| S9 | Full settings, client-side-encrypted Drive/CloudKit backup, deletion purge T0→T0+30 d w/ backup expiry ≤35 d, pepper re-hash/rotation job, restricted evidence vault (KMS, role-gated, access log, retention job, legal hold) | `Hasta S9` |
| S10 | Hardening & launch: perf budget on 2–3 GB RAM Android (cold ≤2.5 s, feed ≥55 fps, APK <45 MB), a11y (200% scaling, labels, reduced motion, contrast), k6 to 10 000 concurrent (feed p95 ≤300 ms, delivery ≤500 ms), SAST/DAST/dependency/secret scans, pen-test remediation, store assets (privacy URL, ToS, data-safety, nutrition labels, 18+ rating, account-deletion path, location strings), runbooks, PRD §21 checklist | `Hasta S10` |

**Sequence locks (enforced by SKILL.md §7):** do not start S6–S7 before S4 passes T16/T17; do not start S8 before S2 passes T38–T44.
**Gate registry:** after each SPEC bump, new gates are appended here and recorded in `.hasta/STATE.md` — never re-paste them.
```


## ┌ references/delivery-guide-my.md

````markdown
# Hasta — Agent နှင့် GitHub ချိတ်ဆက်ပြီး Prompt အနည်းဆုံးသုံးနည်း (မြန်မာ)

## အကျဉ်း

အရင်က message တစ်ခုပို့တိုင်း `Agent_Handoff_Prompt.md` (~15 KB) ကို paste ပြီး PRD/bundle (~154 KB) ကို
ပြန် attach တင်ရခဲ့ပါတယ်။ အခု **အခိုက်အတန့်အားလုံး repo ထဲ** ရှိနေပါတယ်:

```
hasta-app/
├── SKILL.md              ← agent စည်းမျဉ်း + default များ (context အားလုံး)
├── PROMPTS.md            ← သုံးရမည့် စာကြောင်းတိုများ
├── .hasta/STATE.md       ← ဘယ်နေရာရောက်ပြီလဲ (agent က ဖတ်ပြီး ပြန်ရေးသည်)
├── references/
│   ├── spec-master.md    ← Hasta_v1_Master_PRD.md ကို ဒီနာမည်ဖြင့် တင်ပါ
│   ├── api-contract.md   ← Hasta_v1_API_Contract.md
│   ├── sprint-prompts.md ← S0–S10 one-liner
│   └── delivery-guide-my.md
└── assets/
    └── design-tokens.json ← Hasta_v1_Design_Tokens.json
```

`SKILL.md` §1 တွင် "စာကြောင်းတစ်ကြောင်း = လက်မှတ်ရေးထိုးပြီးသား အပြည့်အစုံ instruction" ဟု
သတ်မှတ်ထားသဖြင့် agent က spec ပြန်တောင်း၍ မရတော့ပါ။ Ambiguous ဖြစ်လျှင် §5 DEFAULTS ဇယားကို
အသုံးပြုပြီး `[ASSUMED]` ဖြင့် ဆက်လုပ်သည်။

## ၁။ GitHub repo ပြင်ဆင်ခြင်း

```bash
git clone https://github.com/<user>/hasta-app.git   # private ဖြင့် စတင်ပါ
cd hasta-app
mkdir -p references assets .hasta decisions/adr
cp SKILL.md PROMPTS.md .gitignore .hasta/STATE.md ./
mv Hasta_v1_Master_PRD.md      references/spec-master.md
mv Hasta_v1_API_Contract.md    references/api-contract.md
mv Hasta_v1_Design_Tokens.json assets/design-tokens.json
mv Hasta_v1_UI_Reference.html  docs/ui-reference.html
git add -A && git commit -m "chore: agent skill package (minimal-prompt v2)" && git push
```

Web UI မှ တင်လျှင်: repo → Add file → Upload files → `SKILL.md` တစ်ခုတည်းအရင်တင် → ပြီးလျှင်
`references/`, `assets/`, `.hasta/` ဖိုင်များကို အထက်ပါနာမည်အတိုင်း တင်ပါ (နာမည်မပြောင်းရ)။

## ၂။ Connector ချိတ်ဆက်ခြင်း

1. Perplexity → **Connectors → GitHub** → Authorize → `hasta-app` ကို ရွေးပါ (private repo ဖတ်ခွင့်)။
2. ဤ repo ကို သုံးမည့် project/thread တိုင်းတွင် GitHub connector ဖွင့်ထားသည်ဟု သေချာပါစေ။
3. Token လဲ/permissions ပြောင်းလျှင် `Hasta sync` တစ်ကြောင်းပို့ပြီး state ပြန်ချိန်နှိပ်ပါ။
4. Agent တွင် skill ဖိုင်ကို တိုက်ရိုက်မတင်ရ — repo root `SKILL.md` ကို စာဖတ်ခြင်းအဖြစ် သုံးသည်။

## ၃။ အသုံးပြုနည်း (ပထမ ၃ message)

```
Hasta init
Hasta S0
Hasta status
```
ထို့နောက် `Hasta next` / `Hasta review PR #2` / `Hasta fix T37` စသည်ဖြင့် တစ်ကြောင်းစီ။
အသစ်ဖွင့် thread တိုင်း `Hasta init` တစ်ကြောင်းတည်း — ဖိုင် ပြန် attach မတင်ရ။

## ၄။ စည်းမျဉ်း ၄ ခု (agent အားထားနိုင်အောင်)

| စည်းမျဉ်း | နေရာ |
| --- | --- |
| Sprint တစ်ခု = PR တစ်ခု၊ ≤ 400 lines (bootstrap PR #1 လွှဲ exemptions) | `SKILL.md` §5 |
| Exit criteria = mapped test IDs (T1–T48) စိမ်း | `SKILL.md` §6/§7 |
| `[PROPOSAL]` values = remote config သာ၊ hard-code မလုပ်ရ | `SKILL.md` §7.10 |
| Secrets (OAuth client, FCM/APNs, AWS) ကို agent ထံ ဘယ်တော့မှ မပို့ရ — `.env.example` placeholder သာ | `SKILL.md` §9 |

## ၅။ ဖိုင်အဟောင်းများ

| ဖိုင် | အခြေအနေ |
| --- | --- |
| `Hasta_v1_Agent_Handoff_Prompt.md` | **မတင်ရတော့** — `SKILL.md` က အစားထိုး။ repo `docs/archive/` တွင် သိမ်းရုံ |
| `Hasta_v1_BUNDLE_AllInOne.md` | archive သာ — paste မလုပ်ရ (`SKILL.md` §1.4) |
| `Hasta_v1_Index.md` | archive သာ |
| `Hasta_Sprint1_Review_Sprint2.md` | rulings များကို `.hasta/STATE.md` + `decisions/adr/` ထဲ ပြောင်းပြီး။ ပြင်ဆင်မှုတိုင်း `Hasta fix <id>` |
| `Hasta_Myanmar_Copy_Review_Brief.md` | `references/` ထဲ ခေါ်ဝင်နိုင် (copy review လိုတိုင်း `Hasta review copy`) |

## ၆။ Problem တက်လျှင်

| ပြဿနာ | ဖြေရှင်း |
| --- | --- |
| Agent က spec ပြန်တောင်းသည် | `SKILL.md §1 read လုပ်ပါ။ repo ထဲမှာပဲ အဖြေရှိတယ်။` ပို့ပါ၊ ပြီးလျှင် `Hasta sync` |
| ဘာပြီးပြီလဲ မသိရ | `Hasta status` (state file ကို HEAD နှင့် ချိန်ပေးသည်) |
| Thread အဟောင်း ပျောက်သည် | ပြဿနာ မဟုတ်တော့ — state သည် `.hasta/STATE.md` တွင် ရှိ |
| Gate အသစ် ထပ်စရာ | SPEC bump ပြီး STATE ၏ "Gates currently enforced" သာ ဖြည့်ပါ |
| Repo ကြီးလာသည် | `.gitignore` သုံးပြီး build artifact ဖယ်ပါ；spec/code ခွဲရင် `hasta-docs` repo ခွဲ၍ `SKILL.md` တွင် path ပြောင်းပါ |
````


## ┌ decisions/adr/ADR-0000-template.md

```markdown
# ADR-0000 — <title>

- status: proposed | accepted | superseded-by-ADR-000x
- date: YYYY-MM-DD
- sprint: S<n> · ticket: HAS-<nnn>
- spec refs: SPEC <x.y.z> §<n>

## Context
<one paragraph: what forced a choice>

## Decision
<what we are doing, in imperative voice, with file/module names>

## Consequences
- positive:
- negative / risk:
- gate impact: T<nn> …
- `[PROPOSAL]` values touched: …

## Alternatives rejected
- <alt> — <why not>
```
