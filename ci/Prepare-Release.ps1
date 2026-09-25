[CmdletBinding()]
param(
    [string]$BuildRoot = 'builds\ci',
    [string]$DependencyRoot = 'ci-out',
    [string]$OutputDirectory = 'release-out',
    [Parameter(Mandatory=$true)][string]$MediaReportPath,
    [Parameter(Mandatory=$true)][string]$InstallerReportPath,
    [string]$SourceCommit,
    [string]$Tag = 'v1.3.0',
    [string]$RunUrl
)

# Publish an explicit allow-list, never the workspace or raw test reports.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$version = '1.3.0'
$repository = 'luziellacerda/APARADOR-LZ'
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')

function Assert-Release([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Resolve-RepositoryPath([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $repositoryRoot $Path }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    Assert-Release ($full.StartsWith($repositoryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Release paths must be beneath the repository root.'
    $current = $full
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            Assert-Release (((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Release paths cannot contain symbolic links or junctions.'
        }
        $parent = Split-Path $current -Parent
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
    return $full
}

function Read-ReleaseJson([string]$Path) {
    Assert-Release (Test-Path -LiteralPath $Path -PathType Leaf) ('Required report is missing: ' + [IO.Path]::GetFileName($Path))
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-Sha256([string]$Path) {
    Assert-Release (Test-Path -LiteralPath $Path -PathType Leaf) ('Required artifact is missing: ' + [IO.Path]::GetFileName($Path))
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-PublicFileMetadata([string]$Path, [string]$Name) {
    return [ordered]@{ File=$Name; Bytes=(Get-Item -LiteralPath $Path).Length; SHA256=(Get-Sha256 $Path) }
}

Assert-Release ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion -ge [version]'5.1') 'Use Windows PowerShell 5.1.'
Assert-Release ($Tag -ceq ('v' + $version)) 'The release tag must match application version v1.3.0.'
$build = Resolve-RepositoryPath $BuildRoot
$dependencies = Resolve-RepositoryPath $DependencyRoot
$output = Resolve-RepositoryPath $OutputDirectory
$mediaPath = Resolve-RepositoryPath $MediaReportPath
$installerPath = Resolve-RepositoryPath $InstallerReportPath
Assert-Release (-not (Test-Path -LiteralPath $output)) 'Use a new release output directory; existing deliverables are never overwritten.'
Assert-Release (-not $build.StartsWith($output + '\', [StringComparison]::OrdinalIgnoreCase) -and -not $dependencies.StartsWith($output + '\', [StringComparison]::OrdinalIgnoreCase)) 'The release directory cannot contain the build or dependencies.'

if (-not $SourceCommit) {
    $SourceCommit = (& git -C $repositoryRoot rev-parse HEAD | Out-String).Trim()
    Assert-Release ($LASTEXITCODE -eq 0) 'Could not resolve source commit.'
}
Assert-Release ($SourceCommit -cmatch '^[0-9a-fA-F]{40}$') 'SourceCommit must be a complete Git SHA.'
$resolvedCommit = (& git -C $repositoryRoot rev-parse ($SourceCommit + '^{commit}') | Out-String).Trim()
Assert-Release ($LASTEXITCODE -eq 0 -and $resolvedCommit -eq $SourceCommit) 'SourceCommit does not resolve to the requested commit.'
& git -C $repositoryRoot diff --quiet $SourceCommit --
Assert-Release ($LASTEXITCODE -eq 0) 'Commit all tracked source changes before preparing a release.'
if ($env:GITHUB_ACTIONS -eq 'true') {
    Assert-Release ($env:GITHUB_REPOSITORY -ceq $repository) 'Unexpected GitHub repository.'
    Assert-Release ($env:GITHUB_SHA -eq $SourceCommit) 'Build commit does not match this workflow run.'
    if ($env:GITHUB_REF_TYPE -eq 'tag') { Assert-Release ($env:GITHUB_REF_NAME -ceq $Tag) 'Workflow tag does not match application version.' }
}
if ($RunUrl) {
    Assert-Release ($RunUrl -match '^https://github\.com/luziellacerda/APARADOR-LZ/actions/runs/[0-9]+$') 'RunUrl must identify a workflow run in this repository.'
}

$payload = Join-Path $build 'app'
$application = Join-Path $payload 'APARADOR DE VIDEOS LZ-GAMES.exe'
$productionName = 'LZGames-Aparador-' + $version + '-Setup.exe'
$testName = 'LZGames-Aparador-' + $version + '-TESTE-Setup.exe'
$productionInstaller = Join-Path $build $productionName
$testInstaller = Join-Path $build $testName
$sourceBundleName = 'FFmpeg-corresponding-source.tar.xz'
$sourceBundle = Join-Path $dependencies ('sources\' + $sourceBundleName)
$manifest = Read-ReleaseJson (Join-Path $build 'MANIFEST.json')
$media = Read-ReleaseJson $mediaPath
$installation = Read-ReleaseJson $installerPath
$selfTest = Read-ReleaseJson (Join-Path $build 'self-test\self-test-result.json')
$dependencyLock = Read-ReleaseJson (Join-Path $PSScriptRoot 'dependencies.lock.json')
$applicationHash = Get-Sha256 $application

Assert-Release ($manifest.Version -eq $version) 'Build manifest version mismatch.'
Assert-Release ([Diagnostics.FileVersionInfo]::GetVersionInfo($application).FileVersion -eq '1.3.0.0') 'Application version mismatch.'
Assert-Release ([Diagnostics.FileVersionInfo]::GetVersionInfo($productionInstaller).ProductName -notmatch 'TESTE') 'Refusing to publish a TESTE installer.'
Assert-Release ($media.Passed -eq $true -and $media.Version -eq $version -and @($media.Assertions).Count -ge 85) 'The real-media test suite must pass completely.'
Assert-Release ($media.ExeSHA256 -eq $applicationHash) 'Media tests did not use this exact compiled application.'
foreach ($caseName in @('trim-nested-silent','preserve-existing','overwrite-new-interval','whole-with-audio','h265-profile-0','h265-profile-1','h265-profile-2')) {
    $case = @($media.Cases | Where-Object { $_.Name -ceq $caseName })
    Assert-Release ($case.Count -eq 1 -and $case[0].Failed -eq 0) 'Release media tests must cover every H.264 and H.265 profile; use AllProfiles.'
}
Assert-Release ($installation.Passed -eq $true -and $installation.TestVersion -eq $version -and @($installation.Assertions).Count -ge 122) 'The full installer test suite must pass.'
Assert-Release (@($installation.Assertions) -contains 'Reinstall over the same TESTE application exits with code 0.') 'A release requires the reinstall test; SkipReinstall is not accepted.'
Assert-Release ([IO.Path]::GetFullPath($installation.PayloadRoot).TrimEnd('\') -eq $payload.TrimEnd('\')) 'Installer tests used another payload directory.'
Assert-Release ($installation.InstallerSha256 -eq (Get-Sha256 $testInstaller)) 'Installer tests did not use this exact TESTE installer.'
Assert-Release ($selfTest.Passed -eq $true -and $selfTest.Version -eq $version -and @($selfTest.Assertions).Count -ge 14) 'Compiled application self-test must pass.'
Assert-Release ($installation.SelfTestReport.Passed -eq $true -and @($installation.SelfTestReport.Assertions).Count -ge 14) 'Installed application self-test must pass.'

foreach ($name in @($productionName, $testName)) {
    $record = @($manifest.Installers | Where-Object { $_.File -ceq $name })
    Assert-Release ($record.Count -eq 1) 'Each expected installer must occur once in the build manifest.'
    Assert-Release ($record[0].SHA256 -eq (Get-Sha256 (Join-Path $build $name))) 'Installer hash does not match the verified build manifest.'
}

$publicPayload = @()
$actualPayloadFiles = @(Get-ChildItem -LiteralPath $payload -File -Recurse | Where-Object { $_.Name -ne 'BUILD-INFO.json' })
Assert-Release ($actualPayloadFiles.Count -eq @($manifest.Payload).Count -and $actualPayloadFiles.Count -eq @($installation.PayloadFiles).Count) 'Payload file lists differ between build and tests.'
foreach ($file in $actualPayloadFiles) {
    [void](Resolve-RepositoryPath $file.FullName)
    $relative = $file.FullName.Substring($payload.Length + 1)
    $built = @($manifest.Payload | Where-Object { $_.File -ceq $relative })
    $tested = @($installation.PayloadFiles | Where-Object { $_.RelativePath -ceq $relative })
    Assert-Release ($built.Count -eq 1 -and $tested.Count -eq 1) 'A payload file was not covered by both the manifest and installer tests.'
    $hash = Get-Sha256 $file.FullName
    Assert-Release ($built[0].SHA256 -eq $hash -and $tested[0].SHA256 -eq $hash) 'A runtime payload file changed after testing.'
    Assert-Release ($relative -notmatch '\.(ps1|cs|bat|vbs)$') 'Runtime contains unexpected loose source files.'
    $publicPayload += (Get-PublicFileMetadata $file.FullName $relative.Replace('\','/'))
}
foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
    Assert-Release ((Get-Sha256 (Join-Path $payload ('bin\' + $name))) -eq (Get-Sha256 (Join-Path $dependencies ('bin\' + $name)))) 'Packaged media binaries do not match this dependency build.'
}
Assert-Release ((Get-Sha256 (Join-Path $payload 'docs\TERCEIROS-FFMPEG.txt')) -eq (Get-Sha256 (Join-Path $dependencies 'docs\TERCEIROS-FFMPEG.txt'))) 'The matching FFmpeg distribution notice must be installed.'
[void](Get-Sha256 $sourceBundle)
Assert-Release ((Get-Item -LiteralPath $sourceBundle).Length -gt 0) 'The corresponding-source archive cannot be empty.'
$dependencyChecksumsPath = Join-Path $dependencies 'SHA256SUMS.txt'
Assert-Release (Test-Path -LiteralPath $dependencyChecksumsPath -PathType Leaf) 'Dependency build checksums are required.'
$dependencyChecksums = @{}
foreach ($line in @(Get-Content -LiteralPath $dependencyChecksumsPath -Encoding UTF8)) {
    if (-not $line.Trim()) { continue }
    Assert-Release ($line -cmatch '^([0-9a-fA-F]{64})  (bin/(?:ffmpeg|ffprobe)\.exe|sources/FFmpeg-corresponding-source\.tar\.xz)$') 'Unexpected dependency checksum record.'
    $entryHash = $Matches[1]; $entryName = $Matches[2]
    Assert-Release (-not $dependencyChecksums.ContainsKey($entryName)) 'Duplicate dependency checksum record.'
    $dependencyChecksums[$entryName] = $entryHash
}
Assert-Release ($dependencyChecksums.Count -eq 3) 'Dependency checksum list must cover both binaries and the corresponding sources.'
foreach ($name in @('bin/ffmpeg.exe','bin/ffprobe.exe','sources/FFmpeg-corresponding-source.tar.xz')) {
    Assert-Release ($dependencyChecksums.ContainsKey($name) -and $dependencyChecksums[$name] -eq (Get-Sha256 (Join-Path $dependencies $name))) 'Dependency artifacts differ from their source-build checksums.'
}
Assert-Release ($manifest.NSISVersion -match '^v?3\.[0-9]+(?:\.[0-9]+)?$' -and $manifest.NSISSHA256 -match '^[0-9a-fA-F]{64}$') 'Build must record NSIS version and compiler hash.'

[void][IO.Directory]::CreateDirectory($output)
Copy-Item -LiteralPath $productionInstaller -Destination (Join-Path $output $productionName)
Copy-Item -LiteralPath $sourceBundle -Destination (Join-Path $output $sourceBundleName)
$applicationSourceName = 'APARADOR-LZ-' + $version + '-source.zip'
& git -C $repositoryRoot archive --format=zip ('--prefix=APARADOR-LZ-' + $version + '/') ('--output=' + (Join-Path $output $applicationSourceName)) $SourceCommit
Assert-Release ($LASTEXITCODE -eq 0) 'Could not archive the exact application source commit.'

$releaseFiles = @()
foreach ($name in @($productionName, $sourceBundleName, $applicationSourceName)) {
    $releaseFiles += (Get-PublicFileMetadata (Join-Path $output $name) $name)
}
Assert-Release ((Get-Sha256 (Join-Path $output $productionName)) -eq (Get-Sha256 $productionInstaller)) 'Published installer copy differs from the tested build.'
$publicManifest = [ordered]@{
    Version=$version; Tag=$Tag; Repository=('https://github.com/' + $repository)
    SourceCommit=$SourceCommit.ToLowerInvariant(); WorkflowRun=$RunUrl; PreparedUtc=[DateTime]::UtcNow.ToString('o')
    Platform='Windows 10/11 x64 Intel/AMD'; OfflineMediaDependencies=$true
    RuntimePrerequisites=@('.NET Framework 4.8', 'Windows PowerShell 5.1 x64')
    AuthenticodeStatus=(Get-AuthenticodeSignature -FilePath (Join-Path $output $productionName)).Status.ToString()
    ByteForByteDeterministic=$false
    Engines=[ordered]@{
        NSIS=[ordered]@{Version=$manifest.NSISVersion;CompilerSHA256=$manifest.NSISSHA256.ToLowerInvariant()}
        FFmpeg=[ordered]@{Version=$dependencyLock.ffmpeg.version;SourceCommit=$dependencyLock.ffmpeg.commit}
        X264=[ordered]@{Version=$dependencyLock.x264.version;SourceCommit=$dependencyLock.x264.commit}
        X265=[ordered]@{Version=$dependencyLock.x265.version;SourceCommit=$dependencyLock.x265.commit}
        DependencyLockSHA256=(Get-Sha256 (Join-Path $PSScriptRoot 'dependencies.lock.json'))
    }
    Verification=[ordered]@{
        CompiledSelfTest=[ordered]@{Passed=$true;Assertions=@($selfTest.Assertions).Count}
        RealMedia=[ordered]@{Passed=$true;Assertions=@($media.Assertions).Count;ReportSHA256=(Get-Sha256 $mediaPath)}
        Installer=[ordered]@{Passed=$true;Assertions=@($installation.Assertions).Count;ReportSHA256=(Get-Sha256 $installerPath);Variant='Isolated TESTE; same runtime payload'}
    }
    Payload=$publicPayload; Files=$releaseFiles
    Limits='Automated checks do not replace visual/manual testing or certify all Windows versions, inputs, codecs, or absence of vulnerabilities. Raw reports and fixture videos are not published.'
}
$publicManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'RELEASE-MANIFEST.json') -Encoding UTF8
$checksums = foreach ($name in @($productionName, $sourceBundleName, $applicationSourceName, 'RELEASE-MANIFEST.json')) {
    (Get-Sha256 (Join-Path $output $name)) + '  ' + $name
}
$checksums | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ASCII
Write-Output ('Release prepared after successful verification: ' + $output)
Write-Output ('Installer checks: ' + @($installation.Assertions).Count + '; media checks: ' + @($media.Assertions).Count)
