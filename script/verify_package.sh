#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-.build/Flowtype.app}"
DMG_PATH="${2:-.build/dist/Flowtype.dmg}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'verify_package failed: %s\n' "$1" >&2
  exit 1
}

test -d "$APP_PATH" || fail "app bundle missing at $APP_PATH"
python3 "$ROOT_DIR/script/app_bundle.py" verify --app "$APP_PATH" || fail "canonical bundle verification failed"

plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [ -f "$DMG_PATH" ]; then
  hdiutil verify "$DMG_PATH"
fi

printf 'verify_package passed: %s\n' "$APP_PATH"
