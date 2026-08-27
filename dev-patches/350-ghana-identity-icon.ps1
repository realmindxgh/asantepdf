param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

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

function New-IdentityPng([int]$Size) {
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

        # Three stacked document leaves. Their stepped edges carry Ghana's red/gold/green
        # without turning the whole application into a flag motif.
        $backRed = [System.Drawing.RectangleF]::new($s*0.08, $s*0.20, $s*0.68, $s*0.70)
        $backGold = [System.Drawing.RectangleF]::new($s*0.12, $s*0.14, $s*0.68, $s*0.70)
        $backGreen = [System.Drawing.RectangleF]::new($s*0.16, $s*0.08, $s*0.68, $s*0.70)
        foreach ($layer in @(@($backRed,$red), @($backGold,$gold), @($backGreen,$green))) {
            $p = New-RoundedPath $layer[0] $radius
            try { $b = [System.Drawing.SolidBrush]::new($layer[1]); try { $g.FillPath($b,$p) } finally { $b.Dispose() } } finally { $p.Dispose() }
        }

        # Front black document.
        $front = [System.Drawing.RectangleF]::new($s*0.22, $s*0.12, $s*0.68, $s*0.78)
        $fp = New-RoundedPath $front $radius
        try { $b = [System.Drawing.SolidBrush]::new($black); try { $g.FillPath($b,$fp) } finally { $b.Dispose() } } finally { $fp.Dispose() }

        # Folded corner.
        $fold = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new($s*0.67,$s*0.12),
            [System.Drawing.PointF]::new($s*0.90,$s*0.35),
            [System.Drawing.PointF]::new($s*0.67,$s*0.35)
        )
        $fb = [System.Drawing.SolidBrush]::new($paper)
        try { $g.FillPolygon($fb,$fold) } finally { $fb.Dispose() }
        $foldShadow = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new($s*0.67,$s*0.12),
            [System.Drawing.PointF]::new($s*0.90,$s*0.35),
            [System.Drawing.PointF]::new($s*0.90,$s*0.12)
        )
        $sb = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150,0,107,63))
        try { $g.FillPolygon($sb,$foldShadow) } finally { $sb.Dispose() }

        # A built from the three identity colours. At icon size it reads as a clean mark;
        # at larger sizes it reveals the document/A concept.
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

        $stream = [System.IO.MemoryStream]::new()
        $bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
        return $stream.ToArray()
    }
    finally { $g.Dispose(); $bitmap.Dispose() }
}

$sizes = @(16,24,32,48,64,128,256)
$images = foreach ($size in $sizes) { ,(New-IdentityPng $size) }
$iconPath = Join-Path $SourceRoot 'assets\asantepdf.ico'
$dir = Split-Path -Parent $iconPath
[IO.Directory]::CreateDirectory($dir) | Out-Null
$stream = [IO.MemoryStream]::new()
$writer = [IO.BinaryWriter]::new($stream)
try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)
    $offset = 6 + (16 * $sizes.Count)
    for ($i=0; $i -lt $sizes.Count; $i++) {
        $size = $sizes[$i]
        $png = $images[$i]
        $writer.Write([byte]($(if($size -eq 256){0}else{$size})))
        $writer.Write([byte]($(if($size -eq 256){0}else{$size})))
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$png.Length)
        $writer.Write([uint32]$offset)
        $offset += $png.Length
    }
    foreach ($png in $images) { $writer.Write($png) }
    $writer.Flush()
    [IO.File]::WriteAllBytes($iconPath,$stream.ToArray())
}
finally { $writer.Dispose(); $stream.Dispose() }

# Keep a 256px PNG beside the ICO as the canonical identity preview/source asset.
[IO.File]::WriteAllBytes((Join-Path $SourceRoot 'assets\asantepdf-icon-256.png'), $images[-1])
Write-Host 'Ghana-inspired multi-resolution AsantePDF Windows icon staged.' -ForegroundColor Green
