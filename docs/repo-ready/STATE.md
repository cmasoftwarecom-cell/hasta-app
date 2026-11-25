# .hasta/STATE.md — SPEC 1.0.2 · updated after `Hasta review PR #3` (ac55526)

status: S2 IN REVIEW — pipeline blocked by a CI gate, not by code quality
next:   Hasta fix P0-DESIGN-TOKENS-GATE

## Repo
main:            3983817 (carries stale assets/assets/design-tokens.json; canonical path absent)
PR #2 (S1):      MERGED
PR #3 (S2 Gmail linking): DRAFT @ ac55526 · 938 changed lines (+879/−59) · ACCEPT for draft scope · no open P0/P1/P2
PR #4 (Security & Devices): DRAFT @ dd5b261 · 322 changed lines · REQUEST CHANGES (P0-DESIGN-TOKENS-GATE inherited)
merge train:     #5 (tokens) → merge → rebase #3 → merge → rebase #4 → #6 (revocation + native T30) → #7 (staging infra)
cap policy:      938 lines is terminal for #3; no further waivers — new fix = new draft PR (≤ 400)

## CI (latest reported)
gates        PASS   (but design-token step fails on absent source -> blocks T47 in PR #4)
terraform    PASS
backend      PASS
mobile       PASS
iOS          QUEUED — CI is NOT fully green

## Gates
T20 PASS · T36 PASS (Android artifact scan excludes QA panel; google_sign_in absent from release manifest; iOS unsigned PASS)
T37 PASS-with-caveat (server routes + 10 fixtures; real Google verifier = S2 tail; idempotency key no longer persisted; real-coordinator test committed)
T38/T39 PASS local · T40/T41 server+Flutter PASS, **NATIVE = TIMED OUT at 12 min (must fail fast, not hang)**
T42 PASS · T43 PASS (offline transition EN+MM) · T44 OPEN · T45 PASS · T46 PASS (active-token case committed)
T47 PASS locally + diff vs frozen S1 baseline; skipped in CI when no release tag
T48 PASS (postgres:16 pinned, reverse-control proven)
Design tokens P0-DESIGN-TOKENS-GATE OPEN  — assets/design-tokens.json absent on main
Design tokens P1 button wiring           — resolved in generated Dart (bgBrandPressed / bgBrandDisabled emitted)
P2-SESSION-ACTIVITY-LABEL                OPEN (last_seen_at null -> label "Signed in", EN+MM test)

## Staging
dns:      api-social.hasta.app NXDOMAIN · hasta-api.nexusmmr.com proxied -> 404 · api.oddsmyanmar.online -> 104.207.77.242 (wrong origin)
origin:   Vultr 149.28.136.202, Ubuntu 24.04, **1024 MB RAM (insufficient — add 2 GB swap, resize to 2 GB; move Postgres to managed)**
health:   GET /health -> {"status":"ok"} — NO env, NO commit field => SHA contract unmet; /v1/health does not exist
port 3000: private by design (do not expose; QA goes through Nginx HTTPS)
fixtures: NOT SEEDED · smoke 12-item: NOT RUN (no request_ids)
artifacts: staging APK NOT built; a release APK may never contain the QA panel (T36)
decision:   one canonical host (recommended api-staging.hasta.app), named tunnel or LB, Full(strict), deploy-staging.yml with environment: staging
tools ready: scripts/verify-staging.sh · scripts/seed-staging.sh · infra/nginx/hasta-api.conf · infra/systemd/hasta-api.service

## Native / external QA still open
native Gmail consent on a real device · app association (assetlinks.json + AASA served from the API host) ·
device-toggle QA EN+MM · T30 reinstall/recovery · physical T28 two-device QR

## Rulings / ADRs
ADR-0007 Prisma schema · ADR-0008 S1 draft rationale · ADR-0009 installation proof, fail-closed legacy bindings, Android API 23
ADR-0012 Gmail linking opt-in + debug-only, external browser, masked email only, UUIDv7 Idempotency-Key not persisted
ADR-0014/0015/0016 rollout holds in effect
ADR-0017 [PROPOSAL — REQUIRED BEFORE ANY WAGERING FLAG] licence + server-side geo gate; Myanmar Cybersecurity Law
  (in force 2025-07-30) penalises unlicensed online gambling systems (6 mo–1 yr and/or 5–20M MMK;
  organisation ≥ 20M MMK + confiscation; applies to Myanmar citizens abroad). Apple 5.3 and Google Play
  both require a per-territory licence and server-side geo-fencing; Myanmar is not on the Play whitelist.

## Compliance flags (block release, not staging)
wagering=true for MM-resident users   -> NO-GO until legal opinion exists in decisions/
18+/KYC, deposit & loss limits, self-exclusion, RNG certification, AML withdrawal allowlist -> REQUIRED
no VPN-based access guidance          -> REQUIRED
store listing metadata must not advertise unlicensed betting (incl. API host naming) -> REQUIRED

## Deviations introduced this cycle
None. No security/QA rule, sign-in rule or release restriction was relaxed.

## Next prompt
Hasta fix P0-DESIGN-TOKENS-GATE
