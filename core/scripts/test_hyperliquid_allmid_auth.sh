#!/usr/bin/env bash
# Test Hyperliquid proxy auth for allMids (POST .../info with type=allMids).
# Runs three tests (no token, valid token, invalid token) for both prod and dev endpoints.
# Requires: Rota proxy running with ROTA_HYPERLIQUID_AUTH_ENABLED=true and Privy creds set.
# Env: VALID_PRIVY_TOKEN (required for valid-token test), INVALID_PRIVY_TOKEN (default: "invalid-token").

set -e

ROTA_PROXY_URL="${ROTA_PROXY_URL:-http://localhost:8000}"
BODY='{"type":"allMids"}'
INVALID_TOKEN="${INVALID_PRIVY_TOKEN:-invalid-token}"

# ✅ Add Host header for all requests
HOST_HEADER_VALUE="${HOST_HEADER_VALUE:-delegate.senpi.ai}"

TOTAL_PASS=0
TOTAL_FAIL=0

run_test() {
  local endpoint="$1"
  local name="$2"
  local expected_status="$3"
  local extra_args=("${@:4}")
  local status

  status=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -H "Host: ${HOST_HEADER_VALUE}" \
    -d "$BODY" \
    "${extra_args[@]}")

  if [ "$status" = "$expected_status" ]; then
    echo "    PASS: $name (HTTP $status)"
    ((TOTAL_PASS++)) || true
    return 0
  else
    echo "    FAIL: $name (expected HTTP $expected_status, got $status)"
    ((TOTAL_FAIL++)) || true
    return 1
  fi
}

# Don't exit on first failure so we see all results
set +e

run_endpoint() {
  local label="$1"
  local endpoint="$2"
  echo ""
  echo "--- $label: $endpoint ---"

  run_test "$endpoint" "no token" "401"
  if [ -n "${VALID_PRIVY_TOKEN:-}" ]; then
    run_test "$endpoint" "valid token" "200" -H "Authorization: Bearer $VALID_PRIVY_TOKEN"
  else
    echo "    SKIP: valid token (set VALID_PRIVY_TOKEN)"
  fi
  run_test "$endpoint" "invalid token" "401" -H "Authorization: Bearer $INVALID_TOKEN"
}

echo "Hyperliquid allMids auth tests (prod + dev)"
echo "Proxy base: $ROTA_PROXY_URL"
echo "Host header: $HOST_HEADER_VALUE"

run_endpoint "Prod" "${ROTA_PROXY_URL}/hyperliquid/info"
run_endpoint "Dev"  "${ROTA_PROXY_URL}/dev/hyperliquid/info"

echo ""
echo "Result: $TOTAL_PASS passed, $TOTAL_FAIL failed"
[ "$TOTAL_FAIL" -eq 0 ]
exit $?

