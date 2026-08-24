param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$target = Join-Path $SourceRoot 'dev-patches\160-ocr-configuration-page-scope.ps1'
if (-not (Test-Path $target)) { throw 'OCR configuration patch 160 is missing.' }

$text = [IO.File]::ReadAllText($target).Replace("`r`n", "`n")
$startMarker = '# The remaining configured recognition occurrence belongs to OCR text after the searchable one was replaced.'
$endMarker = '[IO.File]::WriteAllText($backgroundOcrPath, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))'
$start = $text.IndexOf($startMarker, [StringComparison]::Ordinal)
if ($start -lt 0) { throw 'Could not find obsolete OCR cleanup block start in patch 160.' }
$end = $text.IndexOf($endMarker, $start, [StringComparison]::Ordinal)
if ($end -lt 0) { throw 'Could not find obsolete OCR cleanup block end in patch 160.' }
$end += $endMarker.Length
$text = $text.Remove($start, $end - $start).Insert($start, '# OCR text recognition is already converted by the configured-recognition replacement above.')
[IO.File]::WriteAllText($target, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))

& $target -SourceRoot $SourceRoot
if (-not $?) { throw 'OCR configuration patch 160 failed when invoked by the single-carrier shim.' }
Write-Host 'Applied complete OCR configuration through one carrier patch.' -ForegroundColor Green
