[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$IconPath,
    [string]$FfmpegDirectory
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $PSScriptRoot 'app' }
if (-not $IconPath) { $IconPath=Join-Path $PSScriptRoot 'assets\LZGames.ico' }
if (-not $FfmpegDirectory) { $FfmpegDirectory=Join-Path $PSScriptRoot 'vendor\ffmpeg' }
if ($PSVersionTable.PSVersion -lt [version]'5.1' -or $PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Compile pelo Windows PowerShell 5.1 (powershell.exe).'
}
$sourceRoot=Join-Path $PSScriptRoot 'src'
$FfmpegDirectory=[IO.Path]::GetFullPath($FfmpegDirectory)
$destination=[IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if (Test-Path -LiteralPath $destination) {
    if (@(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0) { throw 'A pasta de saída deve estar vazia; escolha outra para preservar builds anteriores.' }
}
$compiler=Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
$automation=[System.Management.Automation.PowerShell].Assembly.Location
$sources=@('LZGamesLauncher.cs','Dashboard-LZGames.cs','VideoSafety.cs','Aparador-LZGames.ps1')
foreach ($name in $sources) { if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $name) -PathType Leaf)) { throw "Fonte ausente: $name" } }
foreach ($name in @('ffmpeg.exe','ffprobe.exe')) { if (-not (Test-Path -LiteralPath (Join-Path $FfmpegDirectory $name) -PathType Leaf)) { throw "Dependência ausente: $name em $FfmpegDirectory. Informe -FfmpegDirectory; consulte docs\DEPENDENCIAS.md." } }
if ($IconPath -and -not (Test-Path -LiteralPath $IconPath -PathType Leaf)) { throw "Ícone ausente: $IconPath" }
[void][IO.Directory]::CreateDirectory($destination)
[void][IO.Directory]::CreateDirectory((Join-Path $destination 'bin'))
$executable=Join-Path $destination 'APARADOR DE VIDEOS LZ-GAMES.exe'
$arguments=@(
    '/nologo','/target:winexe','/platform:x64','/optimize+','/codepage:65001',
    ('/out:'+$executable),'/reference:System.dll','/reference:System.Core.dll',
    '/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:Accessibility.dll',
    ('/reference:'+$automation),
    ('/resource:'+(Join-Path $sourceRoot 'Aparador-LZGames.ps1')+',LZGames.Backend.ps1'),
    (Join-Path $sourceRoot 'LZGamesLauncher.cs'),
    (Join-Path $sourceRoot 'Dashboard-LZGames.cs'),
    (Join-Path $sourceRoot 'VideoSafety.cs')
)
if ($IconPath) { $arguments+=('/win32icon:'+[IO.Path]::GetFullPath($IconPath)) }
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "Falha de compilação: $LASTEXITCODE" }
foreach ($name in @('ffmpeg.exe','ffprobe.exe')) { Copy-Item -LiteralPath (Join-Path $FfmpegDirectory $name) -Destination (Join-Path $destination ('bin\'+$name)) }
$version=[Diagnostics.FileVersionInfo]::GetVersionInfo($executable).FileVersion
if ($version -ne '1.4.0.0') { throw "Versão inesperada: $version" }
$manifestFiles=@('APARADOR DE VIDEOS LZ-GAMES.exe','bin\ffmpeg.exe','bin\ffprobe.exe')
$manifest=foreach ($name in $manifestFiles) {
    $path=Join-Path $destination $name
    [ordered]@{File=$name;Bytes=(Get-Item -LiteralPath $path).Length;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
}
$buildInfo=[ordered]@{
    ApplicationVersion='1.4.0';BuiltUtc=[DateTime]::UtcNow.ToString('o');Compiler=$compiler;
    CompilerSHA256=(Get-FileHash -LiteralPath $compiler).Hash;PowerShellAssembly=$automation;
    PowerShellAssemblySHA256=(Get-FileHash -LiteralPath $automation).Hash;
    EmbeddedBackend='LZGames.Backend.ps1';ExternalSourceFilesRequired=$false;
    UserDataDefault='Documents\LZ Games';DiagnosticsDefault='LocalAppData\LZGames\Logs';
    ByteForByteDeterministic=$false;CommandArguments=$arguments;
    Sources=@($sources | ForEach-Object { [ordered]@{File=$_;SHA256=(Get-FileHash -LiteralPath (Join-Path $sourceRoot $_)).Hash} });
    Files=@($manifest)
}
$buildInfo | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destination 'BUILD-INFO.json') -Encoding UTF8
Write-Output "Aplicativo compilado: $executable"
Write-Output 'UI e segurança compiladas; backend embutido; nenhum PS1/CS externo é necessário para executar.'
