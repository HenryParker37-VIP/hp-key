#!/bin/bash
# Builds HP Key (Vikey-based) with XcodeGen + xcodebuild and signs it with the owner's local
# Apple Development identity (.signing-identity, untracked; a certificate hash, not a secret).
# Refuses to fall back to ad-hoc signing, so macOS keeps the Accessibility grant across updates.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
SIGN="${HPKEY_SIGN_IDENTITY:-}"
[[ -z "$SIGN" && -f .signing-identity ]] && SIGN="$(tr -d '[:space:]' < .signing-identity)"
[[ -n "$SIGN" ]] || { echo "No signing identity: put the Apple Development certificate hash in .signing-identity." >&2; exit 1; }
(cd macos && xcodegen generate --quiet)
xcodebuild -project macos/HPKey.xcodeproj -scheme HPKey -configuration Release -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="$SIGN" OTHER_CODE_SIGN_FLAGS="--timestamp=none" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build -quiet   # universal: Apple silicon and Intel Macs
APP="build/DerivedData/Build/Products/Release/HP Key.app"
mkdir -p build
rm -rf "build/HP Key.app"
ditto "$APP" "build/HP Key.app"
codesign --verify --strict --deep "build/HP Key.app"
SIGNATURE="$(codesign -dvv "build/HP Key.app" 2>&1)"
[[ "$SIGNATURE" == *"Authority=Apple Development"* ]] || { echo "Not signed with Apple Development." >&2; exit 1; }
[[ "$(defaults read "$PWD/build/HP Key.app/Contents/Info" CFBundleIdentifier)" == com.henryparker.hpkey ]] || { echo "Wrong bundle identifier." >&2; exit 1; }
echo "Built build/HP Key.app (com.henryparker.hpkey, Apple Development signed, not notarized)."
