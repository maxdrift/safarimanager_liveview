#!/bin/bash
#
# Usage:
#
#     $ .github/scripts/app/build_macos.sh
#     $ open rel/app/macos/.build/SafariManagerInstall.dmg
#
# Note: This script builds the Mac installer. If you just want to test the Mac app locally, run:
#
#     $ cd rel/app/macos && ./run.sh
#
# See rel/app/macos/README.md for more information.
set -euo pipefail

main() {
  . versions
  OTP_VERSION="${OTP_VERSION:-$otp}"
  ELIXIR_VERSION="${ELIXIR_VERSION:-$elixir}"
  OPENSSL_VERSION="${OPENSSL_VERSION:-$openssl}"

  bootstrap_otp
  download_elixir
  build_app
}

bootstrap_otp() {
  dir=$PWD
  cd elixirkit/otp_bootstrap
  . ./build_macos_universal.sh "$OTP_VERSION" "$OPENSSL_VERSION"
  cd $dir
}

download_elixir() {
  dir=$PWD
  elixir_dir=$PWD/_build/elixir-"$ELIXIR_VERSION"

  if [ ! -d $elixir_dir ]; then
    otp_release=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')
    elixir_zip=v${ELIXIR_VERSION}-otp-${otp_release}.zip
    url=https://builds.hex.pm/builds/elixir/$elixir_zip
    echo downloading $url
    curl --fail -LO $url
    mkdir -p $elixir_dir
    unzip -q $elixir_zip -d $elixir_dir
    rm $elixir_zip
  fi

  export PATH="$elixir_dir/bin:$PATH"
  cd $dir
}

build_app() {
  # Begin Custom
  target="macos-$(uname -m | sed 's/x86_64/x86_64/;s/arm64/aarch64/')"
  # End Custom

  mix local.hex --force --if-missing
  mix local.rebar --force --if-missing

  export MIX_ENV=prod
  export MIX_TARGET=app
  export ELIXIRKIT_BUILD_ARGS="--configuration release --arch x86_64 --arch arm64"


  mix deps.get --only prod
  yarn --cwd assets
  mix compile
  yarn --cwd assets run deploy

  # Begin Custom
  app_version=$(MIX_QUIET=1 mix eval "IO.puts Mix.Project.config()[:version]" | grep -E '^[0-9]{4}\.[0-9]{1,2}\.[0-9]+$' | head -n 1 | tr -d '\n')

  echo "Building app version $app_version for $target..."

  export TARGET_ARCH=$target
  export APP_VERSION=$app_version
  # End Custom

  cd rel/app/macos
  ./build_dmg.sh
}

main "$@"
