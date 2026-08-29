param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$servicePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\LifecycleRestartSelfTest.cs'
$service = @'
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace PdfRescue.App.Services;

internal static class LifecycleRestartSelfTest
{
    public static async Task RunAndShutdownAsync(bool seed, string firstPdf, string secondPdf, string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);
        try
        {
            if (!File.Exists(firstPdf)) throw new FileNotFoundException("Lifecycle first PDF is missing.", firstPdf);
            if (!File.Exists(secondPdf)) throw new FileNotFoundException("Lifecycle second PDF is missing.", secondPdf);

            if (seed)
                await RunSeedAsync(Path.GetFullPath(firstPdf), Path.GetFullPath(secondPdf), outputDirectory);
            else
                await RunVerifyAsync(Path.GetFullPath(firstPdf), Path.GetFullPath(secondPdf), outputDirectory);

            File.WriteAllText(Path.Combine(outputDirectory, seed ? "lifecycle-seed-pass.flag" : "lifecycle-verify-pass.flag"), "pass");
            App.Log(seed ? "Lifecycle restart seed self-test passed." : "Lifecycle restart verification self-test passed.");
            Application.Current.Shutdown(0);
        }
        catch (Exception ex)
        {
            App.Log("Lifecycle restart self-test failed: " + ex);
            try { File.WriteAllText(Path.Combine(outputDirectory, "lifecycle-restart-error.txt"), ex.ToString()); } catch { }
            Application.Current.Shutdown(seed ? 8 : 9);
        }
    }

    private static async Task RunSeedAsync(string firstPdf, string secondPdf, string outputDirectory)
    {
        var recent = new RecentDocumentService();
        recent.ClearHistory();
        recent.ClearLastSession();
        recent.ClearThumbnailCache();

        AppSettingsService.Current.Save(new AppPreferences
        {
            Theme = AppThemeMode.Light,
            DefaultRenderWidth = 1100,
            DefaultPageView = DefaultPageViewMode.SinglePage,
            ReopenLastSession = true,
            TrackRecentFiles = true,
            ShowRecentThumbnails = true,
            DefaultOcrLanguage = "eng",
            RecoveryEnabled = false,
            CheckForUpdates = false,
            FirstLaunchCompleted = false
        });
        AppearanceService.Apply(AppThemeMode.Light);

        var onboardingClicked = false;
        var onboardingTimer = new DispatcherTimer(DispatcherPriority.Send)
        {
            Interval = TimeSpan.FromMilliseconds(100)
        };
        onboardingTimer.Tick += (_, _) =>
        {
            var onboarding = Application.Current.Windows.OfType<FirstLaunchWindow>().FirstOrDefault(window => window.IsVisible);
            if (onboarding is null) return;
            var start = Descendants(onboarding).OfType<Button>()
                .FirstOrDefault(button => string.Equals(button.Content?.ToString(), "Start using AsantePDF", StringComparison.Ordinal));
            if (start is null) return;
            onboardingClicked = true;
            start.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            onboardingTimer.Stop();
        };
        onboardingTimer.Start();

        var window = CreateHostWindow();
        Application.Current.MainWindow = window;
        window.Show();
        await WaitUntilAsync(() => onboardingClicked && AppSettingsService.Current.Preferences.FirstLaunchCompleted,
            TimeSpan.FromSeconds(15), "The real first-launch dialog was not completed and persisted.");

        await window.OpenPdfFromCommandLineAsync(firstPdf);
        await WaitUntilAsync(() => window.DocumentTabs.Count >= 1, TimeSpan.FromSeconds(30), "First lifecycle PDF did not open as a tab.");
        await window.OpenPdfFromCommandLineAsync(secondPdf);
        await WaitUntilAsync(() => window.DocumentTabs.Count >= 2, TimeSpan.FromSeconds(45), "Second lifecycle PDF did not open as a second tab.");

        if (window.FindName("PagesList") is not ListBox pages || pages.Items.Count < 3)
            throw new InvalidOperationException("Lifecycle seed could not access at least three pages in the active PDF.");
        pages.SelectedIndex = 2;
        await RenderCycleAsync();

        if (window.FindName("ThemeToggleButton") is not Button themeToggle || !themeToggle.IsEnabled)
            throw new InvalidOperationException("Lifecycle seed could not access the real theme toggle.");
        themeToggle.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        await RenderCycleAsync();
        if (AppSettingsService.Current.Preferences.Theme != AppThemeMode.Dark)
            throw new InvalidOperationException("The real theme toggle did not persist Dark mode.");

        window.Close();
        await RenderCycleAsync();

        var session = recent.GetLastSession() ?? throw new InvalidOperationException("Clean shutdown did not persist a resumable session.");
        if (session.Documents.Count != 2)
            throw new InvalidOperationException($"Expected two persisted session tabs, found {session.Documents.Count}.");
        if (session.ActiveDocumentIndex != 1)
            throw new InvalidOperationException($"Expected second tab to remain active, got index {session.ActiveDocumentIndex}.");
        if (session.Documents[1].PageNumber != 3)
            throw new InvalidOperationException($"Expected page 3 to persist for the active tab, got page {session.Documents[1].PageNumber}.");
        if (recent.LoadItems().Count < 2)
            throw new InvalidOperationException("Recent history did not persist both lifecycle PDFs.");

        File.WriteAllLines(Path.Combine(outputDirectory, "lifecycle-seed-state.txt"),
        [
            "first-launch-completed=true",
            "theme=Dark",
            $"recent-count={recent.LoadItems().Count}",
            $"session-tabs={session.Documents.Count}",
            $"active-index={session.ActiveDocumentIndex}",
            $"active-page={session.Documents[1].PageNumber}"
        ]);
    }

    private static async Task RunVerifyAsync(string firstPdf, string secondPdf, string outputDirectory)
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (!preferences.FirstLaunchCompleted)
            throw new InvalidOperationException("FirstLaunchCompleted did not survive a real process restart.");
        if (preferences.Theme != AppThemeMode.Dark)
            throw new InvalidOperationException($"Theme preference did not survive restart. Expected Dark, got {preferences.Theme}.");

        var recent = new RecentDocumentService();
        var beforeResume = recent.GetLastSession() ?? throw new InvalidOperationException("The saved session did not survive restart.");
        if (beforeResume.Documents.Count != 2 || beforeResume.ActiveDocumentIndex != 1 || beforeResume.Documents[1].PageNumber != 3)
            throw new InvalidOperationException("The persisted two-tab/page-3 session state changed across restart.");
        if (recent.LoadItems().Count < 2)
            throw new InvalidOperationException("Recent history did not survive restart.");

        var unexpectedOnboarding = false;
        var onboardingWatch = new DispatcherTimer(DispatcherPriority.Send)
        {
            Interval = TimeSpan.FromMilliseconds(100)
        };
        onboardingWatch.Tick += (_, _) =>
        {
            var onboarding = Application.Current.Windows.OfType<FirstLaunchWindow>().FirstOrDefault(window => window.IsVisible);
            if (onboarding is null) return;
            unexpectedOnboarding = true;
            onboarding.Close();
            onboardingWatch.Stop();
        };
        onboardingWatch.Start();

        var window = CreateHostWindow();
        Application.Current.MainWindow = window;
        window.Show();
        await RenderCycleAsync();
        await Task.Delay(900);
        await RenderCycleAsync();
        onboardingWatch.Stop();
        if (unexpectedOnboarding)
            throw new InvalidOperationException("First-launch onboarding recurred after it had already been completed.");

        var recentView = Descendants(window).OfType<RecentFilesView>().FirstOrDefault()
            ?? throw new InvalidOperationException("The real Home Recent view was not created after restart.");
        await recentView.RefreshAsync();
        await RenderCycleAsync();

        var resume = recentView.FindName("ResumeSessionButton") as Button
            ?? throw new InvalidOperationException("Resume session control was not found in the real Recent view.");
        var recentItems = recentView.FindName("RecentItems") as ItemsControl
            ?? throw new InvalidOperationException("Recent items control was not found.");
        if (resume.Visibility != Visibility.Visible || !resume.IsEnabled)
            throw new InvalidOperationException("Resume session is not visible and enabled for the valid persisted session.");
        if (recentItems.Items.Count < 2)
            throw new InvalidOperationException($"Expected populated Recent view after restart, found {recentItems.Items.Count} item(s).");

        var grid = RequireButton(recentView, "GridViewButton");
        var list = RequireButton(recentView, "ListViewButton");
        var compact = RequireButton(recentView, "CompactViewButton");
        list.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        await RenderCycleAsync();
        if (recent.PreferredView != RecentViewMode.List) throw new InvalidOperationException("List Recent mode did not persist.");
        compact.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        await RenderCycleAsync();
        if (recent.PreferredView != RecentViewMode.Compact) throw new InvalidOperationException("Compact Recent mode did not persist.");
        grid.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        await RenderCycleAsync();
        if (recent.PreferredView != RecentViewMode.Grid) throw new InvalidOperationException("Grid Recent mode did not persist.");

        resume.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        await WaitUntilAsync(() => window.DocumentTabs.Count >= 2, TimeSpan.FromSeconds(75), "Resume did not restore both PDF tabs.");
        await RenderCycleAsync();

        var openPaths = window.DocumentTabs.Select(tab => Path.GetFullPath(tab.Path)).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (!openPaths.Contains(firstPdf) || !openPaths.Contains(secondPdf))
            throw new InvalidOperationException("Resume restored the wrong document set.");
        if (window.FindName("PagesList") is not ListBox pages || pages.SelectedIndex != 2)
            throw new InvalidOperationException("Resume did not restore page 3 on the active second tab.");

        window.Close();
        await RenderCycleAsync();

        File.WriteAllLines(Path.Combine(outputDirectory, "lifecycle-verify-state.txt"),
        [
            "first-launch-recurred=false",
            "theme-after-restart=Dark",
            $"recent-count={recent.LoadItems().Count}",
            "resume-visible=true",
            "grid-list-compact=true",
            $"restored-tabs={openPaths.Count}",
            "restored-active-page=3"
        ]);
    }

    private static MainWindow CreateHostWindow() => new()
    {
        Width = 1280,
        Height = 760,
        ShowInTaskbar = false,
        Left = -12000,
        Top = -12000
    };

    private static Button RequireButton(FrameworkElement root, string name)
    {
        var button = root.FindName(name) as Button;
        if (button is null || button.Visibility != Visibility.Visible || !button.IsEnabled)
            throw new InvalidOperationException($"Required Recent control {name} is not visible and enabled.");
        return button;
    }

    private static async Task WaitUntilAsync(Func<bool> predicate, TimeSpan timeout, string failure)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            await RenderCycleAsync();
            if (predicate()) return;
            await Task.Delay(100);
        }
        throw new TimeoutException(failure);
    }

    private static async Task RenderCycleAsync()
    {
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.DataBind);
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Loaded);
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);
    }

    private static IEnumerable<DependencyObject> Descendants(DependencyObject root)
    {
        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            yield return child;
            foreach (var descendant in Descendants(child)) yield return descendant;
        }
    }
}
'@
Write-Lf $servicePath $service

$appPath = Join-Path $SourceRoot 'src\PdfRescue.App\App.xaml.cs'
$app = Read-Lf $appPath
$themeAnchor = '            if (e.Args.Length >= 2 && string.Equals(e.Args[0], "--selftest-theme", StringComparison.OrdinalIgnoreCase))'
if (-not $app.Contains($themeAnchor)) { throw 'Theme self-test branch anchor not found.' }
if (-not $app.Contains('--selftest-lifecycle-seed')) {
$branches = @'
            if (e.Args.Length >= 4 && string.Equals(e.Args[0], "--selftest-lifecycle-seed", StringComparison.OrdinalIgnoreCase))
            {
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                _ = LifecycleRestartSelfTest.RunAndShutdownAsync(true, e.Args[1], e.Args[2], e.Args[3]);
                return;
            }

            if (e.Args.Length >= 4 && string.Equals(e.Args[0], "--selftest-lifecycle-verify", StringComparison.OrdinalIgnoreCase))
            {
                ShutdownMode = ShutdownMode.OnExplicitShutdown;
                _ = LifecycleRestartSelfTest.RunAndShutdownAsync(false, e.Args[1], e.Args[2], e.Args[3]);
                return;
            }

'@
    $app = $app.Replace($themeAnchor, $branches.Replace("`r`n", "`n") + $themeAnchor)
}
Write-Lf $appPath $app

$verifyPath = Join-Path $SourceRoot 'scripts\verify-installed-release.ps1'
$verify = Read-Lf $verifyPath
$anchor = @'
foreach ($theme in @('Light','Dark')) {
    foreach ($case in $cases) {
        Run-InstalledUiProbe $theme (Join-Path $corpus $case.Name) $case.Pages 4 $case.Name
    }
}

$finalOutput = Join-Path $OutputDirectory 'final-selftest'
'@.Replace("`r`n", "`n")
if (-not $verify.Contains($anchor)) { throw 'Installed corpus/final-selftest anchor not found.' }
if (-not $verify.Contains('--selftest-lifecycle-seed')) {
$replacement = @'
foreach ($theme in @('Light','Dark')) {
    foreach ($case in $cases) {
        Run-InstalledUiProbe $theme (Join-Path $corpus $case.Name) $case.Pages 4 $case.Name
    }
}

# Prove lifecycle persistence across two distinct executions of the exact Program Files EXE.
# Seed runs the real first-launch dialog, real theme toggle, opens two tabs and closes cleanly.
# Verify starts a fresh process, proves onboarding does not recur, then uses the real Recent
# Resume/Grid/List/Compact controls to restore the two-tab page-3 session.
$lifecycleOutput = Join-Path $OutputDirectory 'lifecycle-restart'
Remove-Item $lifecycleOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $lifecycleOutput | Out-Null
$lifecycleSecond = Join-Path $corpus 'research-like-18.pdf'
Write-Host 'Running installed first-launch/session seed through the real Program Files EXE...' -ForegroundColor Cyan
$lifecycleSeed = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-lifecycle-seed', $sample, $lifecycleSecond, $lifecycleOutput) -Wait -PassThru
if ($lifecycleSeed.ExitCode -ne 0 -or -not (Test-Path (Join-Path $lifecycleOutput 'lifecycle-seed-pass.flag'))) {
    $lifecycleError = Join-Path $lifecycleOutput 'lifecycle-restart-error.txt'
    if (Test-Path $lifecycleError) { Get-Content $lifecycleError | Write-Host }
    throw "Installed lifecycle seed failed with exit code $($lifecycleSeed.ExitCode)."
}

Write-Host 'Restarting installed AsantePDF to verify onboarding, settings, Recent and Resume persistence...' -ForegroundColor Cyan
$lifecycleVerify = Start-Process -FilePath $installedExe `
    -ArgumentList @('--selftest-lifecycle-verify', $sample, $lifecycleSecond, $lifecycleOutput) -Wait -PassThru
if ($lifecycleVerify.ExitCode -ne 0 -or -not (Test-Path (Join-Path $lifecycleOutput 'lifecycle-verify-pass.flag'))) {
    $lifecycleError = Join-Path $lifecycleOutput 'lifecycle-restart-error.txt'
    if (Test-Path $lifecycleError) { Get-Content $lifecycleError | Write-Host }
    throw "Installed lifecycle restart verification failed with exit code $($lifecycleVerify.ExitCode)."
}

$finalOutput = Join-Path $OutputDirectory 'final-selftest'
'@.Replace("`r`n", "`n")
    $verify = $verify.Replace($anchor, $replacement)
}
Write-Lf $verifyPath $verify

Write-Host 'Added two-process installed first-launch, settings, Recent and Resume acceptance.' -ForegroundColor Green
