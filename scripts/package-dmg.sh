#!/bin/bash
# Package a built YouTubeOnMac.app into a DMG.
# Usage: ./scripts/package-dmg.sh /path/to/YouTubeOnMac.app [output.dmg]

set -euo pipefail

APP_PATH="${1:-}"
OUT_PATH="${2:-YouTubeOnMac.dmg}"

if [[ -z "$APP_PATH" ]]; then
    echo "Usage: $0 /path/to/YouTubeOnMac.app [output.dmg]"
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH is not a directory"
    exit 1
fi

TMP_DIR=$(mktemp -d -t youtubeonmac-dmg)
trap "rm -rf '$TMP_DIR'" EXIT

cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

# Remove any previous DMG
rm -f "$OUT_PATH"

hdiutil create -volname "YouTubeOnMac" -srcfolder "$TMP_DIR" \
  -ov -format UDZO -o "$OUT_PATH"

echo "Created $OUT_PATH"
