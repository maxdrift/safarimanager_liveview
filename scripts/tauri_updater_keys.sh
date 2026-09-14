#!/usr/bin/env bash
# Generate updater signing keys with `tauri signer generate` (https://v2.tauri.app/plugin/updater/).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAURI_DIR="$ROOT/src-tauri"
KEY="$TAURI_DIR/updater.key"
PUB="$TAURI_DIR/updater.pub"

if [[ -f "$KEY" && "${FORCE:-}" != "1" ]]; then
  echo "Refusing to overwrite $KEY" >&2
  echo "Run: make app-updater-keys-force   (or FORCE=1 bash $0)" >&2
  exit 1
fi

mkdir -p "$TAURI_DIR"
rm -f "$KEY" "$PUB" "$TAURI_DIR/updater.key.pub"

# --ci: non-interactive, no password. Requires TAURI_SIGNING_PRIVATE_KEY_PASSWORD="" at sign time
# (set in .envrc.custom locally; CI=true in GitHub Actions skips the prompt automatically).
FORCE_ARGS=()
[[ "${FORCE:-}" == "1" ]] && FORCE_ARGS=(--force)
(cd "$TAURI_DIR" && npx --yes @tauri-apps/cli@2 signer generate -w updater.key "${FORCE_ARGS[@]}" --ci)

if [[ ! -f "$TAURI_DIR/updater.key.pub" ]]; then
  echo "Expected $TAURI_DIR/updater.key.pub after signer generate" >&2
  exit 1
fi

mv "$TAURI_DIR/updater.key.pub" "$PUB"

echo ""
echo "Set src-tauri/tauri.conf.json → plugins.updater.pubkey to the full contents of:"
echo "  $PUB"
echo ""
cat "$PUB"
echo ""
echo ""
echo "Private key: $KEY (gitignored)."
echo "Local dev: export TAURI_SIGNING_PRIVATE_KEY_PASSWORD=\"\" in .envrc.custom (empty string)."
echo "GitHub secret TAURI_SIGNING_PRIVATE_KEY: paste the entire contents of that file (single line)."
echo "GitHub Actions: CI is set automatically; no password secret needed."
