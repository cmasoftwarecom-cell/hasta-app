#!/usr/bin/env bash
# Staging health contract. Replaces manual "is it up?" guessing.
#   usage: bash scripts/verify-staging.sh <HTTPS_BASE_URL> <EXPECTED_DEPLOYED_SHA>
# Pass = HTTP 200 AND body.status == ok AND body.commit == expected SHA AND body.env == staging.
set -euo pipefail
BASE="${1:?base url}"; WANT="${2:?deployed sha}"
HOST="$(printf '%s' "$BASE" | sed -E 's#https?://##; s#/.*##')"

echo "1) DNS  -> $(dig +short A "$HOST" | tr '\n' ' ')"
if dig +short A "$HOST" | grep -q 'trycloudflare\|^$'; then
  echo "   WARN: no stable A record — a Quick Tunnel URL is NOT a staging contract"
fi

echo "2) TLS  -> $(curl -sSv -o /dev/null --max-time 10 "$BASE/health" 2>&1 | grep -E 'SSL cert|subject:' | head -2)"
RESPONSE="$(curl -q -sS --max-time 15 --write-out $'\n%{http_code}' "$BASE/health")"
HTTP_STATUS="${RESPONSE##*$'\n'}"
[[ $HTTP_STATUS == 200 ]] || { printf 'FAIL: expected HTTP 200, got %s\n' "$HTTP_STATUS" >&2; exit 1; }
BODY="${RESPONSE%$'\n'*}"
echo "3) body -> $BODY"

HAVE="$(printf '%s' "$BODY" | jq -r '.commit // empty')"
ENVN="$(printf '%s' "$BODY" | jq -r '.env  // empty')"
STAT="$(printf '%s' "$BODY" | jq -r '.status // empty')"

[ "$STAT" = "ok" ]       || { echo "FAIL: status != ok"; exit 1; }
[ "$ENVN" = "staging" ]  || { echo "FAIL: health does not echo env=staging (isolation unproven)"; exit 1; }
[ "${#HAVE}" -ge 40 ]    || { echo "FAIL: health has no full commit SHA — GIT_COMMIT not baked"; exit 1; }
[ "$HAVE" = "$WANT" ]    || { echo "FAIL: deployed $HAVE != expected $WANT (stale build)"; exit 1; }
echo "PASS: staging is live on $HAVE ($ENVN)"
