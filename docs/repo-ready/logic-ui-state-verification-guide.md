# Hasta — Logic & UI State Verification Guide (v2)

Path in repo: `docs/qa/logic-ui-state-verification-guide.md`
Companion to: `docs/production-golive-plan.md` · SPEC 1.0.2 · PR #3/#4 findings

> **Rule 0 — a GREEN you never made RED proves nothing.** Every assertion below must be run
> as a reverse control (remove/disable the guard in a scratch copy, see the test go RED, restore,
> see GREEN) and the evidence committed. Scratch passes never count; only committed tests count.

---

## 1. Logic states (server / auth) — assertion + reverse control

| ID | Assertion (must hold) | Reverse control (must go RED) |
| --- | --- | --- |
| T46 cross-device refresh | Active-token refresh from an unenrolled device → 401, family revoked, no active sessions left in that family, unrelated families still work | Delete the mismatch branch in `auth/service.ts` → the committed case returns 200 |
| P0-DEVICE-PROOF | Resume requires proof tied to the original enrollment; a caller-supplied identifier hash alone is rejected | Trust the hash without proof → resume succeeds (must not) |
| P0-REPLAY-RETENTION | Expired replay rows are purged **globally** (cron/job), not only when the same scope is hit again | Remove the global sweep, send one request, leave the device silent → rows persist past expiry |
| P1-REPLAY-STATE | Retry with the same idempotency key after logout/family revocation returns the original *error*, never a cached success + token pair | Serve cache before the session-state check → retry returns 200 with dead tokens |
| T37 server verifier | Reject: wrong `iss`, wrong `aud`, expired, bad `nonce`, `email_verified=false`, unsigned payload; accept one valid fixture; S1 fails closed when the verifier is absent | Point the gate at the old text-only check → the valid identity fixture must not pass |
| Gmail link | Authorization-code exchange only (never a client-supplied Google token); masked email is the only PII returned | Return the raw email / accept an id_token → test must fail |
| Link completion | Exactly one authenticated `link:complete`; uncertain result → authenticated **status read**, never a code replay | Replay the code on 503 → Google rejects, app must not treat it as success |
| Pending key | Idempotency key is sent but not persisted; no accumulation across failed completions | Persist on 503 → storage count grows (P2-GMAIL-PENDING-KEY-CLEANUP regression) |
| Session list | Scoped to the signed-in account; no device identifier displayed or stored | Return another account's sessions / leak the raw device id → must fail |
| T48 | `docker-compose.yml` pins `postgres:16` | Change to `postgres:18` → gate RED (proven) |
| Health contract | `status=ok`, `env=staging`, `commit == git rev-parse HEAD` of the running image | Deploy without baking `GIT_COMMIT` → `verify-staging.sh` must fail |

---

## 2. UI states (Flutter)

### 2.1 Matrix

| Screen | empty | loading | success | error | offline | disabled | pressed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Welcome | — | primary CTA spinner | guest session created | 5xx banner, retry keeps state | CTA disabled + reason EN/MM | no Google/Apple button (T36) | `bg.brandPressed` |
| Guest Profile | skeleton | hydrated | editable | inline, no dialog stack | read-only | n/a | n/a |
| Settings | — | — | rows visible | banner | rows dimmed | title shrink-to-fit | n/a |
| Linked Accounts | "Not linked" | spinner | masked email only | typed error (denied/expired/server) | **button disables before tap** | yes while offline | `bg.brandDisabled` |
| Connect Gmail sheet | n/a | browser opened | masked email | explicit restart path on mid-consent expiry | disabled + reason | non-cancellable finishing state after submit | n/a |
| Security & Devices | "No other devices" | skeleton | list, no device ids | retry | cached read-only | revoke disabled while in flight | n/a |

### 2.2 Layout / accessibility (320×568 @ 200 % text scale, EN + MM)
* no truncation on Guest Profile text or the Settings title — `Expanded`/`Flexible` + `minHeight`,
  `FittedBox(fit: BoxFit.scaleDown)` for titles; never hide the failure by forcing `textScale: 1.0`;
* Myanmar body line height ≥ **1.65×** — asserted from the generated token, not hardcoded;
* intentional-overflow control test stays in the suite (proves the harness detects overflow).

### 2.3 Design-token assertions (the assertions referenced by `P0-DESIGN-TOKENS-GATE`)
Source of truth: **`assets/design-tokens.json`** (canonical path — a copy at
`assets/assets/design-tokens.json` is a failure, not a fix). Generator:
`tools/scripts/design-tokens.mjs`. Output: `apps/mobile/lib/design_tokens.g.dart` (never hand-edited).

| Assertion | Pass condition | RED control |
| --- | --- | --- |
| Source present | `node tools/scripts/design-tokens.mjs` exits 0 and names `assets/design-tokens.json` | delete/rename the file → job must fail **before** T47 |
| Misplaced copy detected | generator exits 1 and prints `git mv assets/assets/design-tokens.json assets/design-tokens.json` | leave only the nested copy → must fail, must not silently pass |
| Alias resolution | `{color.bg.brand}` etc. resolve to concrete ARGB values in the Dart | break one alias (`{color.bg.nope}`) → exit 1 with the offending path |
| Three-state button | generated Dart contains `bgBrand`, `bgBrandPressed`, `bgBrandDisabled` and `primaryButtonPressed/Disabled` aliases | drop `brandDisabled` from the source → exit 1 (`required token missing`) |
| Myanmar line height | `lineHeightBody >= 1.65` | set `1.2` → exit 1 |
| Myanmar family | `fontFamilyBase` contains Pyidaungsu / Noto Sans Myanmar | remove both → exit 1 |
| No drift | `--check` against the committed Dart is byte-clean | hand-edit one hex in the `.g.dart` → `--check` fails |
| No literals | widget tests assert the button fill equals the generated token; `main.dart` has no raw hex for the three states | hardcode a hex → widget assertion fails |
| CI wiring | `ci.yml` runs `--check` in the `gates` job | remove the step → gate must go RED on drift (add a drift fixture) |

---

## 3. Evidence discipline (seven rules)
1. **RED before GREEN** — no assertion is signed off without a committed reverse control.
2. Committed tests only; scratch runs are notes, not evidence.
3. One SHA per verdict; a verdict on a SHA whose CI is still queued is provisional.
4. UI checks run in **both** locales (EN + MM) and in default + QA configurations.
5. A blocked item states the missing prerequisite, and gets an explicit `skipped (reason)` —
   never an indefinite hang.
6. Findings carry a severity + exact file:line + fix prompt (e.g. `Hasta fix P2-SESSION-ACTIVITY-LABEL`).
7. `[DEVIATION]` is mandatory per run; "None" is the default. Relaxing a rule requires an ADR line.

---

## 4. Report template

    Verdict: ACCEPT | REQUEST CHANGES | BLOCKED (<sha>, <n> changed lines)
    Logic:  <id> PASS/FAIL/RED->GREEN — <file:line> — <reverse control performed?>
    UI:     <screen> × <state> — EN / MM — <widget test name>
    Tokens: source <path> — required 4 present — lineHeight <x> — --check clean
    Scope:  S<n> items in / deferred (each deferred item needs a follow-up prompt)
    Gates:  T36 … T48 one line each, with the CI run URL
    Next:   Hasta <verb> <target>

---

## 5. Staging run order (condensed)
1. `verify-staging.sh <https base> <deployed SHA>` → PASS (DNS stable A record, TLS, SHA, `env`).
2. `seed-staging.sh` → six fixtures + the `tester.minor` wagering block asserted.
3. QA-flavoured APK (panel present) → long-press panel, `tester.a` session, `/v1/me`, all six fixtures.
4. Release APK → T36 scan proves the panel and `google_sign_in` are excluded.
5. 12-item smoke checklist against the live URL, one `request_id` recorded per item.
6. T40/T41 native with a hard timeout and explicit skip semantics.
7. Any RED → fix PR (new, ≤ 400 lines) + this guide's reverse control, then re-run from step 1.
