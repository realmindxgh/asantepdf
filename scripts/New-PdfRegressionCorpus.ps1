param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$Ascii = [System.Text.Encoding]::ASCII

function ConvertTo-AsciiBytes([string]$Text) {
    return $Ascii.GetBytes($Text)
}

function Join-ByteArrays([byte[][]]$Parts) {
    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($part in $Parts) {
            if ($null -ne $part -and $part.Length -gt 0) { $stream.Write($part, 0, $part.Length) }
        }
        return $stream.ToArray()
    }
    finally { $stream.Dispose() }
}

function New-StreamObject([byte[]]$Data, [string]$ExtraDictionary = '') {
    $dictExtra = if ([string]::IsNullOrWhiteSpace($ExtraDictionary)) { '' } else { " $ExtraDictionary" }
    return Join-ByteArrays @(
        (ConvertTo-AsciiBytes "<< /Length $($Data.Length)$dictExtra >>`nstream`n"),
        $Data,
        (ConvertTo-AsciiBytes "`nendstream")
    )
}

function Write-PdfObjects([System.Collections.Generic.List[byte[]]]$Objects, [string]$OutputPath) {
    $full = [System.IO.Path]::GetFullPath($OutputPath)
    $directory = [System.IO.Path]::GetDirectoryName($full)
    if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }

    $stream = [System.IO.MemoryStream]::new()
    $offsets = [System.Collections.Generic.List[long]]::new()
    try {
        $header = ConvertTo-AsciiBytes "%PDF-1.4`n%AsantePDF-regression`n"
        $stream.Write($header, 0, $header.Length)
        for ($i = 0; $i -lt $Objects.Count; $i++) {
            $offsets.Add($stream.Position)
            $prefix = ConvertTo-AsciiBytes "$($i + 1) 0 obj`n"
            $stream.Write($prefix, 0, $prefix.Length)
            $objectBytes = $Objects[$i]
            $stream.Write($objectBytes, 0, $objectBytes.Length)
            $suffix = ConvertTo-AsciiBytes "`nendobj`n"
            $stream.Write($suffix, 0, $suffix.Length)
        }

        $xrefOffset = $stream.Position
        $xref = [System.Text.StringBuilder]::new()
        [void]$xref.Append("xref`n0 $($Objects.Count + 1)`n")
        [void]$xref.Append("0000000000 65535 f `n")
        foreach ($offset in $offsets) {
            [void]$xref.Append($offset.ToString('D10')).Append(" 00000 n `n")
        }
        [void]$xref.Append("trailer`n<< /Size $($Objects.Count + 1) /Root 1 0 R >>`n")
        [void]$xref.Append("startxref`n$xrefOffset`n%%EOF`n")
        $xrefBytes = ConvertTo-AsciiBytes $xref.ToString()
        $stream.Write($xrefBytes, 0, $xrefBytes.Length)
        [System.IO.File]::WriteAllBytes($full, $stream.ToArray())
    }
    finally { $stream.Dispose() }
}

function Escape-PdfText([string]$Text) {
    return $Text.Replace('\', '\\').Replace('(', '\(').Replace(')', '\)')
}

function New-ResearchLikePdf([string]$Path, [int]$PageCount = 18) {
    $objects = [System.Collections.Generic.List[byte[]]]::new()
    $fontObject = 3 + (2 * $PageCount)
    $kids = @()
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Catalog /Pages 2 0 R >>'))
    $objects.Add([byte[]]@())
    for ($pageIndex = 0; $pageIndex -lt $PageCount; $pageIndex++) {
        $pageObject = 3 + (2 * $pageIndex)
        $contentObject = $pageObject + 1
        $kids += "$pageObject 0 R"
        $objects.Add((ConvertTo-AsciiBytes "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 $fontObject 0 R >> >> /Contents $contentObject 0 R >>"))
        $title = Escape-PdfText "Research brief — section $($pageIndex + 1)"
        $body1 = Escape-PdfText 'This regression page combines headings, body text, rules and shaded content blocks.'
        $body2 = Escape-PdfText 'It approximates the mixed text and vector content found in ordinary academic PDFs.'
        $content = "0.94 g 48 620 516 92 re f`n0 g BT /F1 22 Tf 58 710 Td ($title) Tj ET`nBT /F1 11 Tf 58 670 Td ($body1) Tj 0 -18 Td ($body2) Tj ET`n0.18 0.42 0.70 RG 2 w 58 610 m 554 610 l S`n0.82 g 58 520 230 62 re f 0.72 g 310 520 244 62 re f`n0 g BT /F1 10 Tf 68 555 Td (Methods and evidence summary) Tj ET`nBT /F1 10 Tf 320 555 Td (Results and implications) Tj ET`n"
        $objects.Add((New-StreamObject (ConvertTo-AsciiBytes $content)))
    }
    $objects[1] = ConvertTo-AsciiBytes "<< /Type /Pages /Kids [$($kids -join ' ')] /Count $PageCount >>"
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'))
    Write-PdfObjects $objects $Path
}

function New-RotatedCroppedPdf([string]$Path) {
    $pageCount = 6
    $objects = [System.Collections.Generic.List[byte[]]]::new()
    $fontObject = 3 + (2 * $pageCount)
    $kids = @()
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Catalog /Pages 2 0 R >>'))
    $objects.Add([byte[]]@())
    for ($i = 0; $i -lt $pageCount; $i++) {
        $pageObject = 3 + (2 * $i)
        $contentObject = $pageObject + 1
        $kids += "$pageObject 0 R"
        $rotation = @(0, 90, 180, 270, 90, 0)[$i]
        $crop = if (($i % 2) -eq 0) { '/CropBox [36 48 576 744]' } else { '/CropBox [20 30 592 762]' }
        $objects.Add((ConvertTo-AsciiBytes "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] $crop /Rotate $rotation /Resources << /Font << /F1 $fontObject 0 R >> >> /Contents $contentObject 0 R >>"))
        $content = "0.90 g 40 80 530 630 re f`n0 g BT /F1 24 Tf 70 680 Td (Rotated and cropped page $($i + 1)) Tj 0 -34 Td /F1 12 Tf (Rotation: $rotation degrees) Tj ET`n0.2 0.55 0.35 RG 4 w 70 570 450 70 re S`n"
        $objects.Add((New-StreamObject (ConvertTo-AsciiBytes $content)))
    }
    $objects[1] = ConvertTo-AsciiBytes "<< /Type /Pages /Kids [$($kids -join ' ')] /Count $pageCount >>"
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'))
    Write-PdfObjects $objects $Path
}

function New-FeatureRichPdf([string]$Path) {
    $objects = [System.Collections.Generic.List[byte[]]]::new()
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Catalog /Pages 2 0 R /Outlines 9 0 R /PageMode /UseOutlines /AcroForm 11 0 R >>')) # 1
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Pages /Kids [3 0 R 5 0 R 7 0 R] /Count 3 >>')) # 2
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 13 0 R >> >> /Contents 4 0 R /Annots [10 0 R 12 0 R] >>')) # 3
    $objects.Add((New-StreamObject (ConvertTo-AsciiBytes 'BT /F1 22 Tf 72 700 Td (Feature-rich PDF) Tj 0 -38 Td /F1 12 Tf (This page contains a text annotation and a text form field.) Tj ET'))) # 4
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 13 0 R >> >> /Contents 6 0 R >>')) # 5
    $objects.Add((New-StreamObject (ConvertTo-AsciiBytes 'BT /F1 22 Tf 72 700 Td (Results section) Tj 0 -38 Td /F1 12 Tf (The document outline points directly to this page.) Tj ET'))) # 6
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 13 0 R >> >> /Contents 8 0 R >>')) # 7
    $objects.Add((New-StreamObject (ConvertTo-AsciiBytes 'BT /F1 22 Tf 72 700 Td (Appendix) Tj 0 -38 Td /F1 12 Tf (Final page for bookmark, annotation and form navigation regression.) Tj ET'))) # 8
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Outlines /First 14 0 R /Last 15 0 R /Count 2 >>')) # 9
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Annot /Subtype /Text /Rect [470 650 500 680] /Contents (AsantePDF regression review note) /Name /Comment /P 3 0 R >>')) # 10
    $objects.Add((ConvertTo-AsciiBytes '<< /Fields [12 0 R] /NeedAppearances true /DA (/F1 12 Tf 0 g) /DR << /Font << /F1 13 0 R >> >> >>')) # 11
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Annot /Subtype /Widget /FT /Tx /T (NameField) /Rect [100 530 360 560] /P 3 0 R /V (AsantePDF) /DA (/F1 12 Tf 0 g) /F 4 >>')) # 12
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')) # 13
    $objects.Add((ConvertTo-AsciiBytes '<< /Title (Introduction) /Parent 9 0 R /Next 15 0 R /Dest [3 0 R /Fit] >>')) # 14
    $objects.Add((ConvertTo-AsciiBytes '<< /Title (Results) /Parent 9 0 R /Prev 14 0 R /Dest [5 0 R /Fit] >>')) # 15
    Write-PdfObjects $objects $Path
}

function New-ScannedImagePdf([string]$Path, [int]$PageCount = 8) {
    $width = 600
    $height = 800
    $pixels = [byte[]]::new($width * $height)
    [Array]::Fill[byte]($pixels, 246)
    for ($y = 80; $y -lt 720; $y += 42) {
        for ($row = $y; $row -lt [Math]::Min($y + 4, $height); $row++) {
            $start = ($row * $width) + 55
            $length = if (($y / 42) % 3 -eq 0) { 460 } else { 390 }
            for ($x = 0; $x -lt $length; $x++) { $pixels[$start + $x] = 55 }
        }
    }
    for ($row = 25; $row -lt 60; $row++) {
        for ($x = 70; $x -lt 530; $x++) { $pixels[($row * $width) + $x] = 120 }
    }

    $objects = [System.Collections.Generic.List[byte[]]]::new()
    $kids = @()
    $objects.Add((ConvertTo-AsciiBytes '<< /Type /Catalog /Pages 2 0 R >>'))
    $objects.Add([byte[]]@())
    $imageObject = 3
    $objects.Add((New-StreamObject $pixels "/Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceGray /BitsPerComponent 8"))
    for ($i = 0; $i -lt $PageCount; $i++) {
        $pageObject = 4 + (2 * $i)
        $contentObject = $pageObject + 1
        $kids += "$pageObject 0 R"
        $objects.Add((ConvertTo-AsciiBytes "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /XObject << /Im0 $imageObject 0 R >> >> /Contents $contentObject 0 R >>"))
        $objects.Add((New-StreamObject (ConvertTo-AsciiBytes 'q 612 0 0 792 0 0 cm /Im0 Do Q')))
    }
    $objects[1] = ConvertTo-AsciiBytes "<< /Type /Pages /Kids [$($kids -join ' ')] /Count $PageCount >>"
    Write-PdfObjects $objects $Path
}

$root = [System.IO.Path]::GetFullPath($OutputDirectory)
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $root | Out-Null

$research = Join-Path $root 'research-like-18.pdf'
$scanned = Join-Path $root 'scanned-image-only-8.pdf'
$features = Join-Path $root 'feature-rich-3.pdf'
$rotated = Join-Path $root 'rotated-cropped-6.pdf'
$large = Join-Path $root 'large-text-50.pdf'

New-ResearchLikePdf $research 18
New-ScannedImagePdf $scanned 8
New-FeatureRichPdf $features
New-RotatedCroppedPdf $rotated
& (Join-Path $PSScriptRoot 'New-SamplePdf.ps1') -OutputPath $large -PageCount 50

@(
    'research-like-18.pdf|18|text-vector academic-style document',
    'scanned-image-only-8.pdf|8|image-only scanned-style document',
    'feature-rich-3.pdf|3|bookmarks annotation and AcroForm field',
    'rotated-cropped-6.pdf|6|mixed rotation and CropBox geometry',
    'large-text-50.pdf|50|larger multi-page document'
) | Set-Content (Join-Path $root 'CORPUS-MANIFEST.txt') -Encoding UTF8

Get-ChildItem $root -Filter '*.pdf' | ForEach-Object {
    if ($_.Length -lt 200) { throw "Regression PDF is unexpectedly small: $($_.FullName)" }
    Write-Host "Corpus: $($_.Name) ($($_.Length) bytes)" -ForegroundColor Cyan
}
