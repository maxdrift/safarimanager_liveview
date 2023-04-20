#!/bin/bash
#
# Usage:
#
#     $ sh .github/scripts/app/build_windows.sh
#     $ rel/app/windows/bin/SafariManagerInstall.exe
#
# Note: This script builds the Windows installer. If you just want to test the Windows app locally, run:
#
#     $ cd rel/app/windows && ./run.sh
#
# See rel/app/windows/README.md for more information.
set -e

mix local.hex --force --if-missing
mix local.rebar --force --if-missing

export MIX_ENV=prod
export MIX_TARGET=app
export ELIXIRKIT_CONFIGURATION=Release

mix deps.get --only prod
yarn --cwd assets
mix compile
yarn --cwd assets run deploy

cd rel/app/windows
./build_installer.sh
