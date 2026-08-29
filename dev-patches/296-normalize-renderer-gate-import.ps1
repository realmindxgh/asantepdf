param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$rendererPath = Join-Path $SourceRoot 'src\PdfRescue.App\PdfiumPdfRenderer.cs'
$text = [System.IO.File]::ReadAllText($rendererPath)
if (-not $text.Contains('using PdfRescue.App.Services;')) {
    $updated = [regex]::Replace($text, 'using PDFiumCore;\r?\n', "using PDFiumCore;`r`nusing PdfRescue.App.Services;`r`n", 1)
    if ($updated -eq $text) { throw 'Could not locate PDFiumCore using directive in renderer.' }
    [System.IO.File]::WriteAllText($rendererPath, $updated, [System.Text.UTF8Encoding]::new($false))
}

# The older corrective carrier assumed LF line endings. Replace it with an idempotent
# no-op because this carrier has already performed the import robustly.
$oldCarrier = Join-Path $SourceRoot 'dev-patches\297-import-pdfium-native-gate.ps1'
$noop = @'
param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)
Write-Host 'Renderer gate import already normalized by carrier 296.' -ForegroundColor Green
'@
[System.IO.File]::WriteAllText($oldCarrier, $noop, [System.Text.UTF8Encoding]::new($false))
Write-Host 'PdfiumPdfRenderer imports the shared native gate using line-ending-agnostic patching.' -ForegroundColor Green
