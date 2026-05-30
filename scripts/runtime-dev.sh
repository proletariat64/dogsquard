#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-}"
ACTION="${ACTION:-status}"
APP_NAME="${APP_NAME:-dogsquard}"
DEPLOY_ROOT="${DEPLOY_ROOT:-~/apps/dogsquard-dev}"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-18080}"
FRONTEND_HOST="${FRONTEND_HOST:-127.0.0.1}"
FRONTEND_PORT="${FRONTEND_PORT:-14173}"
ALLOW_US_HERMES_RUNTIME="${ALLOW_US_HERMES_RUNTIME:-false}"
COMPONENT="${COMPONENT:-}"
LOG_LINES="${LOG_LINES:-80}"
TARGET_RELEASE="${TARGET_RELEASE:-}"
RESTART_AFTER_ROLLBACK="${RESTART_AFTER_ROLLBACK:-false}"

usage() {
  cat <<'USAGE' >&2
Usage:
  make runtime-status HOST=cn.ant
  make runtime-start HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev
  make runtime-health HOST=cn.ant
  make runtime-logs HOST=cn.ant COMPONENT=backend
  make runtime-diagnose HOST=cn.ant
  make rollback-dev HOST=cn.ant TARGET_RELEASE=<release-id>
  make runtime-stop HOST=cn.ant

Environment:
  HOST                    Required SSH target.
  ACTION                  start|stop|status|restart|health|logs|diagnose|rollback. Defaults to status.
  DEPLOY_ROOT             Defaults to ~/apps/dogsquard-dev.
  ALLOW_US_HERMES_RUNTIME Defaults to false. Do not enable in Phase 6B-3.

This wrapper runs scripts/remote-runtime.sh over SSH.
It does not use sudo, edit reverse proxy config, or touch Docker.
USAGE
}

if [[ -z "$HOST" ]]; then
  usage
  exit 2
fi

case "$ACTION" in
  start|stop|status|restart|health|logs|diagnose|rollback) ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ "$ACTION" == "rollback" && -z "$TARGET_RELEASE" ]]; then
  echo "TARGET_RELEASE is required for rollback." >&2
  exit 2
fi

if [[ "$HOST" == "us.hermes" && ( "$ACTION" == "start" || "$ACTION" == "restart" || "$ACTION" == "rollback" ) && "$ALLOW_US_HERMES_RUNTIME" != "true" ]]; then
  echo "Blocked: runtime ${ACTION} on us.hermes requires ALLOW_US_HERMES_RUNTIME=true." >&2
  echo "Phase 6B-4 keeps us.hermes dry-run/documentation only to protect multica routing." >&2
  exit 1
fi

quote() {
  printf "%q" "$1"
}

echo "Runtime wrapper"
echo "HOST=${HOST}"
echo "ACTION=${ACTION}"
echo "APP_NAME=${APP_NAME}"
echo "DEPLOY_ROOT=${DEPLOY_ROOT}"
echo "BACKEND=${BACKEND_HOST}:${BACKEND_PORT}"
echo "FRONTEND=${FRONTEND_HOST}:${FRONTEND_PORT}"
if [[ "$ACTION" == "logs" && -n "$COMPONENT" ]]; then
  echo "COMPONENT=${COMPONENT}"
fi
if [[ "$ACTION" == "rollback" ]]; then
  echo "TARGET_RELEASE=${TARGET_RELEASE}"
fi
echo
echo "Safety boundaries:"
echo "- no sudo"
echo "- no reverse proxy edits"
echo "- no Docker commands"
echo "- no multica operations"
echo

ssh "$HOST" \
  "APP_NAME=$(quote "$APP_NAME") DEPLOY_ROOT=$(quote "$DEPLOY_ROOT") BACKEND_HOST=$(quote "$BACKEND_HOST") BACKEND_PORT=$(quote "$BACKEND_PORT") FRONTEND_HOST=$(quote "$FRONTEND_HOST") FRONTEND_PORT=$(quote "$FRONTEND_PORT") LOG_LINES=$(quote "$LOG_LINES") TARGET_RELEASE=$(quote "$TARGET_RELEASE") RESTART_AFTER_ROLLBACK=$(quote "$RESTART_AFTER_ROLLBACK") bash -s -- $(quote "$ACTION") $(quote "$COMPONENT")" \
  < scripts/remote-runtime.sh
