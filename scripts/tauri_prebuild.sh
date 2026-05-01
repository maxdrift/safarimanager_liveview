#!/usr/bin/env bash
# Build the embedded Elixir release for Tauri bundling (run from repo root).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export MIX_ENV=prod
mix do deps.get --only prod + assets.deploy + release --overwrite --path src-tauri/target/rel
