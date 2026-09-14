#!/usr/bin/env bash
# Remove stale DMG artifacts left by interrupted bundle_dmg.sh runs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="$ROOT/src-tauri/target/release/bundle"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  exit 0
fi

while IFS= read -r -d '' rw; do
  echo "Removing stale DMG template: $rw"
  rm -f "$rw"
done < <(find "$BUNDLE_DIR" -name 'rw.*.dmg' -print0 2>/dev/null)

while IFS= read -r dev; do
  [[ -z "$dev" ]] && continue
  echo "Detaching leftover DMG device: $dev"
  hdiutil detach "$dev" -force 2>/dev/null || true
done < <(hdiutil info 2>/dev/null | awk '/\/Volumes\/dmg\./ {print $1}')
