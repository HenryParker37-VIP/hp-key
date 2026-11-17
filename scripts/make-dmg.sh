#!/bin/bash
# Packages build/HP Key.app (from scripts/build.sh) into build/HPKey-<version>.dmg: the app plus an
# Applications shortcut, signed with the same Apple Development identity. Not notarized (no Developer ID).
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/HP Key.app"
[[ -d "$APP" ]] || { echo "Run scripts/build.sh first." >&2; exit 1; }
VERSION="$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)"
SIGN="${HPKEY_SIGN_IDENTITY:-}"
[[ -z "$SIGN" && -f .signing-identity ]] && SIGN="$(tr -d '[:space:]' < .signing-identity)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/HP Key.app"
ln -s /Applications "$STAGE/Applications"
DMG="build/HPKey-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "HP Key $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
[[ -n "$SIGN" ]] && codesign --sign "$SIGN" --timestamp=none "$DMG"
hdiutil verify "$DMG" >/dev/null
shasum -a 256 "$DMG"
echo "Built $DMG (HP Key $VERSION, universal, Apple Development signed, not notarized)."
