#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ! $1 =~ ^emulator-[0-9]+$ || ! $2 =~ ^emulator-[0-9]+$ || $1 == "$2" ]]; then
  printf 'Usage: bash tools/scripts/test-t30-android.sh <dedicated-old-emulator> <dedicated-replacement-emulator>\n' >&2
  exit 2
fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
old=$1
replacement=$2
port=${HASTA_T30_PORT:-3000}
if [[ ! $port =~ ^[0-9]{4,5}$ ]] || ((10#$port < 1024 || 10#$port > 65535)); then
  echo 'T30 requires a valid unprivileged loopback port.' >&2
  exit 2
fi
export HASTA_ENV=test
node -e '
  const u = new URL(process.env.HASTA_DATABASE_URL);
  if (u.protocol !== "postgresql:" || u.hostname !== "127.0.0.1" ||
      u.pathname !== "/hasta_test" || u.search || u.hash) process.exit(2);
'
for bin in adb flutter curl npm node; do
  command -v "$bin" >/dev/null || { echo "T30 requires $bin on PATH." >&2; exit 2; }
done
for device in "$old" "$replacement"; do
  [[ $(adb -s "$device" shell getprop ro.kernel.qemu | tr -d '\r') == 1 ]]
  [[ $(adb -s "$device" shell getprop sys.boot_completed | tr -d '\r') == 1 ]]
  if adb -s "$device" shell pm path app.hasta.mobile | tr -d '\r' | grep -q '^package:'; then
    echo 'T30 requires two dedicated emulators without an existing Hasta install.' >&2
    exit 2
  fi
done

url="http://127.0.0.1:$port"
tmp=$(mktemp -d)
api_pid=''
driver_pid=''
old_reverse=''
replacement_reverse=''
cleanup() {
  if [[ -n $driver_pid ]]; then kill "$driver_pid" 2>/dev/null || true; fi
  if [[ -n $api_pid ]]; then kill "$api_pid" 2>/dev/null || true; fi
  if [[ -n $old_reverse ]]; then adb -s "$old" reverse --remove "tcp:$port" >/dev/null 2>&1 || true; fi
  if [[ -n $replacement_reverse ]]; then adb -s "$replacement" reverse --remove "tcp:$port" >/dev/null 2>&1 || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

(
  cd "$root/apps/server"
  npm run build
  npx --no-install prisma migrate deploy
)
node "$root/apps/server/test/native-recovery-api.cjs" "$port" >"$tmp/api.log" 2>&1 &
api_pid=$!
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 "$url/health" >/dev/null
kill -0 "$api_pid"
curl -fsS "$url/_native/recovery/ready" >/dev/null
adb -s "$old" reverse --no-rebind "tcp:$port" "tcp:$port" >/dev/null
old_reverse=1
adb -s "$replacement" reverse --no-rebind "tcp:$port" "tcp:$port" >/dev/null
replacement_reverse=1

cd "$root/apps/mobile"
flutter pub get --enforce-lockfile
flutter gen-l10n
target=integration_test/recovery_native_test.dart
driver=test_driver/recovery_native_driver.dart
build() {
  flutter build apk --debug --no-pub --target "$target" \
    "--dart-define=HASTA_API_BASE_URL=$url" "--dart-define=HASTA_T30_PHASE=$1"
  cp build/app/outputs/flutter-apk/app-debug.apk "$tmp/$1.apk"
}
drive() {
  flutter drive --no-pub --debug -d "$1" --target "$target" --driver "$driver" \
    --timeout=220 --use-application-binary="$tmp/$2.apk"
}

build seed
drive "$old" seed
curl -fsS -X POST "$url/_native/recovery/seed" >/dev/null

# Install and remove the app on the replacement emulator, then install the
# recovery target there. The old emulator remains intact for DB comparison.
adb -s "$replacement" install "$tmp/seed.apk" >/dev/null
adb -s "$replacement" uninstall app.hasta.mobile >/dev/null
build recover
flutter drive --no-pub --debug -d "$replacement" --target "$target" --driver "$driver" \
  --timeout=220 --use-application-binary="$tmp/recover.apk" &
driver_pid=$!
deadline=$((SECONDS + 95))
tapped=0
while kill -0 "$driver_pid" 2>/dev/null && (( SECONDS < deadline )); do
  if adb -s "$replacement" shell uiautomator dump /sdcard/hasta-t30.xml >/dev/null 2>&1; then
    if point=$(adb -s "$replacement" exec-out cat /sdcard/hasta-t30.xml | node -e '
      const xml = require("node:fs").readFileSync(0, "utf8");
      const match = xml.match(/<node\b(?=[^>]*\b(?:text|content-desc)="Return to Hasta")(?=[^>]*\bpackage="com\.android\.chrome")[^>]*\bbounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
      if (!match || Number(match[3]) <= Number(match[1]) || Number(match[4]) <= Number(match[2])) process.exit(1);
      console.log(Math.floor((Number(match[1]) + Number(match[3])) / 2), Math.floor((Number(match[2]) + Number(match[4])) / 2));
    '); then
      read -r x y <<<"$point"
      adb -s "$replacement" shell input tap "$x" "$y" >/dev/null
      tapped=1
      break
    fi
  fi
  # Browser UI can take a moment to appear; keep the retry bounded.
  sleep 1
done
adb -s "$replacement" shell rm -f /sdcard/hasta-t30.xml >/dev/null
[[ $tapped == 1 ]] || { echo 'T30 could not find the return link in native Chrome.' >&2; exit 1; }
wait "$driver_pid"
driver_pid=''
curl -fsS "$url/_native/recovery/verify" >/dev/null
echo 'T30 Android browser callback and reinstall: PASS'
