#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$PROJECT_ROOT/.build/Flowtype.app}"
OUTPUT_DMG="${2:-$PROJECT_ROOT/.build/dist/Flowtype.dmg}"
BACKGROUND_SOURCE="$APP_PATH/Contents/Resources/DMGBackground.tiff"

VOLUME_NAME="Flowtype Installer"
ICON_SIZE="144"
WINDOW_WIDTH="660"
WINDOW_HEIGHT="435"
WINDOW_LEFT="${FLOWTYPE_DMG_WINDOW_LEFT:-180}"
WINDOW_TOP="${FLOWTYPE_DMG_WINDOW_TOP:-140}"
APP_X="170"
APP_Y="170"
APPLICATIONS_X="490"
APPLICATIONS_Y="170"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Flowtype app bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$BACKGROUND_SOURCE" ]]; then
  echo "DMG background not found: $BACKGROUND_SOURCE" >&2
  exit 1
fi

BUILD_STAMP="$(date -u +%Y%m%d-%H%M%S)-$$"
WORK_ROOT="$PROJECT_ROOT/.build/dmg-work/$BUILD_STAMP"
STAGING_DIR="$WORK_ROOT/staging"
READ_WRITE_DMG="$WORK_ROOT/Flowtype-read-write.dmg"
COMPRESSED_DMG="$WORK_ROOT/Flowtype.dmg"

mkdir -p "$STAGING_DIR" "$(dirname "$OUTPUT_DMG")"
ditto "$APP_PATH" "$STAGING_DIR/Flowtype.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDRW \
  -fs HFS+ \
  "$READ_WRITE_DMG"

MOUNTED="false"
MOUNT_POINT=""
detach_image() {
  if [[ "$MOUNTED" == "true" && -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null || true
    MOUNTED="false"
  fi
}
trap detach_image EXIT INT TERM

ATTACH_OUTPUT="$(hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  "$READ_WRITE_DMG")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '$3 ~ /^\/Volumes\// { print $3; exit }')"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "Unable to resolve mounted DMG path." >&2
  printf '%s\n' "$ATTACH_OUTPUT" >&2
  exit 1
fi
MOUNTED="true"

/usr/bin/osascript - \
  "$VOLUME_NAME" \
  "$ICON_SIZE" \
  "$WINDOW_LEFT" \
  "$WINDOW_TOP" \
  "$WINDOW_WIDTH" \
  "$WINDOW_HEIGHT" \
  "$APP_X" \
  "$APP_Y" \
  "$APPLICATIONS_X" \
  "$APPLICATIONS_Y" <<'APPLESCRIPT'
on run arguments
  set volumeName to item 1 of arguments
  set iconSizeValue to (item 2 of arguments) as integer
  set windowLeft to (item 3 of arguments) as integer
  set windowTop to (item 4 of arguments) as integer
  set windowWidth to (item 5 of arguments) as integer
  set windowHeight to (item 6 of arguments) as integer
  set appX to (item 7 of arguments) as integer
  set appY to (item 8 of arguments) as integer
  set applicationsX to (item 9 of arguments) as integer
  set applicationsY to (item 10 of arguments) as integer

  tell application "Finder"
    tell disk volumeName
      open
      tell container window
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set pathbar visible to false
        set bounds to {windowLeft, windowTop, windowLeft + windowWidth, windowTop + windowHeight}
      end tell
      set backgroundFile to file "Flowtype.app:Contents:Resources:DMGBackground.tiff"
      set viewOptions to icon view options of container window
      tell viewOptions
        set arrangement to not arranged
        set icon size to iconSizeValue
        set text size to 16
        set shows item info to false
        set shows icon preview to true
        set background picture to backgroundFile
      end tell
      set position of item "Flowtype.app" to {appX, appY}
      set position of item "Applications" to {applicationsX, applicationsY}
      update without registering applications
      delay 3
      close container window
    end tell
  end tell
end run
APPLESCRIPT

sync
test -f "$MOUNT_POINT/.DS_Store"
test -L "$MOUNT_POINT/Applications"
test -d "$MOUNT_POINT/Flowtype.app"

TRASH_DIR="$PROJECT_ROOT/.trash"
mkdir -p "$TRASH_DIR"
for generatedItem in "$MOUNT_POINT"/.[!.]* "$MOUNT_POINT"/..?*; do
  if [[ ! -e "$generatedItem" ]]; then
    continue
  fi
  generatedName="$(basename "$generatedItem")"
  if [[ "$generatedName" == ".DS_Store" ]]; then
    continue
  fi
  archiveName="$(date +%F)_${BUILD_STAMP}_dmg-${generatedName#.}"
  archivePath="$TRASH_DIR/$archiveName"
  if [[ -e "$archivePath" ]]; then
    archivePath="$TRASH_DIR/${archiveName}-$(date +%H%M%S)"
  fi
  mv "$generatedItem" "$archivePath"
  echo "Archived generated volume item at: $archivePath"
done

detach_image
trap - EXIT INT TERM

hdiutil convert \
  "$READ_WRITE_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$COMPRESSED_DMG" >/dev/null
hdiutil verify "$COMPRESSED_DMG" >/dev/null

if [[ -e "$OUTPUT_DMG" ]]; then
  ARCHIVE_PATH="$TRASH_DIR/$(date +%F)_$(basename "$OUTPUT_DMG")"
  if [[ -e "$ARCHIVE_PATH" ]]; then
    ARCHIVE_PATH="$TRASH_DIR/$(date +%F)_$(date +%H%M%S)_$(basename "$OUTPUT_DMG")"
  fi
  mv "$OUTPUT_DMG" "$ARCHIVE_PATH"
  echo "Archived previous DMG at: $ARCHIVE_PATH"
fi

mv "$COMPRESSED_DMG" "$OUTPUT_DMG"
echo "Created styled DMG at: $OUTPUT_DMG"
echo "Retained build workspace for review at: $WORK_ROOT"
