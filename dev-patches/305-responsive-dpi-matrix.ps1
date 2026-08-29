param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\ThemeRuntimeSelfTest.cs'
$text = Read-Lf $path

$homeAnchor = '            Capture(window, Path.Combine(outputDirectory, "home-dark-roundtrip.png"));'
if (-not $text.Contains($homeAnchor)) { throw 'Home round-trip capture anchor not found.' }
if (-not $text.Contains('VerifyResponsiveMatrixAsync(window, outputDirectory, "home")')) {
    $text = $text.Replace($homeAnchor, $homeAnchor + "`n            await VerifyResponsiveMatrixAsync(window, outputDirectory, \"home\");")
}

$workspaceAnchor = '                Capture(window, Path.Combine(outputDirectory, "workspace-light-roundtrip.png"));'
if (-not $text.Contains($workspaceAnchor)) { throw 'Workspace round-trip capture anchor not found.' }
if (-not $text.Contains('VerifyResponsiveMatrixAsync(window, outputDirectory, "workspace")')) {
    $text = $text.Replace($workspaceAnchor, $workspaceAnchor + "`n                await VerifyResponsiveMatrixAsync(window, outputDirectory, \"workspace\");")
}

$methodAnchor = '    private static async Task RenderCycleAsync()'
if (-not $text.Contains($methodAnchor)) { throw 'RenderCycle anchor not found.' }
if (-not $text.Contains('private static async Task VerifyResponsiveMatrixAsync')) {
$methods = @'
    private static async Task VerifyResponsiveMatrixAsync(MainWindow window, string outputDirectory, string surface)
    {
        // These logical viewports approximate a 1600x900 usable desktop area at the
        // Windows scaling values in the acceptance contract. The 175%/200% cases clamp
        // to the product minimum where appropriate, which is the real WPF behaviour.
        var cases = new (string Label, double Width, double Height)[]
        {
            ("100", 1600, 900),
            ("125", 1280, 720),
            ("150", 1067, 600),
            ("175", 914, 514),
            ("200", 880, 500)
        };

        var originalWidth = window.Width;
        var originalHeight = window.Height;
        try
        {
            foreach (var theme in new[] { AppThemeMode.Light, AppThemeMode.Dark })
            {
                AppearanceService.Apply(theme);
                AppearanceService.ApplyToWindow(window);
                foreach (var item in cases)
                {
                    window.Width = Math.Max(window.MinWidth, item.Width);
                    window.Height = Math.Max(window.MinHeight, item.Height);
                    await RenderCycleAsync();
                    AssertCriticalShellBounds(window, surface, item.Label);
                    var themeName = theme == AppThemeMode.Light ? "light" : "dark";
                    WriteContrastReport(window,
                        Path.Combine(outputDirectory, $"contrast-{surface}-{themeName}-dpi-{item.Label}.txt"),
                        $"{surface} {themeName} effective {item.Label}%");
                    Capture(window, Path.Combine(outputDirectory, $"{surface}-{themeName}-dpi-{item.Label}.png"));
                }
            }
        }
        finally
        {
            window.Width = originalWidth;
            window.Height = originalHeight;
            await RenderCycleAsync();
        }
    }

    private static void AssertCriticalShellBounds(MainWindow window, string surface, string scale)
    {
        string[] names = surface == "workspace"
            ? ["HomeNavButton", "TaskCenterNavButton", "ThemeToggleButton", "SettingsButton", "DocumentTabsList", "RibbonScrollViewer", "PageViewModeCombo", "DocumentSearchContainer"]
            : ["HomeNavButton", "RecentNavButton", "StarredNavButton", "ToolsNavButton", "TaskCenterNavButton", "ThemeToggleButton", "SettingsButton"];

        foreach (var name in names)
        {
            if (window.FindName(name) is not FrameworkElement element || element.Visibility != Visibility.Visible || element.ActualWidth <= 0 || element.ActualHeight <= 0)
                continue;
            Rect bounds;
            try
            {
                var origin = element.TransformToAncestor(window).Transform(new Point(0, 0));
                bounds = new Rect(origin, new Size(element.ActualWidth, element.ActualHeight));
            }
            catch (InvalidOperationException)
            {
                continue;
            }

            const double tolerance = 3;
            if (bounds.Left < -tolerance || bounds.Top < -tolerance ||
                bounds.Right > window.ActualWidth + tolerance || bounds.Bottom > window.ActualHeight + tolerance)
                throw new InvalidOperationException($"{surface} effective {scale}% clips critical element {name}: {bounds} inside {window.ActualWidth:F0}x{window.ActualHeight:F0}.");
        }
    }

'@
    $text = $text.Replace($methodAnchor, $methods.Replace("`r`n", "`n") + $methodAnchor)
}

Write-Lf $path $text
Write-Host 'Added Light/Dark effective 100/125/150/175/200% viewport acceptance evidence.' -ForegroundColor Green
