param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$carrier = Join-Path $SourceRoot 'dev-patches\400-installer-batch-responsive.ps1'
$text = [IO.File]::ReadAllText($carrier).Replace("`r`n", "`n")
$old = @'
function R([string]$Path,[string]$Old,[string]$New,[string]$Label) {
  $t=N([IO.File]::ReadAllText($Path)); $o=N $Old
  if(-not $t.Contains($o)){ throw "Target not found: $Label" }
  W $Path ($t.Replace($o,(N $New)))
}
'@
$new = @'
function R([string]$Path,[string]$Old,[string]$New,[string]$Label) {
  $t = N ([IO.File]::ReadAllText($Path))
  $o = N $Old
  if (-not $t.Contains($o)) { throw "Target not found: $Label" }
  $replacement = N $New
  W $Path ($t.Replace($o, $replacement))
}
'@
if (-not $text.Contains($old)) { throw '400 carrier helper anchor not found.' }
$text = $text.Replace($old, $new)
[IO.File]::WriteAllText($carrier, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
$global:LASTEXITCODE = 0
Write-Host 'Final carrier replacement helper corrected.' -ForegroundColor Green
