# Hasta app

## Local development

The Flutter shell lives in `apps/mobile`, the NestJS/Prisma server in
`apps/server`, and the AWS environment baseline in `infra/terraform`.

Copy `.env.example` to `.env`, set distinct random auth and pepper keys and a local URL-safe Postgres password, and
run `docker compose up --build` to launch the loopback-only services. The
internal server probe is `GET http://127.0.0.1:3000/health`. To apply the
schema locally, run `npm ci` and `npx prisma migrate deploy` from `apps/server`
with `HASTA_DATABASE_URL` pointing to the Compose database. In `apps/mobile`,
run `flutter pub get --enforce-lockfile`, `flutter gen-l10n`, and `flutter test`
(Linux tests require `libsqlite3-dev`).

To run the S1 guest flow on an Android emulator, use
`flutter run --dart-define=HASTA_API_BASE_URL=http://10.0.2.2:3000`.
All deployed endpoints must use HTTPS. To exercise the fixture picker, enable
`HASTA_QUICK_TEST_ACCOUNTS_ENABLED=true` only on an isolated dev/test/beta
backend, then add `--dart-define=HASTA_ENV=dev
--dart-define=HASTA_QUICK_TEST_ACCOUNTS_ENABLED=true` to the debug build and
hold the welcome-screen title for three seconds. Release builds exclude the panel.

## Agent skill package (minimal-prompt v2)

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
