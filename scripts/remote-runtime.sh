#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-dogsquard}"
DEPLOY_ROOT="${DEPLOY_ROOT:-~/apps/dogsquard-dev}"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-18080}"
FRONTEND_HOST="${FRONTEND_HOST:-127.0.0.1}"
FRONTEND_PORT="${FRONTEND_PORT:-14173}"

case "$DEPLOY_ROOT" in
  "~")
    DEPLOY_ROOT="$HOME"
    ;;
  "~/"*)
    DEPLOY_ROOT="$HOME/${DEPLOY_ROOT#"~/"}"
    ;;
esac

LOG_DIR="${LOG_DIR:-${DEPLOY_ROOT}/logs}"
RUN_DIR="${RUN_DIR:-${DEPLOY_ROOT}/shared/run}"

current_dir="${DEPLOY_ROOT}/current"
release_dir="${current_dir}/release"
backend_binary="${release_dir}/backend/${APP_NAME}-server"
frontend_dist="${release_dir}/frontend/dist"
backend_pid_file="${RUN_DIR}/backend.pid"
frontend_pid_file="${RUN_DIR}/frontend.pid"
backend_log="${LOG_DIR}/backend.log"
frontend_log="${LOG_DIR}/frontend.log"

usage() {
  cat <<'USAGE' >&2
Usage:
  scripts/remote-runtime.sh start|stop|status|restart|health

Environment:
  APP_NAME        Defaults to dogsquard.
  DEPLOY_ROOT     Defaults to ~/apps/dogsquard-dev.
  BACKEND_HOST    Defaults to 127.0.0.1.
  BACKEND_PORT    Defaults to 18080.
  FRONTEND_HOST   Defaults to 127.0.0.1.
  FRONTEND_PORT   Defaults to 14173.
  LOG_DIR         Defaults to $DEPLOY_ROOT/logs.
  RUN_DIR         Defaults to $DEPLOY_ROOT/shared/run.

This script manages only Dogsquard pid files under RUN_DIR.
It does not use sudo, Docker, systemd, reverse proxy config, or multica services.
USAGE
}

action="${1:-}"
if [[ -z "$action" ]]; then
  usage
  exit 2
fi

is_alive() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

pid_value() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    cat "$pid_file" 2>/dev/null || true
  fi
}

remove_stale_pid() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]] && ! is_alive "$pid_file"; then
    rm -f "$pid_file"
  fi
}

require_release() {
  if [[ ! -d "$current_dir" ]]; then
    echo "Missing current release symlink or directory: $current_dir" >&2
    exit 1
  fi
  if [[ ! -x "$backend_binary" ]]; then
    echo "Missing executable backend binary: $backend_binary" >&2
    exit 1
  fi
  if [[ ! -d "$frontend_dist" ]]; then
    echo "Missing frontend dist directory: $frontend_dist" >&2
    exit 1
  fi
}

start_runtime() {
  require_release
  mkdir -p "$LOG_DIR" "$RUN_DIR"
  remove_stale_pid "$backend_pid_file"
  remove_stale_pid "$frontend_pid_file"

  if is_alive "$backend_pid_file"; then
    echo "Backend already running with pid $(pid_value "$backend_pid_file")."
  else
    echo "Starting backend on ${BACKEND_HOST}:${BACKEND_PORT}"
    nohup env HTTP_ADDR="${BACKEND_HOST}:${BACKEND_PORT}" "$backend_binary" >>"$backend_log" 2>&1 &
    echo "$!" > "$backend_pid_file"
  fi

  if is_alive "$frontend_pid_file"; then
    echo "Frontend already running with pid $(pid_value "$frontend_pid_file")."
  else
    if ! command -v python3 >/dev/null 2>&1; then
      echo "python3 is required to serve frontend static files in Phase 6B-3." >&2
      exit 1
    fi
    echo "Starting frontend static server on ${FRONTEND_HOST}:${FRONTEND_PORT}"
    (
      cd "$frontend_dist"
      nohup python3 -m http.server "$FRONTEND_PORT" --bind "$FRONTEND_HOST" >>"$frontend_log" 2>&1 &
      echo "$!" > "$frontend_pid_file"
    )
  fi

  echo "Backend endpoint: http://${BACKEND_HOST}:${BACKEND_PORT}/healthz"
  echo "Frontend endpoint: http://${FRONTEND_HOST}:${FRONTEND_PORT}/"
}

stop_one() {
  local label="$1"
  local pid_file="$2"

  if ! [[ -f "$pid_file" ]]; then
    echo "$label: stopped (no pid file)"
    return 0
  fi

  local pid
  pid="$(pid_value "$pid_file")"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "Stopping $label pid $pid"
    kill "$pid" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
      if ! kill -0 "$pid" >/dev/null 2>&1; then
        break
      fi
      sleep 0.2
    done
    if kill -0 "$pid" >/dev/null 2>&1; then
      echo "$label pid $pid did not stop after TERM." >&2
      return 1
    fi
  else
    echo "$label: removing stale pid file"
  fi

  rm -f "$pid_file"
}

stop_runtime() {
  local failed=0
  stop_one "frontend" "$frontend_pid_file" || failed=1
  stop_one "backend" "$backend_pid_file" || failed=1
  return "$failed"
}

status_runtime() {
  local backend_status="stopped"
  local frontend_status="stopped"

  if is_alive "$backend_pid_file"; then
    backend_status="running pid $(pid_value "$backend_pid_file")"
  elif [[ -f "$backend_pid_file" ]]; then
    backend_status="stale pid $(pid_value "$backend_pid_file")"
  fi

  if is_alive "$frontend_pid_file"; then
    frontend_status="running pid $(pid_value "$frontend_pid_file")"
  elif [[ -f "$frontend_pid_file" ]]; then
    frontend_status="stale pid $(pid_value "$frontend_pid_file")"
  fi

  echo "Deploy root: $DEPLOY_ROOT"
  echo "Backend: $backend_status"
  echo "Frontend: $frontend_status"
}

health_runtime() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required for runtime health checks." >&2
    exit 1
  fi

  local failed=0
  local backend_url="http://${BACKEND_HOST}:${BACKEND_PORT}/healthz"
  local frontend_url="http://${FRONTEND_HOST}:${FRONTEND_PORT}/"

  if curl -fsS "$backend_url" >/dev/null; then
    echo "PASS: backend health reachable at $backend_url"
  else
    echo "FAIL: backend health failed at $backend_url" >&2
    failed=1
  fi

  if curl -fsS "$frontend_url" >/dev/null; then
    echo "PASS: frontend reachable at $frontend_url"
  else
    echo "FAIL: frontend failed at $frontend_url" >&2
    failed=1
  fi

  return "$failed"
}

case "$action" in
  start)
    start_runtime
    ;;
  stop)
    stop_runtime
    ;;
  status)
    status_runtime
    ;;
  restart)
    stop_runtime
    start_runtime
    ;;
  health)
    health_runtime
    ;;
  *)
    usage
    exit 2
    ;;
esac
