#!/usr/bin/env bash
set -euo pipefail

API_HOST="${API_HOST:-127.0.0.1}"
API_PORT="${API_PORT:-18080}"
WEB_HOST="${WEB_HOST:-127.0.0.1}"
WEB_PORT="${WEB_PORT:-4173}"
API_BASE_URL="${API_BASE_URL:-http://${API_HOST}:${API_PORT}}"
BASE_URL="${BASE_URL:-http://${WEB_HOST}:${WEB_PORT}}"

backend_pid=""
frontend_pid=""

cleanup() {
  if [[ -n "$frontend_pid" ]] && kill -0 "$frontend_pid" >/dev/null 2>&1; then
    kill "$frontend_pid" >/dev/null 2>&1 || true
    wait "$frontend_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" >/dev/null 2>&1; then
    kill "$backend_pid" >/dev/null 2>&1 || true
    wait "$backend_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -z "${CHROMIUM_EXECUTABLE_PATH:-}" ]] && command -v chromium >/dev/null 2>&1; then
  export CHROMIUM_EXECUTABLE_PATH="$(command -v chromium)"
  echo "Using system Chromium at ${CHROMIUM_EXECUTABLE_PATH}"
fi

wait_for_url() {
  local label="$1"
  local url="$2"
  local attempts="${3:-40}"

  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "PASS: ${label} is reachable at ${url}"
      return 0
    fi
    sleep 0.5
  done

  echo "FAIL: ${label} did not become reachable at ${url}" >&2
  return 1
}

echo "Starting backend at ${API_HOST}:${API_PORT}"
(
  cd backend
  HTTP_ADDR="${API_HOST}:${API_PORT}" go run ./cmd/server
) &
backend_pid="$!"

wait_for_url "backend" "${API_BASE_URL}/healthz"

echo "Installing frontend dependencies and building with VITE_API_BASE_URL=${API_BASE_URL}"
(
  cd frontend
  npm install
  VITE_API_BASE_URL="$API_BASE_URL" npm run build
)

echo "Starting frontend preview at ${WEB_HOST}:${WEB_PORT}"
(
  cd frontend
  npm run preview -- --host "$WEB_HOST" --port "$WEB_PORT"
) &
frontend_pid="$!"

wait_for_url "frontend" "$BASE_URL"

echo "Running Playwright smoke test against ${BASE_URL}"
(
  cd frontend
  BASE_URL="$BASE_URL" npm run e2e:smoke
)

echo "PASS: Playwright smoke test completed."
