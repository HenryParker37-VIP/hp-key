#!/bin/bash
# Restores the copies saved by install-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
APPS="${HPKEY_APPS_DIR:-$HOME/Applications}"
IMES="${HPKEY_IME_DIR:-$HOME/Library/Input Methods}"
BACKUP="${HPKEY_BACKUP_DIR:-build/backup}"
[[ -d "$BACKUP/HP Key.app" ]] || { echo "No backup in $BACKUP." >&2; exit 1; }
if [[ -z "${HPKEY_NO_LAUNCH:-}" ]]; then
  osascript -e 'quit app id "com.henryparker.hpkey"' >/dev/null 2>&1 || true
  sleep 1; pkill -f "$APPS/HP Key.app/Contents/MacOS/" 2>/dev/null || true
fi
restore() { rm -rf "$2"; ditto "$1" "$2"; codesign --verify --strict "$2"; }
restore "$BACKUP/HP Key.app" "$APPS/HP Key.app"
if [[ -d "$BACKUP/HP Key Input Method.app" ]]; then
  restore "$BACKUP/HP Key Input Method.app" "$IMES/HP Key Input Method.app"
  [[ -n "${HPKEY_NO_LAUNCH:-}" ]] || pkill -f "$IMES/HP Key Input Method.app/Contents/MacOS/HPKeyInputMethod" 2>/dev/null || true
fi
[[ -n "${HPKEY_NO_LAUNCH:-}" ]] || open "$APPS/HP Key.app"
echo "Rolled back from $BACKUP/."
