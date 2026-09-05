param([string]$Root = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = 'Stop'
$violations = @()
Get-ChildItem (Join-Path $Root 'src\PdfRescue.App') -Filter '*.cs' -File -Recurse | ForEach-Object {
    if ($_.Name -eq 'PdfiumNativeGate.cs') { return }
    $text = [System.IO.File]::ReadAllText($_.FullName)
    if ($text -match '\bfpdf(?:view|_doc|_text|_annot|_save)\.' -and $text -notmatch 'PdfiumNativeGate') {
        $violations += $_.FullName
    }
}
if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw 'PDFium serialization contract failed: direct native callers must use PdfiumNativeGate.'
}
Write-Host 'PDFium serialization contract passed.' -ForegroundColor Green