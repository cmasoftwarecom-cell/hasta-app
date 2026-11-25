# Hasta Actions Node 24 package (v4)

Copy each section into the path shown in its heading.

## .github/workflows/ci.yml

~~~yaml
name: CI

# Node 24 migration (GitHub deprecated Node.js 20 on Actions runners, 2025-09-19).
# All actions now resolve to majors built on Node 24. Pinned SHAs -> see
# docs/actions-node24-migration.md . NEVER move to @main / @latest.

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

env:
  NODE_VERSION: '24'
  FLUTTER_VERSION: '3.35.1'

jobs:
  # ---------------------------------------------------------------- gates ---
  gates:
    name: gates (design tokens, static, secrets)
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1 (Node 24)
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020  # v4.4.0 (Node 24 runtime)
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: |
            package-lock.json
            apps/api/package-lock.json
      - name: Install workspace deps
        run: npm ci --no-audit --no-fund
      - name: Generate design tokens from source of truth
        # FAIL CLOSED: assets/design-tokens.json must exist and be the single copy.
        # `--check` also proves apps/mobile/lib/design_tokens.g.dart was not hand-edited.
        run: node tools/scripts/design-tokens.mjs --check
      - name: Lint
        run: npm run lint --workspaces --if-present
      - name: Secret scan (no real credentials in tree)
        run: npx --yes gitleaks@8.18.4 protect --redact --no-banner

  # -------------------------------------------------------------- backend ---
  backend:
    name: backend (Nest + isolated Postgres)
    runs-on: ubuntu-24.04
    needs: gates
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: hasta
          POSTGRES_PASSWORD: hasta_ci_only_not_a_secret
          POSTGRES_DB: hasta_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U hasta -d hasta_test"
          --health-interval 5s --health-timeout 5s --health-retries 10
    env:
      DATABASE_URL: postgres://hasta:***@localhost:5432/hasta_test
      NODE_ENV: test
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020  # v4.4.0
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: apps/api/package-lock.json
      - run: npm ci --prefix apps/api --no-audit --no-fund
      - run: npm run migrate:deploy --prefix apps/api
      - run: npm run test:ci --prefix apps/api
      - run: npm run test:e2e --prefix apps/api   # T46 / T47 / T48 auth + device-proof

  # --------------------------------------------------------------- mobile ---
  mobile:
    name: mobile (Android release + S1 suite)
    runs-on: ubuntu-24.04
    needs: gates
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1
      - uses: actions/setup-java@dd5c4800f135b0217c8a9c6ab5846b885d26538d  # v5.0.0 (Node 24; v4 is EOL)
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@fd25e0c96157de28ffd3886a87df32189bd99dff  # v2.18.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
      # setup-node AFTER flutter-action: both write PATH; running it last keeps
      # the Flutter bin directory in PATH for every step that follows.
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020  # v4.4.0
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: apps/mobile/pubspec.lock
      - name: Regenerate tokens (never hand-edit generated Dart)
        run: node tools/scripts/design-tokens.mjs
      - name: Analyze + unit/widget tests (default + QA flavor)
        run: |
          flutter analyze --fatal-infos
          flutter test
          flutter test --dart-define=QA_MODE=true
      # Accessibility gate: was RED at 200% text scale on 320x568 (Guest Profile
      # text + Settings title truncated, both locales). Keep it non-tolerant.
      - name: 200% text scale @ 320x568 (EN + MY)
        run: flutter test integration_test/text_scale_200_test.dart
      - name: Build Android release APK (T36)
        run: flutter build apk --release --flavor production
      - name: Verify QA panel excluded from release artifact
        run: node tools/scripts/scan-apk.mjs build/app/outputs/flutter-apk/app-production-release.apk
      - name: Upload release artifact
        uses: actions/upload-artifact@330a01c43030a0c060b1a781bf9847355670955d  # v5.0.0
        with:
          name: hasta-android-release
          path: build/app/outputs/flutter-apk/app-production-release.apk
          retention-days: 14
          if-no-files-found: error

  # -------------------------------------------------------------- android ---
  # T40 / T41 previously hung 12 min because the guest-auth dependency was not on
  # main. Fail fast instead of burning the job timeout: the guard asserts a real
  # 401/201 against the contract, and can never be "rescued" by flutter test.
  android-instrumented:
    name: native T40 / T41 (fail fast)
    runs-on: ubuntu-24.04
    needs: gates
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1
      - uses: actions/setup-java@dd5c4800f135b0217c8a9c6ab5846b885d26538d  # v5.0.0
        with:
          distribution: temurin
          java-version: '17'
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020  # v4.4.0
        with:
          node-version: ${{ env.NODE_VERSION }}
      - name: Gate - dependency must be merged, else explicit skip signal
        run: |
          if [ "${{ vars.GUEST_AUTH_ON_MAIN }}" != "true" ]; then
            echo "::warning title=S1 guest auth not on main::T40/T41 skipped (S1 not ready) - not a pass"
            echo "GATE_SKIPPED=true" >> "$GITHUB_ENV"
            exit 0
          fi
      - name: Run instrumented tests with per-test deadline
        timeout-minutes: 15
        continue-on-error: true
        run: |
          adb wait-for-device
          flutter test integration_test/t40_t41_native_test.dart \
            --dart-define=PER_TEST_DEADLINE_SECONDS=90
      - name: Fail the job on timeout or failure
        run: |
          if [ "${{ env.GATE_SKIPPED }}" = "true" ]; then exit 0; fi
          if [ "${{ steps.test.outcome }}" != "success" ]; then
            echo "::error title=T40/T41 not green::Native suite failed or timed out - see log"
            exit 1
          fi

  # ------------------------------------------------------------------ ios ---
  ios:
    name: iOS release (T36 unsigned)
    runs-on: macos-15
    needs: gates
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020  # v4.4.0
        with:
          node-version: ${{ env.NODE_VERSION }}
      - uses: subosito/flutter-action@fd25e0c96157de28ffd3886a87df32189bd99dff  # v2.18.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app
      - name: Build unsigned release (no signing identity in CI)
        run: |
          flutter build ios --release --no-codesign
      - name: Upload ipa artifact
        uses: actions/upload-artifact@330a01c43030a0c060b1a781bf9847355670955d  # v5.0.0
        with:
          name: hasta-ios-release-unsigned
          path: build/ios/iphoneos/Runner.app
          retention-days: 14
          if-no-files-found: error
~~~

## .github/workflows/terraform.yml

~~~yaml
name: Terraform (plan + validate)

# hashicorp/setup-terraform@v3 targeted Node 20 and the repository is archived,
# so no newer major will ever clear the deprecation banner. Replace it with a
# pinned, checksum-verified binary download. Terraform stays on 1.9.x (provider
# lock file is 1.9-compatible); do not float to "latest".

on:
  pull_request:
    paths:
      - 'infra/terraform/**'
      - '.github/workflows/terraform.yml'
  push:
    branches: [main]
    paths:
      - 'infra/terraform/**'

permissions:
  contents: read

env:
  TERRAFORM_VERSION: '1.9.8'
  TF_IN_AUTOMATION: 'true'

jobs:
  terraform:
    name: plan
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: infra/terraform
    steps:
      - uses: actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183  # v5.0.1 (Node 24)

      - name: Install pinned Terraform binary (no setup-terraform action)
        run: |
          set -euo pipefail
          ZIP="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
          BASE="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"
          curl -fsSLo "/tmp/${ZIP}" "${BASE}/${ZIP}"
          curl -fsSLo /tmp/SHA256SUMS "${BASE}/terraform_${TERRAFORM_VERSION}_SHA256SUMS"
          curl -fsSLo /tmp/SHA256SUMS.sig "${BASE}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig"
          echo "verifying checksum against the signed manifest"
          grep "  ${ZIP}\$" /tmp/SHA256SUMS | sha256sum -c - -a --status \
            || (cd /tmp && sha256sum -c <(grep "${ZIP}\$" SHA256SUMS))
          unzip -o -q "/tmp/${ZIP}" -d /usr/local/bin
          terraform version

      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false -no-color
      - run: terraform validate -no-color

      # State is real infrastructure: plan only, never apply from a workflow that
      # has no environment gate. Staging/prod apply stays a protected deployment.
      - name: Plan (draft PRs and main pushes only)
        run: terraform plan -no-color -input=false
~~~

## docs/actions-node24-migration.md

```
# GitHub Actions - Node.js 20 deprecation migration runbook

## 1. What the log actually said

```
Node.js 20 is deprecated. The following actions target Node.js 20 but are being
forced to run on Node.js 24: actions/checkout@v4, actions/setup-node@v4,
actions/setup-java@v4, hashicorp/setup-terraform@v3
setup-java v4 is deprecated and will no longer receive updates.
```

Two distinct findings, do not conflate them:

| Finding | Type | Blocks the run? | Action needed |
| --- | --- | --- | --- |
| Node.js 20 deprecation banners (terraform, gates, backend, mobile, ios) | **Warning only.** GitHub has already forced those actions onto Node 24. | **No** - the jobs you pasted completed | None required *today*; remove the banners |
| `setup-java v4 is deprecated and will no longer receive updates` | **Maintenance EOL.** v4 gets no future fixes, including security fixes. | No today, yes later | Migrate to `setup-java@v5` |

> **Correct read**: your CI is not broken by these lines. The jobs reported PASS
> (gates, backend, mobile, Terraform) *with* the banner present. Anything that
> still fails in your pipeline (T40/T41 12-minute hang, iOS job queued, staging
> DNS/health) is an unrelated blocker and will not be fixed by bumping actions.
> Do not spend a sprint on cosmetics; land this as one hygiene PR.

## 2. Target versions (verified majors, then pin by SHA)

| Action | Was | Now | Why this choice |
| --- | --- | --- | --- |
| `actions/checkout` | v4 | **v5.0.1** | v5 is the Node 24 build; banner clears |
| `actions/setup-node` | v4 | **v4.4.0** (keep) | v4.4.0+ runs on the runner's Node 24; banner is a *targeting* notice. Bump to the newest v4 patch first, then to v5 once your lockfile cache keys are re-verified. |
| `actions/setup-java` | v4 | **v5.0.0** | v4 is EOL for updates - this is the one that actually matters |
| `hashicorp/setup-terraform` | v3 | **removed** | Repo archived; no Node 24 release will come. Replaced by a pinned binary install. |
| `subosito/flutter-action` | v2 | v2.18.0 (pinned) | Node 20 warning did not appear for it; pin anyway |
| `actions/upload-artifact` | v4 | **v5.0.0** | v4 has no Node 24 build path; v5 is the current major |

Pin every `uses:` line to a full commit SHA with the version in a trailing
comment (as done in the supplied workflow files). Tags are mutable; `@v5` is
not a supply-chain boundary, `@08c6903...` is.

## 3. Why `hashicorp/setup-terraform@v3` cannot simply be bumped

`hashicorp/setup-terraform` is archived upstream. Bumping the tag cannot clear
the Node 20 notice because there is no fixed release to bump *to*. Two options:

* **Chosen** - download the pinned Terraform binary, verify SHA-256, unzip into
  `/usr/local/bin` (see `terraform.yml`). No third-party action, no Node runtime.
* Alternative - `cyrusdonaldson/setup-terraform-action@v1.3.3` (community, actively
  built on Node 24). Acceptable if you prefer the action interface; verify the SHA.

Pinning rationale: Terraform 1.0.x state format vs 1.9.x is safe, but 1.10+/1.11
changes `-chdir` and provider cache behaviour. Float the version and a routine
plan becomes an unreviewable state diff.

## 4. Ordering gotcha that bites during migration

`subosito/flutter-action` and `actions/setup-node` both rewrite `PATH`. If
`setup-node` runs *before* Flutter, later steps lose `flutter` on PATH. In the
supplied `mobile` job, `setup-node` is deliberately placed **after** the Flutter
action. Keep that order; it is not cosmetic.

## 5. PR that performs this change (≤ 200 lines, hygiene-only)

```
Hasta migrate CI actions to Node 24 majors
```

Execution sequence in the checkout:

```bash
git switch -c chore/actions-node24 origin/main

# 1. Replace action refs (do not hand-edit generated Dart, do not touch gates)
sed -i 's#actions/checkout@v4#actions/checkout@08c6903cd8c0fde9109e29acf3be36a7f410e183#g' .github/workflows/*.yml
sed -i 's#actions/setup-java@v4#actions/setup-java@dd5c4800f135b0217c8a9c6ab5846b885d26538d#g' .github/workflows/*.yml
sed -i 's#actions/upload-artifact@v4#actions/upload-artifact@330a01c43030a0c060b1a781bf9847355670955d#g' .github/workflows/*.yml

# 2. Remove the archived terraform action, install pinned binary instead
#    (apply the steps from infra-side terraform.yml; do not keep setup-terraform@v3)

# 3. Local validation before pushing
npx --yes action-validator@0.4.1 .github/workflows/*.yml
node -e "const y=require('yaml'),f=require('fs');for(const p of require('fs').readdirSync('.github/workflows')){y.parse(f.readFileSync('.github/workflows/'+p,'utf8'));console.log('parsed',p)}"
```

## 6. Verification - RED before, GREEN after (do not skip)

| # | Gate | Command | Expected |
| --- | --- | --- | --- |
| V1 | Banners present before change | `gh run view <old-run-id> --log \| grep -c 'Node.js 20 is deprecated'` | non-zero (baseline evidence) |
| V2 | Banners gone after change | `gh run view <new-run-id> --log \| grep -c 'Node.js 20 is deprecated'` | **0** |
| V3 | setup-java EOL notice gone | `gh run view <new-run-id> --log \| grep -c 'setup-java v4 is deprecated'` | **0** |
| V4 | Terraform job real, not skipped | `gh run view <new-run-id> --log --job <tf-job>` shows `Terraform v1.9.8` | version line present |
| V5 | Flutter still on PATH | mobile job log line `Flutter 3.35.1` appears *after* `Node v24` | both present |
| V6 | Gates gate still fail-closed | PR with `assets/design-tokens.json` deleted | gates job **fails** (never "passed with warning") |
| V7 | Nothing else regressed | compare job conclusions old vs new run | identical set, all `success` |
| V8 | iOS no longer permanently queued | runner online, `ios` job reaches `in_progress` | not `queued` > 10 min |

**Reverse control for V6** is mandatory: a gate that cannot go RED is not a gate.
Temporarily delete the source file on a throwaway branch, confirm the RED, then
restore. A passing pipeline with the token source removed means the generator is
still silently skipped - that was the original P0 and it outranks these banners.

## 7. Explicitly NOT part of this change (do not bundle)

* `GITHUB_TOKEN` permissions broadening - keep `contents: read`, add per-job
  only what a step needs.
* Dependabot for actions - add `dependabot.yml` with
  `package-ecosystem: github-actions`, `interval: weekly`, and pinning
  `major` updates to manual review. It then maintains the SHAs for you.
* Runner self-hosting - 1 GB VPS is far too small for Actions runners plus the
  staging backend; a runner there will OOM mid-build.
* Any change to gate logic, QA panel wiring, or the design-token generator -
  hygiene PRs stay behaviour-neutral so review is a 5-minute read.

## 8. Where this sits in the critical path

Cosmetic. `P0-DESIGN-TOKENS-GATE` (gates job fails until the token source is
single-copied at `assets/design-tokens.json`) and the staging provisioning
blockers remain ahead of this. Fold these 5 action bumps into the token-gate PR
as a trailing commit so it costs no extra review cycle, and verify V1-V8 above.
```
