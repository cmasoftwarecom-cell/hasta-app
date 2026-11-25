# T28: Local Android optical transfer and old-device relaunch

Use two dedicated Android 11+ phones with no Hasta installation, USB debugging authorized, a hardware-backed screen lock on the source, and a working camera on the replacement. Use Flutter 3.24.5, Android build tools, Node 20, and a freshly created disposable PostgreSQL 16 database named `hasta_test` bound to host loopback. The runner starts a loopback-only API, creates emulator-independent Android debug artifacts, and uses `adb reverse`. No cloud, staging, screenshot file, or live account is needed.

```bash
export HASTA_DATABASE_URL='postgresql://hasta@127.0.0.1:55432/hasta_test'
bash tools/scripts/test-t28-android.sh SOURCE_SERIAL REPLACEMENT_SERIAL
```

At the prompts:

1. Create one Guest on the source and leave the replacement on Welcome. For the replacement, long-press the Hasta launcher icon to find **Receive Hasta account**. Do not tap Continue there. The runner checks the native UI and snapshots the single initial account and binding.
2. On the source, open **Settings → Change device → Show transfer QR**. The runner checks the native window's secure flag without taking a screenshot.
3. Open the launcher shortcut and camera on the replacement. Allow camera access and point it at the physical source screen. Compare the two codes, then **Codes match. Approve transfer** and complete the real OS prompt on the source. Finish before the original 120-second deadline.
4. Expect Welcome on the source and Profile on the replacement. The runner relaunches both apps and checks the same native UI states again. It also requires one original account, one active target binding, the consumed and claimed transfer, and revocation of the old session with reason `transfer`. Passing requires all checks.

The runner refuses a phone with an existing Hasta install and does not uninstall QA packages. Before a repeat, manually remove the harness-installed APKs on the dedicated phones and use a fresh disposable database. The debug feature requires both the Dart define and server opt-in; release/profile never expose these surfaces.
