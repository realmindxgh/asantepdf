param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$carrier = Join-Path $SourceRoot 'dev-patches\400-installer-batch-responsive.ps1'
$text = [IO.File]::ReadAllText($carrier).Replace("`r`n", "`n")

# R is a built-in PowerShell alias for Invoke-History and shadows a function named R.
# Rename the carrier helper and every call before the workflow invokes the carrier.
$text = $text.Replace('function R([string]$Path,[string]$Old,[string]$New,[string]$Label)',
                      'function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label)')
$text = [Text.RegularExpressions.Regex]::Replace($text, '(?m)^R ', 'Replace-Exact ')

# Also expand the helper body into the explicit function-call form that has already proven safe in CI.
$line1 = '  $t=N([IO.File]::ReadAllText($Path)); $o=N $Old'
$line2 = '  if(-not $t.Contains($o)){ throw "Target not found: $Label" }'
$line3 = '  W $Path ($t.Replace($o,(N $New)))'
foreach ($line in @($line1,$line2,$line3)) {
  if (-not $text.Contains($line)) { throw "400 carrier helper line not found: $line" }
}
$text = $text.Replace($line1, "  `$t = N ([IO.File]::ReadAllText(`$Path))`n  `$o = N `$Old")
$text = $text.Replace($line2, '  if (-not $t.Contains($o)) { throw "Target not found: $Label" }')
$text = $text.Replace($line3, "  `$replacement = N `$New`n  W `$Path (`$t.Replace(`$o, `$replacement))")

[IO.File]::WriteAllText($carrier, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
$global:LASTEXITCODE = 0
Write-Host 'Final carrier helper renamed and corrected.' -ForegroundColor Green
