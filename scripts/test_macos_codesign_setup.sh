#!/usr/bin/env bash
# Load repo-root .env.codesign.local if present, then run the same setup as CI.
# Usage:
#   ./scripts/test_macos_codesign_setup.sh
#   ./scripts/test_macos_codesign_setup.sh --validate-only
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.codesign.local"

if [ "${1:-}" = "--validate-only" ]; then
  export CODESIGN_SETUP_ONLY_VALIDATE=1
fi

if [ -f "$ENV_FILE" ]; then
  echo "Sourcing $ENV_FILE" >&2
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
else
  echo "No $ENV_FILE — export MACOS_CERTIFICATE_P12 (or MACOS_CERTIFICATE_BASE64), MACOS_CERTIFICATE_PASSWORD," >&2
  echo "and KEYCHAIN_PASSWORD yourself, or copy .env.codesign.local.example to .env.codesign.local" >&2
fi

exec bash "$ROOT/.github/scripts/app/setup_macos_codesigning.sh"
