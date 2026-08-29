param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }
function Replace-Exact([string]$text, [string]$old, [string]$new, [string]$label) {
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    if (-not $text.Contains($old)) { throw "Could not locate $label." }
    return $text.Replace($old, $new)
}

$appPath = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml.cs'
$app = Read-Lf $appPath
$app = Replace-Exact $app @'
                _ = RunThemeRuntimeSelfTestAsync(e.Args[1]);
'@ @'
                _ = RunThemeRuntimeSelfTestAsync(e.Args[1], e.Args.Length >= 3 ? e.Args[2] : null);
'@ 'theme self-test invocation'
$app = Replace-Exact $app @'
    private async Task RunThemeRuntimeSelfTestAsync(string outputDirectory)
    {
        try
        {
            Log("Theme runtime self-test started.");
            await ThemeRuntimeSelfTest.RunAsync(outputDirectory);
'@ @'
    private async Task RunThemeRuntimeSelfTestAsync(string outputDirectory, string? samplePdf)
    {
        try
        {
            Log("Theme runtime self-test started.");
            await ThemeRuntimeSelfTest.RunAsync(outputDirectory, samplePdf);
'@ 'theme self-test method signature'
Write-Lf $appPath $app

$testPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\ThemeRuntimeSelfTest.cs'
$test = Read-Lf $testPath
$test = Replace-Exact $test @'
    public static async Task RunAsync(string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);
        await VerifyRecentFilesControlsAsync(outputDirectory);
        await VerifyWholeShellAsync(outputDirectory);
        File.WriteAllText(Path.Combine(outputDirectory, "theme-runtime-pass.flag"), DateTimeOffset.Now.ToString("O"));
    }
'@ @'
    public static async Task RunAsync(string outputDirectory, string? samplePdf = null)
    {
        Directory.CreateDirectory(outputDirectory);
        await VerifyRecentFilesControlsAsync(outputDirectory);
        await VerifySettingsAndTaskCenterAsync(outputDirectory);
        await VerifyWholeShellAsync(outputDirectory, samplePdf);
        File.WriteAllText(Path.Combine(outputDirectory, "theme-runtime-pass.flag"), DateTimeOffset.Now.ToString("O"));
    }
'@ 'theme test entry point'

$test = Replace-Exact $test @'
            Capture(host, Path.Combine(outputDirectory, "recent-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
'@ @'
            Capture(host, Path.Combine(outputDirectory, "recent-grid-light.png"));

            list.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-list-light.png"));
            compact.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-compact-light.png"));
            grid.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();

            AppearanceService.Apply(AppThemeMode.Dark);
'@ 'recent Light layout captures'

$test = Replace-Exact $test @'
            AssertBrush(sort.Foreground, "#F3F7FC", "Dark sort text");
            Capture(host, Path.Combine(outputDirectory, "recent-dark.png"));
        }
'@ @'
            AssertBrush(sort.Foreground, "#F3F7FC", "Dark sort text");
            Capture(host, Path.Combine(outputDirectory, "recent-grid-dark.png"));
            list.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-list-dark.png"));
            compact.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-compact-dark.png"));
        }
'@ 'recent Dark layout captures'

$insertMarker = '    private static async Task VerifyWholeShellAsync(string outputDirectory)'
if (-not $test.Contains($insertMarker)) { throw 'Could not locate whole-shell method marker.' }
$surfaceMethod = @'
    private static async Task VerifySettingsAndTaskCenterAsync(string outputDirectory)
    {
        var recentService = new RecentDocumentService();
        var settings = new SettingsWindow(AppSettingsService.Current.Preferences, recentService)
        {
            ShowInTaskbar = false,
            Left = -12000,
            Top = -12000
        };

        try
        {
            settings.Show();
            await RenderCycleAsync();
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(settings);
            await RenderCycleAsync();
            WriteContrastReport(settings, Path.Combine(outputDirectory, "contrast-settings-light.txt"), "Settings Light");
            Capture(settings, Path.Combine(outputDirectory, "settings-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(settings);
            await RenderCycleAsync();
            WriteContrastReport(settings, Path.Combine(outputDirectory, "contrast-settings-dark.txt"), "Settings Dark");
            Capture(settings, Path.Combine(outputDirectory, "settings-dark.png"));
        }
        finally
        {
            settings.Close();
        }

        var taskHost = new Window
        {
            Width = 1040,
            Height = 760,
            ShowInTaskbar = false,
            WindowStyle = WindowStyle.None,
            Left = -12000,
            Top = -12000,
            Content = new TaskCenterView(new TaskCenterService())
        };

        try
        {
            taskHost.Show();
            await RenderCycleAsync();
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(taskHost);
            await RenderCycleAsync();
            WriteContrastReport(taskHost, Path.Combine(outputDirectory, "contrast-task-center-light.txt"), "Task Center Light");
            Capture(taskHost, Path.Combine(outputDirectory, "task-center-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(taskHost);
            await RenderCycleAsync();
            WriteContrastReport(taskHost, Path.Combine(outputDirectory, "contrast-task-center-dark.txt"), "Task Center Dark");
            Capture(taskHost, Path.Combine(outputDirectory, "task-center-dark.png"));
        }
        finally
        {
            taskHost.Close();
        }
    }

'@
$test = $test.Replace($insertMarker, $surfaceMethod + '    private static async Task VerifyWholeShellAsync(string outputDirectory, string? samplePdf)')

$workspaceAnchor = @'
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark-roundtrip.txt"), "Dark round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-dark-roundtrip.png"));
        }
'@
$workspaceReplacement = @'
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark-roundtrip.txt"), "Dark round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-dark-roundtrip.png"));

            if (!string.IsNullOrWhiteSpace(samplePdf) && File.Exists(samplePdf))
            {
                AppearanceService.Apply(AppThemeMode.Light);
                AppearanceService.ApplyToWindow(window);
                await window.OpenPdfFromCommandLineAsync(samplePdf);
                await RenderCycleAsync();
                WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-workspace-light.txt"), "Workspace Light");
                Capture(window, Path.Combine(outputDirectory, "workspace-light.png"));

                AppearanceService.Apply(AppThemeMode.Dark);
                AppearanceService.ApplyToWindow(window);
                await RenderCycleAsync();
                WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-workspace-dark.txt"), "Workspace Dark");
                Capture(window, Path.Combine(outputDirectory, "workspace-dark.png"));

                AppearanceService.Apply(AppThemeMode.Light);
                AppearanceService.ApplyToWindow(window);
                await RenderCycleAsync();
                WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-workspace-light-roundtrip.txt"), "Workspace Light round-trip");
                Capture(window, Path.Combine(outputDirectory, "workspace-light-roundtrip.png"));
            }
        }
'@
$test = Replace-Exact $test $workspaceAnchor $workspaceReplacement 'workspace theme captures'
Write-Lf $testPath $test

Write-Host 'Expanded theme evidence to Recent layouts, Settings, Task Center, and optional document workspace.' -ForegroundColor Green
