param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$carrier = Join-Path $PSScriptRoot '370-accessibility-names.ps1'
$text = [IO.File]::ReadAllText($carrier)
$old = 'function R([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=N([IO.File]::ReadAllText($Path)); $o=N $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; W $Path ($t.Replace($o,(N $New))) }'
$new = 'function R { if ($args.Count -ne 4) { throw "Replace helper expected 4 arguments, got $($args.Count)." }; $Path=[string]$args[0]; $Old=[string]$args[1]; $New=[string]$args[2]; $Label=[string]$args[3]; $t=N([IO.File]::ReadAllText($Path)); $o=N $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; W $Path ($t.Replace($o,(N $New))) }'
if (-not $text.Contains($old)) { throw 'Accessibility helper function anchor not found.' }
$corrected = $text.Replace($old, $new)
$script = [scriptblock]::Create($corrected)
& $script -SourceRoot $SourceRoot
Write-Host 'Accessibility carrier executed through deterministic argument wrapper.' -ForegroundColor Green
