[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallerPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedInstallerSha256,
    [Parameter(Mandatory=$true)][string]$PayloadRoot,
    [switch]$SkipReinstall
)

# Runs only a distinctly identified TESTE build in a new bounded directory.
# Never accepts the production setup, never touches the existing G: program,
# and never recursively deletes any directory. Residual fixtures are evidence.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$packageRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$testAppId = '{5E1F9064-C604-4842-A430-0530BF05A6D7}'
$testRegPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + $testAppId
$productionRegPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{0D8E26E9-24D0-47B9-9360-A2BED14C3E32}'
$shortcutGroup = Join-Path ([Environment]::GetFolderPath('Programs')) 'LZ Games - TESTE'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Aparador de vídeos LZ Games - TESTE.lnk'
$appExeName = 'APARADOR DE VIDEOS LZ-GAMES.exe'
$uninstallerName = 'Desinstalar.exe'
$result = [ordered]@{
    TestVersion = '1.3.0'; StartedUtc = [DateTime]::UtcNow.ToString('o')
    Passed = $false; Installer = $null; InstallerSha256 = $null; RunRoot = $null
    PayloadRoot = $null; TestScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    PayloadFiles = @(); Assertions = @(); Processes = @(); Failure = $null
    Scope = 'Isolated NSIS TESTE installation, exact packaged EXE self-test, reinstall, uninstall; no user videos processed.'
    Limits = 'Does not emulate a clean Windows machine, verify code signing, or replace visual/manual UI testing.'
}
$runRoot = $null
$sentinels = @{}

function Assert-Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $result.Assertions += $Message
}

function Assert-NoReparseAncestors([string]$Path) {
    $candidate = [IO.Path]::GetFullPath($Path)
    while ($candidate) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point not allowed in a test path: $candidate"
            }
        }
        $parent = Split-Path $candidate -Parent
        if (-not $parent -or $parent -eq $candidate) { break }
        $candidate = $parent
    }
}

function Resolve-PackagePath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($packageRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Test artifacts must be inside $packageRoot. Rejected: $full"
    }
    Assert-NoReparseAncestors $full
    return $full
}

function Get-UninstallKey([string]$Subkey) {
    $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, [Microsoft.Win32.RegistryView]::Registry32)
    try {
        $key = $registry.OpenSubKey($Subkey, $false)
        if (-not $key) { return $null }
        try {
            $values = [ordered]@{}
            foreach ($name in ($key.GetValueNames() | Sort-Object)) { $values[$name] = $key.GetValue($name) }
            return ($values | ConvertTo-Json -Compress -Depth 4)
        } finally { $key.Dispose() }
    } finally { $registry.Dispose() }
}

function Invoke-TestProcess([string]$File, [string]$Arguments, [int]$TimeoutSeconds = 60, [switch]$Capture) {
    $full = Resolve-PackagePath $File
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Executable missing: $full" }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $full
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.WorkingDirectory = Split-Path $full -Parent
    $info.RedirectStandardOutput = [bool]$Capture
    $info.RedirectStandardError = [bool]$Capture
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $started = [DateTime]::UtcNow
    try {
        if (-not $process.Start()) { throw "Failed to start $full" }
        $stdoutTask = $null; $stderrTask = $null
        if ($Capture) {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
        }
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            # Only our exact child process is stopped; never search and stop by name.
            $process.Kill()
            [void]$process.WaitForExit(5000)
            throw "Timeout for owned test process PID $($process.Id): $full"
        }
        $exitCode = $process.ExitCode
        $stdout = ''; $stderr = ''
        if ($Capture) { $stdout = $stdoutTask.Result; $stderr = $stderrTask.Result }
        $result.Processes += [ordered]@{
            File = $full; Arguments = $Arguments; ExitCode = $exitCode
            ElapsedSeconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3)
            StandardOutput = $stdout; StandardError = $stderr
        }
        return [pscustomobject]@{ ExitCode = $exitCode; StandardOutput = $stdout; StandardError = $stderr }
    } finally { $process.Dispose() }
}

function Assert-Payload([string]$InstallRoot) {
    foreach ($entry in $result.PayloadFiles) {
        $destination = Resolve-PackagePath (Join-Path $InstallRoot $entry.RelativePath)
        Assert-Test (Test-Path -LiteralPath $destination -PathType Leaf) ("Installed file exists: " + $entry.RelativePath)
        Assert-Test ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $entry.SHA256) ("Installed SHA256 matches payload: " + $entry.RelativePath)
    }
}

function Add-Sentinel([string]$Path) {
    $full = Resolve-PackagePath $Path
    if (Test-Path -LiteralPath $full) { throw "Sentinel path already exists: $full" }
    [void][IO.Directory]::CreateDirectory((Split-Path $full -Parent))
    [IO.File]::WriteAllText($full, ('LZGames installer safety sentinel ' + [guid]::NewGuid().ToString('N')), [Text.Encoding]::UTF8)
    $sentinels[$full] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
}

try {
    Assert-Test ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion -ge [version]'5.1') 'Host is Windows PowerShell 5.1 / Desktop.'
    $installer = Resolve-PackagePath $InstallerPath
    $payload = Resolve-PackagePath $PayloadRoot
    Assert-Test (Test-Path -LiteralPath $installer -PathType Leaf) 'Test installer exists.'
    Assert-Test ([IO.Path]::GetFileName($installer) -match '-TESTE-Setup\.exe$') 'Installer filename is distinctly TESTE, not production.'
    $actualInstallerHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    Assert-Test ($actualInstallerHash -eq $ExpectedInstallerSha256) 'Installer hash matches explicitly approved artifact.'
    $installerVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($installer)
    Assert-Test ($installerVersion.ProductName -match 'TESTE') 'Installer ProductName identifies TESTE before execution.'
    Assert-Test ((Get-UninstallKey $testRegPath) -eq $null) 'No previous TESTE uninstall registration exists.'
    Assert-Test (-not (Test-Path -LiteralPath $shortcutGroup)) 'TESTE Start menu group is initially absent.'
    Assert-Test (-not (Test-Path -LiteralPath $desktopShortcut)) 'TESTE desktop shortcut is initially absent.'
    $productionRegistryBefore = Get-UninstallKey $productionRegPath
    $result.Installer = $installer
    $result.InstallerSha256 = $actualInstallerHash
    $result.PayloadRoot = $payload

    foreach ($file in @(Get-ChildItem -LiteralPath $payload -Recurse -File)) {
        Assert-NoReparseAncestors $file.FullName
        $relative = $file.FullName.Substring($payload.TrimEnd('\').Length + 1)
        # Build provenance is not distributed by NSIS; all runtime/docs files are.
        if ($relative -eq 'BUILD-INFO.json') { continue }
        $result.PayloadFiles += [pscustomobject]@{ RelativePath = $relative; SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
    Assert-Test ($result.PayloadFiles.Count -ge 3) 'Payload includes application and video dependencies.'
    Assert-Test (@($result.PayloadFiles | Where-Object { $_.RelativePath -match '\.(ps1|cs|vbs|bat)$' }).Count -eq 0) 'Runtime payload contains no loose source scripts or launch wrappers.'
    foreach ($required in @($appExeName, 'bin\ffmpeg.exe', 'bin\ffprobe.exe')) {
        Assert-Test ($result.PayloadFiles.RelativePath -contains $required) ("Required payload dependency exists: " + $required)
    }

    $runRoot = Resolve-PackagePath (Join-Path $PSScriptRoot ('runs\' + [guid]::NewGuid().ToString('N')))
    Assert-Test (-not (Test-Path -LiteralPath $runRoot)) 'Run directory is new and isolated.'
    [void][IO.Directory]::CreateDirectory($runRoot)
    [IO.File]::WriteAllText((Join-Path $runRoot 'TEST-RUN-MARKER.txt'), $testAppId, [Text.Encoding]::UTF8)
    $result.RunRoot = $runRoot
    $installRoot = Join-Path $runRoot 'app'
    $dataRoot = Join-Path $runRoot 'dados'
    $blockedRoot = Join-Path $runRoot 'blocked-nonempty-destination'
    $blockedSentinel = Join-Path $blockedRoot 'KEEP-EXISTING-DATA.txt'
    Add-Sentinel $blockedSentinel
    $blockedInstall = Invoke-TestProcess $installer ('/S /D=' + $blockedRoot)
    Assert-Test ($blockedInstall.ExitCode -eq 11) 'First installation refuses a nonempty unregistered folder with code 11.'
    Assert-Test ((Get-FileHash -LiteralPath $blockedSentinel -Algorithm SHA256).Hash -eq $sentinels[$blockedSentinel]) 'Rejected installation preserved the existing file SHA256.'
    Assert-Test (@(Get-ChildItem -LiteralPath $blockedRoot -Force).Count -eq 1) 'Rejected installation created no files in the protected destination.'
    Assert-Test ((Get-UninstallKey $testRegPath) -eq $null) 'Rejected installation created no uninstall registration.'
    Assert-Test (-not (Test-Path -LiteralPath $shortcutGroup)) 'Rejected installation created no Start menu group.'
    # NSIS explicitly requires /D last, absolute, and not surrounded by quotes.
    $install = Invoke-TestProcess $installer ('/S /D=' + $installRoot)
    Assert-Test ($install.ExitCode -eq 0) 'Silent TESTE installer exits with code 0.'
    $registrationJson = Get-UninstallKey $testRegPath
    Assert-Test ($registrationJson -ne $null) 'TESTE uninstall registration exists.'
    $registration = $registrationJson | ConvertFrom-Json
    Assert-Test ($registration.AppId -eq $testAppId -and $registration.IsTestBuild -eq 1) 'Registration identifies isolated TestBuild/AppId.'
    Assert-Test ($registration.InstallLocation.TrimEnd('\') -eq $installRoot.TrimEnd('\')) 'Registration points to this exact isolated installation.'
    Assert-Test ($registration.DisplayName -match 'TESTE') 'Installed display name is clearly TESTE.'
    Assert-Payload $installRoot
    $installedExe = Join-Path $installRoot $appExeName
    Assert-Test ([Diagnostics.FileVersionInfo]::GetVersionInfo($installedExe).FileVersion -eq '1.3.0.0') 'Installed executable reports file version 1.3.0.0.'
    foreach ($shortcut in @('Aparador de vídeos LZ Games - TESTE.lnk', 'Desinstalar Aparador de vídeos - TESTE.lnk')) {
        Assert-Test (Test-Path -LiteralPath (Join-Path $shortcutGroup $shortcut) -PathType Leaf) ("Created isolated shortcut: " + $shortcut)
    }

    $selfTest = Invoke-TestProcess $installedExe ('--self-test --data-root "' + $dataRoot + '"')
    Assert-Test ($selfTest.ExitCode -eq 0) 'Exact installed EXE self-test exits with code 0.'
    $selfTestReport = Join-Path $dataRoot 'self-test-result.json'
    Assert-Test (Test-Path -LiteralPath $selfTestReport -PathType Leaf) 'Packaged runtime self-test wrote its JSON result in the isolated data root.'
    $result['SelfTestReport'] = Get-Content -LiteralPath $selfTestReport -Raw | ConvertFrom-Json
    Assert-Test ($result.SelfTestReport.Passed -eq $true -and $result.SelfTestReport.Version -eq '1.3.0') 'Runtime self-test JSON declares success for version 1.3.0.'
    Assert-Test ($result.SelfTestReport.RuntimeRoot.TrimEnd('\') -eq $installRoot.TrimEnd('\')) 'Runtime self-test used the installed payload, not development sources.'
    Assert-Test ($result.SelfTestReport.DataRoot.TrimEnd('\') -eq $dataRoot.TrimEnd('\')) 'Runtime self-test used only the isolated data root.'
    Assert-Payload $installRoot
    foreach ($utility in @('ffmpeg', 'ffprobe')) {
        $dependency = Invoke-TestProcess (Join-Path $installRoot ('bin\' + $utility + '.exe')) '-version' -Capture
        Assert-Test ($dependency.ExitCode -eq 0 -and $dependency.StandardOutput -match ($utility + ' version')) ("Installed dependency starts successfully: " + $utility)
    }
    $heldExecutable = [IO.File]::Open($installedExe, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        $busyInstall = Invoke-TestProcess $installer ('/S /D=' + $installRoot)
        Assert-Test ($busyInstall.ExitCode -eq 12) 'Installer refuses a locked application executable with code 12, without terminating another process.'
    } finally { $heldExecutable.Dispose() }
    Assert-Payload $installRoot

    Add-Sentinel (Join-Path $installRoot 'KEEP-USER-FILE.txt')
    Add-Sentinel (Join-Path $dataRoot 'KEEP-USER-DATA.txt')
    Add-Sentinel (Join-Path $dataRoot 'RECORTADOS_LZGAMES\Ação\KEEP-RESULT.mp4')
    if (-not $SkipReinstall) {
        $reinstall = Invoke-TestProcess $installer ('/S /D=' + $installRoot)
        Assert-Test ($reinstall.ExitCode -eq 0) 'Reinstall over the same TESTE application exits with code 0.'
        Assert-Payload $installRoot
        foreach ($sentinel in $sentinels.Keys) {
            Assert-Test ((Test-Path -LiteralPath $sentinel) -and (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -eq $sentinels[$sentinel]) ("Reinstall preserved sentinel: " + $sentinel.Substring($runRoot.Length + 1))
        }
    }
    Add-Sentinel (Join-Path $installRoot 'VIDEOS_ORIGINAIS\subpasta\KEEP-ORIGINAL.mp4')
    Add-Sentinel (Join-Path $installRoot 'RECORTADOS_LZGAMES\subpasta\KEEP-RESULT.mp4')
    $unsafeReinstall = Invoke-TestProcess $installer ('/S /D=' + $installRoot)
    Assert-Test ($unsafeReinstall.ExitCode -eq 11) 'Installer refuses a destination containing original/result media markers with code 11.'
    Assert-Payload $installRoot

    # Before invoking deletion implemented by the uninstaller, revalidate its
    # exact root, marker, registry identity, executable path, and reparse safety.
    Assert-Test ([IO.File]::ReadAllText((Join-Path $runRoot 'TEST-RUN-MARKER.txt')) -eq $testAppId) 'Exact bounded run marker verified before uninstall.'
    Assert-NoReparseAncestors $installRoot
    $preUninstall = (Get-UninstallKey $testRegPath) | ConvertFrom-Json
    Assert-Test ($preUninstall.InstallLocation.TrimEnd('\') -eq $installRoot.TrimEnd('\') -and $preUninstall.IsTestBuild -eq 1) 'Exact test registration reverified before uninstall.'
    $uninstaller = Resolve-PackagePath (Join-Path $installRoot $uninstallerName)
    Assert-Test (Test-Path -LiteralPath $uninstaller -PathType Leaf) 'Expected isolated uninstaller exists.'
    # _?= prevents NSIS spawning a detached temporary copy, so this PID is the
    # real uninstall. Its in-use executable may remain; no reboot is requested.
    $uninstall = Invoke-TestProcess $uninstaller ('/S _?=' + $installRoot)
    Assert-Test ($uninstall.ExitCode -eq 0) 'Isolated uninstaller exits with code 0.'
    foreach ($entry in $result.PayloadFiles) {
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $installRoot $entry.RelativePath))) ("Uninstall removed only known payload: " + $entry.RelativePath)
    }
    foreach ($sentinel in $sentinels.Keys) {
        Assert-Test ((Test-Path -LiteralPath $sentinel) -and (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -eq $sentinels[$sentinel]) ("Uninstall preserved sentinel: " + $sentinel.Substring($runRoot.Length + 1))
    }
    Assert-Test (Test-Path -LiteralPath $selfTestReport -PathType Leaf) 'Uninstall preserves external application data and test report.'
    Assert-Test ((Get-UninstallKey $testRegPath) -eq $null) 'TESTE uninstall registration was removed.'
    Assert-Test (-not (Test-Path -LiteralPath $shortcutGroup)) 'TESTE Start menu group was removed.'
    Assert-Test (-not (Test-Path -LiteralPath $desktopShortcut)) 'TESTE desktop shortcut was removed or was not selected.'
    Assert-Test ((Get-UninstallKey $productionRegPath) -eq $productionRegistryBefore) 'Production uninstall registration remains unchanged.'
    $result['UninstallerResidualExpected'] = Test-Path -LiteralPath $uninstaller
    $result['SentinelSha256'] = $sentinels
    $result.Passed = $true
} catch {
    $result.Failure = $_.Exception.ToString() + [Environment]::NewLine + $_.ScriptStackTrace
} finally {
    $result['FinishedUtc'] = [DateTime]::UtcNow.ToString('o')
    if ($runRoot -and (Test-Path -LiteralPath $runRoot)) {
        $reportPath = Join-Path $runRoot 'installer-test-result.json'
        $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
        Write-Output ("Report: " + $reportPath)
    }
    Write-Output ("Passed: " + $result.Passed + '; assertions: ' + $result.Assertions.Count)
    if (-not $result.Passed) { Write-Output $result.Failure }
}
if (-not $result.Passed) { exit 1 }
