param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Read-Lf([string]$path) { [IO.File]::ReadAllText($path).Replace("`r`n", "`n") }
function Write-Lf([string]$path, [string]$text) { [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }

$path = Join-Path $SourceRoot 'src\PdfRescue.App\Services\ThemeRuntimeSelfTest.cs'
$text = Read-Lf $path

$callAnchor = '        await VerifySettingsAndTaskCenterAsync(outputDirectory);'
$callLine = '        await VerifyLifecycleWindowsAsync(outputDirectory);'
if (-not $text.Contains($callAnchor)) { throw 'Theme self-test call anchor not found.' }
if (-not $text.Contains($callLine)) {
    $text = $text.Replace($callAnchor, $callAnchor + "`n" + $callLine)
}

$methodAnchor = '    private static async Task VerifyWholeShellAsync(string outputDirectory, string? samplePdf)'
if (-not $text.Contains($methodAnchor)) { throw 'Whole-shell method anchor not found.' }
if (-not $text.Contains('private static async Task VerifyLifecycleWindowsAsync')) {
$method = @'
    private static async Task VerifyLifecycleWindowsAsync(string outputDirectory)
    {
        var firstLaunch = new FirstLaunchWindow
        {
            Width = 700,
            Height = 500,
            ShowInTaskbar = false,
            Left = -12000,
            Top = -12000
        };
        try
        {
            firstLaunch.Show();
            await RenderCycleAsync();
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(firstLaunch);
            await RenderCycleAsync();
            AssertButtonInsideWindow(firstLaunch, "Start using AsantePDF", "First launch Light");
            WriteContrastReport(firstLaunch, Path.Combine(outputDirectory, "contrast-first-launch-light.txt"), "First launch Light");
            Capture(firstLaunch, Path.Combine(outputDirectory, "first-launch-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(firstLaunch);
            await RenderCycleAsync();
            AssertButtonInsideWindow(firstLaunch, "Start using AsantePDF", "First launch Dark");
            WriteContrastReport(firstLaunch, Path.Combine(outputDirectory, "contrast-first-launch-dark.txt"), "First launch Dark");
            Capture(firstLaunch, Path.Combine(outputDirectory, "first-launch-dark.png"));
        }
        finally
        {
            firstLaunch.Close();
        }

        var diagnostics = new DiagnosticsWindow
        {
            Width = 680,
            Height = 560,
            ShowInTaskbar = false,
            Left = -12000,
            Top = -12000
        };
        try
        {
            diagnostics.Show();
            await RenderCycleAsync();
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(diagnostics);
            await RenderCycleAsync();
            WriteContrastReport(diagnostics, Path.Combine(outputDirectory, "contrast-diagnostics-light.txt"), "Diagnostics Light");
            Capture(diagnostics, Path.Combine(outputDirectory, "diagnostics-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(diagnostics);
            await RenderCycleAsync();
            WriteContrastReport(diagnostics, Path.Combine(outputDirectory, "contrast-diagnostics-dark.txt"), "Diagnostics Dark");
            Capture(diagnostics, Path.Combine(outputDirectory, "diagnostics-dark.png"));
        }
        finally
        {
            diagnostics.Close();
        }
    }

    private static void AssertButtonInsideWindow(Window window, string content, string label)
    {
        var button = Descendants(window).OfType<Button>()
            .FirstOrDefault(item => string.Equals(item.Content?.ToString(), content, StringComparison.Ordinal));
        if (button is null || !button.IsVisible || button.ActualWidth <= 0 || button.ActualHeight <= 0)
            throw new InvalidOperationException($"{label}: required button '{content}' is not visible.");
        var origin = button.TransformToAncestor(window).Transform(new Point(0, 0));
        var bounds = new Rect(origin, new Size(button.ActualWidth, button.ActualHeight));
        if (bounds.Left < -2 || bounds.Top < -2 || bounds.Right > window.ActualWidth + 2 || bounds.Bottom > window.ActualHeight + 2)
            throw new InvalidOperationException($"{label}: '{content}' is clipped at {bounds} inside {window.ActualWidth:F0}x{window.ActualHeight:F0}.");
    }

'@
    $text = $text.Replace($methodAnchor, $method.Replace("`r`n", "`n") + $methodAnchor)
}

Write-Lf $path $text
Write-Host 'Added constrained first-launch and diagnostics Light/Dark visual evidence.' -ForegroundColor Green
