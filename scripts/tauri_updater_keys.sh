#!/usr/bin/env bash
# Generate a minisign keypair for Tauri updater signatures (same format as `tauri signer`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUB="$ROOT/src-tauri/updater.pub"
KEY="$ROOT/src-tauri/updater.key"

if [[ -f "$KEY" && "${FORCE:-}" != "1" ]]; then
  echo "Refusing to overwrite $KEY" >&2
  echo "Run: make app-updater-keys-force   (or FORCE=1 bash $0)" >&2
  exit 1
fi

if ! command -v minisign >/dev/null 2>&1; then
  echo "minisign is required (e.g. brew install minisign)" >&2
  exit 1
fi

mkdir -p "$ROOT/src-tauri"
rm -f "$PUB" "$KEY"
# -W: do not encrypt secret key (CI uses TAURI_SIGNING_PRIVATE_KEY file contents; optional password secret)
minisign -G -p "$PUB" -s "$KEY" -W

echo ""
echo "Public key line for src-tauri/tauri.conf.json → plugins.updater.pubkey:"
tail -n 1 "$PUB"
echo ""
echo "Private key: $KEY (gitignored). Set GitHub secret TAURI_SIGNING_PRIVATE_KEY to the full file contents."
echo "Optional: TAURI_SIGNING_PRIVATE_KEY_PASSWORD if you regenerate with encryption (omit -W)."
