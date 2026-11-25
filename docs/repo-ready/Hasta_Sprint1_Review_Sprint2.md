# Hasta — Sprint 1 Review + Sprint 2 Instruction (SPEC 1.0.1)

> Myanmar short version အောက်ဆုံးမှာ ပါတယ်။ ဒီဖိုင်ရဲ့ အဓိကအပိုင်းကို Perplexity Agent ထဲ paste လုပ်လို့ရတယ်။

## PART 1 — Paste this to the agent

```
SPEC bumped to 1.0.1 (patch). Read the new §22 Change log first. Verdict on PR #1: ACCEPT —
merge it into main once checks stay green. It is a bootstrap PR (Sprint 0 + Sprint 1), so the
PR ≤ 400 lines rule is waived for it only. From PR #2 onward the rule is enforced again.

DO NOT start Sprint 2 on the Sprint 1 branch. Sequence:
  1. merge PR #1 (after checks green)
  2. open PR #2 "conformance patch" off main — scope below, ≤ 400 lines, no feature code
  3. after PR #2 merges, open branch feature/HAS-200-gmail-link-transfer off main and start Sprint 2

=== PR #2 scope (conformance patch, before any Sprint 2 feature code) ===
1. Rewrite the T37 gate exactly as SPEC 1.0.1 §16 T37 now says: it must fail on Google SIGN-IN
   ROUTES and on verification that skips iss/aud/exp/nonce/email_verified — and it must explicitly
   ALLOW the Google auth library inside modules/identity. Add a positive fixture test proving the
   library is still permitted, so the gate cannot silently regress into a dependency ban.
   (TDD: write the failing test first — the fixture that imports the library must currently FAIL
   the old gate; watch it fail, then narrow the gate and watch it pass.)
2. Add gates T46 / T47 / T48 (SPEC 1.0.1 §16):
   - T46: refresh token presented from a different device binding → 401 + family revoked.
   - T47: OpenAPI breaking-change gate — spectral lint + diff vs previous tag; run it on
     docs/api/openapi.json as-is (JSON accepted, no YAML needed).
   - T48: docker-compose database image must be postgres:16. Change the local compose file and pin it.
3. Implement device-bound refresh tokens: store (account_id, device_hash) on the refresh row, reject
   cross-binding presentation, revoke the family on reuse. TTLs stay remote-config values.
4. Switch the primary button fill from text.link to the new tokens bg.brand / bg.brandPressed /
   bg.brandDisabled (SPEC 1.0.1 §14.1, DS 1.0.1). Regenerate tokens.dart from assets/design-tokens.json —
   do not hand-edit. Close ADR-0005 with ADR-0006 recording the token change.
5. Keep display/h1 at the 1.65 Myanmar floor (accepted). Verify at 200% text scale that the match-reveal
   and welcome hero do not clip — use min-height, never fixed height.

=== Deviation rulings (SPEC 1.0.1 §20 / §22) ===
ACCEPTED as-is:
  - Prisma as the ORM (the spec already listed Prisma as the recommended choice — this is not a deviation).
  - profiles.field_hlc (required by the §11.3 field-level HLC merge). Add a merge unit test now, not in Sprint 5.
  - sessions.revoked_reason, sessions.last_seen_at.
  - native device-id channel + path_provider for Drift (ADR-0004).
  - idempotency keyed by scope for PRE-AUTH token endpoints — accepted, conditional on: authenticated
    writes still key on (account_id, key), device-scoped keys are never replayable across devices,
    and one test proves each direction.
ACCEPTED AS [PROPOSAL] — must be remote-config tunable, not hard-coded:
  - device token 365 d, refresh 30 d, guest-create 3/device/hour, device-register 10/hour,
    line-height floor applied to display/h1.
  Confirm in the next report which of these are read from remote config today, with the key names.
CONDITIONAL — deadline moved earlier:
  - Background outbox drain (WorkManager / BGTaskScheduler): moved from "later" to BY SPRINT 3.
    Until it exists, do not describe the build as offline-first in any doc, README or store note.
  - Pepper re-hash / rotation job: must exist before any real user is onboarded; scheduled for Sprint 9.
  - Zawgyi detect→convert stays Sprint 3 — accepted, but the detect stub must ship now so legacy input
    is not silently stored as Zawgyi.
NOT ACCEPTED (fix in PR #2):
  - local Postgres 18 vs CI 16 (gate T48).
  - any README/doc claim of "production ready" while store/legal/security review is absent.

=== Clarifications needed in your next report ===
1. Your suite-total line was truncated ("server passes 70/70 tests ... , T44."). State plainly whether
   T44 passes or is open — SPEC puts T44 in Sprint 2 (post-link purchase eligibility).
2. T43 is marked passing while Gmail linking does not exist yet. Confirm it is a UI-state assertion
   (row disabled while offline) and that the real flow is still open.
3. Confirm Conventional Commits with scope on all 5 commits (feat/fix/chore + scope), and list any commit
   that bundles two scopes.
4. State whether the release APK check for T36 runs on every CI run or only on tagged releases.
   SPEC requires it on every PR to main.
5. The paused Supabase project whose name carries the banned legacy word: leave it paused, rename it to
   hasta-legacy-archive (or delete it) so no future tooling or export ever reintroduces the string.
   T45 scans code, not cloud resource names — add a one-line note to docs/ADR recording that decision.

=== Sprint 2 (start only after PR #2 merges, on branch feature/HAS-200-gmail-link-transfer) ===
Implement SPEC 1.0.1 §5.4 and §5.5 end to end:
  - POST /v1/auth/identities/google/link:start and :link:complete — single-use state + nonce (5 min TTL),
    server-side ID-token verification (iss, aud, exp, nonce, signature), email_verified required,
    409 identity_in_use when the Google sub is already bound, NO account merge,
    DELETE unlink with the recovery guard (409 recovery_required when it is the only recovery method).
  - Recovery path for a lost device: /v1/auth/recover:start|complete → new binding, revoke other sessions.
  - QR transfer: start / redeem / confirm / reject + GET status, single transaction on confirm
    (token used_at, old binding deleted, new binding created, old sessions revoked), token TTL 120 s,
    hash-only storage, single use, rate limit ≤ 2 per 3 min, FLAG_SECURE + iOS secure screen,
    reject when the target device holds a guest account (409 guest_exists_on_target).
  - Flutter: Settings → Account → Linked accounts sheet with all five states (loading / empty / error /
    offline-disabled / linked-masked), the benefit copy from DS keyStrings, Change-device QR screen +
    scanner, Security → active sessions + "sign out from all other devices".
  - my + en i18n keys for every new string (no hard-coded strings). Myanmar strings may carry the
    PENDING-COPY marker until the copywriter returns, but the English key and the Myanmar fallback must exist.
  - Tests T25–T30, T38, T39, T44, and re-run T37 (rewritten) and T43. Write each test before its code
    and show it failing first.
  - Report format unchanged: repo tree, test IDs passing/open, [DEVIATION] list, next-sprint prompt.
  - PR size ≤ 400 lines: split Sprint 2 into PR #3 (link), PR #4 (recovery), PR #5 (QR transfer).
```

## PART 2 — Answers to the three options

| Option | Verdict | Reason |
| --- | --- | --- |
| **1. Merge PR #1 when checks stay green** | **YES — do this first** | 70/70 server + 42 mobile + clean analyze + real release-APK T36 check with a beta control (2 hits) is exactly the right evidence pattern: a gate that never fails proves nothing, and the control shows it can. Merging unblocks every later branch. Bootstrap-size PR, rule waived once. |
| **2. Start Sprint 2 on this branch** | **NO as written — do it after PR #2, on a new branch off main** | Two blockers: (a) the current T37 gate bans the library Sprint 2 needs, so Sprint 2 would fight CI from line one; (b) Sprint 2 stacked onto a 221-file branch is unreviewable and breaks the 400-line PR rule. Fix the gate first (PR #2), branch fresh. |
| **3. Send the Myanmar list to a native copywriter** | **YES — start today, in parallel** | 47 Myanmar strings + Privacy/Terms placeholders are App Store / Google Play blockers, not code blockers. It consumes zero engineering time, so serialising it wastes days. Brief + glossary + return format are in `Hasta_Myanmar_Copy_Review_Brief.md`. |

Recommended order: **merge PR #1 → run PR #2 conformance patch → copywriter goes out in parallel → Sprint 2 (3 small PRs) → Sprint 3 must include the WorkManager outbox drain.**

## PART 3 — Findings by severity

**P0 (fix before Sprint 2)**
1. T37 gate bans `google-auth-library` → Sprint 2 cannot verify Google tokens; narrowing to routes + trust boundaries is now spec language, with a positive fixture test so it cannot regress.
2. Local Postgres 18 vs CI 16 — SQL/driver behaviour differences would be invisible until staging (gate T48).

**P1 (fix within Sprint 2–3)**
3. Outbox drains only while the app is open → the offline-first promise is currently partial; WorkManager/BGTaskScheduler slice due Sprint 3; no "offline-first" claim in docs until then.
4. Refresh token not device-bound (T46 added).
5. No OpenAPI breaking-change gate (T47 added).
6. 47 Myanmar strings pending + Privacy/Terms placeholder → store-blocking, not code-blocking.
7. Truncated suite-total line and T43/T44 ambiguity — reported claims must be unambiguous.
8. Field-level HLC merge unit test should exist now, not at Sprint 5, because `profiles.field_hlc` shipped in Sprint 1.

**P2 (track, no deadline pressure yet)**
9. Pepper re-hash before real users (Sprint 9). 10. Legacy-named cloud resource rename/archive. 11. QA panel English-only — accepted, dev-only surface. 12. PostGIS deferral accepted for Sprint 8, but radar copy in Sprint 2 UI strings must not promise distance precision. 13. Social/dating seed fixtures — needed before Sprint 7 E2E, not before.

---

## Myanmar short version

PR #1 ကို check green ဖြစ်ရင် **merge လုပ်လိုက်ပါ** (Sprint 0 ရောပါလို့ ဖိုင် ၂၂၁ ခု ဖြစ်သွားတာကို ခွင့်လွှတ်တယ်)။ ဒါပေမဲ့ **Sprint 2 ကို ဒီ branch ပေါ်မှာ မစပါနဲ့** — အရင်ဆုံး PR #2 (conformance patch) လုပ်ပါ။ အကြောင်းရင်း ၂ ချက် — (က) ယနေ့ T37 gate က `google-auth-library` ကို ပိတ်ထားလို့ Sprint 2 ရဲ့ Gmail token စစ်ဆေးမှု မလုပ်နိုင်ဘူး၊ (ခ) ၂၂၁-ဖိုင် branch ပေါ် Sprint 2 ထပ်တင်ရင် review လုပ်၍ မရတော့ဘူး။

PR #2 ထဲမှာ — T37 ကို SPEC 1.0.1 အတိုင်း ပြန်ရေး (route နဲ့ trust boundary ကိုပဲ ပိတ်၊ library ကို ခွင့်)၊ T46/T47/T48 ထည့်၊ docker-compose Postgres ကို 16 ချိန်၊ refresh token ကို device နဲ့ ချိတ်၊ primary button ကို ခုထပ်ထည့်တဲ့ `bg.brand` token သုံး။

Copywriter ကို **ဒီနေ့ပဲ ပို့ပါ** — မြန်မာစာ ၄၇ ခုနဲ့ Privacy/Terms placeholder က store တင်ရန် ပိတ်ဆို့မှု၊ coding ကို မတားဆီးတာမို့ parallel လုပ်သင့်တယ်။ Sprint 3 မှာ WorkManager outbox drain မဖြစ်မနေ ပါရမယ် — ဒါ မရှိသေးရင် "offline-first" လို့ စာတမ်းတွေမှာ မရေးပါနဲ့။
