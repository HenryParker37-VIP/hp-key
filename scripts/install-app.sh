#!/bin/bash
# Installs the built HP Key.app (and, with --with-input-method, the native keyboard) after backing up
# the installed copies. Refuses an ad-hoc build when a stable identity is configured, so macOS keeps
# the Accessibility grant. Roll back with scripts/rollback-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
APPS="${HPKEY_APPS_DIR:-$HOME/Applications}"
IMES="${HPKEY_IME_DIR:-$HOME/Library/Input Methods}"
BACKUP="${HPKEY_BACKUP_DIR:-build/backup}"
check_signature() {
  if [[ -f .signing-identity ]] && codesign -dv "$1" 2>&1 | grep -q 'Signature=adhoc'; then
    echo "Refusing to install ad-hoc signed $1: .signing-identity is configured. Rebuild with scripts/build.sh." >&2; exit 1
  fi
  codesign --verify --strict "$1"
}
replace() { # replace <source> <destination>, keeping a backup of the destination first
  if [[ -d "$2" ]]; then rm -rf "$BACKUP/$(basename "$2")"; ditto "$2" "$BACKUP/$(basename "$2")"; fi
  rm -rf "$2"; ditto "$1" "$2"; codesign --verify --strict "$2"
}
check_signature "build/HP Key.app"
mkdir -p "$BACKUP" "$APPS"
if [[ -z "${HPKEY_NO_LAUNCH:-}" ]]; then
  osascript -e 'quit app id "com.henryparker.hpkey"' >/dev/null 2>&1 || true
  sleep 1; pkill -f "$APPS/HP Key.app/Contents/MacOS/" 2>/dev/null || true
fi
replace "build/HP Key.app" "$APPS/HP Key.app"
if [[ "${1:-}" == --with-input-method ]]; then
  check_signature "build/HP Key Input Method.app"
  mkdir -p "$IMES"
  replace "build/HP Key Input Method.app" "$IMES/HP Key Input Method.app"
  # macOS relaunches the input method on the next keystroke; its registration is unchanged.
  [[ -n "${HPKEY_NO_LAUNCH:-}" ]] || pkill -f "$IMES/HP Key Input Method.app/Contents/MacOS/HPKeyInputMethod" 2>/dev/null || true
fi
[[ -n "${HPKEY_NO_LAUNCH:-}" ]] || open "$APPS/HP Key.app"
echo "Installed. Backups in $BACKUP/. Roll back with scripts/rollback-app.sh."
