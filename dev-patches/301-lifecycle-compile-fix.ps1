param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

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

$path = Join-Path $SourceRoot 'src\PdfRescue.App\LifecycleWindows.cs'
Replace-Exact $path @'
        var actions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Left };
        var check = new Button { Content = "Check for updates", Style = (Style)FindResource("PrimaryButtonStyle") };
        check.Click += async (_, _) => await CheckUpdatesAsync();
        var release = new Button { Content = "Open update page", Style = (Style)FindResource("FlatButtonStyle"), IsEnabled = false };
        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
'@ @'
        var actions = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Left };
        var release = new Button { Content = "Open update page", Style = (Style)FindResource("FlatButtonStyle"), IsEnabled = false };
        release.Click += (_, _) => { if (_availableUpdate is not null) UpdateService.OpenRelease(_availableUpdate); };
        var check = new Button { Content = "Check for updates", Style = (Style)FindResource("PrimaryButtonStyle") };
        check.Click += async (_, _) => await CheckUpdatesAsync();
'@ 'diagnostics update button definite assignment'

Write-Host 'Lifecycle compile fix staged.' -ForegroundColor Green
