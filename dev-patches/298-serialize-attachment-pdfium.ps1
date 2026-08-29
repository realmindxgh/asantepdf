param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\DocumentAttachmentService.cs'
$text = [System.IO.File]::ReadAllText($path)
$anchor = 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();'
$count = ([regex]::Matches($text, [regex]::Escape($anchor))).Count
if ($count -ne 2) { throw "Expected two attachment runtime anchors, found $count." }
$text = $text.Replace($anchor, 'using var nativeGate = PdfiumNativeGate.Enter(token);')
[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host 'DocumentAttachmentService now uses the process-global PDFium gate.' -ForegroundColor Green
