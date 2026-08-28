param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Normalized([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw).Replace("`r`n", "`n")
}

function Write-Normalized([string]$Path, [string]$Text) {
    Set-Content -LiteralPath $Path -Value $Text -Encoding utf8 -NoNewline
}

function Replace-Exact([ref]$Text, [string]$Old, [string]$New, [string]$Label) {
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $Text.Value.Contains($oldN)) { throw "Anchor not found: $Label" }
    $Text.Value = $Text.Value.Replace($oldN, $newN)
}

$appearancePath = Join-Path $SourceRoot 'src/PdfRescue.App/Services/AppearanceService.cs'
$appearance = Read-Normalized $appearancePath
Replace-Exact ([ref]$appearance) @'
    private static readonly ThemeColors Light = new(
        "#F4F7FA", "#FFFFFF", "#F7F9FB", "#FFFFFF", "#E4EBF2", "#D4E0EA", "#AEBFCE", "#17212B", "#53687B");
'@ @'
    private static readonly ThemeColors Light = new(
        "#EEF3F8", "#F8FAFC", "#F5F8FB", "#FFFFFF", "#DCE6F0", "#C9D8E6", "#8EA3B7", "#0F172A", "#3F556B");
'@ 'stronger Light palette'
Replace-Exact ([ref]$appearance) @'
        ["#09131F"] = "#F4F7FA", ["#08111C"] = "#FFFFFF", ["#101C2A"] = "#F7F9FB",
        ["#162333"] = "#FFFFFF", ["#263B50"] = "#E4EBF2", ["#304B64"] = "#D4E0EA",
        ["#36506A"] = "#AEBFCE", ["#F3F7FC"] = "#17212B", ["#B7C5D4"] = "#53687B",
'@ @'
        ["#09131F"] = "#EEF3F8", ["#08111C"] = "#F8FAFC", ["#101C2A"] = "#F5F8FB",
        ["#162333"] = "#FFFFFF", ["#263B50"] = "#DCE6F0", ["#304B64"] = "#C9D8E6",
        ["#36506A"] = "#8EA3B7", ["#F3F7FC"] = "#0F172A", ["#B7C5D4"] = "#3F556B",
'@ 'base Light hard-coded color map'
Replace-Exact ([ref]$appearance) @'
        ["#3A4A59"] = "#A8B7C6", ["#41566C"] = "#8092A3", ["#53677C"] = "#6D7F90",
        ["#54708A"] = "#5B7288", ["#6282A1"] = "#58748D", ["#698096"] = "#596F84",
        ["#6F8399"] = "#637588", ["#71869D"] = "#607488", ["#73879D"] = "#607488",
        ["#7E92A8"] = "#62778C", ["#7192B1"] = "#536F88", ["#7990A7"] = "#5E7489"
'@ @'
        ["#3A4A59"] = "#52677A", ["#41566C"] = "#4A6074", ["#53677C"] = "#455B70",
        ["#54708A"] = "#405970", ["#6282A1"] = "#46617B", ["#698096"] = "#435D75",
        ["#6F8399"] = "#40586F", ["#71869D"] = "#3E576E", ["#73879D"] = "#3E576E",
        ["#7E92A8"] = "#425C73", ["#7192B1"] = "#3B5871", ["#7990A7"] = "#3F5B73",
        ["#80B9FF"] = "#185D9C", ["#4D9BFF"] = "#155DA8", ["#627B94"] = "#455F77",
        ["#7890A8"] = "#405A72"
'@ 'secondary text Light color map'
Write-Normalized $appearancePath $appearance

$appXamlPath = Join-Path $SourceRoot 'src/PdfRescue.App/App.xaml'
$appXaml = Read-Normalized $appXamlPath
if (-not $appXaml.Contains('Value="0.58"')) { throw 'Expected disabled-opacity tokens were not found in App.xaml.' }
$appXaml = $appXaml.Replace('Value="0.58"', 'Value="0.72"')
$appXaml = $appXaml.Replace('Value="0.42"', 'Value="0.62"')
Write-Normalized $appXamlPath $appXaml

$viewModesPath = Join-Path $SourceRoot 'src/PdfRescue.App/MainWindow.ViewModes.cs'
$viewModes = Read-Normalized $viewModesPath
Replace-Exact ([ref]$viewModes) @'
    private int _pageViewGeneration;
    private bool _syncingPageViewSelection;
'@ @'
    private int _pageViewGeneration;
    private bool _syncingPageViewSelection;
    private bool _loadingDocument;
'@ 'document-loading guard field'
Replace-Exact ([ref]$viewModes) @'
        Pages.CollectionChanged += (_, _) =>
        {
            if (_activePageViewMode == DefaultPageViewMode.Continuous) RebuildContinuousPageItems();
            else if (_activePageViewMode == DefaultPageViewMode.TwoPage && _currentPdf is not null) _ = RenderTwoPageAsync();
        };
'@ @'
        Pages.CollectionChanged += (_, _) =>
        {
            if (_loadingDocument) return;
            if (_activePageViewMode == DefaultPageViewMode.Continuous) RebuildContinuousPageItems();
            else if (_activePageViewMode == DefaultPageViewMode.TwoPage && _currentPdf is not null) _ = RenderTwoPageAsync();
        };
'@ 'suppress page-view churn while loading a document'
Replace-Exact ([ref]$viewModes) @'
    private async Task RefreshActivePageViewAsync(bool forceRerender = false)
    {
        if (_currentPdf is null || Pages.Count == 0) { ApplyPageViewVisibility(); return; }
'@ @'
    private async Task RefreshActivePageViewAsync(bool forceRerender = false)
    {
        if (_loadingDocument) return;
        if (_currentPdf is null || Pages.Count == 0) { ApplyPageViewVisibility(); return; }
'@ 'do not refresh active view mid-open'
Replace-Exact ([ref]$viewModes) @'
    private async Task RenderSelectedPageForActiveViewAsync(PdfPageItem page)
    {
        if (_currentPdf is null) return;
'@ @'
    private async Task RenderSelectedPageForActiveViewAsync(PdfPageItem page)
    {
        if (_loadingDocument || _currentPdf is null) return;
'@ 'do not render selection mid-open'
Write-Normalized $viewModesPath $viewModes

$mainPath = Join-Path $SourceRoot 'src/PdfRescue.App/MainWindow.xaml.cs'
$main = Read-Normalized $mainPath
Replace-Exact ([ref]$main) @'
            _undo.Clear();
            _redo.Clear();
            _thumbnailCache.Clear();
            Pages.Clear();

            var count = checked((int)_renderer.PageCount);
            if (count < 1)
                throw new InvalidDataException("This PDF contains no pages.");

            for (var i = 1; i <= count; i++)
                Pages.Add(new PdfPageItem(i, i));

            _savedLayoutBaseline = CaptureLayout();
'@ @'
            _undo.Clear();
            _redo.Clear();
            _thumbnailCache.Clear();

            var count = checked((int)_renderer.PageCount);
            if (count < 1)
                throw new InvalidDataException("This PDF contains no pages.");

            _loadingDocument = true;
            try
            {
                Pages.Clear();
                for (var i = 1; i <= count; i++)
                    Pages.Add(new PdfPageItem(i, i));
            }
            finally
            {
                _loadingDocument = false;
            }

            _savedLayoutBaseline = CaptureLayout();
'@ 'bulk-load Pages without view churn'
Replace-Exact ([ref]$main) @'
            PagesList.SelectedIndex = 0;
            await RenderPreviewAsync(Pages[0]);
            StatusText.Text = "PDF opened locally. Changes remain non-destructive until Save As.";
            App.Log($"Opened PDF: {fi.Name}, {count} pages.");
'@ @'
            _loadingDocument = true;
            try
            {
                PagesList.SelectedIndex = 0;
            }
            finally
            {
                _loadingDocument = false;
            }
            StatusText.Text = "PDF opened locally. Changes remain non-destructive until Save As.";
            App.Log($"Opened PDF model: {fi.Name}, {count} pages. Foreground render pending.");
'@ 'defer first render until document model is settled'
Replace-Exact ([ref]$main) @'
        UpdateCommandStates();
        StartThumbnailRendering(_documentGeneration);
        await RefreshActivePageViewAsync();
'@ @'
        UpdateCommandStates();
        App.Log("Open PDF foreground view refresh started.");
        await RefreshActivePageViewAsync();
        App.Log("Opened PDF: foreground view refresh completed.");
        StartThumbnailRendering(_documentGeneration);
'@ 'render foreground before thumbnails'
Write-Normalized $mainPath $main

$productPath = Join-Path $SourceRoot 'src/PdfRescue.App/MainWindow.ProductShell.cs'
$product = Read-Normalized $productPath
Replace-Exact ([ref]$product) @'
    private void ProductShell_PagesSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (PageNumberBox is null || PageCountText is null) return;
'@ @'
    private void ProductShell_PagesSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loadingDocument) return;
        if (PageNumberBox is null || PageCountText is null) return;
'@ 'suppress persistence while loading pages'
Write-Normalized $productPath $product

$verifyPath = Join-Path $SourceRoot 'scripts/verify-installed-release.ps1'
$verify = Read-Normalized $verifyPath
Replace-Exact ([ref]$verify) @'
$logDir = Join-Path $env:LOCALAPPDATA 'AsantePDF\Logs'
$readyFlag = Join-Path $logDir 'window-ready.flag'
Remove-Item $readyFlag -Force -ErrorAction SilentlyContinue

Write-Host 'Launching the installed copy and checking the WPF ready flag...' -ForegroundColor Cyan
$app = Start-Process -FilePath $installedExe -PassThru
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path $readyFlag) { $ready = $true; break }
    if ($app.HasExited) { break }
}
if (-not $ready) {
    if (Test-Path (Join-Path $logDir 'startup.log')) { Get-Content (Join-Path $logDir 'startup.log') | Write-Host }
    try { if (-not $app.HasExited) { $app.Kill() } } catch { }
    throw 'Installed AsantePDF did not reach its main-window ready state.'
}
try { if (-not $app.HasExited) { $app.Kill() } } catch { }
'@ @'
$settingsRoot = Join-Path $env:LOCALAPPDATA 'AsantePDF'
New-Item -ItemType Directory -Force -Path $settingsRoot | Out-Null
@{
    theme = 'Light'
    defaultRenderWidth = 1100
    defaultPageView = 'SinglePage'
    reopenLastSession = $false
    trackRecentFiles = $false
    showRecentThumbnails = $false
    defaultOcrLanguage = 'eng'
    defaultOutputFolder = ''
    outputNamePattern = '{name}-{operation}'
    existingOutput = 'CreateUniqueCopy'
    recoveryEnabled = $false
    checkForUpdates = $false
    firstLaunchCompleted = $true
} | ConvertTo-Json | Set-Content (Join-Path $settingsRoot 'settings.json') -Encoding UTF8

$logDir = Join-Path $settingsRoot 'Logs'
$readyFlag = Join-Path $logDir 'window-ready.flag'
$startupLog = Join-Path $logDir 'startup.log'
Remove-Item $logDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host 'Launching the installed copy in Light mode, opening a PDF, and checking that the normal UI remains alive...' -ForegroundColor Cyan
$app = Start-Process -FilePath $installedExe -ArgumentList @($sample) -PassThru
$ready = $false
$opened = $false
for ($i = 0; $i -lt 80; $i++) {
    Start-Sleep -Milliseconds 500
    $app.Refresh()
    if (Test-Path $readyFlag) { $ready = $true }
    if (Test-Path $startupLog) {
        $log = Get-Content $startupLog -Raw
        if ($log -match 'Opened PDF:') { $opened = $true }
    }
    if ($app.HasExited -or ($ready -and $opened)) { break }
}
if (-not $ready -or -not $opened -or $app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    try { if (-not $app.HasExited) { $app.Kill() } } catch { }
    throw "Installed AsantePDF failed the normal Light-mode PDF-open UI regression. Ready=$ready Opened=$opened Exited=$($app.HasExited)."
}
Start-Sleep -Seconds 3
$app.Refresh()
if ($app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    throw "Installed AsantePDF opened the PDF but then exited unexpectedly with code $($app.ExitCode)."
}
try { $app.Kill() } catch { }
'@ 'installed-copy normal UI PDF-open regression'
Write-Normalized $verifyPath $verify

Write-Host 'Staged Light-mode contrast and PDF-open stability repairs.' -ForegroundColor Green
