param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\PdfiumPdfRenderer.cs'
$text = [System.IO.File]::ReadAllText($path)
$anchor = "using PDFiumCore;`n"
if (-not $text.Contains($anchor)) { throw 'Could not find PDFiumCore import in PdfiumPdfRenderer.cs.' }
if (-not $text.Contains('using PdfRescue.App.Services;')) {
    $text = $text.Replace($anchor, $anchor + "using PdfRescue.App.Services;`n")
}
[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host 'PdfiumPdfRenderer imports the shared native gate.' -ForegroundColor Green
