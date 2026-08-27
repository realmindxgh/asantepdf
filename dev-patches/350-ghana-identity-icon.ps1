param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AsantePdfIconNative {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
'@

function New-RoundedPath([System.Drawing.RectangleF]$Rect, [float]$Radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $Radius * 2
    if ($d -le 0) { $path.AddRectangle($Rect); return $path }
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IdentityBitmap([int]$Size) {
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $s = [float]$Size
        $radius = [Math]::Max(1.0, $s * 0.09)
        $red = [System.Drawing.Color]::FromArgb(255, 206, 17, 38)
        $gold = [System.Drawing.Color]::FromArgb(255, 252, 209, 22)
        $green = [System.Drawing.Color]::FromArgb(255, 0, 107, 63)
        $black = [System.Drawing.Color]::FromArgb(255, 17, 17, 17)
        $paper = [System.Drawing.Color]::FromArgb(255, 247, 249, 250)

        $layers = @(
            @([System.Drawing.RectangleF]::new($s*0.08, $s*0.20, $s*0.68, $s*0.70), $red),
            @([System.Drawing.RectangleF]::new($s*0.12, $s*0.14, $s*0.68, $s*0.70), $gold),
            @([System.Drawing.RectangleF]::new($s*0.16, $s*0.08, $s*0.68, $s*0.70), $green)
        )
        foreach ($layer in $layers) {
            $p = New-RoundedPath $layer[0] $radius
            $b = [System.Drawing.SolidBrush]::new($layer[1])
            try { $g.FillPath($b,$p) } finally { $b.Dispose(); $p.Dispose() }
        }

        $front = [System.Drawing.RectangleF]::new($s*0.22, $s*0.12, $s*0.68, $s*0.78)
        $fp = New-RoundedPath $front $radius
        $fb = [System.Drawing.SolidBrush]::new($black)
        try { $g.FillPath($fb,$fp) } finally { $fb.Dispose(); $fp.Dispose() }

        $fold = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new($s*0.67,$s*0.12),
            [System.Drawing.PointF]::new($s*0.90,$s*0.35),
            [System.Drawing.PointF]::new($s*0.67,$s*0.35)
        )
        $paperBrush = [System.Drawing.SolidBrush]::new($paper)
        try { $g.FillPolygon($paperBrush,$fold) } finally { $paperBrush.Dispose() }
        $foldShadow = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new($s*0.67,$s*0.12),
            [System.Drawing.PointF]::new($s*0.90,$s*0.35),
            [System.Drawing.PointF]::new($s*0.90,$s*0.12)
        )
        $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150,0,107,63))
        try { $g.FillPolygon($shadowBrush,$foldShadow) } finally { $shadowBrush.Dispose() }

        $stroke = [Math]::Max(2.0, $s * 0.075)
        $cap = [System.Drawing.Drawing2D.LineCap]::Round
        $leftPen = [System.Drawing.Pen]::new($red,$stroke)
        $rightPen = [System.Drawing.Pen]::new($green,$stroke)
        $barPen = [System.Drawing.Pen]::new($gold,[Math]::Max(1.5,$s*0.065))
        try {
            $leftPen.StartCap=$cap; $leftPen.EndCap=$cap
            $rightPen.StartCap=$cap; $rightPen.EndCap=$cap
            $barPen.StartCap=$cap; $barPen.EndCap=$cap
            $g.DrawLine($leftPen,$s*0.35,$s*0.73,$s*0.52,$s*0.38)
            $g.DrawLine($rightPen,$s*0.52,$s*0.38,$s*0.72,$s*0.73)
            $g.DrawLine($barPen,$s*0.42,$s*0.59,$s*0.64,$s*0.59)
        } finally { $leftPen.Dispose(); $rightPen.Dispose(); $barPen.Dispose() }
        return $bitmap
    }
    finally { $g.Dispose() }
}

$assets = Join-Path $SourceRoot 'assets'
[IO.Directory]::CreateDirectory($assets) | Out-Null
$iconPath = Join-Path $assets 'asantepdf.ico'
$previewPath = Join-Path $assets 'asantepdf-icon-256.png'

# System.Drawing's native HICON serializer produces a conventional ICO resource
# that Roslyn, Explorer, Inno Setup and the Windows shell all accept reliably.
$iconBitmap = New-IdentityBitmap 64
$hIcon = [IntPtr]::Zero
$icon = $null
$file = $null
try {
    $hIcon = $iconBitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)
    $file = [IO.File]::Create($iconPath)
    $icon.Save($file)
}
finally {
    if ($file) { $file.Dispose() }
    if ($icon) { $icon.Dispose() }
    if ($hIcon -ne [IntPtr]::Zero) { [AsantePdfIconNative]::DestroyIcon($hIcon) | Out-Null }
    $iconBitmap.Dispose()
}

$preview = New-IdentityBitmap 256
try { $preview.Save($previewPath,[System.Drawing.Imaging.ImageFormat]::Png) }
finally { $preview.Dispose() }

# Validate the ICO through the same Windows API path consumers use before compile.
$probe = [System.Drawing.Icon]::new($iconPath)
try {
    if ($probe.Width -lt 16 -or $probe.Height -lt 16) { throw 'Generated icon dimensions are invalid.' }
}
finally { $probe.Dispose() }

Write-Host 'Ghana-inspired compiler-safe AsantePDF Windows icon staged.' -ForegroundColor Green
