param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$carrier = Join-Path $SourceRoot 'dev-patches\400-installer-batch-responsive.ps1'
$text = [IO.File]::ReadAllText($carrier).Replace("`r`n", "`n")
$replacements = @(
  @('  $t=N([IO.File]::ReadAllText($Path)); $o=N $Old', "  `$t = N ([IO.File]::ReadAllText(`$Path))`n  `$o = N `$Old"),
  @('  if(-not $t.Contains($o)){ throw "Target not found: $Label" }', '  if (-not $t.Contains($o)) { throw "Target not found: $Label" }'),
  @('  W $Path ($t.Replace($o,(N $New)))', "  `$replacement = N `$New`n  W `$Path (`$t.Replace(`$o, `$replacement))")
)
foreach ($pair in $replacements) {
  if (-not $text.Contains($pair[0])) { throw "400 carrier helper line not found: $($pair[0])" }
  $text = $text.Replace($pair[0], $pair[1])
}
[IO.File]::WriteAllText($carrier, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
$global:LASTEXITCODE = 0
Write-Host 'Final carrier replacement helper corrected.' -ForegroundColor Green
