#!/bin/sh
set -euo pipefail

. $(dirname $0)/build.sh

# The installer (Installer.nsi) writes HKCR entries. Here we create HKCU entries which don't
# require admin priveleges.

root="HKEY_CURRENT_USER\\Software\\Classes"

if ! reg query $root\\safarimanager >/dev/null 2>&1; then
  echo Setting registry
  exe="$(cmd //c cd)\\bin\\Safarimanager-$configuration\\Safarimanager.exe"

  reg add "$root\\.smgr" //d "Safarimanager.SMBundle" //f
  reg add "$root\\Safarimanager.SMBundle\\DefaultIcon" //d "$exe,1" //f
  reg add "$root\\Safarimanager.SMBundle\\shell\\open\\command" //d "$exe open:%1" //f

  reg add "$root\\safarimanager" //d "URL:Safarimanager Protocol" //f
  reg add "$root\\safarimanager" //v "URL Protocol" //f
  reg add "$root\\Safarimanager\\DefaultIcon" //d "$exe,1" //f
  reg add "$root\\safarimanager\\shell\\open\\command" //d "$exe open:%1" //f
fi

dotnet run --no-build
