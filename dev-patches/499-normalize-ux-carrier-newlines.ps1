param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$path = Join-Path $SourceRoot 'dev-patches\500-rc49-ux-acceptance-round1.ps1'
if (-not (Test-Path $path)) { throw 'Expected RC49 UX carrier 500 is missing.' }
$text = [IO.File]::ReadAllText($path)
$literal = [string][char]96 + 'r' + [char]96 + 'n'
$count = ([regex]::Matches($text, [regex]::Escape($literal))).Count
if ($count -eq 0) { throw 'Carrier 500 contains no literal CRLF escape sequences to normalize.' }
$text = $text.Replace($literal, "`n")
$oldRead = '    return [IO.File]::ReadAllText($path, $utf8)'
$newRead = '    return [IO.File]::ReadAllText($path, $utf8).Replace("`r`n", "`n")'
if (-not $text.Contains($oldRead)) { throw 'Carrier 500 Read-Text anchor is missing.' }
$text = $text.Replace($oldRead, $newRead)
[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
Write-Host "Normalized $count newline-sensitive sequences and source reads in carrier 500." -ForegroundColor Green
