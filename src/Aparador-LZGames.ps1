[CmdletBinding()]
param(
    [switch]$SmokeTest,
    [string]$DiagnosticLog,
    [switch]$LoadOnly,
    [string]$RuntimeRoot,
    [string]$DataRoot,
    [switch]$SelfTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { throw 'A pasta do aplicativo precisa ser fornecida pelo executável.' }
if ([string]::IsNullOrWhiteSpace($DataRoot)) { $DataRoot=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'LZ Games' }
$script:AppRoot = [IO.Path]::GetFullPath($RuntimeRoot)
$script:DataRoot = [IO.Path]::GetFullPath($DataRoot)
if ($SelfTest -and (Test-Path -LiteralPath $script:DataRoot)) { throw 'O autoteste exige uma pasta de dados nova, para não tocar em arquivos existentes.' }
$script:Ffmpeg = Join-Path $script:AppRoot 'bin\ffmpeg.exe'
$script:Ffprobe = Join-Path $script:AppRoot 'bin\ffprobe.exe'
$script:InputFolder = Join-Path $script:DataRoot 'VIDEOS_ORIGINAIS'
$script:OutputFolder = Join-Path $script:DataRoot 'RECORTADOS_LZGAMES'
$script:CurrentProcess = $null
$script:CurrentRow = $null
$script:CurrentOutput = $null
$script:CurrentTemporaryOutput = $null
$script:BatchOutputs = @{}
$script:Queue = New-Object System.Collections.Queue
$script:CurrentCollector = $null
$script:IsRunning = $false
$script:CancelRequested = $false
$script:Completed = 0
$script:Failed = 0
$script:Skipped = 0
$script:TotalInputBytes = [int64]0
$script:TotalOutputBytes = [int64]0
$script:CurrentDuration = 1.0
$script:StartedAt = $null
$script:LastFfmpegError = ''
$script:CurrentStage = ''
$script:CurrentInfo = $null
$script:InputLease = $null
$script:BatchInputs = @{}
$script:BatchOriginalIds = @{}
$script:OriginalIdentities = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$script:ResolvedOutputFolder = $null
$script:OutputFolderIdentity = $null
$script:CloseAfterCancel = $false
$script:TickBusy = $false
$script:BatchTrim = $null
$script:CurrentTrimDuration = $null
$script:RelativePaths = @{}
$script:CurrentOutputDirectory = $null

$script:Colors = @{
    Background = [System.Drawing.Color]::FromArgb(15, 18, 26)
    Surface    = [System.Drawing.Color]::FromArgb(24, 29, 40)
    Surface2   = [System.Drawing.Color]::FromArgb(32, 39, 53)
    Border     = [System.Drawing.Color]::FromArgb(54, 64, 82)
    Text       = [System.Drawing.Color]::FromArgb(239, 243, 248)
    Muted      = [System.Drawing.Color]::FromArgb(157, 169, 187)
    Accent     = [System.Drawing.Color]::FromArgb(50, 205, 120)
    AccentDark = [System.Drawing.Color]::FromArgb(29, 151, 84)
    Blue       = [System.Drawing.Color]::FromArgb(64, 142, 255)
    Warning    = [System.Drawing.Color]::FromArgb(255, 184, 77)
    Danger     = [System.Drawing.Color]::FromArgb(242, 91, 91)
}

function Format-Bytes([int64]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Quote-Arg([string]$Value) {
    return '"' + ($Value -replace '"', '\"') + '"'
}

function ConvertTo-MediaNumber($Value) {
    $number = 0.0
    if ([double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number) -and -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) { return $number }
    return 0.0
}

function Read-VideoMetadata([string]$Json) {
    $probe = $Json | ConvertFrom-Json
    $streams = @($probe.streams | Where-Object { $_.codec_type -eq 'video' })
    if ($streams.Count -eq 0) { throw 'O arquivo não contém um fluxo de vídeo.' }
    $stream = $streams[0]
    if ([int]$stream.width -le 0 -or [int]$stream.height -le 0) { throw 'As dimensões do vídeo são inválidas.' }
    $duration = 0.0
    if ($stream.PSObject.Properties['duration']) { $duration = ConvertTo-MediaNumber $stream.duration }
    $fps = 0.0
    if ($stream.PSObject.Properties['avg_frame_rate'] -and [string]$stream.avg_frame_rate -match '^(\d+)/(\d+)$' -and [double]$Matches[2] -gt 0) { $fps = [double]$Matches[1] / [double]$Matches[2] }
    return [pscustomobject]@{ Duration=$duration; Fps=$fps; Width=[int]$stream.width; Height=[int]$stream.height; ReliableDuration=($duration -gt 0) }
}

function Start-MediaProcess([string]$Stage, [string]$Executable, [string]$Arguments, [int]$TimeoutMilliseconds=30000, [bool]$Timeline=$false) {
    $script:CurrentStage = $Stage
    $script:LastFfmpegError = ''
    $script:CurrentProcess = [LZGames.Safety.MediaProcess]::Start($Executable, $Arguments, $TimeoutMilliseconds, $Timeline)
    $script:CurrentCollector = $script:CurrentProcess
}

function Start-MetadataProbe([string]$Stage, [string]$Path) {
    $arguments = '-v error -select_streams v:0 -show_entries stream=codec_type,width,height,avg_frame_rate,duration -of json -- ' + (Quote-Arg $Path)
    Start-MediaProcess $Stage $script:Ffprobe $arguments
}

function Assert-SafeDestination {
    $folder = [LZGames.Safety.Paths]::Inspect($script:ResolvedOutputFolder)
    if ($folder.Id -ne $script:OutputFolderIdentity) { throw 'A pasta de saída mudou durante o processamento. O resultado não foi publicado.' }
    $relativeOutput = [LZGames.Safety.Paths]::RelativePath($script:ResolvedOutputFolder,$script:CurrentOutput)
    $relativeDirectory = [System.IO.Path]::GetDirectoryName($relativeOutput)
    $script:CurrentOutputDirectory = [LZGames.Safety.Paths]::EnsureSafeDirectory($script:ResolvedOutputFolder,$relativeDirectory,$true)
    $script:CurrentOutput = Join-Path $script:CurrentOutputDirectory ([System.IO.Path]::GetFileName($relativeOutput))
    if (Test-Path -LiteralPath $script:CurrentOutput) {
        if ((Get-Item -LiteralPath $script:CurrentOutput -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'O arquivo de saída é um link. Ele foi preservado; escolha outro destino.' }
        $destination = [LZGames.Safety.Paths]::Inspect($script:CurrentOutput)
        if ($script:OriginalIdentities.Contains($destination.Id)) { throw 'O destino aponta para um vídeo original (atalho, link ou mesmo arquivo). Escolha outra pasta de saída.' }
        foreach ($sourcePath in $script:BatchInputs.Values) {
            if ((Test-Path -LiteralPath $sourcePath) -and ([LZGames.Safety.Paths]::Inspect($sourcePath)).Id -eq $destination.Id) { throw 'O destino passou a apontar para um dos vídeos originais. Ele foi preservado.' }
        }
    }
}

function Remove-CurrentTemporaryOutput {
    if ($script:CurrentTemporaryOutput) {
        $temporaryPath = $script:CurrentTemporaryOutput
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction Stop
        }
        $script:CurrentTemporaryOutput = $null
    }
}

function Test-EncodedDuration($Metadata) {
    if ($Metadata.Duration -le 0) { throw 'O resultado não contém uma duração de vídeo válida.' }
    $sourceFrame = if ($script:CurrentInfo.Fps -gt 0) { 1.0/$script:CurrentInfo.Fps } else { 0.1 }
    $outputFrame = if ($Metadata.Fps -gt 0) { 1.0/$Metadata.Fps } else { 0.1 }
    # Two frame periods accommodate rounding, seek boundaries and VFR tails;
    # do not scale tolerance with movie length, which would hide missing minutes.
    $tolerance = [Math]::Max(0.15, [Math]::Min(1.0, 2.0*[Math]::Max($sourceFrame,$outputFrame)))
    if ([Math]::Abs($Metadata.Duration-$script:CurrentDuration) -gt $tolerance) {
        throw ('A duração do resultado ({0:N3}s) difere do trecho esperado ({1:N3}s). O arquivo anterior foi preservado.' -f $Metadata.Duration,$script:CurrentDuration)
    }
}

function Publish-CurrentVideo {
    Assert-SafeDestination
    if (Test-Path -LiteralPath $script:CurrentOutput) {
        if (-not $overwriteCheck.Checked) {
            throw 'O destino passou a existir durante a compactação. Ele foi preservado.'
        }
        try {
            [System.IO.File]::Replace($script:CurrentTemporaryOutput, $script:CurrentOutput, [System.Management.Automation.Language.NullString]::Value, $true)
        } catch {
            throw "Não foi possível substituir o resultado com segurança. O arquivo anterior foi preservado. $($_.Exception.Message)"
        }
    } else {
        [System.IO.File]::Move($script:CurrentTemporaryOutput, $script:CurrentOutput)
    }
    $script:CurrentTemporaryOutput = $null
}

function New-Label([string]$Text, [float]$Size = 9, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $Size, $Style)
    $label.ForeColor = $script:Colors.Text
    $label.AutoSize = $true
    return $label
}

function Style-Button($Button, [System.Drawing.Color]$Color) {
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $Color
    $Button.ForeColor = [System.Drawing.Color]::White
    $Button.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function Style-Input($Control) {
    $Control.BackColor = $script:Colors.Surface2
    $Control.ForeColor = $script:Colors.Text
    $Control.Font = New-Object System.Drawing.Font('Segoe UI', 9)
}

function Set-Status([string]$Text, [System.Drawing.Color]$Color) {
    $statusLabel.Text = $Text
    $statusLabel.ForeColor = $Color
}

function Add-Log([string]$Text) {
    $stamp = Get-Date -Format 'HH:mm:ss'
    $logBox.AppendText("[$stamp] $Text`r`n")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Update-Summary {
    $sourceBytes = [int64]0
    foreach ($row in $grid.Rows) {
        if (-not $row.IsNewRow -and $row.Tag) { $sourceBytes += [int64]$row.Tag.Length }
    }
    $form.UpdateQueueState($grid.Rows.Count)
    $inputCardValue.Text = Format-Bytes $sourceBytes
    if ($script:TotalOutputBytes -gt 0 -and $script:TotalInputBytes -gt 0) {
        $saved = [Math]::Max(0, $script:TotalInputBytes - $script:TotalOutputBytes)
        $percent = 100.0 * $saved / $script:TotalInputBytes
        $savingCardValue.Text = ('{0:N0}%  ({1})' -f $percent, (Format-Bytes $saved))
    } else {
        $savingCardValue.Text = '--'
    }
}

function Refresh-VideoList {
    if ($script:IsRunning) { return }
    $grid.Rows.Clear()
    if (-not (Test-Path -LiteralPath $script:InputFolder)) {
        [void](New-Item -ItemType Directory -Path $script:InputFolder -Force)
    }
    if (-not (Test-Path -LiteralPath $script:OutputFolder)) {
        [void](New-Item -ItemType Directory -Path $script:OutputFolder -Force)
    }

    $extensions = @('.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v')
    $script:RelativePaths = @{}
    $found = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    $physicalInput = [LZGames.Safety.Paths]::Inspect($script:InputFolder)
    $physicalOutput = [LZGames.Safety.Paths]::Inspect($script:OutputFolder)
    $excludeOutput = $physicalInput.Id -ne $physicalOutput.Id -and [LZGames.Safety.Paths]::IsWithin($physicalInput.Path,$physicalOutput.Path)
    $folders = New-Object 'System.Collections.Generic.Stack[string]'
    $folders.Push($physicalInput.Path)
    $skippedLinks = 0
    while ($folders.Count -gt 0) {
        $currentFolder=$folders.Pop()
        if ($excludeOutput -and [LZGames.Safety.Paths]::IsWithin($physicalOutput.Path,$currentFolder)) { continue }
        try { $items=@(Get-ChildItem -LiteralPath $currentFolder -Force -ErrorAction Stop) }
        catch { Add-Log "Pasta não lida: $currentFolder. $($_.Exception.Message)"; continue }
        foreach ($item in $items) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { $skippedLinks++; continue }
            if ($item.PSIsContainer) { $folders.Push($item.FullName); continue }
            if ($extensions -contains $item.Extension.ToLowerInvariant()) {
                $script:RelativePaths[$item.FullName]=[LZGames.Safety.Paths]::RelativePath($physicalInput.Path,$item.FullName)
                $found.Add([System.IO.FileInfo]$item)
            }
        }
    }
    $files = @($found | Sort-Object { $script:RelativePaths[$_.FullName] })
    foreach ($file in $files) {
        $index = $grid.Rows.Add('Pronto', $script:RelativePaths[$file.FullName], (Format-Bytes $file.Length), '--', '--')
        $grid.Rows[$index].Tag = $file
        $grid.Rows[$index].Cells[0].Style.ForeColor = $script:Colors.Blue
    }
    $inputPathBox.Text = $script:InputFolder
    $outputPathBox.Text = $script:OutputFolder
    Update-Summary
    if ($skippedLinks -gt 0) { Add-Log "$skippedLinks link(s)/junction(s) ignorado(s) para evitar loops e arquivos fora da origem." }
    $readyText = if ($files.Count -gt 0) { "$($files.Count) vídeo(s) pronto(s), incluindo subpastas" } else { 'Adicione vídeos na pasta de entrada ou nas subpastas' }
    Set-Status $readyText $script:Colors.Muted
}

function Get-EncodingProfile {
    switch ($presetBox.SelectedIndex) {
        0 { return @{ Codec='libx265'; Crf='28'; Preset='medium'; Label='Ultra compacto (H.265)' } }
        1 { return @{ Codec='libx265'; Crf='24'; Preset='medium'; Label='Equilibrado (H.265)' } }
        2 { return @{ Codec='libx265'; Crf='20'; Preset='slow'; Label='Alta qualidade (H.265)' } }
        3 { return @{ Codec='libx264'; Crf='23'; Preset='medium'; Label='Compatível (H.264)' } }
        default { return @{ Codec='libx265'; Crf='24'; Preset='medium'; Label='Equilibrado (H.265)' } }
    }
}

function Build-FfmpegArguments([System.IO.FileInfo]$File, [string]$OutputPath) {
    $profile = Get-EncodingProfile
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('-hide_banner')
    $parts.Add('-loglevel'); $parts.Add('error')
    $parts.Add('-nostdin')
    $parts.Add('-xerror')
    $parts.Add('-y')
    if ($script:BatchTrim -and $script:BatchTrim.Enabled -and $script:BatchTrim.Start -gt 0) {
        $parts.Add('-ss'); $parts.Add(([decimal]$script:BatchTrim.Start).ToString([System.Globalization.CultureInfo]::InvariantCulture))
    }
    $parts.Add('-err_detect'); $parts.Add('explode')
    $inputPath = if ($script:BatchInputs.ContainsKey($File.FullName)) { $script:BatchInputs[$File.FullName] } else { $File.FullName }
    $parts.Add('-i'); $parts.Add((Quote-Arg $inputPath))
    if ($script:BatchTrim -and $script:BatchTrim.Enabled) {
        $trimDuration = if ($null -ne $script:CurrentTrimDuration) { [decimal]$script:CurrentTrimDuration } else { [decimal]$script:BatchTrim.End-[decimal]$script:BatchTrim.Start }
        if ($trimDuration -le 0) { throw 'O fim do recorte precisa ser maior que o começo.' }
        $parts.Add('-t'); $parts.Add($trimDuration.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    }
    $parts.Add('-map'); $parts.Add('0:v:0')

    $filters = New-Object System.Collections.Generic.List[string]
    switch ($resolutionBox.SelectedIndex) {
        0 { $filters.Add('pad=ceil(iw/2)*2:ceil(ih/2)*2') }
        1 { $filters.Add("scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease"); $filters.Add("scale='trunc(iw/2)*2':'trunc(ih/2)*2'") }
        2 { $filters.Add("scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease"); $filters.Add("scale='trunc(iw/2)*2':'trunc(ih/2)*2'") }
        3 { $filters.Add("scale='min(854,iw)':'min(480,ih)':force_original_aspect_ratio=decrease"); $filters.Add("scale='trunc(iw/2)*2':'trunc(ih/2)*2'") }
    }
    $sourceFps = if ($script:CurrentInfo) { $script:CurrentInfo.Fps } else { 0.0 }
    switch ($fpsBox.SelectedIndex) {
        1 { if ($sourceFps -le 0 -or $sourceFps -gt 60.01) { $filters.Add('fps=60') } }
        2 { if ($sourceFps -le 0 -or $sourceFps -gt 30.01) { $filters.Add('fps=30') } }
        3 { if ($sourceFps -le 0 -or $sourceFps -gt 24.01) { $filters.Add('fps=24') } }
    }
    if ($filters.Count -gt 0) {
        $parts.Add('-vf'); $parts.Add((Quote-Arg ([string]::Join(',', $filters))))
    }

    $parts.Add('-c:v'); $parts.Add($profile.Codec)
    $parts.Add('-preset'); $parts.Add($profile.Preset)
    $parts.Add('-crf'); $parts.Add($profile.Crf)
    if ($profile.Codec -eq 'libx265') { $parts.Add('-tag:v'); $parts.Add('hvc1') }
    $parts.Add('-pix_fmt'); $parts.Add('yuv420p')

    if ($audioCheck.Checked) {
        $parts.Add('-map'); $parts.Add('0:a?')
        $parts.Add('-c:a'); $parts.Add('aac')
        $parts.Add('-b:a'); $parts.Add(([string]$audioBitrateBox.SelectedItem))
    } else {
        $parts.Add('-an')
    }
    $parts.Add('-movflags'); $parts.Add('+faststart')
    $parts.Add('-progress'); $parts.Add('pipe:1')
    $parts.Add('-nostats')
    $parts.Add((Quote-Arg $OutputPath))
    return [string]::Join(' ', $parts)
}

function Set-ControlsEnabled([bool]$Enabled) {
    $startButton.Enabled = $Enabled
    $refreshButton.Enabled = $Enabled
    $inputBrowseButton.Enabled = $Enabled
    $outputBrowseButton.Enabled = $Enabled
    $presetBox.Enabled = $Enabled
    $resolutionBox.Enabled = $Enabled
    $fpsBox.Enabled = $Enabled
    $audioCheck.Enabled = $Enabled
    $audioBitrateBox.Enabled = $Enabled -and $audioCheck.Checked
    $trimCheck.Enabled = $Enabled
    $startNumeric.Enabled = $Enabled -and $trimCheck.Checked
    $endNumeric.Enabled = $Enabled -and $trimCheck.Checked
    $overwriteCheck.Enabled = $Enabled
    $cancelButton.Enabled = -not $Enabled
}

function Finish-Batch {
    $script:IsRunning = $false
    $timer.Stop()
    Set-ControlsEnabled $true
    if (-not $script:CancelRequested) {
        $overallProgress.Value = 100
        $fileProgress.Value = 100
    }
    Update-Summary
    $elapsed = if ($script:StartedAt) { (Get-Date) - $script:StartedAt } else { [TimeSpan]::Zero }
    if ($script:CancelRequested) {
        foreach ($pendingRow in $script:Queue) {
            $pendingRow.Cells[0].Value = 'Cancelado'
            $pendingRow.Cells[0].Style.ForeColor = $script:Colors.Warning
        }
        $script:Queue.Clear()
        Set-Status 'Processamento cancelado' $script:Colors.Warning
        Add-Log 'Processamento cancelado pelo usuário.'
    } elseif ($script:Failed -gt 0) {
        Set-Status "Concluído com $($script:Failed) erro(s)" $script:Colors.Warning
        Add-Log ("Fila concluída em {0:mm\:ss}. Sucesso: {1}; falhas: {2}; ignorados: {3}." -f $elapsed, $script:Completed, $script:Failed, $script:Skipped)
    } elseif ($script:Completed -eq 0) {
        Set-Status ("Nenhum vídeo refeito: {0} existente(s). Para refazer, ative Substituir em Pastas." -f $script:Skipped) $script:Colors.Warning
        Add-Log ("Nenhum vídeo novo foi processado. {0} resultado(s) existente(s) preservado(s). Para aplicar outro recorte ou configuração, ative Substituir resultados na aba Pastas e execute novamente." -f $script:Skipped)
    } else {
        $completedMessage = if ($script:BatchTrim -and $script:BatchTrim.Enabled) { 'Recorte e compactação concluídos!' } else { 'Compactação concluída!' }
        Set-Status $completedMessage $script:Colors.Accent
        Add-Log ("Tudo pronto em {0:mm\:ss}. Processados: {1}; ignorados: {2}." -f $elapsed, $script:Completed, $script:Skipped)
        if ($script:Skipped -gt 0) { Add-Log 'Resultados existentes foram preservados. Para refazê-los com estas configurações, ative Substituir resultados na aba Pastas.' }
        [System.Media.SystemSounds]::Asterisk.Play()
    }
    if ($script:InputLease) { $script:InputLease.Dispose(); $script:InputLease=$null }
    if ($script:CloseAfterCancel) { $form.Close() }
}

function Start-NextVideo {
    if ($script:CancelRequested -or $script:Queue.Count -eq 0) { Finish-Batch; return }
    # One item per timer turn keeps long queues of skipped/error files cancellable.
    $row = $script:Queue.Dequeue()
    $file = [System.IO.FileInfo]$row.Tag
    $script:CurrentRow = $row
    $script:CurrentOutput = [string]$script:BatchOutputs[$file.FullName]
    $script:CurrentTemporaryOutput = $null
    $script:CurrentInfo = $null
    $script:CurrentTrimDuration = $null
    try {
        Assert-SafeDestination
        if ((Test-Path -LiteralPath $script:CurrentOutput) -and -not $overwriteCheck.Checked) {
            Finish-CurrentVideo 'Ignorado' 'Resultado existente preservado. Para aplicar o novo recorte ou configuração, ative Substituir resultados na aba Pastas e execute novamente.'
            return
        }
        $sourcePath = [string]$script:BatchInputs[$file.FullName]
        $script:InputLease = [LZGames.Safety.Paths]::OpenReadLease($sourcePath)
        if (([LZGames.Safety.Paths]::Inspect($sourcePath)).Id -ne $script:BatchOriginalIds[$file.FullName]) { throw 'O vídeo original mudou desde o início da fila. Atualize a lista e tente novamente.' }
        $file.Refresh()
        $row.Cells[0].Value = 'Analisando'
        $row.Cells[0].Style.ForeColor = $script:Colors.Blue
        $grid.CurrentCell = $row.Cells[0]
        $fileProgress.Value = 0
        Set-Status "Analisando: $($file.Name)" $script:Colors.Blue
        Start-MetadataProbe 'InputProbe' $sourcePath
    } catch {
        Finish-CurrentVideo 'Erro' $_.Exception.Message
    }
}

function Start-CurrentEncoding {
    $file = [System.IO.FileInfo]$script:CurrentRow.Tag
    $sourceDuration = [double]$script:CurrentInfo.Duration
    if ($sourceDuration -le 0) { throw 'Não foi possível determinar a duração real do fluxo de vídeo.' }
    if ($script:BatchTrim -and $script:BatchTrim.Enabled) {
        $trimStart=[double]$script:BatchTrim.Start
        $requestedEnd=[double]$script:BatchTrim.End
        if ($requestedEnd -le $trimStart) { throw 'O fim do recorte precisa ser maior que o começo.' }
        if ($trimStart -ge $sourceDuration) { throw ('O começo do recorte ({0:N3}s) precisa ser menor que a duração do vídeo ({1:N3}s).' -f $trimStart,$sourceDuration) }
        $effectiveEnd=[Math]::Min($requestedEnd,$sourceDuration)
        $script:CurrentDuration=$effectiveEnd-$trimStart
        $script:CurrentTrimDuration=$script:CurrentDuration
        if ($requestedEnd -gt $sourceDuration) { Add-Log ('Fim solicitado {0:N3}s ultrapassa este vídeo; usando o fim real em {1:N3}s.' -f $requestedEnd,$sourceDuration) }
        Add-Log ('Recorte de {0}: começo {1:N3}s → fim {2:N3}s; duração {3:N3}s.' -f $file.Name,$trimStart,$effectiveEnd,$script:CurrentDuration)
    } else { $script:CurrentDuration = $sourceDuration }
    Assert-SafeDestination
    $temporaryPath = Join-Path $script:CurrentOutputDirectory ('.lzgames-'+[guid]::NewGuid().ToString('N')+'.partial.mp4')
    $reservation = [System.IO.File]::Open($temporaryPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    $reservation.Dispose()
    $script:CurrentTemporaryOutput = $temporaryPath
    $action = if ($script:BatchTrim -and $script:BatchTrim.Enabled) { 'Recortando' } else { 'Compactando' }
    $script:CurrentRow.Cells[0].Value = $action
    $script:CurrentRow.Cells[0].Style.ForeColor = $script:Colors.Accent
    Set-Status "${action}: $($file.Name)" $script:Colors.Accent
    Add-Log "Iniciando: $($file.Name) → $([System.IO.Path]::GetFileName($script:CurrentOutput))"
    Start-MediaProcess 'Encode' $script:Ffmpeg (Build-FfmpegArguments $file $temporaryPath) 0
}

function Finish-CurrentVideo([string]$Outcome,[string]$Detail='') {
    $row = $script:CurrentRow
    $file = [System.IO.FileInfo]$row.Tag
    $row.Cells[0].Value = $Outcome
    switch ($Outcome) {
        'Concluído' {
            $outputFile = Get-Item -LiteralPath $script:CurrentOutput
            $reduction = if ($file.Length -gt 0) { 100.0*(1.0-$outputFile.Length/[double]$file.Length) } else { 0 }
            $row.Cells[0].Style.ForeColor=$script:Colors.Accent
            $row.Cells[3].Value=Format-Bytes $outputFile.Length
            $row.Cells[4].Value=('{0:N0}%' -f $reduction)
            $row.Cells[4].Style.ForeColor=if($reduction -ge 0){$script:Colors.Accent}else{$script:Colors.Warning}
            $script:Completed++;$script:TotalInputBytes+=$file.Length;$script:TotalOutputBytes+=$outputFile.Length
            Add-Log ("Concluído: {0} • {1} → {2} ({3:N0}% de redução)" -f $file.Name,(Format-Bytes $file.Length),(Format-Bytes $outputFile.Length),$reduction)
        }
        'Ignorado' { $script:Skipped++;$row.Cells[0].Style.ForeColor=$script:Colors.Warning;Add-Log "Ignorado: $($file.Name). $Detail" }
        'Cancelado' { $row.Cells[0].Style.ForeColor=$script:Colors.Warning }
        default { $script:Failed++;$row.Cells[0].Style.ForeColor=$script:Colors.Danger;Add-Log "Erro em $($file.Name): $Detail" }
    }
    try { Remove-CurrentTemporaryOutput } catch { Add-Log "Não foi possível remover o temporário: $($_.Exception.Message)" }
    if ($script:InputLease) { $script:InputLease.Dispose();$script:InputLease=$null }
    $script:CurrentRow=$null
    $script:CurrentStage=''
    $processed=$script:Completed+$script:Failed+$script:Skipped
    $overallProgress.Value=[Math]::Min(100,[int](100*$processed/[Math]::Max(1,$grid.Rows.Count)))
    Update-Summary
}

function Complete-MediaStage($Job,[string]$Stage) {
    switch ($Stage) {
        'InputProbe' {
            $script:CurrentInfo=Read-VideoMetadata $Job.Text
            if ($script:CurrentInfo.Duration -gt 0) { Start-CurrentEncoding } else {
                $sourcePath=$script:BatchInputs[([System.IO.FileInfo]$script:CurrentRow.Tag).FullName]
                $arguments='-v error -select_streams v:0 -show_packets -show_entries packet=pts_time,duration_time -of csv=p=0 -- '+(Quote-Arg $sourcePath)
                Start-MediaProcess 'InputTimeline' $script:Ffprobe $arguments 60000 $true
            }
        }
        'InputTimeline' {
            if ($Job.PacketCount -eq 0 -or $Job.TimelineDuration -le 0 -or [double]::IsInfinity($Job.TimelineDuration)) { throw 'O fluxo de vídeo não contém uma linha de tempo válida.' }
            $script:CurrentInfo.Duration=$Job.TimelineDuration
            Start-CurrentEncoding
        }
        'Encode' {
            if (-not (Test-Path -LiteralPath $script:CurrentTemporaryOutput) -or (Get-Item -LiteralPath $script:CurrentTemporaryOutput).Length -eq 0) { throw 'A compactação não gerou um vídeo válido.' }
            $script:CurrentRow.Cells[0].Value='Verificando'
            Set-Status 'Verificando duração e integridade do resultado...' $script:Colors.Blue
            Start-MetadataProbe 'OutputProbe' $script:CurrentTemporaryOutput
        }
        'OutputProbe' {
            Test-EncodedDuration (Read-VideoMetadata $Job.Text)
            $arguments='-hide_banner -nostdin -v error -xerror -err_detect explode -i '+(Quote-Arg $script:CurrentTemporaryOutput)+' -map 0:v:0 -map 0:a? -progress pipe:1 -nostats -f null -'
            $script:ValidatedFrames=0
            Start-MediaProcess 'Validate' $script:Ffmpeg $arguments 120000
        }
        'Validate' {
            if ($script:ValidatedFrames -le 0) { throw 'O resultado não contém quadros de vídeo decodificáveis.' }
            Publish-CurrentVideo
            Finish-CurrentVideo 'Concluído'
        }
        default { throw 'Etapa de processamento inválida.' }
    }
}

function Start-Batch {
    if ($script:IsRunning) { return }
    [decimal]$trimStart=0
    [decimal]$trimEnd=0
    [string]$trimError=''
    if (-not $form.TryGetTrimRange([ref]$trimStart,[ref]$trimEnd,[ref]$trimError)) {
        [System.Windows.Forms.MessageBox]::Show($trimError,'Verifique o recorte','OK','Warning') | Out-Null
        return
    }
    # Capture committed values once. Encoding never reads editable trim controls.
    $script:BatchTrim=[pscustomobject]@{Enabled=[bool]$trimCheck.Checked;Start=$trimStart;End=$trimEnd}
    $script:CurrentTrimDuration=$null
    if ($grid.Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Nenhum vídeo foi encontrado na pasta de entrada.', 'LZ Games', 'OK', 'Information') | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $script:Ffmpeg) -or -not (Test-Path -LiteralPath $script:Ffprobe)) {
        [System.Windows.Forms.MessageBox]::Show('ffmpeg.exe ou ffprobe.exe não foi encontrado na pasta do programa.', 'Arquivo ausente', 'OK', 'Error') | Out-Null
        return
    }
    try {
        $inputDirectory = [System.IO.Path]::GetFullPath($script:InputFolder).TrimEnd([char[]]'\/')
        $outputDirectory = [System.IO.Path]::GetFullPath($script:OutputFolder).TrimEnd([char[]]'\/')
        if ([string]::Equals($inputDirectory, $outputDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Escolha uma pasta de saída diferente da pasta de entrada para proteger seus vídeos originais.'
        }
        [void](New-Item -ItemType Directory -Path $script:OutputFolder -Force)
        $physicalInput = [LZGames.Safety.Paths]::Inspect($script:InputFolder)
        $physicalOutput = [LZGames.Safety.Paths]::Inspect($script:OutputFolder)
        if ($physicalInput.Id -eq $physicalOutput.Id) { throw 'Entrada e saída apontam para a mesma pasta física, inclusive por link ou atalho. Escolha outra pasta de saída.' }
        $script:ResolvedOutputFolder = $physicalOutput.Path
        $script:OutputFolderIdentity = $physicalOutput.Id
        $script:BatchOutputs = @{}
        $script:BatchInputs = @{}
        $script:BatchOriginalIds = @{}
        $script:OriginalIdentities.Clear()
        $baseNameCounts = @{}
        foreach ($row in $grid.Rows) {
            $sourceFile = [System.IO.FileInfo]$row.Tag
            $sourceFile.Refresh()
            $sourceRelative = [LZGames.Safety.Paths]::RelativePath($physicalInput.Path,$sourceFile.FullName)
            $relativeDirectory = [System.IO.Path]::GetDirectoryName($sourceRelative)
            [void][LZGames.Safety.Paths]::EnsureSafeDirectory($physicalInput.Path,$relativeDirectory,$false)
            if ($sourceFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Um vídeo da fila passou a ser um link. Atualize a lista antes de processar.' }
            $physicalSource = [LZGames.Safety.Paths]::Inspect($sourceFile.FullName)
            if (-not [LZGames.Safety.Paths]::IsWithin($physicalInput.Path,$physicalSource.Path)) { throw 'Um vídeo da fila está fora da pasta física de origem. Atualize a lista.' }
            $script:RelativePaths[$sourceFile.FullName] = $sourceRelative
            $script:BatchInputs[$sourceFile.FullName] = $physicalSource.Path
            $script:BatchOriginalIds[$sourceFile.FullName] = $physicalSource.Id
            [void]$script:OriginalIdentities.Add($physicalSource.Id)
            $collisionKey = $relativeDirectory+'\'+$sourceFile.BaseName
            if ($baseNameCounts.ContainsKey($collisionKey)) { $baseNameCounts[$collisionKey]++ } else { $baseNameCounts[$collisionKey] = 1 }
        }
        $reservedNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $grid.Rows) {
            $file = [System.IO.FileInfo]$row.Tag
            $relativeDirectory = [System.IO.Path]::GetDirectoryName([string]$script:RelativePaths[$file.FullName])
            $baseName = $file.BaseName
            $collisionKey = $relativeDirectory+'\'+$baseName
            if ($baseNameCounts[$collisionKey] -gt 1) { $baseName += '_' + $file.Extension.TrimStart('.') }
            $outputName = $baseName + '.mp4'
            $relativeOutput = if ($relativeDirectory) { Join-Path $relativeDirectory $outputName } else { $outputName }
            $suffix = 2
            while (-not $reservedNames.Add($relativeOutput)) {
                $outputName = $baseName + '_' + $suffix + '.mp4'
                $relativeOutput = if ($relativeDirectory) { Join-Path $relativeDirectory $outputName } else { $outputName }
                $suffix++
            }
            $script:BatchOutputs[$file.FullName] = Join-Path $script:ResolvedOutputFolder $relativeOutput
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Verifique as pastas', 'OK', 'Warning') | Out-Null
        return
    }
    $script:Queue.Clear()
    foreach ($row in $grid.Rows) {
        if (-not $row.IsNewRow) {
            $row.Cells[0].Value = 'Na fila'
            $row.Cells[0].Style.ForeColor = $script:Colors.Muted
            $row.Cells[3].Value = '--'
            $row.Cells[4].Value = '--'
            $script:Queue.Enqueue($row)
        }
    }
    $script:IsRunning = $true
    $script:CancelRequested = $false
    $script:CloseAfterCancel = $false
    $script:Completed = 0
    $script:Failed = 0
    $script:Skipped = 0
    $script:TotalInputBytes = [int64]0
    $script:TotalOutputBytes = [int64]0
    $script:StartedAt = Get-Date
    $overallProgress.Value = 0
    $fileProgress.Value = 0
    $logBox.Clear()
    $profile = Get-EncodingProfile
    Add-Log "Perfil: $($profile.Label) | Áudio: $(if ($audioCheck.Checked) { 'mantido' } else { 'removido' })"
    if ($script:BatchTrim.Enabled) { Add-Log ('Recorte solicitado: começo {0:N3}s → fim {1:N3}s; duração {2:N3}s. Aplicado igualmente à fila, limitado ao fim de cada vídeo.' -f $script:BatchTrim.Start,$script:BatchTrim.End,($script:BatchTrim.End-$script:BatchTrim.Start)) }
    else { Add-Log 'Recorte desligado: será processado o vídeo inteiro.' }
    $existingCount = @($script:BatchOutputs.Values | Where-Object { Test-Path -LiteralPath $_ }).Count
    if (-not $overwriteCheck.Checked -and $existingCount -gt 0) {
        $existingNotice="$existingCount resultado(s) existente(s) serão ignorados. Para refazer, ative Substituir resultados em Pastas."
        Add-Log $existingNotice
        Set-Status $existingNotice $script:Colors.Warning
    }
    Set-ControlsEnabled $false
    $timer.Start()
    Start-NextVideo
}

$form = New-Object LZGames.UI.Dashboard
$grid = $form.grid
$filesCardValue = $form.filesCardValue
$inputCardValue = $form.inputCardValue
$savingCardValue = $form.savingCardValue
$statusLabel = $form.statusLabel
$logBox = $form.logBox
$fileProgress = $form.fileProgress
$overallProgress = $form.overallProgress
$inputPathBox = $form.inputPathBox
$outputPathBox = $form.outputPathBox
$startButton = $form.startButton
$cancelButton = $form.cancelAction
$refreshButton = $form.refreshButton
$inputBrowseButton = $form.inputBrowseButton
$outputBrowseButton = $form.outputBrowseButton
$openOutputButton = $form.openOutputButton
$helpButton = $form.helpAction
$audioCheck = $form.audioCheck
$trimCheck = $form.trimCheck
$overwriteCheck = $form.overwriteCheck
$startNumeric = $form.startNumeric
$endNumeric = $form.endNumeric
$presetBox = $form.presetBox
$resolutionBox = $form.resolutionBox
$fpsBox = $form.fpsBox
$audioBitrateBox = $form.audioBitrateBox

$audioCheck.add_CheckedChanged({ $audioBitrateBox.Enabled = $audioCheck.Checked -and -not $script:IsRunning })
$trimCheck.add_CheckedChanged({ $startNumeric.Enabled=$trimCheck.Checked -and -not $script:IsRunning; $endNumeric.Enabled=$trimCheck.Checked -and -not $script:IsRunning })
$refreshButton.add_Click({ Refresh-VideoList })
$startButton.add_Click({ Start-Batch })
$openOutputButton.add_Click({ [void](New-Item -ItemType Directory -Path $script:OutputFolder -Force); Start-Process explorer.exe -ArgumentList (Quote-Arg $script:OutputFolder) })

$inputBrowseButton.add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description='Escolha a pasta com os vídeos originais'; $dialog.SelectedPath=$script:InputFolder
    if ($dialog.ShowDialog() -eq 'OK') { $script:InputFolder=$dialog.SelectedPath; Refresh-VideoList }
})
$outputBrowseButton.add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description='Escolha onde salvar os vídeos compactados'; $dialog.SelectedPath=$script:OutputFolder
    if ($dialog.ShowDialog() -eq 'OK') { $script:OutputFolder=$dialog.SelectedPath; Refresh-VideoList }
})
$cancelButton.add_Click({
    $script:CancelRequested=$true
    if ($script:CurrentProcess -and -not $script:CurrentProcess.HasExited) {
        try { $script:CurrentProcess.Kill() } catch {}
    }
    $cancelButton.Enabled=$false
    Set-Status 'Cancelando…' $script:Colors.Warning
})
$helpButton.add_Click({
    $message = @"
COMO USAR

1. Escolha a pasta de origem. Os vídeos da pasta e de suas subpastas entram na fila; a mesma organização será criada na pasta de resultados.
2. Selecione o perfil. “Equilibrado” é a melhor escolha geral.
3. Desmarque “Manter áudio” para economizar ainda mais espaço.
4. Na aba Recorte, ative “Recortar um trecho” e informe COMEÇO e FIM em segundos. Exemplo: 7 e 22 salva do segundo 7 ao 22 (15 segundos). Desligado mantém o vídeo inteiro.
5. Clique em RECORTAR VÍDEOS quando o recorte estiver ligado, ou COMPACTAR VÍDEOS para processar os vídeos inteiros.
6. Resultados existentes são preservados. Para refazê-los com outro recorte, ative Substituir resultados na aba Pastas. A pasta de saída é excluída da leitura quando estiver dentro da origem; links e junctions são ignorados.

QUALIDADE
H.265 produz arquivos menores, mas aparelhos muito antigos podem não reproduzi-lo. Use H.264 para compatibilidade máxima. Não existe compactação drástica literalmente sem perda; os perfis foram ajustados para reduzir o tamanho com perda visual mínima ou imperceptível no uso comum.
"@
    [System.Windows.Forms.MessageBox]::Show($message,'Ajuda • LZ Games','OK','Information') | Out-Null
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
function Drain-MediaOutput {
    $line = $null
    while ($script:CurrentCollector -and $script:CurrentCollector.Output.TryDequeue([ref]$line)) {
        if ($script:CurrentStage -eq 'Encode' -and $line -match '^out_time_ms=(\d+)') {
            $seconds = [double]$Matches[1] / 1000000.0
            $percent = [Math]::Min(100, [Math]::Max(0, [int](100*$seconds/$script:CurrentDuration)))
            $fileProgress.Value=$percent
        }
        if ($script:CurrentStage -eq 'Validate' -and $line -match '^frame=(\d+)') { $script:ValidatedFrames=[int]$Matches[1] }
    }
    while ($script:CurrentCollector -and $script:CurrentCollector.Error.TryDequeue([ref]$line)) {
        if ($line) {
            if ($script:CurrentStage -ne 'Encode' -or $line -match '(?i)error|failed|invalid|cannot|unable|partial file|corrupt') { $script:LastFfmpegError=$line }
        }
    }
}

$timer.add_Tick({
    if ($script:TickBusy -or -not $script:IsRunning) { return }
    $script:TickBusy=$true
    try {
        if (-not $script:CurrentProcess) { Start-NextVideo; return }
        Drain-MediaOutput
        if (-not $script:CurrentProcess.HasExited) { return }
        $job=$script:CurrentProcess
        $stage=$script:CurrentStage
        # HasExited is published only after the worker waits for all callbacks.
        # Drain again to include lines that arrived between the first drain and it.
        Drain-MediaOutput
        $script:CurrentProcess=$null
        $script:CurrentCollector=$null
        try {
            if ($script:CancelRequested -or $job.Cancelled) { Finish-CurrentVideo 'Cancelado'; return }
            if ($job.TimedOut) { throw "Tempo limite na etapa $stage. O processo foi encerrado; tente outro arquivo ou disco." }
            if ($job.Failure) { throw $job.Failure }
            if ($job.ExitCode -ne 0 -or $script:LastFfmpegError) {
                $detail=if($script:LastFfmpegError){$script:LastFfmpegError}else{"O processo encerrou com código $($job.ExitCode)."}
                throw $detail
            }
            Complete-MediaStage $job $stage
        } catch {
            Finish-CurrentVideo 'Erro' $_.Exception.Message
        } finally {
            $job.Dispose()
        }
    } finally {
        $script:TickBusy=$false
    }
})

$form.add_FormClosing({
    $closingEventArgs = $_
    if ($script:IsRunning) {
        # A modal confirmation has its own message loop. Pause timer transitions
        # while it is open so completion cannot race the close/cancel decision.
        $timer.Stop()
        $choice=[System.Windows.Forms.MessageBox]::Show('Há uma compactação em andamento. Deseja cancelar e sair?','LZ Games','YesNo','Warning')
        if ($choice -ne 'Yes') { $closingEventArgs.Cancel=$true; $timer.Start(); return }
        $closingEventArgs.Cancel=$true
        $script:CancelRequested=$true
        $script:CloseAfterCancel=$true
        if ($script:CurrentProcess) { $script:CurrentProcess.Kill() }
        $cancelButton.Enabled=$false
        Set-Status 'Encerrando o processo e removendo o temporário...' $script:Colors.Warning
        $timer.Start()
    }
})

if ($SelfTest) {
    $selfTestResult=[ordered]@{Version='1.3.0';Passed=$false;TestedUtc=[DateTime]::UtcNow.ToString('o');RuntimeRoot=$script:AppRoot;DataRoot=$script:DataRoot;Mode='Embedded backend and compiled controls; no UI shown';Assertions=@()}
    function Assert-SelfTest([bool]$Condition,[string]$Description) {
        if (-not $Condition) { throw $Description }
        $selfTestResult.Assertions+=,$Description
    }
    try {
        [void][IO.Directory]::CreateDirectory($script:DataRoot)
        Assert-SelfTest ([LZGames.UI.Dashboard].Assembly -eq [LZGames.Safety.Paths].Assembly) 'Dashboard and safety code are compiled into one assembly.'
        Assert-SelfTest ((Test-Path -LiteralPath $script:Ffmpeg -PathType Leaf) -and (Test-Path -LiteralPath $script:Ffprobe -PathType Leaf)) 'FFmpeg and ffprobe are present.'
        Assert-SelfTest ($grid.Columns.Count -eq 5 -and $audioCheck.Checked -and -not $trimCheck.Checked -and -not $overwriteCheck.Checked) 'Safe UI defaults are preserved.'
        $trimCheck.Checked=$true
        [decimal]$rangeStart=0;[decimal]$rangeEnd=0;[string]$rangeError=$null
        $startNumeric.Text='7';$endNumeric.Text='22'
        Assert-SelfTest ($form.TryGetTrimRange([ref]$rangeStart,[ref]$rangeEnd,[ref]$rangeError) -and $rangeStart -eq 7 -and $rangeEnd -eq 22) 'Start 7 and end 22 are accepted.'
        $fixturePaths=@('sample.mp4','A\same.mp4','B\same.mp4','A\Ação\nested.mkv')
        foreach ($fixture in $fixturePaths) {
            $fixturePath=Join-Path $script:InputFolder $fixture
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fixturePath))
            [IO.File]::WriteAllBytes($fixturePath,[byte[]]@(0))
        }
        Refresh-VideoList
        Assert-SelfTest ($grid.Rows.Count -eq 4) 'Recursive discovery finds all four test paths.'
        $relative=@($grid.Rows | ForEach-Object { [string]$_.Cells['File'].Value })
        foreach ($fixture in $fixturePaths) { Assert-SelfTest ($relative -contains $fixture) ('Relative path retained: '+$fixture) }
        $script:BatchTrim=[pscustomobject]@{Enabled=$true;Start=$rangeStart;End=$rangeEnd}
        $sample=Get-Item -LiteralPath (Join-Path $script:InputFolder 'sample.mp4')
        $arguments=Build-FfmpegArguments $sample (Join-Path $script:OutputFolder 'sample.mp4')
        Assert-SelfTest ($arguments.Contains('-ss 7 ') -and $arguments.Contains('-t 15 ') -and $arguments.Contains('-map 0:a?')) 'Trim command saves 7 to 22 seconds and keeps audio by default.'
        $audioCheck.Checked=$false
        $arguments=Build-FfmpegArguments $sample (Join-Path $script:OutputFolder 'sample.mp4')
        Assert-SelfTest ($arguments.Contains('-an') -and -not $arguments.Contains('-map 0:a?')) 'Remove-audio option is honored.'
        $startNumeric.Text='7.5';$endNumeric.Text='12,25'
        Assert-SelfTest ($form.TryGetTrimRange([ref]$rangeStart,[ref]$rangeEnd,[ref]$rangeError) -and $rangeStart -eq [decimal]7.5 -and $rangeEnd -eq [decimal]12.25) 'Both decimal separators are supported.'
        $endNumeric.Text='1'
        Assert-SelfTest (-not $form.TryGetTrimRange([ref]$rangeStart,[ref]$rangeEnd,[ref]$rangeError)) 'End before start is rejected.'
        Assert-SelfTest (-not $script:IsRunning -and $null -eq $script:CurrentProcess) 'Loading and testing never starts an encode automatically.'
        $selfTestResult.Passed=$true
    } catch {
        $selfTestResult.Error=$_.Exception.ToString()
        throw
    } finally {
        $timer.Stop();$timer.Dispose();$form.Dispose()
        $selfTestResult | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:DataRoot 'self-test-result.json') -Encoding UTF8
    }
    return
}
if ($LoadOnly) { return }
if ($SmokeTest) {
    Refresh-VideoList
    $form.Dispose()
    exit 0
}

if ($DiagnosticLog) {
    $form.add_Shown({
        "SHOWN visible=$($form.Visible) bounds=$($form.Bounds)" | Add-Content -LiteralPath $DiagnosticLog
    })
    "BEFORE_SHOW visible=$($form.Visible) bounds=$($form.Bounds)" | Add-Content -LiteralPath $DiagnosticLog
}
$form.add_Shown({ Refresh-VideoList })
[void]$form.ShowDialog()
