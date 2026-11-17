#!/bin/bash
# Engine regression suite inherited from Vikey (rules, reported bugs, golden snapshots, undo, realistic
# typing, performance budget). Must pass before any install.
set -euo pipefail
cd "$(dirname "$0")/.."
zsh macos/Tools/autoswitch/check.sh
