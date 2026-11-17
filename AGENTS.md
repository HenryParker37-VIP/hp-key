# HP Key project instructions

HP Key for macOS and Windows (`windows/`) is a GPL-3.0 derivative of Vikey/OpenKey (see NOTICE.md). Keep upstream copyright notices,
record every modification in NOTICE.md, and keep HP Key-specific code in `macos/App/Model/HPKey.swift` where
possible so upstream changes stay easy to merge. The owner authorized Vikey's event-tap design (backspace +
Unicode rewrite of the current word) on 2026-11-17; do not reintroduce a second keyboard backend.

Protect typed text: no network, no typing history (the inherited typing log stays off by default), no
clipboard reads; secure input passes through. Use scripts/test.sh, scripts/build.sh (Apple Development
signing only) and scripts/install-app.sh (backs up first). Changing system permissions, input sources or
signing accounts needs the owner's explicit approval. Do not claim app compatibility without a live test.
