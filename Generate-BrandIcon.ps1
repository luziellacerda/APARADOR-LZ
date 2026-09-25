param([string]$Destination=(Join-Path $PSScriptRoot 'assets\LZGames.ico'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
[void](New-Item -ItemType Directory -Path (Split-Path $Destination -Parent) -Force)
$images=New-Object 'System.Collections.Generic.List[byte[]]'
$sizes=@(16,24,32,48,64,128,256)
foreach($size in $sizes){
    $bitmap=New-Object Drawing.Bitmap($size,$size)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    $background=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(15,22,30))
    $accent=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(49,210,151))
    $font=New-Object Drawing.Font('Segoe UI',([single]($size*0.43)),[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
    $format=New-Object Drawing.StringFormat
    $stream=New-Object IO.MemoryStream
    try {
        $graphics.SmoothingMode='AntiAlias'
        $graphics.TextRenderingHint='AntiAliasGridFit'
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.FillRectangle($background,0,0,$size,$size)
        $graphics.FillRectangle($accent,0,([single]($size*0.87)),$size,([single]($size*0.13)))
        $format.Alignment='Center';$format.LineAlignment='Center'
        $rect=New-Object Drawing.RectangleF(0,(-$size*0.04),$size,($size*0.91))
        $graphics.DrawString('LZ',$font,$accent,$rect,$format)
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        $images.Add($stream.ToArray())
        if($size -eq 256){$bitmap.Save([IO.Path]::ChangeExtension($Destination,'.png'),[Drawing.Imaging.ImageFormat]::Png)}
    } finally {$stream.Dispose();$format.Dispose();$font.Dispose();$accent.Dispose();$background.Dispose();$graphics.Dispose();$bitmap.Dispose()}
}
$ico=[IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
$writer=New-Object IO.BinaryWriter($ico)
try {
    $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$sizes.Count)
    $offset=6+16*$sizes.Count
    for($i=0;$i -lt $sizes.Count;$i++){
        $dimension=if($sizes[$i] -eq 256){0}else{$sizes[$i]}
        $writer.Write([byte]$dimension);$writer.Write([byte]$dimension);$writer.Write([byte]0);$writer.Write([byte]0)
        $writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$images[$i].Length);$writer.Write([uint32]$offset)
        $offset+=$images[$i].Length
    }
    foreach($data in $images){$writer.Write($data)}
} finally {$writer.Dispose()}
Get-Item -LiteralPath $Destination | Select-Object FullName,Length
