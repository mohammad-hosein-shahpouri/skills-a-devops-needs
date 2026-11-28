#!/usr/bin/env bash
# curl-based API smoke suite — no framework dependency, produces JUnit XML.
# Usage: BASE_URL=https://api.example.internal RUN_ID=ci-123 ./api-smoke-tests.sh
#
# Asserts: status codes, response schema keys, error envelopes, auth matrix,
# and cleanup. Every created entity is namespaced with RUN_ID and deleted.

set -uo pipefail

BASE_URL="${BASE_URL:?set BASE_URL}"
RUN_ID="${RUN_ID:-run-$(date +%s)}"
JUNIT_OUT="${JUNIT_OUT:-api-smoke-junit.xml}"
TOKEN="${TOKEN:-}"          # least-privilege token injected by CI

pass=0; fail=0; failures=""

check() {  # check <name> <expected_status> <actual_status> <body> [required_keys]
    local name="$1" expected="$2" actual="$3" body="$4" keys="${5:-}"
    if [ "$actual" != "$expected" ]; then
        fail=$((fail + 1))
        failures="${failures}<failure message='expected HTTP ${expected}, got ${actual}'>${name}</failure>"
        printf 'FAIL %-40s expected %s got %s\n' "$name" "$expected" "$actual"
        return 0
    fi
    if [ -n "$keys" ]; then
        for k in $keys; do
            if ! printf '%s' "$body" | grep -q "\"${k}\""; then
                fail=$((fail + 1))
                failures="${failures}<failure message='missing key ${k}'>${name}</failure>"
                printf 'FAIL %-40s missing key %s\n' "$name" "$k"
                return 0
            fi
        done
    fi
    pass=$((pass + 1))
    printf 'PASS %s\n' "$name"
}

req() {  # req <method> <path> [json_body]
    local method="$1" path="$2" body="${3:-}" tmp
    tmp="$(mktemp)"
    local code
    if [ -n "$body" ]; then
        code=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
            -H 'Content-Type: application/json' \
            ${TOKEN:+-H "Authorization: Bearer ${TOKEN}"} \
            -d "$body" "${BASE_URL}${path}")
    else
        code=$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
            ${TOKEN:+-H "Authorization: Bearer ${TOKEN}"} \
            "${BASE_URL}${path}")
    fi
    RESP_CODE="$code"; RESP_BODY="$(cat "$tmp")"; rm -f "$tmp"
}

# ─── 1. Health and readiness ────────────────────────────────────────────────
req GET /health
check "health returns 200" 200 "$RESP_CODE" "$RESP_BODY"

# ─── 2. Auth matrix ─────────────────────────────────────────────────────────
req GET /api/widgets
check "anonymous rejected" 401 "$RESP_CODE" "$RESP_BODY" "error"

BAD_TOKEN="invalid-${RUN_ID}"
saved="$TOKEN"; TOKEN="$BAD_TOKEN"
req GET /api/widgets
check "invalid token rejected" 401 "$RESP_CODE" "$RESP_BODY" "error"
TOKEN="$saved"

# ─── 3. Happy path with schema assertions ───────────────────────────────────
WIDGET_NAME="qa-${RUN_ID}-widget"
req POST /api/widgets "{\"name\":\"${WIDGET_NAME}\",\"size\":3}"
check "create widget" 201 "$RESP_CODE" "$RESP_BODY" "id name size"
WIDGET_ID="$(printf '%s' "$RESP_BODY" | sed -n 's/.*"id":"\{0,1\}([^",}]*\).*/\1/p' | head -1)"

if [ -n "$WIDGET_ID" ]; then
    req GET "/api/widgets/${WIDGET_ID}"
    check "read created widget" 200 "$RESP_CODE" "$RESP_BODY" "id name size"

    # ─── 4. Validation and conflict paths ──────────────────────────────────
    req POST /api/widgets '{"name":""}'
    check "empty name rejected" 422 "$RESP_CODE" "$RESP_BODY" "error"

    req POST /api/widgets "{\"name\":\"${WIDGET_NAME}\",\"size\":3}"
    check "duplicate name conflict" 409 "$RESP_CODE" "$RESP_BODY" "error"

    req GET "/api/widgets/does-not-exist-${RUN_ID}"
    check "missing widget 404" 404 "$RESP_CODE" "$RESP_BODY" "error"

    # ─── 5. Cleanup (trap guarantees it on failure) ────────────────────────
    cleanup() { req DELETE "/api/widgets/${WIDGET_ID}"; }
    trap cleanup EXIT
    req PATCH "/api/widgets/${WIDGET_ID}" '{"size":5}'
    check "update widget" 200 "$RESP_CODE" "$RESP_BODY" "size"
    cleanup
    trap - EXIT
    req GET "/api/widgets/${WIDGET_ID}"
    check "deleted widget gone" 404 "$RESP_CODE" "$RESP_BODY" "error"
else
    fail=$((fail + 1))
    printf 'FAIL could not parse created widget id\n'
fi

# ─── JUnit output ───────────────────────────────────────────────────────────
cat > "$JUNIT_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="api-smoke" tests="$((pass + fail))" failures="${fail}" run="${RUN_ID}">
  <testcase name="api-smoke-suite"/>
  ${failures}
</testsuite>
EOF

printf '\n%d passed, %d failed — report: %s\n' "$pass" "$fail" "$JUNIT_OUT"
[ "$fail" -eq 0 ] || exit 1

# Notes:
# - This suite is a smoke gate: schema keys, auth matrix, one happy path per
#   endpoint family. Deeper behavior belongs to the framework-based suite.
# - Keep total runtime under two minutes; long gates get bypassed.
# - Never assert on free-form error text — assert on the error code field.
# - RUN_ID namespacing makes concurrent executions safe on shared environments.
