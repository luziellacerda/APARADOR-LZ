param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$assembly=[Reflection.Assembly]::LoadFrom((Join-Path (Resolve-Path $AppRoot) 'APARADOR DE VIDEOS LZ-GAMES.exe'))
[void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
$assertions=New-Object 'Collections.Generic.List[string]'
function Assert-UI([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$assertions.Add($Message)}
function Check-Visible([Windows.Forms.Control]$Control,[Windows.Forms.Form]$Form){
    Assert-UI ($Control.Visible -and $Control.Width -gt 0 -and $Control.Height -gt 0) ('Visible: '+$Control.GetType().Name+' '+$Control.Text)
    $rect=$Form.RectangleToClient($Control.RectangleToScreen($Control.ClientRectangle))
    Assert-UI ($Form.ClientRectangle.Contains($rect)) ('Inside window: '+$Control.GetType().Name+' '+$Control.Text)
}
$form=New-Object LZGames.UI.Dashboard
try {
    $form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-20000,-20000)
    # This is an isolated control-rendering harness, not a capture of the user's desktop.
    $form.Show();$form.Location=New-Object Drawing.Point(-20000,-20000)
    foreach($size in @(@(1260,720),@(960,560))){
        $form.Size=New-Object Drawing.Size($size[0],$size[1]);$form.PerformLayout();[Windows.Forms.Application]::DoEvents()
        foreach($tab in 0,1,2){
            $form.SelectTab($tab);[Windows.Forms.Application]::DoEvents()
            foreach($control in @($form.startButton,$form.cancelAction,$form.openOutputButton,$form.refreshButton)){Check-Visible $control $form}
            if($tab -eq 0){foreach($control in @($form.presetBox,$form.resolutionBox,$form.fpsBox)){Check-Visible $control $form}}
            if($tab -eq 1){$form.trimCheck.Checked=$true;$form.startNumeric.Value=7;$form.endNumeric.Value=22;$form.RefreshTrimSummary();Assert-UI ($form.trimSummaryLabel.Text -match '15') '7 to 22 displays 15 seconds.'}
            $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
            try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $OutputDirectory ('ui-'+$size[0]+'-tab'+$tab+'.png')))}finally{$bitmap.Dispose()}
        }
    }
    $form.Size=New-Object Drawing.Size(1260,720);$form.SelectTab(0)
    foreach($row in @(@('Pronto','PS5 / Horizon Forbidden West.mp4','246 MB','--','--'),@('Concluído','PC / Cyberpunk 2077.mp4','184 MB','62 MB','66%'),@('Erro','Xbox / Exemplo inválido.mp4','--','--','--'))){[void]$form.grid.Rows.Add([object[]]$row)}
    $form.UpdateQueueState(3);$form.inputCardValue.Text='430 MB';$form.savingCardValue.Text='66%';$form.fileProgress.Value=100;$form.overallProgress.Value=66
    [Windows.Forms.Application]::DoEvents()
    $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $OutputDirectory 'ui-queue-fixture.png'))}finally{$bitmap.Dispose()}
    $form.trimCheck.Checked=$true;$form.startNumeric.Text='7,5';$form.endNumeric.Text='22.25'
    [decimal]$start=0;[decimal]$end=0;[string]$errorText=''
    Assert-UI ($form.TryGetTrimRange([ref]$start,[ref]$end,[ref]$errorText) -and $start -eq 7.5 -and $end -eq 22.25) 'Decimal trim range preserved.'
    $form.endNumeric.Text='3';Assert-UI (-not $form.TryGetTrimRange([ref]$start,[ref]$end,[ref]$errorText)) 'Invalid interval rejected.'
    # Exercise the same SelectBox menu repeatedly; regression for disposed ContextMenuStrip.
    $method=$form.presetBox.GetType().GetMethod('OpenMenu',[Reflection.BindingFlags]'Instance,NonPublic')
    $menuField=$form.presetBox.GetType().GetField('menu',[Reflection.BindingFlags]'Instance,NonPublic')
    for($cycle=0;$cycle -lt 12;$cycle++){
        $method.Invoke($form.presetBox,@());$menu=$menuField.GetValue($form.presetBox)
        $menu.Items[$cycle % 4].PerformClick();$menu.Close();[Windows.Forms.Application]::DoEvents()
        Assert-UI (-not $menu.IsDisposed -and $form.presetBox.SelectedIndex -eq ($cycle % 4)) ('Reusable menu cycle '+$cycle)
    }
    [ordered]@{Passed=$true;Assertions=$assertions.ToArray();ExeSHA256=(Get-FileHash (Join-Path $AppRoot 'APARADOR DE VIDEOS LZ-GAMES.exe')).Hash;Scope='Isolated WinForms control rendering at 1260x720 and 960x560; menu lifecycle and trim validation. Not a manual desktop session.'}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $OutputDirectory 'ui-result.json') -Encoding UTF8
    Write-Output ('PASS: '+$assertions.Count+' UI assertions')
} finally {$form.Close();$form.Dispose()}
