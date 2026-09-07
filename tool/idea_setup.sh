#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER_ROOT:-/Users/feixianghuang/development/flutter}/bin/flutter"
DART="$(dirname "$FLUTTER")/dart"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="$(command -v flutter)"
  DART="$(command -v dart)"
fi

cd "$ROOT"
echo "==> flutter pub get"
"$FLUTTER" pub get

echo "==> generate IDEA library indexes"
"$DART" run tool/generate_idea_libraries.dart

echo "==> done"
echo "Open in IntelliJ IDEA: $ROOT"
echo "Run configuration default: macos"
