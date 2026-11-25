#!/usr/bin/env bash
# Seed the six synthetic staging fixtures. REFUSE to run unless env is proven staging.
#   usage: STAGING_URL=https://api-staging.hasta.app DEPLOYED_SHA=<40hex> bash scripts/seed-staging.sh
set -euo pipefail
S="${STAGING_URL:?}"; SHA="${DEPLOYED_SHA:?}"
bash "$(dirname "$0")/verify-staging.sh" "$S" "$SHA" || { echo "seed blocked: health contract failed"; exit 1; }
ADMIN_TOKEN="${HASTA_ADMIN_TOKEN:?}"        # staging-only bootstrap admin, never a prod credential
for login in tester.a tester.b tester.social tester.premium tester.minor tester.fresh; do
  curl -fsS --fail-with-body -X POST "$S/v1/qa/fixtures" \
    -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' \
    -H "Idempotency-Key: seed-$login-$(date -u +%Y%m%d%H)" \
    -d "{\"login\":\"$login\",\"kind\":\"synthetic\",\"sprint\":\"S1\"}" >/dev/null
  echo "seeded $login"
done
# tester.minor MUST exist and MUST be blocked from wagering/dating — assert it, do not skip it:
curl -fsS -o /dev/null -w 'minor wager -> HTTP %{http_code}\n' -X POST "$S/v1/bets" \
  -H "Authorization: Bearer ${MINOR_TOKEN:?}" -H 'Content-Type: application/json' -d '{"game":"demo","amount":1}' \
  && { echo "FAIL: minor account was allowed to place a bet"; exit 1; } || true
