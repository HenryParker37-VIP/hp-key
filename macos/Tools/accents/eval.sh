#!/bin/zsh
# eval.sh MODEL TEXT [examples]: builds the evaluator with the app's own AccentRestorer.swift and runs it.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cp "$here/eval.swift" "$dir/main.swift"
swiftc -O -o "$dir/eval" "$here/../../App/Model/AccentRestorer.swift" "$dir/main.swift"
"$dir/eval" "$@"
