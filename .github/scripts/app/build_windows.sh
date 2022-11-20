#!/bin/bash
#
# Usage:
#
#     $ sh .github/scripts/app/build_windows.sh
#     $ wscript _build/app_prod/SafariManager-win/SafariManagerLauncher.vbs
#     $ start smgr://github.com/maxdrift/safarimanager_liveview/blob/main/test/support/basic.smgr
#     $ start ./test/support/basic.smgr
set -e

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
MIX_ENV=prod MIX_TARGET=app mix deps.get --only prod
MIX_ENV=prod MIX_TARGET=app mix release app --overwrite
