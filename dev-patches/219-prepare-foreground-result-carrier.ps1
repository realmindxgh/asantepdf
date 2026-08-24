param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

$target = Join-Path $SourceRoot 'dev-patches\220-foreground-result-workflows.ps1'
if (-not (Test-Path $target)) { throw 'Foreground completion carrier is missing.' }

$text = [IO.File]::ReadAllText($target)
$old = @'
function N([string]$s){$s.Replace("`r`n","`n")}
function W([string]$p,[string]$s){[IO.File]::WriteAllText($p,(N $s).Replace("`n","`r`n"),[Text.UTF8Encoding]::new($false))}
function R([string]$p,[string]$old,[string]$new,[string]$label){$t=N([IO.File]::ReadAllText($p));$o=N $old;$n=N $new;if(-not $t.Contains($o)){throw "Target not found: $label"};W $p ($t.Replace($o,$n))}
'@
$new = @'
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}
Set-Alias -Name R -Value Replace-Exact -Scope Script
'@
if (-not $text.Contains($old)) { throw 'Could not find compact helper block in foreground carrier.' }
$text = $text.Replace($old, $new)
$text += @'

# Restore this tracked carrier after it runs so Windows promotion can remove dev-patches cleanly.
Push-Location $SourceRoot
try {
    git checkout -- dev-patches/220-foreground-result-workflows.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Could not restore foreground completion carrier.' }
}
finally { Pop-Location }
'@
[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
Write-Host 'Prepared foreground carrier with robust PowerShell helpers.' -ForegroundColor Green
& cmd /c exit 0
