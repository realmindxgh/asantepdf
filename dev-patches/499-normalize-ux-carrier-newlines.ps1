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
$oldHelper = @'
function Replace-Exact([string]$text, [string]$old, [string]$new, [string]$label) {
    if (-not $text.Contains($old)) { throw "Anchor not found: $label" }
    return $text.Replace($old, $new)
}
'@
$newHelper = @'
function Replace-Exact([string]$text, [string]$old, [string]$new, [string]$label) {
    $text = $text.Replace("`r`n", "`n")
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    if (-not $text.Contains($old)) { throw "Anchor not found: $label" }
    return $text.Replace($old, $new)
}
'@
if (-not $text.Contains($oldHelper)) { throw 'Carrier 500 Replace-Exact helper anchor is missing.' }
$text = $text.Replace($oldHelper, $newHelper)
[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
Write-Host "Normalized $count newline-sensitive sequences, source reads and multiline anchors in carrier 500." -ForegroundColor Green
