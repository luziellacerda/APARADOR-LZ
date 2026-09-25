; NSIS 3.12, Unicode / Modern UI 2. Payload fechado: nenhum script-fonte.
Unicode true
RequestExecutionLevel user
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 32
SetDatablockOptimize on
CRCCheck on
ShowInstDetails show
ShowUninstDetails show
AutoCloseWindow false

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "WordFunc.nsh"
!include "WinVer.nsh"
!include "x64.nsh"

!ifndef TestBuild
  !define TestBuild 0
!endif
!ifndef PAYLOAD_ROOT
  !define PAYLOAD_ROOT "..\app"
!endif
!define APP_VERSION "1.3.0"
!define APP_EXE "APARADOR DE VIDEOS LZ-GAMES.exe"
!if ${TestBuild} == 1
  !define APP_ID "{5E1F9064-C604-4842-A430-0530BF05A6D7}"
  !define APP_NAME "Aparador de vídeos LZ Games - TESTE"
  !define START_GROUP "LZ Games - TESTE"
  !define UNINSTALL_SHORTCUT "Desinstalar Aparador de vídeos - TESTE"
  !define INSTALL_SUBDIR "Aparador de Videos - TESTE"
  !define SETUP_BASENAME "LZGames-Aparador-1.3.0-TESTE-Setup.exe"
!else
  !define APP_ID "{0D8E26E9-24D0-47B9-9360-A2BED14C3E32}"
  !define APP_NAME "Aparador de vídeos LZ Games"
  !define START_GROUP "LZ Games"
  !define UNINSTALL_SHORTCUT "Desinstalar Aparador de vídeos"
  !define INSTALL_SUBDIR "Aparador de Videos"
  !define SETUP_BASENAME "LZGames-Aparador-1.3.0-Setup.exe"
!endif
!ifndef OUTPUT_FILE
  !define OUTPUT_FILE "..\dist\${SETUP_BASENAME}"
!endif
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"

Name "${APP_NAME}"
Caption "Instalar ${APP_NAME}"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\LZ Games\${INSTALL_SUBDIR}"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
BrandingText "LZ Games · Aparador e compactador de vídeos"
VIProductVersion "1.3.0.0"
VIAddVersionKey /LANG=1046 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=1046 "CompanyName" "LZ Games"
VIAddVersionKey /LANG=1046 "FileDescription" "Instalador do ${APP_NAME}"
VIAddVersionKey /LANG=1046 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1046 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1046 "LegalCopyright" "LZ Games"

!define MUI_ICON "..\assets\LZGames.ico"
!define MUI_UNICON "..\assets\LZGames.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Aparador de vídeos LZ Games"
!define MUI_WELCOMEPAGE_TEXT "Instale o programa para o seu usuário do Windows.$\r$\n$\r$\nRecorte por início e fim, compacte vídeos e mantenha a organização das suas subpastas.$\r$\n$\r$\nSeus vídeos originais e resultados anteriores não são alterados pela instalação. Não é necessário executar como administrador."
!insertmacro MUI_PAGE_WELCOME
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_DIRECTORYPAGE_TEXT_TOP "Escolha onde instalar os arquivos do programa. Não selecione a pasta dos seus vídeos nem a pasta da versão portátil anterior. Os seus vídeos ficam separados da instalação."
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Instalação concluída"
!define MUI_FINISHPAGE_TEXT "O programa está disponível no Menu Iniciar.$\r$\n$\r$\nSeus vídeos e configurações ficam separados dos arquivos instalados. A desinstalação preserva esses dados."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Abrir Aparador de vídeos"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

!define MUI_UNCONFIRMPAGE_TEXT_TOP "O programa será removido. Seus vídeos originais, resultados e dados pessoais serão mantidos."
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "PortugueseBR"

Var TargetError
Var CheckPath
Var ParentPath
Var RegisteredDir
Var LockAttempt
Var LastFileError

; Confirma cada ancestral e o destino: não seguir junctions/symlinks na instalação
; ou desinstalação. Nunca usamos exclusão recursiva nem curingas no desinstalador.
!macro DefineDirectoryCheck Prefix
Function ${Prefix}CheckDirectoryChain
  Pop $CheckPath
  ${Do}
    System::Call 'kernel32::GetFileAttributesW(w "$CheckPath") i.r0'
    ${If} $0 <> -1
      IntOp $1 $0 & 0x400
      ${If} $1 != 0
        StrCpy $TargetError "A pasta escolhida contém um link ou redirecionamento. Escolha uma pasta local normal para instalar ou remover o programa com segurança."
        Return
      ${EndIf}
    ${EndIf}
    ${GetParent} "$CheckPath" $ParentPath
    ${If} $ParentPath == ""
      ${ExitDo}
    ${EndIf}
    ${If} $ParentPath == $CheckPath
      ${ExitDo}
    ${EndIf}
    StrCpy $CheckPath $ParentPath
  ${Loop}
FunctionEnd
!macroend
!insertmacro DefineDirectoryCheck ""
!insertmacro DefineDirectoryCheck "un."

!macro CheckPayloadPaths Prefix
  Push "$INSTDIR\${APP_EXE}"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\bin\ffmpeg.exe"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\bin\ffprobe.exe"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\docs\LEIA-ME.txt"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\docs\LICENSE-info.txt"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\docs\TERCEIROS-NSIS.txt"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\docs\TERCEIROS-FFMPEG.txt"
  Call ${Prefix}CheckDirectoryChain
  Push "$INSTDIR\Desinstalar.exe"
  Call ${Prefix}CheckDirectoryChain
!macroend

!macro DefineProgramCheck Prefix
Function ${Prefix}CheckProgramFile
  Pop $CheckPath
  ${If} $TargetError != ""
    Return
  ${EndIf}
  IfFileExists "$CheckPath" 0 file_is_available
  ; OPEN_EXISTING + acesso exclusivo: não cria nem modifica o arquivo.
  ; A liberação após encerrar um processo pode ser transitória (Windows/antivírus).
  ; No máximo 10 tentativas, somente para acesso negado/compartilhamento/trava.
  StrCpy $LockAttempt 0
  ${Do}
    System::Call 'kernel32::CreateFileW(w "$CheckPath", i 0xC0000000, i 0, p 0, i 3, i 0, p 0) p.r0 ?e'
    Pop $LastFileError
    ${If} $0 <> -1
      System::Call 'kernel32::CloseHandle(p r0)'
      Return
    ${EndIf}
    IntOp $LockAttempt $LockAttempt + 1
    ${If} $LockAttempt >= 10
      ${ExitDo}
    ${EndIf}
    ${If} $LastFileError = 5
    ${OrIf} $LastFileError = 32
    ${OrIf} $LastFileError = 33
      Sleep 250
    ${Else}
      ${ExitDo}
    ${EndIf}
  ${Loop}
  StrCpy $TargetError "Um arquivo do programa está em uso ou sem permissão de acesso (Windows: $LastFileError).$\r$\n$CheckPath$\r$\n$\r$\nFeche o Aparador de vídeos, aguarde o término dos processamentos e tente novamente. Nenhum processo será encerrado automaticamente."
  file_is_available:
FunctionEnd
!macroend
!insertmacro DefineProgramCheck ""
!insertmacro DefineProgramCheck "un."

Function CheckInstallTarget
  StrCpy $TargetError ""
  ; O comando NSIS GetFullPathName retorna vazio se a pasta não existir.
  ; A API Win32 apenas normaliza o caminho e aceita uma instalação nova.
  System::Call 'kernel32::GetFullPathNameW(w "$INSTDIR", i ${NSIS_MAX_STRLEN}, w .r0, p 0) i.r1'
  ${If} $1 <= 0
  ${OrIf} $1 >= ${NSIS_MAX_STRLEN}
    StrCpy $TargetError "O caminho escolhido é inválido ou longo demais. Escolha uma pasta local com nome mais curto."
    Return
  ${EndIf}
  StrCpy $INSTDIR $0
  ${GetRoot} "$INSTDIR" $0
  ${If} $INSTDIR == ""
  ${OrIf} $INSTDIR == "$0"
  ${OrIf} $INSTDIR == "$0\"
  ${OrIf} $INSTDIR == "$PROFILE"
  ${OrIf} $INSTDIR == "$DOCUMENTS"
  ${OrIf} $INSTDIR == "$DOCUMENTS\LZ Games"
  ${OrIf} $INSTDIR == "$LOCALAPPDATA"
  ${OrIf} $INSTDIR == "$TEMP"
  ${OrIf} $INSTDIR == "$WINDIR"
    StrCpy $TargetError "Escolha uma subpasta exclusiva para o programa, não uma pasta principal do Windows ou dos seus dados."
    Return
  ${EndIf}
  IfFileExists "$INSTDIR\Aparador-LZGames.ps1" legacy_folder 0
  IfFileExists "$INSTDIR\VIDEOS_ORIGINAIS\*.*" legacy_folder 0
  IfFileExists "$INSTDIR\RECORTADOS_LZGAMES\*.*" legacy_folder 0
  Goto directory_markers_ok
  legacy_folder:
    StrCpy $TargetError "Esta pasta contém a versão portátil ou seus vídeos. Instale em uma pasta separada; a versão anterior e os vídeos serão preservados."
    Return
  directory_markers_ok:
  ReadRegStr $RegisteredDir HKCU "${UNINSTALL_KEY}" "InstallLocation"
  ${If} $RegisteredDir != ""
    ReadRegStr $2 HKCU "${UNINSTALL_KEY}" "AppId"
    ${If} $2 != "${APP_ID}"
      StrCpy $TargetError "O registro desta instalação está incompleto. Nenhum arquivo será sobrescrito. Verifique a instalação existente antes de continuar."
      Return
    ${EndIf}
    GetFullPathName $RegisteredDir "$RegisteredDir"
    ${If} $RegisteredDir != $INSTDIR
      StrCpy $TargetError "Já existe uma instalação em $RegisteredDir. Atualize nessa mesma pasta ou desinstale a versão instalada antes de mudar o local. Seus dados serão preservados."
      Return
    ${EndIf}
  ${Else}
    ; Primeira instalação: não sobrescrever arquivos que já pertenciam ao usuário,
    ; mesmo que tenham o mesmo nome de um executável ou documento do payload.
    ClearErrors
    FindFirst $0 $1 "$INSTDIR\*"
    ${IfNot} ${Errors}
      ${Do}
        ${If} $1 != "."
        ${AndIf} $1 != ".."
        ${AndIf} $1 != ""
          FindClose $0
          StrCpy $TargetError "A pasta escolhida já contém arquivos ou subpastas. Para proteger seu conteúdo, escolha uma pasta nova ou vazia para esta primeira instalação."
          Return
        ${EndIf}
        ClearErrors
        FindNext $0 $1
        ${If} ${Errors}
          ${ExitDo}
        ${EndIf}
      ${Loop}
      FindClose $0
    ${EndIf}
    ClearErrors
  ${EndIf}
  !insertmacro CheckPayloadPaths ""
FunctionEnd

Function .onInit
  SetShellVarContext current
  SetRegView 32
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_OK|MB_ICONSTOP "Este programa precisa do Windows 10 ou 11 de 64 bits." /SD IDOK
    SetErrorLevel 10
    Abort
  ${EndIf}
  ${IfNot} ${IsNativeAMD64}
    MessageBox MB_OK|MB_ICONSTOP "Este instalador é para Windows de 64 bits em processador Intel/AMD (x64)." /SD IDOK
    SetErrorLevel 10
    Abort
  ${EndIf}
  ReadRegDWORD $0 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" "Release"
  ${If} $0 < 528040
    MessageBox MB_OK|MB_ICONSTOP "É necessário o Microsoft .NET Framework 4.8 ou superior. Instale-o pelo Windows Update ou pelo site oficial da Microsoft e execute este instalador novamente. Nenhum componente será baixado automaticamente." /SD IDOK
    SetErrorLevel 10
    Abort
  ${EndIf}
  SetRegView 64
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" "PowerShellVersion"
  SetRegView 32
  ${VersionCompare} "$0" "5.1" $1
  ${If} $1 == 2
    MessageBox MB_OK|MB_ICONSTOP "É necessário o Windows PowerShell 5.1. Restaure esse componente do Windows e execute o instalador novamente. PowerShell 7 não substitui esse requisito." /SD IDOK
    SetErrorLevel 10
    Abort
  ${EndIf}
  IfFileExists "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" prerequisites_ok 0
    MessageBox MB_OK|MB_ICONSTOP "O Windows PowerShell 5.1 de 64 bits não foi encontrado. Restaure o componente do Windows antes de instalar." /SD IDOK
    SetErrorLevel 10
    Abort
  prerequisites_ok:
FunctionEnd

Function .onVerifyInstDir
  Call CheckInstallTarget
  ${If} $TargetError != ""
    Abort
  ${EndIf}
FunctionEnd

Section "Programa e atalho no Menu Iniciar" SEC_PROGRAM
  SectionIn RO
  Call CheckInstallTarget
  ${If} $TargetError != ""
    MessageBox MB_OK|MB_ICONSTOP "$TargetError" /SD IDOK
    SetErrorLevel 11
    Abort
  ${EndIf}
  Push "$INSTDIR\${APP_EXE}"
  Call CheckProgramFile
  Push "$INSTDIR\bin\ffmpeg.exe"
  Call CheckProgramFile
  Push "$INSTDIR\bin\ffprobe.exe"
  Call CheckProgramFile
  ${If} $TargetError != ""
    MessageBox MB_OK|MB_ICONSTOP "$TargetError" /SD IDOK
    SetErrorLevel 12
    Abort
  ${EndIf}
  SetOverwrite on
  ClearErrors
  SetOutPath "$INSTDIR"
  File "${PAYLOAD_ROOT}\${APP_EXE}"
  SetOutPath "$INSTDIR\bin"
  File "${PAYLOAD_ROOT}\bin\ffmpeg.exe"
  File "${PAYLOAD_ROOT}\bin\ffprobe.exe"
  SetOutPath "$INSTDIR\docs"
  File "${PAYLOAD_ROOT}\docs\LEIA-ME.txt"
  File "${PAYLOAD_ROOT}\docs\LICENSE-info.txt"
  File "${PAYLOAD_ROOT}\docs\TERCEIROS-NSIS.txt"
  File "${PAYLOAD_ROOT}\docs\TERCEIROS-FFMPEG.txt"
  ${If} ${Errors}
    MessageBox MB_OK|MB_ICONSTOP "Não foi possível copiar todos os arquivos. Verifique o espaço livre e as permissões da pasta e execute o instalador novamente." /SD IDOK
    SetErrorLevel 14
    Abort
  ${EndIf}
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Desinstalar.exe"
  CreateDirectory "$SMPROGRAMS\${START_GROUP}"
  CreateShortcut "$SMPROGRAMS\${START_GROUP}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortcut "$SMPROGRAMS\${START_GROUP}\${UNINSTALL_SHORTCUT}.lnk" "$INSTDIR\Desinstalar.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "LZ Games"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "AppId" "${APP_ID}"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "IsTestBuild" ${TestBuild}
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE},0"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Desinstalar.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\Desinstalar.exe$\" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
  SetErrorLevel 0
SectionEnd

Section /o "Criar atalho na Área de Trabalho" SEC_DESKTOP
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_PROGRAM} "Instala o programa, os processadores de vídeo e os atalhos do Menu Iniciar. Seus vídeos não são copiados nem alterados."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} "Adiciona um atalho para o seu usuário na Área de Trabalho."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function un.onInit
  SetShellVarContext current
  SetRegView 32
  StrCpy $TargetError ""
  ReadRegStr $0 HKCU "${UNINSTALL_KEY}" "AppId"
  ReadRegStr $RegisteredDir HKCU "${UNINSTALL_KEY}" "InstallLocation"
  GetFullPathName $RegisteredDir "$RegisteredDir"
  GetFullPathName $INSTDIR "$INSTDIR"
  ${If} $0 != "${APP_ID}"
  ${OrIf} $RegisteredDir != $INSTDIR
    MessageBox MB_OK|MB_ICONSTOP "Esta pasta não corresponde à instalação registrada. Nenhum arquivo será removido. Execute o desinstalador pelo item correto em Aplicativos do Windows." /SD IDOK
    SetErrorLevel 13
    Abort
  ${EndIf}
  !insertmacro CheckPayloadPaths "un."
  Push "$INSTDIR\${APP_EXE}"
  Call un.CheckProgramFile
  Push "$INSTDIR\bin\ffmpeg.exe"
  Call un.CheckProgramFile
  Push "$INSTDIR\bin\ffprobe.exe"
  Call un.CheckProgramFile
  ${If} $TargetError != ""
    MessageBox MB_OK|MB_ICONSTOP "$TargetError" /SD IDOK
    SetErrorLevel 12
    Abort
  ${EndIf}
FunctionEnd

Section "Uninstall"
  ; Lista fechada, sem curingas, /REBOOTOK, RMDir /r ou acesso a Documentos.
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\bin\ffmpeg.exe"
  Delete "$INSTDIR\bin\ffprobe.exe"
  Delete "$INSTDIR\docs\LEIA-ME.txt"
  Delete "$INSTDIR\docs\LICENSE-info.txt"
  Delete "$INSTDIR\docs\TERCEIROS-NSIS.txt"
  Delete "$INSTDIR\docs\TERCEIROS-FFMPEG.txt"
  IfFileExists "$INSTDIR\${APP_EXE}" uninstall_incomplete 0
  IfFileExists "$INSTDIR\bin\ffmpeg.exe" uninstall_incomplete 0
  IfFileExists "$INSTDIR\bin\ffprobe.exe" uninstall_incomplete 0
  IfFileExists "$INSTDIR\docs\LEIA-ME.txt" uninstall_incomplete 0
  IfFileExists "$INSTDIR\docs\LICENSE-info.txt" uninstall_incomplete 0
  IfFileExists "$INSTDIR\docs\TERCEIROS-NSIS.txt" uninstall_incomplete 0
  IfFileExists "$INSTDIR\docs\TERCEIROS-FFMPEG.txt" uninstall_incomplete 0
  Delete "$INSTDIR\Desinstalar.exe"
  Delete "$SMPROGRAMS\${START_GROUP}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${START_GROUP}\${UNINSTALL_SHORTCUT}.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${START_GROUP}"
  RMDir "$INSTDIR\bin"
  RMDir "$INSTDIR\docs"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  SetErrorLevel 0
  Goto uninstall_done
  uninstall_incomplete:
    MessageBox MB_OK|MB_ICONSTOP "Alguns arquivos do programa ainda estão em uso ou protegidos. Feche o programa e execute o desinstalador novamente. Seus vídeos e os demais arquivos não foram apagados." /SD IDOK
    SetErrorLevel 14
    Abort
  uninstall_done:
SectionEnd
