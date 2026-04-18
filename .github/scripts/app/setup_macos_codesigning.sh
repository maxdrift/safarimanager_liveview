#!/usr/bin/env bash
# Creates a temporary keychain, imports a Developer ID .p12 from secrets, and
# configures non-interactive access for codesign. Intended for self-hosted macOS runners.
#
# Required env (GitHub Actions secrets):
#   KEYCHAIN_PASSWORD           — password for the throwaway keychain (any strong random string)
#   MACOS_CERTIFICATE_BASE64    — base64 of the exported .p12 (Developer ID Application)
#   MACOS_CERTIFICATE_PASSWORD  — export password of the .p12
#
# One-time local step to produce MACOS_CERTIFICATE_BASE64:
#   base64 -i DeveloperID.p12 | tr -d '\n' | pbcopy
#
set -euo pipefail

KEYCHAIN_NAME="${KEYCHAIN_NAME:-SM_CI_CODESIGN.keychain}"
# security create-keychain foo.keychain → ~/Library/Keychains/foo.keychain-db
KEYCHAIN_PATH="$HOME/Library/Keychains/${KEYCHAIN_NAME%.keychain}.keychain-db"

: "${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD (e.g. GitHub secret)}"
: "${MACOS_CERTIFICATE_BASE64:?Set MACOS_CERTIFICATE_BASE64 (base64 .p12)}"
: "${MACOS_CERTIFICATE_PASSWORD:?Set MACOS_CERTIFICATE_PASSWORD}"

P12="$(mktemp -t sm-ci-signing.XXXXXX.p12)"
cleanup() { rm -f "$P12"; }
trap cleanup EXIT

printf '%s' "$MACOS_CERTIFICATE_BASE64" | base64 -d >"$P12"

security delete-keychain "$KEYCHAIN_NAME" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

security import "$P12" -k "$KEYCHAIN_PATH" -P "$MACOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

# Prefer this keychain for lookup (prepend)
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/\"//g')
security default-keychain -s "$KEYCHAIN_PATH"

echo "Code signing keychain ready at $KEYCHAIN_PATH"
