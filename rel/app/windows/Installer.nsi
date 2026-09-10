!include "MUI2.nsh"
!include "WinVer.nsh"

Name "Safarimanager"
ManifestDPIAware true
OutFile "bin\SafarimanagerInstall.exe"
Unicode True

; Install to user home so we have permission to write COOKIE, crash dumps, etc
InstallDir "$LOCALAPPDATA\Safarimanager"

; Need admin for registering URL scheme
RequestExecutionLevel admin

!define MUI_ABORTWARNING
!define MUI_ICON "Resources\AppIcon.ico"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
${IfNot} ${AtLeastWin10}
  MessageBox mb_iconStop "It is recommended to run Safari Manager on Windows 10+"
${EndIf}
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"

  File "bin\vc_redist.x64.exe"
  ExecWait '"$INSTDIR\vc_redist.x64.exe" /install /quiet /norestart'
  Delete "$INSTDIR\vc_redist.x64.exe"

  File /a /r "bin\Safarimanager-Release\"

  CreateDirectory "$INSTDIR\Logs"
  WriteUninstaller "$INSTDIR\SafarimanagerUninstall.exe"
SectionEnd

Section "Desktop Shortcut"
  CreateShortCut "$DESKTOP\Safarimanager.lnk" "$INSTDIR\Safarimanager.exe" ""
SectionEnd

Section "Check"
  DetailPrint "Checking Erlang..."
  ; we use otp\erts-:vsn\bin\erl.exe instead of otp\bin\erl.exe because the latter for some reason
  ; hardcoded the path: c:\otp\erts-:vsn\bin\erlexec.dll. The Elixir releases uses the former
  ; anyway.
  nsExec::ExecToLog '"$INSTDIR\rel\vendor\otp\erts-${ERTS_VERSION}\bin\erl.exe" -noinput -eval "erlang:display(ok), halt()."'
  Pop $0
  ${If} $0 != 0
    MessageBox mb_iconStop "Checking Erlang failed: $0. Please click 'Show details' and report an issue."
    Abort
  ${EndIf}

  DetailPrint "Checking Distributed Erlang..."
  nsExec::ExecToLog '"$INSTDIR\rel\vendor\otp\erts-${ERTS_VERSION}\bin\erl.exe" -sname "safarimanager-install-test" -noinput -eval "erlang:display(ok), halt()."'
  Pop $0
  ${If} $0 != 0
    MessageBox mb_iconStop "Checking Distributed Erlang failed: $0. Please click 'Show details' and report an issue."
    Abort
  ${EndIf}
SectionEnd

Section "Install Handlers"
  DetailPrint "Registering .smgr File Handler"
  DeleteRegKey HKCR ".smgr"
  WriteRegStr  HKCR ".smgr" "" "Safarimanager.SMBundle"
  DeleteRegKey HKCR "Safarimanager.SMBundle"
  WriteRegStr  HKCR "Safarimanager.SMBundle" "" "SMBundle"
  WriteRegStr  HKCR "Safarimanager.SMBundle\DefaultIcon" "" "$INSTDIR\Safarimanager.exe,1"
  WriteRegStr  HKCR "Safarimanager.SMBundle\shell\open\command" "" '"$INSTDIR\Safarimanager.exe" "open:%1"'

  DetailPrint "Registering safarimanager URL Handler"
  DeleteRegKey HKCR "safarimanager"
  WriteRegStr  HKCR "safarimanager" "" "Safarimanager URL Protocol"
  WriteRegStr  HKCR "safarimanager" "URL Protocol" ""
  WriteRegStr  HKCR "safarimanager\shell" "" ""
  WriteRegStr  HKCR "safarimanager\shell\open" "" ""
  WriteRegStr  HKCR "safarimanager\shell\open\command" "" '"$INSTDIR\Safarimanager.exe" "open:%1"'
SectionEnd

Section "Uninstall"
  DeleteRegKey HKCR ".smgr"
  DeleteRegKey HKCR "Safarimanager.SMBundle"
  DeleteRegKey HKCR "safarimanager"

  DetailPrint "Terminating Safarimanager..."
  ExecWait "taskkill /f /t /im Safarimanager.exe"
  ExecWait "taskkill /f /t /im epmd.exe"
  Sleep 1000

  Delete "$DESKTOP\Safarimanager.lnk"
  RMDir /r "$INSTDIR"
SectionEnd
