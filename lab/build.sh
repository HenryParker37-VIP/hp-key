#!/bin/bash
# Builds HP Key Lab (a disposable local window with native and WebKit text fields) and its key driver.
set -euo pipefail
cd "$(dirname "$0")/.."
LAB="build/HP Key Lab.app"
mkdir -p "$LAB/Contents/MacOS"
swiftc -O -swift-version 5 -parse-as-library lab/LabApp.swift -framework AppKit -framework WebKit -o "$LAB/Contents/MacOS/HPKeyLab"
/usr/libexec/PlistBuddy -c "Clear dict" -c "Add :CFBundleExecutable string HPKeyLab" -c "Add :CFBundleIdentifier string com.henryparker.hpkey.lab" \
  -c "Add :CFBundleName string 'HP Key Lab'" -c "Add :CFBundlePackageType string APPL" -c "Add :NSPrincipalClass string NSApplication" "$LAB/Contents/Info.plist" >/dev/null 2>&1 || true
codesign --force --sign - "$LAB"
swiftc -O -swift-version 5 lab/LabDriver.swift -framework AppKit -o build/lab-driver
echo "Built $LAB and build/lab-driver"
