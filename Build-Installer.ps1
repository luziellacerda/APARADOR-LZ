[CmdletBinding()]
param(
    [string]$OutputRoot,
    [string]$MakeNsis='C:\Program Files (x86)\NSIS\makensis.exe',
    [string]$FfmpegDirectory,
    [string]$FfmpegNoticePath,
    [string]$NsisNoticePath,
    [switch]$IncludeTestBuild
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion -lt [version]'5.1' -or $PSVersionTable.PSEdition -ne 'Desktop'){throw 'Execute pelo Windows PowerShell 5.1.'}
if(-not $FfmpegDirectory){$FfmpegDirectory=Join-Path $PSScriptRoot 'vendor\ffmpeg'}
if(-not $FfmpegNoticePath){$FfmpegNoticePath=Join-Path $FfmpegDirectory '..\docs\TERCEIROS-FFMPEG.txt'}
if(-not $NsisNoticePath){$NsisNoticePath=Join-Path $PSScriptRoot 'docs\TERCEIROS-NSIS.txt'}
if(-not $OutputRoot){$OutputRoot=Join-Path $PSScriptRoot ('builds\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))}
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $OutputRoot){throw 'Use uma pasta de build nova para preservar os resultados anteriores.'}
if(-not (Test-Path -LiteralPath $MakeNsis -PathType Leaf)){throw 'Compilador NSIS não encontrado; informe -MakeNsis.'}
$nsisVersion=(& $MakeNsis /VERSION | Out-String).Trim()
if($LASTEXITCODE -ne 0){throw 'Não foi possível identificar a versão do NSIS.'}
if(-not (Test-Path -LiteralPath $FfmpegNoticePath -PathType Leaf)){throw 'Avisos das dependências ausentes; informe -FfmpegNoticePath.'}
if(-not (Test-Path -LiteralPath $NsisNoticePath -PathType Leaf)){throw 'Avisos do NSIS ausentes; informe -NsisNoticePath.'}
$packagedDocs=@('LEIA-ME.txt','LICENSE-info.txt')
foreach($name in $packagedDocs){if(-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot ('docs\'+$name)) -PathType Leaf)){throw ('Documento de distribuição ausente: '+$name)}}
[void](New-Item -ItemType Directory -Path $OutputRoot)
$payload=Join-Path $OutputRoot 'app'
& (Join-Path $PSScriptRoot 'Build-App.ps1') -OutputDirectory $payload -FfmpegDirectory $FfmpegDirectory
$payloadDocs=Join-Path $payload 'docs'
[void](New-Item -ItemType Directory -Path $payloadDocs)
foreach($name in $packagedDocs){Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('docs\'+$name)) -Destination (Join-Path $payloadDocs $name)}
Copy-Item -LiteralPath $FfmpegNoticePath -Destination (Join-Path $payloadDocs 'TERCEIROS-FFMPEG.txt')
Copy-Item -LiteralPath $NsisNoticePath -Destination (Join-Path $payloadDocs 'TERCEIROS-NSIS.txt')
$selfTestData=Join-Path $OutputRoot 'self-test'
$launch=New-Object Diagnostics.ProcessStartInfo
$launch.FileName=Join-Path $payload 'APARADOR DE VIDEOS LZ-GAMES.exe'
$launch.Arguments='--self-test --data-root "'+$selfTestData+'"'
$launch.UseShellExecute=$false;$launch.CreateNoWindow=$true
$selfTest=[Diagnostics.Process]::Start($launch)
try{
    if(-not $selfTest.WaitForExit(60000)){throw 'O autoteste excedeu 60 segundos; o processo não foi encerrado à força.'}
    if($selfTest.ExitCode -ne 0){throw ('Autoteste falhou: '+$selfTest.ExitCode)}
}finally{$selfTest.Dispose()}
$scriptPath=Join-Path $PSScriptRoot 'installer\LZGames-Setup.nsi'
$variants=@(0)
if($IncludeTestBuild){$variants+=1}
$installers=foreach($variant in $variants){
    $name=if($variant -eq 1){'LZGames-Aparador-1.5.0-TESTE-Setup.exe'}else{'LZGames-Aparador-1.5.0-Setup.exe'}
    $installer=Join-Path $OutputRoot $name
    & $MakeNsis /INPUTCHARSET UTF8 /V3 /WX ('/DTestBuild='+$variant) ('/DPAYLOAD_ROOT='+$payload) ('/DOUTPUT_FILE='+$installer) $scriptPath | Out-Host
    if($LASTEXITCODE -ne 0){throw ('A compilação do instalador falhou: '+$LASTEXITCODE)}
    [ordered]@{File=$name;Bytes=(Get-Item -LiteralPath $installer).Length;SHA256=(Get-FileHash -LiteralPath $installer).Hash;TestBuild=($variant -eq 1)}
}
$files=Get-ChildItem -LiteralPath $payload -File -Recurse|Where-Object{$_.Name -ne 'BUILD-INFO.json'}|ForEach-Object{
    [ordered]@{File=$_.FullName.Substring($payload.Length+1);Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}
}
[ordered]@{Version='1.5.0';BuiltUtc=[DateTime]::UtcNow.ToString('o');NSIS=$MakeNsis;NSISVersion=$nsisVersion;NSISSHA256=(Get-FileHash -LiteralPath $MakeNsis).Hash;Payload=@($files);Installers=@($installers);SelfTest=(Join-Path $selfTestData 'self-test-result.json');Installed=$false}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $OutputRoot 'MANIFEST.json') -Encoding UTF8
Write-Output ('Instaladores criados, sem instalação automática: '+$OutputRoot)
