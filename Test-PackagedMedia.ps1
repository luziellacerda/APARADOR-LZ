param([string]$AppRoot=(Join-Path $PSScriptRoot 'app'),[switch]$AllProfiles)
$ErrorActionPreference='Stop'
$runRoot=Join-Path $PSScriptRoot ('media-tests\'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $runRoot)
$exe=Join-Path $AppRoot 'APARADOR DE VIDEOS LZ-GAMES.exe'
$result=[ordered]@{Version='1.5.0';Passed=$false;RunRoot=$runRoot;ExeSHA256=(Get-FileHash -LiteralPath $exe).Hash;Assertions=@();Cases=@()}
$form=$null
function Assert-Packaged([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$result.Assertions+=,$Message}
try {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $assembly=[Reflection.Assembly]::LoadFrom($exe)
    $reader=New-Object IO.StreamReader($assembly.GetManifestResourceStream('LZGames.Backend.ps1'),[Text.Encoding]::UTF8)
    try{$backend=$reader.ReadToEnd()}finally{$reader.Dispose()}
    Assert-Packaged ($assembly.GetName().Version.ToString() -eq '1.5.0.0') 'Compiled assembly version is 1.5.0.0.'
    Assert-Packaged ($null -ne $assembly.GetType('LZGames.UI.Dashboard') -and $null -ne $assembly.GetType('LZGames.Safety.Paths')) 'UI and safety types are compiled in the EXE.'
    . ([scriptblock]::Create($backend)) -LoadOnly -RuntimeRoot $AppRoot -DataRoot (Join-Path $runRoot 'data')
    $ast=[Management.Automation.Language.Parser]::ParseInput($backend,[ref]$null,[ref]$null)
    $tick=$ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$timer' -and $n.Member.Extent.Text -eq 'add_Tick'},$true)[0].Arguments[0].ScriptBlock.GetScriptBlock()
    $fixture=Join-Path $runRoot 'fixture.mp4'
    & $script:Ffmpeg -hide_banner -loglevel error -f lavfi -i 'testsrc2=size=160x90:rate=30:duration=4' -f lavfi -i 'sine=frequency=700:duration=4' -c:v libx264 -preset ultrafast -crf 18 -c:a aac -shortest -movflags +faststart $fixture
    Assert-Packaged ($LASTEXITCODE -eq 0) 'Generated fixture with audio inside the isolated test directory.'
    $script:InputFolder=Join-Path $runRoot 'input'
    $originalOutput=Join-Path $runRoot 'output'
    $script:OutputFolder=$originalOutput
    $relativeFiles=@('raiz.mp4','PS4\Ação\shared.mp4','PS5\shared.mp4')
    $originalHashes=@{}
    foreach($relative in $relativeFiles){
        $target=Join-Path $script:InputFolder $relative
        [void](New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force)
        Copy-Item -LiteralPath $fixture -Destination $target
        $originalHashes[$relative]=(Get-FileHash -LiteralPath $target).Hash
    }
    function Run-PackagedBatch([string]$Name,[bool]$Trim,[decimal]$Start,[decimal]$End,[bool]$KeepAudio,[bool]$Overwrite,[int]$ExpectedCompleted,[int]$ExpectedSkipped,[double]$ExpectedDuration,[int]$ProfileIndex=3){
        $trimCheck.Checked=$Trim;$startNumeric.Value=$Start;$endNumeric.Value=$End
        $audioCheck.Checked=$KeepAudio;$overwriteCheck.Checked=$Overwrite
        $presetBox.SelectedIndex=$ProfileIndex;$resolutionBox.SelectedIndex=0;$fpsBox.SelectedIndex=0
        Refresh-VideoList
        Assert-Packaged ($grid.Rows.Count -eq 3) ($Name+': scanned all three videos recursively.')
        Start-Batch
        $deadline=[datetime]::UtcNow.AddSeconds(90)
        while($script:IsRunning -and [datetime]::UtcNow -lt $deadline){& $tick;[Threading.Thread]::Sleep(20)}
        Assert-Packaged (-not $script:IsRunning) ($Name+': batch finished before deadline.')
        Assert-Packaged ($script:Completed -eq $ExpectedCompleted -and $script:Skipped -eq $ExpectedSkipped -and $script:Failed -eq 0) ($Name+': expected completed/skipped counts; no errors.')
        foreach($relative in $relativeFiles){
            $output=Join-Path $script:OutputFolder $relative
            Assert-Packaged (Test-Path -LiteralPath $output -PathType Leaf) ($Name+': mirrored path '+$relative)
            $raw=& $script:Ffprobe -v error -show_entries stream=codec_type,duration -of json -- $output
            Assert-Packaged ($LASTEXITCODE -eq 0) ($Name+': output probe succeeds '+$relative)
            $probe=($raw -join "`n")|ConvertFrom-Json
            $video=@($probe.streams|Where-Object{$_.codec_type -eq 'video'})[0]
            $duration=[double]::Parse($video.duration,[Globalization.CultureInfo]::InvariantCulture)
            Assert-Packaged ([Math]::Abs($duration-$ExpectedDuration) -le 0.1) ($Name+': requested duration '+$relative)
            $audioCount=@($probe.streams|Where-Object{$_.codec_type -eq 'audio'}).Count
            Assert-Packaged (($KeepAudio -and $audioCount -gt 0) -or (-not $KeepAudio -and $audioCount -eq 0)) ($Name+': audio option '+$relative)
            & $script:Ffmpeg -v error -xerror -i $output -f null - 2>&1|Out-String|Out-Null
            Assert-Packaged ($LASTEXITCODE -eq 0) ($Name+': full output decode succeeds '+$relative)
        }
        Assert-Packaged (@(Get-ChildItem -LiteralPath $script:OutputFolder -File -Recurse -Force|Where-Object{$_.Name -like '*.partial.mp4'}).Count -eq 0) ($Name+': no unfinished temporary outputs.')
        $result.Cases+=,[pscustomobject]@{Name=$Name;Completed=$script:Completed;Skipped=$script:Skipped;Failed=$script:Failed;Log=$logBox.Text}
    }
    Run-PackagedBatch 'trim-nested-silent' $true 0.5 2.25 $false $false 3 0 1.75
    $oldResults=@{}
    foreach($relative in $relativeFiles){$oldResults[$relative]=(Get-FileHash -LiteralPath (Join-Path $originalOutput $relative)).Hash}
    Run-PackagedBatch 'preserve-existing' $true 1 2 $false $false 0 3 1.75
    foreach($relative in $relativeFiles){Assert-Packaged ((Get-FileHash -LiteralPath (Join-Path $originalOutput $relative)).Hash -eq $oldResults[$relative]) ('Existing result unchanged: '+$relative)}
    Run-PackagedBatch 'overwrite-new-interval' $true 1 2 $false $true 3 0 1
    $script:OutputFolder=Join-Path $runRoot 'output-audio'
    Run-PackagedBatch 'whole-with-audio' $false 0 4 $true $false 3 0 4
    if($AllProfiles){
        foreach($profileIndex in 0..2){
            $script:OutputFolder=Join-Path $runRoot ('output-h265-'+$profileIndex)
            Run-PackagedBatch ('h265-profile-'+$profileIndex) $true 0.5 2.25 $true $false 3 0 1.75 $profileIndex
        }
    }
    foreach($relative in $relativeFiles){Assert-Packaged ((Get-FileHash -LiteralPath (Join-Path $script:InputFolder $relative)).Hash -eq $originalHashes[$relative]) ('Original unchanged: '+$relative)}
    $result.Passed=$true
} catch {$result.Error=$_.Exception.ToString();$result.Stack=$_.ScriptStackTrace;throw}
finally {
    if($form){if($script:CurrentProcess -and -not $script:CurrentProcess.HasExited){$script:CurrentProcess.Kill();[void]$script:CurrentProcess.WaitForExit(5000)};if($script:InputLease){$script:InputLease.Dispose()};$form.Dispose()}
    $result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $runRoot 'result.json') -Encoding UTF8
    Write-Output ('Packaged media evidence: '+(Join-Path $runRoot 'result.json'))
}
if($result.Passed){Write-Output ('PACKAGED_MEDIA_PASS checks='+$result.Assertions.Count)}
