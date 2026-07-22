#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Flowtype"
BUNDLE_ID="com.smg.flowtype"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
UV_BINARY="${UV_BINARY:-$(command -v uv 2>/dev/null || true)}"
PYTHON_BINARY="${PYTHON_BINARY:-python3}"

mode="${1:-run}"

log() {
  printf "[%s] %s\n" "$APP_NAME" "$1"
}

resolve_realpath() {
  "$PYTHON_BINARY" -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

stop_app() {
  log "Stopping existing process (if any)"
  pkill -x "$APP_NAME" || true
}

build_app() {
  log "Building Swift package"
  (
    cd "$ROOT_DIR"
    swift build
  )

  local bin_path
  bin_path="$(
    cd "$ROOT_DIR"
    swift build --show-bin-path
  )"
  local built_binary="$bin_path/$APP_NAME"

  if [ ! -f "$built_binary" ]; then
    echo "Built binary not found: $built_binary" >&2
    exit 1
  fi

  if [ -z "$UV_BINARY" ]; then
    echo "uv is required to build a standalone Flowtype dev bundle. Install uv or set UV_BINARY=/path/to/uv." >&2
    exit 1
  fi

  local uv_realpath
  uv_realpath="$(resolve_realpath "$UV_BINARY")"
  if [ ! -x "$uv_realpath" ]; then
    echo "uv is not executable: $uv_realpath" >&2
    exit 1
  fi

  (
    cd "$ROOT_DIR"
    "$PYTHON_BINARY" script/app_bundle.py assemble \
      --app "$APP_BUNDLE" \
      --app-binary "$built_binary" \
      --uv "$uv_realpath"
  )
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

show_logs() {
  /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
}

show_telemetry() {
  /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
}

verify_run() {
  open_app
  sleep 1
  if pgrep -x "$APP_NAME" >/dev/null; then
    log "Verify success: process is running"
  else
    echo "Verify failed: process not running" >&2
    exit 1
  fi
}

case "$mode" in
  run|"")
    stop_app
    build_app
    open_app
    ;;
  --debug|debug)
    stop_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    stop_app
    build_app
    open_app
    show_logs
    ;;
  --telemetry|telemetry)
    stop_app
    build_app
    open_app
    show_telemetry
    ;;
  --verify|verify)
    stop_app
    build_app
    verify_run
    ;;
  --build-only)
    build_app
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    echo "Usage: $0 [run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--build-only]" >&2
    exit 2
    ;;
esac
