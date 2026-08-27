param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$patchRoot = Join-Path $SourceRoot 'dev-patches'
& (Join-Path $patchRoot '300-lifecycle-recovery-diagnostics.ps1') -SourceRoot $SourceRoot
if (-not $?) { throw 'Lifecycle feature carrier failed.' }
& (Join-Path $patchRoot '301-lifecycle-compile-fix.ps1') -SourceRoot $SourceRoot
if (-not $?) { throw 'Lifecycle compile-fix carrier failed.' }

Write-Host 'Lifecycle batch applied in deterministic order.' -ForegroundColor Green
