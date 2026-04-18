#!/usr/bin/env bash
# Creates a temporary keychain, imports a Developer ID .p12 from secrets, and
# configures non-interactive access for codesign. Intended for self-hosted macOS runners.
#
# CI (GitHub Actions secrets):
#   KEYCHAIN_PASSWORD           — password for the throwaway keychain
#   MACOS_CERTIFICATE_BASE64    — base64 of the exported .p12 (single line)
#   MACOS_CERTIFICATE_PASSWORD  — export password of the .p12
#
# Local testing (easier than base64):
#   export MACOS_CERTIFICATE_P12="$HOME/path/to/DeveloperID.p12"
#   export MACOS_CERTIFICATE_PASSWORD="..."
#   export KEYCHAIN_PASSWORD="..."   # skip if only validating, see below
#
# Dry run (verify .p12 + password only; no keychain changes):
#   CODESIGN_SETUP_ONLY_VALIDATE=1 MACOS_CERTIFICATE_P12=... MACOS_CERTIFICATE_PASSWORD=... \
#     bash .github/scripts/app/setup_macos_codesigning.sh
#
# One-time: base64 for MACOS_CERTIFICATE_BASE64 secret:
#   base64 -i DeveloperID.p12 | tr -d '\n'
#
set -euo pipefail

# Keychain-exported .p12 often needs -legacy on OpenSSL 3; passwords with shell-special
# chars break "pass:..." — use stdin for both checks and for consistency with CI.
openssl_pkcs12_can_read() {
  local p12="$1"
  local pass="$2"
  if printf '%s' "$pass" | openssl pkcs12 -in "$p12" -nokeys -passin stdin -info -noout >/dev/null 2>&1; then
    return 0
  fi
  if printf '%s' "$pass" | openssl pkcs12 -legacy -in "$p12" -nokeys -passin stdin -info -noout >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

KEYCHAIN_NAME="${KEYCHAIN_NAME:-SM_CI_CODESIGN.keychain}"
KEYCHAIN_PATH="$HOME/Library/Keychains/${KEYCHAIN_NAME%.keychain}.keychain-db"

: "${MACOS_CERTIFICATE_PASSWORD:?Set MACOS_CERTIFICATE_PASSWORD}"

P12="$(mktemp -t sm-ci-signing.XXXXXX.p12)"
cleanup() { rm -f "$P12"; }
trap cleanup EXIT

if [ -n "${MACOS_CERTIFICATE_P12:-}" ]; then
  if [ ! -f "$MACOS_CERTIFICATE_P12" ]; then
    echo "ERROR: MACOS_CERTIFICATE_P12 is not a file: $MACOS_CERTIFICATE_P12" >&2
    exit 1
  fi
  cp "$MACOS_CERTIFICATE_P12" "$P12"
else
  : "${MACOS_CERTIFICATE_BASE64:?Set MACOS_CERTIFICATE_BASE64 or MACOS_CERTIFICATE_P12}"
  B64=$(printf '%s' "$MACOS_CERTIFICATE_BASE64" | tr -d '\n\r\t ')
  B64="${B64#\"}"
  B64="${B64%\"}"
  if ! printf '%s' "$B64" | base64 -d >"$P12" 2>/dev/null; then
    echo "ERROR: MACOS_CERTIFICATE_BASE64 is not valid base64." >&2
    exit 1
  fi
fi

if [ ! -s "$P12" ]; then
  echo "ERROR: certificate material is empty." >&2
  exit 1
fi

first=$(head -c 1 "$P12" || true)
if [ "$first" = "-" ]; then
  echo "ERROR: content looks like PEM text, not a .p12 file." >&2
  echo "Export 'Developer ID Application' as .p12 from Keychain Access, then:" >&2
  echo "  base64 -i Your.p12 | tr -d '\n'" >&2
  exit 1
fi

if ! openssl_pkcs12_can_read "$P12" "$MACOS_CERTIFICATE_PASSWORD"; then
  echo "ERROR: PKCS#12 is unreadable or MACOS_CERTIFICATE_PASSWORD is wrong." >&2
  echo "Check the export password. If it contains \$, quotes, or !, use single-quoted values in .env.codesign.local." >&2
  echo "Re-run with CODESIGN_SETUP_VERBOSE=1 to print openssl errors (no password is echoed)." >&2
  if [ "${CODESIGN_SETUP_VERBOSE:-}" = "1" ]; then
    echo "--- openssl ---" >&2
    printf '%s' "$MACOS_CERTIFICATE_PASSWORD" | openssl pkcs12 -in "$P12" -nokeys -passin stdin -info -noout 2>&1 | tail -30 >&2 || true
    echo "--- openssl -legacy ---" >&2
    printf '%s' "$MACOS_CERTIFICATE_PASSWORD" | openssl pkcs12 -legacy -in "$P12" -nokeys -passin stdin -info -noout 2>&1 | tail -30 >&2 || true
  fi
  exit 1
fi

if [ "${CODESIGN_SETUP_ONLY_VALIDATE:-}" = "1" ]; then
  echo "OK: PKCS#12 and password are valid (CODESIGN_SETUP_ONLY_VALIDATE=1 — no keychain changes)."
  exit 0
fi

: "${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD (or use CODESIGN_SETUP_ONLY_VALIDATE=1 for a dry run)}"

security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

# -f pkcs12 avoids mis-detection that yields SecKeychainItemImport: Unknown format in import.
security import "$P12" -f pkcs12 -k "$KEYCHAIN_PATH" -P "$MACOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/\"//g')
security default-keychain -s "$KEYCHAIN_PATH"

echo "Code signing keychain ready at $KEYCHAIN_PATH"
