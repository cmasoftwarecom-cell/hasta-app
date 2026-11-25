# Hasta — Production-Grade Go-Live Plan

Scope: turn the current verified state (SPEC 1.0.2, S1 merged, S2 in review) into a live,
operationally defensible release. Every claim below is traceable to the run log in
`Hasta_fix_P2-GMAIL-FLOW-COVERAGE` or to the artefacts shipped with this plan.

မြန်မာအကျဉ်း — ဒီဖိုင်က "အခုအခြေအနေ → live app" သွားရမယ့် အဆင့်အစီအစဉ်အပြည့်အစုံ။ Phase A က CI ကို ပိတ်ထားတဲ့ design-token gate ကို ဖွင့်တာ (အရင်ဆုံးလုပ်ရမယ့်အရာ)၊ Phase B က ကျန် test gap များ၊ Phase C စစ်မှန်တဲ့ staging environment၊ Phase D production hardening၊ Phase E မလွဲမသွေ လိုက်နာရမယ့် တရားရေးတံခါး။ ဖိုင်အားလုံးကို repo path အတိုင်း ထုတ်ပေးထားပြီး။

---

## 0. Verified snapshot (what the log actually proves)

| Object | State | Evidence |
| --- | --- | --- |
| `main` | `3983817` — carries the **stale token file at `assets/assets/design-tokens.json`**; canonical `assets/design-tokens.json` is absent | `Hasta fix P0-DESIGN-TOKENS-GATE` → "Blocked before edits" |
| PR #2 (S1 guest auth) | **merged** | "Hasta S2 Execution" section |
| PR #3 (S2 Gmail linking) | **draft @ `ac55526`**, 938 changed lines (+879/−59), verdict **ACCEPT for the draft scope — no open P0/P1/P2** | last `Hasta review PR #3` |
| PR #3 CI | gates + Terraform + backend + mobile **pass**; **iOS still queued → CI not fully green** | same |
| PR #4 (Security & Devices) | **draft @ `dd5b261`**, 322 lines, **REQUEST CHANGES** — blocker `P0-DESIGN-TOKENS-GATE` inherited from `main`, not introduced | `Hasta PR #4 review` |
| Open P2 | `P2-SESSION-ACTIVITY-LABEL` — `last_seen_at == null` renders "Last active" instead of "Signed in" | same |
| Still-open verification | native Gmail consent · app association (universal links / `assetlinks`) · device-toggle QA · **T40/T41 native E2E (12-min timeouts)** · physical T28 (2 Android) · staging QA (all items) | throughout |
| Staging infra | Vultr `149.28.136.202`, Ubuntu 24.04, **1024 MB RAM**, 25 GB | provisioning log |
| Hosts attempted | `api-social.hasta.app` → NXDOMAIN · `hasta-api.nexusmmr.com` → proxied but `404 page not found` · `api.oddsmyanmar.online` → A record `104.207.77.242` (**not** the Vultr origin) · direct `:3000` → intentionally private | staging QA logs |

**The single thing blocking the pipeline is not security and not code quality — it is a file path.**
`P0-DESIGN-TOKENS-GATE` stops the `gates` job *before* T47, which in turn stops PR #4 from being
reviewable, which keeps S2 open, which keeps staging unsigned. Fix Phase A first.

---

## 1. Phase A — unblock `P0-DESIGN-TOKENS-GATE` (today)

**A1.** Put the canonical DTCG source at `assets/design-tokens.json` on `main` and delete the
misplaced nested copy (shipped: `assets/design-tokens.json`, 56 tokens, `bg.brand /
bg.brandPressed / bg.brandDisabled`, `lineHeight.body = 1.65`, Myanmar families):

    git checkout main && git pull
    git rm -r --cached assets/assets 2>/dev/null || true
    rm -rf assets/assets
    # place assets/design-tokens.json (from this package)
    git add assets/design-tokens.json && git commit -m "fix(tokens): restore DS 1.0.2 at canonical path (P0-DESIGN-TOKENS-GATE)"

**A2.** Replace `tools/scripts/design-tokens.mjs` with the shipped resolver. It parses DTCG,
resolves `{color.bg.brand}`-style aliases, refuses to run on a missing/misplaced source, and
supports `--check` so CI can prove `design_tokens.g.dart` is **generated, not hand-edited**.

**A3.** Regenerate and commit the Dart (`apps/mobile/lib/design_tokens.g.dart` is included in
this package, produced by that generator):

    node tools/scripts/design-tokens.mjs && flutter analyze

**A4.** Wire the gate into CI so the failure is loud, not silent:

    - name: Design tokens (generated, not hand-edited)
      run: node tools/scripts/design-tokens.mjs --check

**A5.** Land this as its own **small PR #5 (< 200 lines) directly to `main`** — do *not* grow
PR #3 (already at a terminal 938-line waiver) or PR #4 to carry it.

**A6.** Then `git rebase main` on PR #3 and PR #4, push, rerun CI.

**A7. Prove the gate with a RED control before calling it closed** (rule 1 of the verification
guide): rename the JSON in a scratch copy → the job must go RED; restore → GREEN. Commit the
evidence line in the PR description.

---

## 2. Phase B — close the remaining verification gaps

| # | Gap | Concrete work | Done when |
| --- | --- | --- | --- |
| B1 | iOS job queued | Add `timeout-minutes`, retry, and move T36-iOS to a pre-warmed/self-hosted macOS runner | iOS job GREEN on the same SHA as backend |
| B2 | Native Gmail consent | Real device: system browser → consent → callback → masked email only; assert zero token persistence | log line + screenshot in `docs/qa/` |
| B3 | App association | Serve `/.well-known/assetlinks.json` (Android) and `/.well-known/apple-app-site-association` (iOS) **from the API host**, allowlist the redirect URI, verify with `adb` / `aasa-crawler` | deep link opens the app, no browser loop |
| B4 | Server-side verifier (was the S2 remainder of T37) | Verify `iss`, `aud`, `exp`, `nonce`, `email_verified`; reject unsigned/id-token passthrough; keep S1 fail-closed when absent | T37 positive + negative fixtures committed |
| B5 | Device-toggle QA | Airplane mode *while* Linked Accounts is open, EN+MM, button disables before tap | committed test + device pass |
| B6 | **T40/T41 native 12-min hang** | Root cause pattern: native test waits on an endpoint/flow that the deployed revision lacks. Fix: (a) run against a revision that includes S1+S2 screens, (b) add explicit `timeout` + `skipIf` with `skipped (S1 not ready)` so CI fails fast, (c) cache `.gradle`/Pods, (d) split suites | job reports pass/skip in < 8 min, never a wall |
| B7 | Physical T28 (two devices, QR) | Pin `zxing-android-embedded` 4.3.0, record both device IDs | two-device transfer observed |
| B8 | `P2-SESSION-ACTIVITY-LABEL` | "Signed in" for `last_seen_at == null`, "Last active" otherwise, EN+MM widget test | PR #4 flips to ACCEPT |
| B9 | Revocation controls (S2 tail) | Security & Devices: revoke session, revoke family, confirm re-auth | S2 acceptance list complete |

---

## 3. Phase C — a staging environment that is a contract, not a workaround

Quick tunnels are for a 20-minute look, not for sign-off: the URL dies with the session, anyone
holding it can reach the API, and nothing records the deployed SHA.

**C1 — capacity (do this before anything else).** 1 GB is not enough for Nest + build + proxy.

    sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    sudo sysctl vm.swappiness=10

Then resize the instance to **2 GB** for staging, **4 GB** for production, and move PostgreSQL to
a managed isolated staging DB (Neon/Supabase free tier is acceptable for QA, never shared with
prod). Build images in CI, not on the box.

**C2 — one canonical host.** Pick `api-staging.hasta.app` (your own zone) rather than
`hasta-api.nexusmmr.com` / `api.oddsmyanmar.online`; the last three attempts each failed for a
different reason (NXDOMAIN, proxy 404, wrong A record `104.207.77.242`). One host = one DNS zone =
one Nginx `server_name` = one CI base URL.

**C3 — edge.** Ship `infra/nginx/hasta-api.conf` + `infra/systemd/hasta-api.service`.
Cloudflare: **Proxied**, SSL mode **Full (strict)**, Origin CA cert on the box. Keep `:3000`
bound to `127.0.0.1` and `UFW allow 22,80,443`.

**C4 — health contract (the piece still missing).** The log shows `GET /health` returns
`{"status":"ok"}` only. Extend it to:

    { "status": "ok", "env": "staging", "commit": "<40-char GIT_COMMIT>", "version": "1.2.0", "db": "up" }

Bake `GIT_COMMIT` as a build arg into the image and pass it through systemd. Then
`scripts/verify-staging.sh <URL> <SHA>` is the single gate: HTTP 200 **and** `env == staging`
**and** `commit == git rev-parse HEAD`. No SHA echo → no sign-off, ever.

**C5 — deployment record.** Add `.github/workflows/deploy-staging.yml` (shipped) with
`environment: staging` + required reviewers, so GitHub's deployments page shows a staging API
release instead of "GitHub Pages only".

**C6 — fixtures + artifacts.** `scripts/seed-staging.sh` seeds `tester.a / b / social / premium /
minor / fresh` **only after** the health contract passes, and asserts `tester.minor` is rejected
from wagering. Keep **two APKs**: a non-release QA build (long-press fixture panel) and a release
build that must pass the T36 exclusion scan — the log already proved a release APK with the panel
violates T36.

**C7 — 12-item smoke checklist.** Run against the live URL and record a `request_id` per item;
an item with no `request_id` counts as not run.

**Failure ladder (use in this order — each has already occurred here):**
`NXDOMAIN` → DNS zone has no record · `404 page not found` → Nginx `server_name`/`proxy_pass`
path mismatch · `502` → upstream down or bound to wrong interface · `521/522` → Cloudflare can't
reach origin / UFW blocking · `err_ssl_version` / "Not secure" → SSL mode is Flexible, switch to
Full (strict) with Origin CA · `403` from `/health` → WAF rule on the health path.

---

## 4. Phase D — "Production Grade" definition of done

Anything unchecked here is a production incident with a delay attached.

| Area | Requirement | Verification |
| --- | --- | --- |
| Secrets | No `.env` in git; per-environment signing keys; vault/SSM; 90-day rotation | secret scan + `gitleaks` in CI |
| Data | Postgres 16 pinned (T48), managed HA, PITR ≤ 15 min, nightly snapshot + **quarterly restore drill** | restore ticket |
| Migrations | `expand → backfill → contract`, reversible, never a locking DDL on a hot table | migration dry-run on staging clone |
| Compute | ≥ 2 API replicas behind LB, readiness vs liveness split, graceful WebSocket drain, OOM guard | kill a pod mid-session, no 5xx spike |
| WebSockets | Redis adapter, heartbeat ≤ 30 s, reconnect with backoff + jitter, server-side dedup (T17 outbox) | 1 000-concurrent-connection soak |
| Abuse | Per-device + per-IP rate limits, WAF rules, origin accepts Cloudflare IPs only, replay-row **global** expiry job (ops closure of P0-REPLAY-RETENTION) | load test + cleanup test without a second request |
| Observability | Structured JSON logs with `request_id`; redact tokens, emails, PINs; OpenTelemetry traces; RED dashboards; alerts on p95, 5xx, WS reconnect rate, DB pool, lagging replay cleanup, health-SHA mismatch, cert expiry, RAM/swap | page a human in a drill |
| Security | TLS 1.2+, HSTS, Argon2id for PIN, device-bound refresh + family revocation (already merged), SCA (`trivy`) on images + `npm audit`/`flutter` deps, GH push protection, least-privilege env secrets | CI fail on critical |
| Privacy | Account deletion + data export, 30-day grace, retention policy, audit log for entitlement and payout changes | end-to-end deletion test |
| Load | k6 scenarios for guest auth, `/v1/me`, feed read, WS chat; targets p95 < 400 ms API, < 150 ms WS | report attached to release |
| Release | Semver tags, signed AAB + signed iOS artifact, staged rollout 5 → 20 → 50 → 100 % behind a remote-config kill switch, **rollback < 10 min rehearsed** | rehearsal log |
| Feature flags | `gmail_linking`, `wagering`, `premium_unlock`, `dating` default **off** server-side (client checks are advisory only) | config snapshot at deploy |
| Ops | On-call rota, severity levels, incident template, postmortem within 72 h, error budget | runbook in `docs/ops/` |
| Cost | Budget alerts, CDN for static, log retention 30 d hot / 180 d cold | billing rule |

---

## 5. Phase E — the legal gate (No-Go until cleared)

This is a hard gate, not advice. Myanmar's **Cybersecurity Law** (enacted 1 January 2025, **in
force 30 July 2025**) criminalises establishing an online gambling system without permission:
**6 months–1 year imprisonment and/or a fine of 5–20 million kyat for an individual; an
organisation is fined not less than 20 million kyat, with the related property confiscated.**
The law reaches conduct inside Myanmar's national cyber domain and **applies to Myanmar citizens
who commit the offence abroad**. Unlicensed VPN establishment or provision is separately
punishable (1–6 months and/or 1–10 million kyat). *(Sources: The Star, 3 Jan 2025 & 1 Aug 2025.)*

Consequences for this product, stated plainly:

1. **Do not enable wagering for Myanmar-resident users** without a licence or a written legal
   opinion. There is no public online-casino licensing pathway in Myanmar today, so "we are
   applying" is not a defensible position. Ship code, keep `wagering` flag off, keep the entry
   state `disabled` for Myanmar geo — exactly the position the integration guide already took.
2. **Store policy will refuse it anyway.** Apple Guideline 5.3 requires a licence per distribution
   territory, real server-side **geo-fencing that blocks users located in prohibited territories**,
   no mixing of social-casino and real-money play inside one app, and no IAP for stakes. Google
   Play requires prior written approval and a country whitelist — Myanmar is not on it — so an
   APK/AAB carrying wagering risks rejection, takedown and **developer-account termination**.
3. **Advertising**: Google Ads gambling certification is per-country; social-casino lists ~36
   permitted countries, Myanmar not among them. Do not plan Myanmar paid acquisition for wagering.
4. **Never ship access-via-VPN guidance, or a domain/metadata set that advertises unlicensed
   betting** (e.g. `oddsmyanmar.online` as the API host on a store-listed app) — it is evidence,
   and it also breaks the store metadata review.
5. **Non-negotiable controls in whichever market you do open**: 18+/KYC before any deposit,
   deposit/loss/time limits, self-exclusion, reality checks, certified RNG (GLI-19 or the licence
   jurisdiction's equivalent), immutable bet & payout audit ledger, AML screening for Web3
   withdrawals with an allowlisted destination address set, and a **CI-blocking minor-account test**
   (the `tester.minor` fixture must get 4xx, asserted in `scripts/seed-staging.sh`).
6. **Recommended live variant for now**: Phase-1 launch = social + premium non-wagering features,
   geo-scoped to a jurisdiction where the licence exists, with server-side entitlement checks and
   the wagering module compiled out of the store artifact. Store the legal sign-off as
   `decisions/ADR-0017-licence-geo-gate.md` before anyone flips a flag.

မြန်မာအကျဉ်း — မြန်မာ Cybersecurity Law (၂၀၂၅ ဇူလိုင် ၃၀ ရက်မှ တည်ရှိ) အရ ခွင့်ပြုချက်မရှိ လောင်းကစားစနစ် တည်ဆောက်ခြင်းသည် အကျဉ်း + ငွေဒဏ် ဖြစ်နိုင်ပါတယ်။ ဒါကြောင့် **wagering flag ကို Myanmar user များအတွက် ပွင့်မထားရ** — code ကိုတော့ အသင့်ရှိအောင် ထားနိုင်ပါတယ်။ Store (Apple 5.3 / Google Play) ကလည်း licence မပါဘဲ ပယ်ဖျက်ပါတယ်။ Live ကို social/premium (မလောင်းကစားရသော feature) သုံးပြီး စတင်အကြံပြုပါတယ်။

---

## 6. Merge train and PR hygiene

    PR #5  tokens at canonical path + generator + --check  → merge to main   (< 200 lines)
    PR #3  rebase on main → iOS green → merge                               (frozen at 938)
    PR #4  rebase on main → fix P2-SESSION-ACTIVITY-LABEL → ACCEPT → merge  (322 + delta)
    PR #6  session revocation controls + native T30 (new, ≤ 400)
    PR #7  staging infra: nginx + systemd + workflow + verify scripts (new, ≤ 400)

Rules to hold from here on: **no more line-cap waivers** — every further fix opens a new draft
targeting its parent branch; a draft is never used as a parking lot for unrelated work; `main`
stays protected; nothing is merged while iOS is queued; a verdict of "ACCEPT for the draft scope"
is a code-review result, not merge or release approval.

---

## 7. Next one-liners (in order, one per message)

    Hasta fix P0-DESIGN-TOKENS-GATE          # commit assets/design-tokens.json + mjs from this package
    Hasta review PR #5
    Hasta rebase PR #3 and PR #4 onto main
    Hasta fix P2-SESSION-ACTIVITY-LABEL
    Hasta review PR #4 after CI
    Hasta provision staging api-staging.hasta.app   # C1–C5, then health SHA contract
    Hasta staging QA https://api-staging.hasta.app <40-char SHA>
    Hasta seed fixtures <staging URL> <SHA>
    Hasta test T40 native with fail-fast
    Hasta test T30 native Gmail callback
    Hasta adr 0017 licence geo gate wagering off
    Hasta release candidate 1.0.0-rc1

---

## 8. Go / No-Go checklist

| Gate | Must be true | Status now |
| --- | --- | --- |
| Design tokens | canonical source present, Dart generated, `--check` in CI, RED control shown | 🔴 blocked (Phase A) |
| CI | backend, gates, Android, iOS, Terraform all GREEN on one SHA | 🟠 iOS queued |
| S1 | merged, guest auth live | ✅ |
| S2 | linking + recovery + revocation + native consent/app association/device toggle | 🟠 draft accepted, native open |
| Staging | stable DNS, TLS Full(strict), `/health` echoes SHA + env, `staging` environment record | 🔴 none of it yet |
| QA evidence | 6 fixtures seeded, T40/T41 pass-or-explicit-skip, 12 smoke items with request_ids | 🔴 not run |
| Operations | backup/restore drill, alerts paging, rollback rehearsed, kill switch | 🔴 not built |
| **Legal** | licence or written opinion on file; wagering geo-fenced off for Myanmar; 18+/KYC/RNG | 🔴 not cleared |
| **Verdict** | | **No-Go for a wagering launch. Go for staging build + social/premium-only RC.** |

---

## 9. Risk register (top 6)

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| 1 GB box OOM-kills the API during CI-driven builds | High | swap now, 2 GB staging / 4 GB prod, build in CI, `MemoryMax` in systemd |
| DNS drift across two registrars (Cloudflare + Spaceship) pointing the old host at `104.207.77.242` | High | single zone, single canonical host, delete stale records, `dig` check in CI |
| Quick-tunnel URL reused as "staging" in a sign-off | High | health contract requires `env: staging` + SHA; `verify-staging.sh` warns on `trycloudflare` |
| T40/T41 hangs again and eats the runner budget | Medium | `timeout-minutes`, `skipIf` with explicit reason, cached Gradle/Pods |
| Draft PR line growth hiding regressions | Medium | cap frozen, new PR per fix (section 6) |
| Wagering flag reaching Myanmar users | Severe | server-side geo+licence gate, flag default off, store artifact compiled without wagering, ADR-0017 |

---

## 10. Files shipped with this plan

| Path | Purpose |
| --- | --- |
| `assets/design-tokens.json` | DS 1.0.2 source of truth (DTCG, 56 tokens, aliases, `lineHeight.body = 1.65`, Myanmar families) |
| `tools/scripts/design-tokens.mjs` | Generator + `--check`, fails closed on absent/misplaced source (validated: 1 GREEN / 5 RED scenarios) |
| `apps/mobile/lib/design_tokens.g.dart` | Regenerated output, ready to commit; `bgBrand / bgBrandPressed / bgBrandDisabled / primaryButton*` |
| `infra/nginx/hasta-api.conf` | 80→443, Origin CA TLS, `/health` exact path, `/ws/` upgrade, rate limit, `X-Request-Id` |
| `infra/systemd/hasta-api.service` | Non-root, `MemoryMax`, loopback-only bind, graceful WS drain, hardened unit |
| `.github/workflows/deploy-staging.yml` | `environment: staging` deployment record + baked `GIT_COMMIT` + post-deploy health gate |
| `scripts/verify-staging.sh` | DNS/TLS/health SHA/env contract — the pass condition for every QA run |
| `scripts/seed-staging.sh` | Seeds the six fixtures only after the contract passes; asserts `tester.minor` cannot wager |
| `.hasta/STATE.md` | Tracker aligned to this log — replace the one in `main` |
| `docs/qa/logic-ui-state-verification-guide.md` | The guide the agent could not find; §2.3 holds the token assertions |
