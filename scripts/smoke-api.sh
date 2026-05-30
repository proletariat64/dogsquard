#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8080}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local output="$4"
  local url="${API_BASE_URL}${path}"

  if [[ -n "$body" ]]; then
    curl -sS -X "$method" \
      -H "Content-Type: application/json" \
      -o "$output" \
      -w "%{http_code}" \
      --connect-timeout 2 \
      --max-time 5 \
      --data "$body" \
      "$url"
  else
    curl -sS -X "$method" \
      -o "$output" \
      -w "%{http_code}" \
      --connect-timeout 2 \
      --max-time 5 \
      "$url"
  fi
}

expect_status() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  local body_file="$4"

  if [[ "$actual" != "$expected" ]]; then
    echo "Response body preview:" >&2
    head -c 1000 "$body_file" >&2 || true
    echo >&2
    fail "$label returned HTTP $actual, expected $expected"
  fi
  pass "$label"
}

extract_id() {
  sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$1" | head -n 1
}

echo "Running API smoke test against ${API_BASE_URL}"

health_body="$tmp_dir/health.json"
if ! health_code="$(request GET /healthz "" "$health_body")"; then
  fail "backend is not reachable at ${API_BASE_URL}; start it with 'cd backend && go run ./cmd/server'"
fi
expect_status "GET /healthz" "$health_code" "200" "$health_body"
grep -q '"status":"ok"' "$health_body" || fail "GET /healthz did not return status ok"

list_body="$tmp_dir/list.json"
list_code="$(request GET /api/tasks "" "$list_body")"
expect_status "GET /api/tasks" "$list_code" "200" "$list_body"

create_body="$tmp_dir/create.json"
create_code="$(request POST /api/tasks '{"title":"Smoke task","description":"Created by smoke-api","priority":"medium"}' "$create_body")"
expect_status "POST /api/tasks valid task" "$create_code" "201" "$create_body"
task_id="$(extract_id "$create_body")"
[[ -n "$task_id" ]] || fail "created task response did not include an id"

invalid_body="$tmp_dir/invalid.json"
invalid_code="$(request POST /api/tasks '{"description":"Missing title"}' "$invalid_body")"
expect_status "POST /api/tasks missing title" "$invalid_code" "400" "$invalid_body"
grep -q '"code":"validation_error"' "$invalid_body" || fail "missing title response did not include validation_error"

patch_body="$tmp_dir/patch.json"
patch_code="$(request PATCH "/api/tasks/${task_id}" '{"status":"in_progress"}' "$patch_body")"
expect_status "PATCH /api/tasks/{id} status" "$patch_code" "200" "$patch_body"
grep -q '"status":"in_progress"' "$patch_body" || fail "patched task did not return in_progress status"

delete_body="$tmp_dir/delete.json"
delete_code="$(request DELETE "/api/tasks/${task_id}" "" "$delete_body")"
expect_status "DELETE /api/tasks/{id}" "$delete_code" "204" "$delete_body"

echo "API smoke test completed."
