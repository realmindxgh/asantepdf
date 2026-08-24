param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$sourcePatch = Join-Path $SourceRoot 'dev-patches\170-complete-config-dialogs.ps1'
if (-not (Test-Path $sourcePatch)) { throw 'Advanced configuration patch 170 is missing.' }

$text = [IO.File]::ReadAllText($sourcePatch)
$old = 'using PdfRescue.Core.Jobs;'
$new = 'using PdfRescue.Core.Models;'
if (-not $text.Contains($old)) { throw 'Could not find the PdfJobType namespace import in patch 170.' }
$text = $text.Replace($old, $new)

$tempPatch = Join-Path $env:RUNNER_TEMP 'asantepdf-config-170-fixed.ps1'
[IO.File]::WriteAllText($tempPatch, $text, [Text.UTF8Encoding]::new($false))
try {
    & $tempPatch -SourceRoot $SourceRoot
    if (-not $?) { throw 'Corrected advanced configuration patch failed.' }
}
finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $tempPatch
}

Write-Host 'Applied advanced configuration patch with corrected PdfJobType namespace.' -ForegroundColor Green
