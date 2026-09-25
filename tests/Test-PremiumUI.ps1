param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$appPath=Join-Path (Resolve-Path $AppRoot) 'APARADOR DE VIDEOS LZ-GAMES.exe'
$assembly=[Reflection.Assembly]::LoadFrom($appPath)
Add-Type -Path (Join-Path $PSScriptRoot 'UIRepaintProbe.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
[void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
$OutputDirectory=(Resolve-Path $OutputDirectory).Path
$assertions=New-Object 'Collections.Generic.List[string]'
$failures=New-Object 'Collections.Generic.List[string]'
$repaintResults=New-Object 'Collections.Generic.List[object]'
$snapshots=New-Object 'Collections.Generic.List[string]'
function Assert-UI([bool]$Condition,[string]$Message){
    if($Condition){$assertions.Add($Message)}else{$failures.Add($Message);Write-Warning $Message}
}
function Pump-UI{[Windows.Forms.Application]::DoEvents()}
function Check-Visible([Windows.Forms.Control]$Control,[Windows.Forms.Form]$Form,[string]$Context){
    $name=$Context+': '+$Control.GetType().Name+' '+$Control.Text.Replace("`r",' ').Replace("`n",' ')
    Assert-UI ($Control.Visible -and $Control.Width -gt 0 -and $Control.Height -gt 0) ('Visible: '+$name)
    $rect=$Control.RectangleToScreen($Control.ClientRectangle)
    Assert-UI ($Form.RectangleToScreen($Form.ClientRectangle).Contains($rect)) ('Inside window: '+$name)
    # Being inside the Form is insufficient: a page may clip fields behind the
    # pinned action footer. Check every ancestor's visible viewport as well.
    $inside=$true
    for($parent=$Control.Parent;$null -ne $parent;$parent=$parent.Parent){
        if(-not $parent.RectangleToScreen($parent.ClientRectangle).Contains($rect)){$inside=$false;break}
    }
    Assert-UI $inside ('Inside ancestor viewports: '+$name)
}
function Check-Accessible([Windows.Forms.Control]$Control,[Windows.Forms.Form]$Form,[string]$Context){
    # Compact layouts may scroll settings, but every field must be reachable.
    $page=$Control.Parent
    while($null -ne $page -and -not ($page -is [Windows.Forms.ScrollableControl] -and $page.AutoScroll)){$page=$page.Parent}
    if($null -ne $page){$page.ScrollControlIntoView($Control);Pump-UI}
    Check-Visible $Control $Form $Context
}
function Save-UI([Windows.Forms.Form]$Form,[string]$Name){
    $Form.Invalidate($true);$Form.Update();Pump-UI
    Settle-FiniteMotion $Form
    $bitmap=New-Object Drawing.Bitmap($Form.Width,$Form.Height)
    try{$Form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$Form.Width,$Form.Height)));$bitmap.Save((Join-Path $OutputDirectory $Name));$snapshots.Add($Name)}finally{$bitmap.Dispose()}
}
function Set-Fixture([LZGames.UI.Dashboard]$Form,[bool]$Populated){
    $Form.grid.Rows.Clear()
    if($Populated){
        foreach($row in @(@('Pronto','Jogos / Exemplo A.mp4','246 MB','--','--'),@('Concluido','Jogos / Subpasta / Exemplo B.mp4','184 MB','62 MB','66%'),@('Erro','Exemplo invalido.mp4','--','--','--'))){[void]$Form.grid.Rows.Add([object[]]$row)}
        $Form.UpdateQueueState(3);$Form.inputCardValue.Text='430 MB';$Form.savingCardValue.Text='66%';$Form.fileProgress.Value=100;$Form.overallProgress.Value=66
    }else{$Form.UpdateQueueState(0);$Form.inputCardValue.Text='0 B';$Form.savingCardValue.Text='--';$Form.fileProgress.Value=0;$Form.overallProgress.Value=0}
    Pump-UI
    Assert-UI ($Form.grid.Visible -eq $Populated) ('Queue visibility matches populated='+$Populated)
    Assert-UI ($Form.filesCardValue.Text -eq $(if($Populated){'03'}else{'00'})) ('Queue count matches populated='+$Populated)
}
function Check-CompactSummary([LZGames.UI.Dashboard]$Form,[string]$Context){
    # The summary is metadata, not a second dashboard of large number cards.
    # Fonts use points; bounds use logical pixels scaled to the form's DPI.
    $scale=[Math]::Max(1.0,$Form.CurrentAutoScaleDimensions.Height/96.0)
    $metrics=@($Form.filesCardValue,$Form.inputCardValue,$Form.savingCardValue)
    $bounds=@($metrics | ForEach-Object {$_.RectangleToScreen($_.ClientRectangle)})
    for($i=0;$i -lt $metrics.Count;$i++){
        Assert-UI ($metrics[$i].Font.SizeInPoints -le 12) ($Context+': summary '+$i+' uses at most 12pt type')
        Assert-UI ($metrics[$i].Height -le [Math]::Ceiling(40*$scale)) ($Context+': summary '+$i+' is at most 40 logical pixels high')
        if($i -gt 0){
            $firstCenter=$bounds[0].Top+$bounds[0].Height/2.0
            $thisCenter=$bounds[$i].Top+$bounds[$i].Height/2.0
            Assert-UI ([Math]::Abs($firstCenter-$thisCenter) -le [Math]::Ceiling(2*$scale)) ($Context+': summary '+$i+' stays on the same line')
            Assert-UI ($bounds[$i-1].Right -le $bounds[$i].Left) ($Context+': summary '+$i+' follows the previous value without overlap')
        }
    }
    $top=($bounds | Measure-Object -Property Top -Minimum).Minimum
    $bottom=($bounds | Measure-Object -Property Bottom -Maximum).Maximum
    Assert-UI (($bottom-$top) -le [Math]::Ceiling(40*$scale)) ($Context+': all summary values fit one compact 40px line')
}
function Check-Layout([LZGames.UI.Dashboard]$Form,[string]$Context){
    foreach($control in @($Form.startButton,$Form.cancelAction,$Form.openOutputButton,$Form.refreshButton,$Form.helpAction,$Form.filesCardValue,$Form.inputCardValue,$Form.savingCardValue,$Form.fileProgress,$Form.overallProgress)){Check-Visible $control $Form $Context}
    Check-CompactSummary $Form $Context
    $actions=@($Form.startButton,$Form.cancelAction,$Form.openOutputButton)
    for($i=0;$i -lt $actions.Count;$i++){for($j=$i+1;$j -lt $actions.Count;$j++){
        $a=$actions[$i].RectangleToScreen($actions[$i].ClientRectangle);$b=$actions[$j].RectangleToScreen($actions[$j].ClientRectangle)
        Assert-UI (-not $a.IntersectsWith($b)) ($Context+': action buttons do not overlap '+$i+'/'+$j)
    }}
    if($Form.grid.Visible){Check-Visible $Form.grid $Form $Context;Assert-UI ($Form.grid.Height -ge 76) ($Context+': queue shows a header and at least one row')}
    foreach($tab in 0,1,2){
        $Form.SelectTab($tab);Pump-UI
        $controls=switch($tab){0{@($Form.presetBox,$Form.resolutionBox,$Form.fpsBox,$Form.audioCheck,$Form.audioBitrateBox)}1{@($Form.trimCheck,$Form.startNumeric,$Form.endNumeric,$Form.trimSummaryLabel)}2{@($Form.inputPathBox,$Form.inputBrowseButton,$Form.outputPathBox,$Form.outputBrowseButton,$Form.overwriteCheck)}}
        foreach($control in $controls){Check-Accessible $control $Form ($Context+' tab '+$tab)}
        Assert-UI ($Form.presetBox.Visible -eq ($tab -eq 0)) ($Context+': compression page isolated for tab '+$tab)
        Assert-UI ($Form.trimCheck.Visible -eq ($tab -eq 1)) ($Context+': trim page isolated for tab '+$tab)
        Assert-UI ($Form.inputPathBox.Visible -eq ($tab -eq 2)) ($Context+': folders page isolated for tab '+$tab)
        Save-UI $Form ('ui-'+$Context+'-tab'+$tab+'.png')
    }
}
function Invoke-MotionTick([Windows.Forms.Timer]$Timer){
    [void][Windows.Forms.Timer].GetMethod('OnTick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($Timer,@([EventArgs]::Empty))
}
function Settle-FiniteMotion([Windows.Forms.Control]$Root){
    # Static layout evidence must not catch a tab underline halfway across its
    # transition. Animation-specific evidence below intentionally keeps middle
    # frames. Progress animation is deliberately not included here.
    $pending=New-Object 'Collections.Generic.Stack[Windows.Forms.Control]'
    $pending.Push($Root)
    while($pending.Count -gt 0){
        $item=$pending.Pop()
        foreach($child in $item.Controls){$pending.Push($child)}
        $fieldName=switch($item.GetType().Name){ActionButton{'hoverAnimation'}Toggle{'slide'}TabStrip{'transition'}default{$null}}
        if($null -eq $fieldName){continue}
        $field=$item.GetType().GetField($fieldName,[Reflection.BindingFlags]'Instance,NonPublic')
        if($null -eq $field){continue}
        $timer=$field.GetValue($item);$ticks=0
        while($timer.Enabled -and $ticks -lt 64){Invoke-MotionTick $timer;$ticks++}
        if($timer.Enabled){throw ('Animation did not settle before static render: '+$item.GetType().Name)}
    }
}
function Finish-Motion([Windows.Forms.Timer]$Timer,[string]$Context){
    # Advance the actual Tick event, not a duplicate easing implementation.
    # No DoEvents/wall-clock sleeps: deterministic, finite and independent of CPU.
    $ticks=0
    while($Timer.Enabled -and $ticks -lt 64){Invoke-MotionTick $Timer;$ticks++}
    Assert-UI (-not $Timer.Enabled) ($Context+': timer stops within 64 ticks')
}
function Invoke-Hover([Windows.Forms.Control]$Control,[bool]$Enter){
    $method=if($Enter){'OnMouseEnter'}else{'OnMouseLeave'}
    [void]$Control.GetType().GetMethod($method,[Reflection.BindingFlags]'Instance,NonPublic').Invoke($Control,@([EventArgs]::Empty))
}
function Motion-Frame([Windows.Forms.Control]$Control,[string]$Name){
    $file='motion-'+$Name+'.png';$snapshots.Add($file)
    return [LZGames.Tests.UIRepaintProbe]::SaveFrame($Control,(Join-Path $OutputDirectory $file))
}
function Check-Motion([Windows.Forms.Form]$Form){
    foreach($kind in @('ActionButton','Toggle','TabStrip')){
        $control=$assembly.CreateInstance('LZGames.UI.'+$kind)
        if($null -eq $control){Assert-UI $false ($kind+': animated control exists');continue}
        try{
            $control.Dock='None';$control.Size=New-Object Drawing.Size(300,42);$Form.Controls.Add($control);$control.BringToFront()
            $control.Text='Teste';$control.CreateControl()
            $stateName=switch($kind){ActionButton{'hoverAmount'} Toggle{'position'} TabStrip{'underline'}}
            $timerName=switch($kind){ActionButton{'hoverAnimation'} Toggle{'slide'} TabStrip{'transition'}}
            $stateField=$control.GetType().GetField($stateName,[Reflection.BindingFlags]'Instance,NonPublic')
            $timerField=$control.GetType().GetField($timerName,[Reflection.BindingFlags]'Instance,NonPublic')
            Assert-UI ($null -ne $stateField -and $null -ne $timerField) ($kind+': finite animation state and timer exist')
            if($null -eq $stateField -or $null -eq $timerField){continue}
            $timer=$timerField.GetValue($control)
            Assert-UI ($timer.Interval -ge 15 -and $timer.Interval -le 20) ($kind+': animation interval is lightweight 15-20ms')
            $before=Motion-Frame $control ($kind+'-initial')
            $target=if($kind -eq 'TabStrip'){200.0}else{1.0}
            switch($kind){ActionButton{Invoke-Hover $control $true}Toggle{$control.Checked=$true}TabStrip{$control.Select(2)}}
            Assert-UI $timer.Enabled ($kind+': interaction starts animation')
            Invoke-MotionTick $timer
            $middle=[double]$stateField.GetValue($control)
            Assert-UI ($middle -gt 0 -and $middle -lt $target) ($kind+': first tick produces an intermediate state')
            $during=Motion-Frame $control ($kind+'-intermediate')
            Assert-UI ($before -ne $during) ($kind+': intermediate frame visibly differs from initial frame')
            Finish-Motion $timer ($kind+' forward')
            Assert-UI ([Math]::Abs([double]$stateField.GetValue($control)-$target) -lt 0.001) ($kind+': animation reaches exact endpoint')
            $after=Motion-Frame $control ($kind+'-final')
            Assert-UI ($during -ne $after) ($kind+': final frame visibly differs from intermediate frame')
            switch($kind){ActionButton{Invoke-Hover $control $false}Toggle{$control.Checked=$false}TabStrip{$control.Select(0)}}
            Invoke-MotionTick $timer
            $reverse=[double]$stateField.GetValue($control)
            Assert-UI ($reverse -gt 0 -and $reverse -lt $target) ($kind+': reverse transition has an intermediate state')
            Finish-Motion $timer ($kind+' reverse')
            Assert-UI ([Math]::Abs([double]$stateField.GetValue($control)) -lt 0.001) ($kind+': reverse transition returns to exact origin')
            switch($kind){ActionButton{Invoke-Hover $control $true}Toggle{$control.Checked=$true}TabStrip{$control.Select(2)}}
            Invoke-MotionTick $timer
            $control.Visible=$false
            Assert-UI (-not $timer.Enabled) ($kind+': hidden control stops animation')
            $hiddenTarget=if($kind -eq 'ActionButton'){0.0}else{$target}
            Assert-UI ([Math]::Abs([double]$stateField.GetValue($control)-$hiddenTarget) -lt 0.001) ($kind+': hidden control has a settled state')
            $control.Visible=$true
            if($kind -eq 'ActionButton'){
                Invoke-Hover $control $true;Invoke-MotionTick $timer;$control.Enabled=$false
                Assert-UI (-not $timer.Enabled -and [double]$stateField.GetValue($control) -eq 0) 'ActionButton: disabling cancels and resets hover animation'
                $control.Enabled=$true;Invoke-Hover $control $true
            }elseif($kind -eq 'Toggle'){
                $control.Checked=$false;Invoke-MotionTick $timer;$control.Enabled=$false
                Assert-UI (-not $timer.Enabled -and [double]$stateField.GetValue($control) -eq 0) 'Toggle: disabling cancels animation and settles at checked state'
                $control.Enabled=$true;$control.Checked=$true
            }else{
                $control.Select(1);Invoke-MotionTick $timer;$control.Width=450
                Assert-UI (-not $timer.Enabled -and [double]$stateField.GetValue($control) -eq 150) 'TabStrip: resize stops transition and aligns underline to new tab width'
                $control.Select(0)
            }
            $script:motionTimerDisposed=$false
            $timer.add_Disposed({$script:motionTimerDisposed=$true})
            $control.Dispose()
            Assert-UI ($script:motionTimerDisposed -and -not $timer.Enabled) ($kind+': disposing control disposes and stops its timer')
        }finally{$Form.Controls.Remove($control);$control.Dispose()}
    }
}
$form=New-Object LZGames.UI.Dashboard
try {
    # The owned fixture stays transparent and absent from the taskbar, including
    # during maximize/restore. This is not a screenshot of the user's desktop.
    $form.Opacity=0;$form.ShowInTaskbar=$false;$form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-20000,-20000)
    $form.inputPathBox.Text='C:\UI-fixture\Entrada';$form.outputPathBox.Text='C:\UI-fixture\Saida'
    $form.Show();$form.Location=New-Object Drawing.Point(-20000,-20000)
    $form.trimCheck.Checked=$true;$form.startNumeric.Value=7;$form.endNumeric.Value=22;$form.RefreshTrimSummary()
    Assert-UI ($form.trimSummaryLabel.Text -match '15') '7 to 22 displays 15 seconds.'
    foreach($populated in $false,$true){
        Set-Fixture $form $populated
        $state=if($populated){'queue'}else{'empty'}
        # Reuse a single form: a fresh full render at each size hid this bug.
        $step=0
        foreach($size in @(@(1260,720),@(1360,728),@(960,560),@(1360,728))){
            $form.Size=New-Object Drawing.Size($size[0],$size[1]);$form.PerformLayout();Pump-UI
            $form.FitToWorkingArea((New-Object Drawing.Rectangle(-20000,-20000,$size[0],$size[1])));Pump-UI
            Assert-UI ($form.Width -le $size[0] -and $form.Height -le $size[1]) ($state+': fits work area '+$size[0]+'x'+$size[1])
            Check-Layout $form ($state+'-'+$step+'-'+$size[0]+'x'+$size[1]);$step++
        }
        $maximizedProperty=[Windows.Forms.Form].GetProperty('MaximizedBounds',[Reflection.BindingFlags]'Instance,NonPublic')
        $maximizedProperty.SetValue($form,(New-Object Drawing.Rectangle(-20000,-20000,1360,728)),$null)
        $form.WindowState='Maximized';Pump-UI
        Assert-UI ($form.WindowState -eq 'Maximized') ($state+': entered maximized state')
        Check-Layout $form ($state+'-maximized')
        $form.WindowState='Normal';$form.Location=New-Object Drawing.Point(-20000,-20000);$form.Size=New-Object Drawing.Size(1260,720);Pump-UI
        Assert-UI ($form.WindowState -eq 'Normal') ($state+': restored normal state')
        Check-Layout $form ($state+'-restored')
    }
    Set-Fixture $form $false;Save-UI $form 'ui-cleared-queue.png'
    $form.SelectTab(1);$form.trimCheck.Checked=$true;$form.startNumeric.Text='7,5';$form.endNumeric.Text='22.25'
    [decimal]$start=0;[decimal]$end=0;[string]$errorText=''
    Assert-UI ($form.TryGetTrimRange([ref]$start,[ref]$end,[ref]$errorText) -and $start -eq 7.5 -and $end -eq 22.25) 'Decimal trim range preserved.'
    $form.endNumeric.Text='3';Assert-UI (-not $form.TryGetTrimRange([ref]$start,[ref]$end,[ref]$errorText)) 'Invalid interval rejected.'
    $form.endNumeric.Text='22';$form.trimCheck.Checked=$false;$form.RefreshTrimSummary()
    Assert-UI (-not $form.startNumeric.Enabled -and -not $form.endNumeric.Enabled) 'Trim inputs disable when full-video mode is selected.'
    $form.SelectTab(0)
    $method=$form.presetBox.GetType().GetMethod('OpenMenu',[Reflection.BindingFlags]'Instance,NonPublic')
    $menuField=$form.presetBox.GetType().GetField('menu',[Reflection.BindingFlags]'Instance,NonPublic')
    for($cycle=0;$cycle -lt 12;$cycle++){
        $method.Invoke($form.presetBox,@());$menu=$menuField.GetValue($form.presetBox)
        $menu.Items[$cycle % 4].PerformClick();$menu.Close();Pump-UI
        Assert-UI (-not $menu.IsDisposed -and $form.presetBox.SelectedIndex -eq ($cycle % 4)) ('Reusable menu cycle '+$cycle)
    }
    # No child windows occlude the owner-drawn areas under test. Optional artwork
    # classes may disappear during redesign without changing Dashboard's API.
    foreach($kind in @('Card','WorkspacePane','TabStrip','StudioHeader','EmptyLibrary','ProgressTrack','StudioMark','ActionButton','SelectBox','Toggle','PathDisplay')){
        $control=$assembly.CreateInstance('LZGames.UI.'+$kind)
        if($null -eq $control){continue}
        try{
            $control.Dock='None';$control.Location=New-Object Drawing.Point(0,0);$form.Controls.Add($control);$control.BringToFront()
            if($kind -eq 'Card' -and $null -ne $control.GetType().GetField('Highlight')){$control.Highlight=$true}
            if($kind -eq 'ActionButton'){$control.Text='Teste';$control.Primary=$true}
            if($kind -eq 'Toggle'){$control.Text='Teste';$control.Checked=$true}
            $height=if($kind -eq 'ProgressTrack'){8}elseif($kind -eq 'EmptyLibrary'){270}elseif($kind -eq 'Card'){86}elseif($kind -eq 'StudioMark'){66}else{42}
            $number=0
            $states=if($kind -eq 'ProgressTrack'){@(0,37,100)}else{@(-1)}
            foreach($progressValue in $states){
                if($progressValue -ge 0){$control.Value=$progressValue}
                # No message pump within these synchronous probes: progress
                # animation phase stays fixed, so both images compare one state.
                foreach($transition in @(@(240,$height,360,$height),@(360,$height,180,$height),@(180,$height,320,$height),@(320,$height,320,($height+24)),@(320,($height+24),320,$height))){
                    $result=[LZGames.Tests.UIRepaintProbe]::Resize($control,(New-Object Drawing.Size($transition[0],$transition[1])),(New-Object Drawing.Size($transition[2],$transition[3])),(Join-Path $OutputDirectory ('repaint-'+$kind+'-'+$number)))
                    $repaintResults.Add($result)
                    Assert-UI ($result.DifferentPixels -eq 0) ('Partial repaint equals complete repaint: '+$kind+' '+$result.Transition+' progress='+$progressValue+' ('+$result.DifferentPixels+' stale pixels)');$number++
                }
            }
        }finally{$form.Controls.Remove($control);$control.Dispose()}
    }
    Check-Motion $form
    $startup=New-Object LZGames.UI.Dashboard
    try{
        $startup.Opacity=0;$startup.ShowInTaskbar=$false;$startup.StartPosition='Manual';$startup.Location=New-Object Drawing.Point(-20000,-20000)
        $startup.Size=New-Object Drawing.Size(1360,728);$startup.Show();$startup.Location=New-Object Drawing.Point(-20000,-20000)
        $startup.SelectTab(0);Pump-UI
        Assert-UI (-not $startup.trimCheck.Checked -and $startup.filesCardValue.Text -eq '00') 'Clean startup defaults preserve full-video mode and empty queue'
        Save-UI $startup 'ui-clean-startup-1360x728.png'
    }finally{$startup.Close();$startup.Dispose()}
} catch {$failures.Add($_.Exception.ToString())} finally {
    $form.Close();$form.Dispose()
    [ordered]@{Passed=($failures.Count -eq 0);AssertionCount=$assertions.Count;Assertions=$assertions.ToArray();Failures=$failures.ToArray();RepaintProbes=$repaintResults.ToArray();Snapshots=$snapshots.ToArray();ExeSHA256=(Get-FileHash $appPath).Hash;Scope='Isolated owned WinForms controls: resize sequences at 1260x720, 1360x728 and 960x560, maximize/restore, compact single-line summary, finite hover/toggle/tab animations with distinct initial/intermediate/final frames and timer cleanup, ancestor viewport checks, empty/queue/cleared states, all tabs, partial-paint comparison, menu lifecycle and trim validation. Synthetic paths and rows only. Not a desktop screenshot or manual visual review.'}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputDirectory 'ui-result.json') -Encoding UTF8
}
if($failures.Count -gt 0){throw ('FAIL: '+$failures.Count+' UI assertions/checks; see '+(Join-Path $OutputDirectory 'ui-result.json'))}
Write-Output ('PASS: '+$assertions.Count+' UI assertions')
