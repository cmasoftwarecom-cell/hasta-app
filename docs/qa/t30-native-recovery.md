# T30: Android browser callback and replacement-device reinstall

This test uses the app's native device ID, Android secure storage, an external Chrome window, and a real callback intent into Flutter. The only identity provider is an in-process fixture that issues ephemeral signed Google-shaped proofs. No live Google account, signed distribution build, staging service, DNS change, or tunnel is required.

## Run locally

1. Boot two dedicated Android emulators with distinct identities and Chrome available. Complete Chrome's first-run screen and choose Chrome as the default browser on the replacement emulator. Do not use personal devices or emulators with an existing Hasta installation; the script installs and uninstalls the package.
2. Start a fresh, disposable PostgreSQL 16 instance with a database named `hasta_test` listening at `127.0.0.1`. Set `HASTA_DATABASE_URL` for that database. Install the locked server dependencies with `npm --prefix apps/server ci`.
3. With Flutter 3.24.5, Android SDK tools and the emulator serials available, run:

   ```bash
   adb devices
   bash tools/scripts/test-t30-android.sh emulator-5554 emulator-5556
   ```

The first install creates exactly one guest on the old emulator. The fixture links that account to a synthetic verified Google subject. The script then installs and uninstalls the app on the replacement emulator, installs the recovery build there, and asserts an empty local session. Chrome opens the loopback consent page. The runner locates and taps its return link in Chrome, not via a direct `adb am start` callback. The test requires successful recovery and restore of the same account, a distinct active device binding, retired old credentials and binding, one browser visit, one code exchange, and no additional account.

If the test reports that it could not find the return link, check Chrome is the default browser and not showing onboarding. The script refuses non-emulator serials, a non-loopback or non-test database, and an existing app installation on either emulator. Use fresh emulators and a fresh database for each run. `HASTA_T30_PORT` can override the default loopback port `3000`.

## Coverage limits

The Android debug manifest registers `hasta-recovery-qa://callback/complete` only for the fixture. The Dart test adapts that URI to the HTTPS redirect before applying the same callback-state and server verification used by the production flow. This exercises native browser delivery, not the verification of an HTTPS domain association by Android or iOS.

The production callback is `https://<configured-host>/auth/recovery/callback`. Android takes `HASTA_RECOVERY_LINK_HOST` when building; iOS takes the same build setting via `Flutter/RecoveryHost.xcconfig` or Xcode settings. The server redirect and signed app association must match the selected host and path. The default `.invalid` host is not usable for production recovery. The iOS handler is present but not exercised by the Android script. A signed-app HTTPS association check, iOS browser/reinstall run, and a user-facing recovery entry outside Welcome remain separate work.

For test-harness development only, the server fixture can be exercised without a phone using `node --test test/native-recovery-fixture.test.cjs` from `apps/server` against a separately migrated, fresh loopback `hasta_test` database with `HASTA_ENV=test`. That check is not native T30.
