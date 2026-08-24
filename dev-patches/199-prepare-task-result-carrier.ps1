param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$target = Join-Path $SourceRoot 'dev-patches\200-task-result-completion.ps1'
if (-not (Test-Path $target)) { throw 'Main item-19 carrier is missing.' }
$text = [IO.File]::ReadAllText($target)
$replacements = @(
    @("'^\\| 17 \\|.*$'", "'^\\| 17 \\|[^\\n]*$'"),
    @("'^\\| 18 \\|.*$'", "'^\\| 18 \\|[^\\n]*$'"),
    @("'^\\| 43 \\|.*$'", "'^\\| 43 \\|[^\\n]*$'")
)
foreach ($pair in $replacements) {
    if (-not $text.Contains($pair[0])) { throw "Could not find regex carrier target $($pair[0])" }
    $text = $text.Replace($pair[0], $pair[1])
}
$text += @'

# Restore the tracked carrier before returning so promotion can remove dev-patches cleanly.
Push-Location $SourceRoot
try {
    git checkout -- dev-patches/200-task-result-completion.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Could not restore the staged main carrier.' }
}
finally { Pop-Location }
exit 0
'@
[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
Write-Host 'Prepared corrected item-19 carrier with one-line ledger regexes.' -ForegroundColor Green
exit 0
