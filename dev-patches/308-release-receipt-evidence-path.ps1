param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$path = Join-Path $SourceRoot 'scripts\write-release-receipt.ps1'
$text = Read-Lf $path

$old = @'
$installedFlag = Join-Path $root 'dist\selftest-installed\final-candidate-pass.flag'
'@.Trim()
$new = @'
$installedFlagCandidates = @(
    (Join-Path $root 'dist\selftest-installed\final-selftest\final-candidate-pass.flag'),
    (Join-Path $root 'dist\selftest-installed\final-candidate-pass.flag')
)
$installedFlag = $installedFlagCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $installedFlag) {
    $installedFlag = $installedFlagCandidates[0]
}
'@.Replace("`r`n", "`n").TrimEnd()
if (-not $text.Contains($old)) { throw 'Installed release evidence flag anchor not found.' }
$text = $text.Replace($old, $new)

$text = $text.Replace('- selftest-installed/final-candidate-pass.flag = pass', '- selftest-installed/final-selftest/final-candidate-pass.flag = pass')
$oldReceiptLine = '- installed-copy final candidate functional self-test'
$newReceiptLines = @'
- installed-copy Light/Dark visual, DPI, representative-PDF and restart/Resume acceptance
- installed-copy final candidate functional self-test
'@.Replace("`r`n", "`n").TrimEnd()
if (-not $text.Contains($oldReceiptLine)) { throw 'Installed receipt summary anchor not found.' }
$text = $text.Replace($oldReceiptLine, $newReceiptLines)

Write-Lf $path $text
Write-Host 'Release receipt now resolves the installed final-selftest evidence path and records expanded installed acceptance.' -ForegroundColor Green
