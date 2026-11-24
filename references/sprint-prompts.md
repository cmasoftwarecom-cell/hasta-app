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
