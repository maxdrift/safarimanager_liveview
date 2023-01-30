#!/bin/bash
#
# Usage:
#
#     $ sh .github/scripts/app/build_mac.sh
#     $ open _build/app_prod/SafariManager.app
#     $ open smgr://github.com/maxdrift/safarimanager_liveview/blob/main/test/support/basic.smgr
#     $ open ./test/support/notebooks/basic.livemd
set -e

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
MIX_ENV=prod MIX_TARGET=app mix deps.get --only prod
MIX_ENV=prod MIX_TARGET=app yarn --cwd assets
MIX_ENV=prod MIX_TARGET=app mix compile
MIX_ENV=prod MIX_TARGET=app yarn --cwd assets run deploy
# MIX_ENV=prod MIX_TARGET=app mix phx.digest
MIX_ENV=prod MIX_TARGET=app mix app.build
