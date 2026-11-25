#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: bash tools/scripts/test-t28-android.sh <dedicated-source-serial> <dedicated-replacement-serial>' >&2
  exit 2
}
[[ $# == 2 && $1 =~ ^[[:alnum:]_.:-]+$ && $2 =~ ^[[:alnum:]_.:-]+$ && $1 != "$2" ]] || usage
for tool in adb flutter curl node npm; do
  command -v "$tool" >/dev/null || { echo "T28 blocked: $tool is not on PATH." >&2; exit 2; }
done
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
old=$1 new=$2
app=app.hasta.mobile
port=${HASTA_T28_PORT:-3028}
[[ $port =~ ^[1-9][0-9]{3,4}$ ]] && ((port <= 65535)) || usage

for serial in "$old" "$new"; do
  if [[ $(adb -s "$serial" get-state 2>/dev/null || true) != device ]]; then
    echo 'T28 blocked: two authorized Android devices must be connected.' >&2
    exit 2
  fi
  sdk=$(adb -s "$serial" shell getprop ro.build.version.sdk | tr -d '\r')
  [[ $sdk =~ ^[0-9]+$ ]] && ((sdk >= 30)) &&
    [[ $(adb -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r') != 1 ]] || {
      echo 'T28 requires two physical Android 11+ devices with a real camera and a hardware-backed source lock.' >&2
      exit 2
    }
  if adb -s "$serial" shell pm path "$app" 2>/dev/null | grep -q '^package:'; then
    echo 'T28 requires dedicated devices without an existing Hasta installation.' >&2
    exit 2
  fi
done

[[ -t 0 ]] || { echo 'T28 requires a local operator for the live camera scan and native approval.' >&2; exit 2; }
node -e '
  const text = process.env.HASTA_DATABASE_URL ?? "";
  if (!URL.canParse(text)) process.exit(2);
  const u = new URL(text);
  if (u.protocol !== "postgresql:" || u.hostname !== "127.0.0.1" ||
      u.pathname !== "/hasta_test" || u.search || u.hash) process.exit(2);
' || { echo 'T28 requires a disposable loopback hasta_test PostgreSQL database.' >&2; exit 2; }

export HASTA_ENV=test
url="http://127.0.0.1:$port"
tmp=$(mktemp -d)
api=''
reversed=()
dump=/data/local/tmp/hasta-t28-ui.xml
cleanup() {
  [[ -z $api ]] || { kill "$api" 2>/dev/null || true; wait "$api" 2>/dev/null || true; }
  for serial in "${reversed[@]}"; do
    adb -s "$serial" reverse --remove "tcp:$port" >/dev/null 2>&1 || true
    adb -s "$serial" shell rm -f "$dump" >/dev/null 2>&1 || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

assert_ui() {
  local serial=$1 id=$2
  for _ in {1..6}; do
    if adb -s "$serial" shell uiautomator dump "$dump" >/dev/null 2>&1 &&
       adb -s "$serial" exec-out cat "$dump" | node -e '
         const xml = require("node:fs").readFileSync(0, "utf8");
         const id = process.argv[1];
         process.exit(new RegExp(`resource-id="(?:app\\.hasta\\.mobile:id/)?${id}"`).test(xml) ? 0 : 1)
       ' "$id"; then
      adb -s "$serial" shell rm -f "$dump"
      return 0
    fi
  done
  echo 'T28 did not find the expected native UI state.' >&2
  return 1
}

(
  cd "$root/apps/server"
  npm run build
  npx --no-install prisma migrate deploy
)
node "$root/apps/server/test/native-transfer-api.cjs" "$port" >"$tmp/api.log" 2>&1 &
api=$!
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 "$url/health" >/dev/null
kill -0 "$api"
(
  cd "$root/apps/mobile"
  flutter pub get --enforce-lockfile
  flutter gen-l10n
  flutter build apk --debug --no-pub --dart-define=HASTA_ENV=test \
    --dart-define=HASTA_AUTH_QR_TRANSFER_ENABLED=true "--dart-define=HASTA_API_BASE_URL=$url"
)
for serial in "$old" "$new"; do
  adb -s "$serial" reverse --no-rebind "tcp:$port" "tcp:$port"
  reversed+=("$serial")
  adb -s "$serial" install "$root/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk" >/dev/null
  adb -s "$serial" shell am start -n "$app/.MainActivity" >/dev/null
done

read -r -p 'Enter Guest on the source only. Leave the replacement on Welcome. Press Return when the source profile appears. '
assert_ui "$old" hasta_signed_in_profile
assert_ui "$new" hasta_welcome_continue
curl -fsS -X POST "$url/_native/transfer/ready" >/dev/null

read -r -p 'On the source, open Settings > Change device > Show transfer QR. Press Return with the QR visible. '
assert_ui "$old" hasta_transfer_qr
adb -s "$old" shell dumpsys window windows | awk '
  /Window #[0-9]+ Window\{/ { own = /app\.hasta\.mobile\/(app\.hasta\.mobile)?\.MainActivity/ }
  own && /(^|[= |])SECURE([ |}]|$)/ { secure = 1 }
  END { exit !secure }
' || { echo 'T28 could not verify FLAG_SECURE for the source window.' >&2; exit 1; }

echo 'On the replacement, use the Hasta launcher shortcut, open the camera, and optically scan the source screen.'
echo 'Verify that the matching codes agree. Approve on the source with the OS credential prompt.'
read -r -p 'Press Return after Welcome appears on the source and Profile on the replacement. '
assert_ui "$old" hasta_welcome_continue
assert_ui "$new" hasta_signed_in_profile
for serial in "$old" "$new"; do
  adb -s "$serial" shell am force-stop "$app"
  adb -s "$serial" shell am start -n "$app/.MainActivity" >/dev/null
done
assert_ui "$old" hasta_welcome_continue
assert_ui "$new" hasta_signed_in_profile
curl -fsS "$url/_native/transfer/verify" >/dev/null
echo 'T28 native optical transfer, source relaunch and binding/session assertions: PASS'
