param(
    [Parameter(Mandatory = $true)] [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-Text([string]$relative) {
    return [System.IO.File]::ReadAllText((Join-Path $SourceRoot $relative))
}

function Write-Text([string]$relative, [string]$text) {
    $path = Join-Path $SourceRoot $relative
    $directory = [System.IO.Path]::GetDirectoryName($path)
    if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}

function Replace-Required([string]$text, [string]$old, [string]$new, [string]$label) {
    if (-not $text.Contains($old)) { throw "Required patch anchor missing: $label" }
    return $text.Replace($old, $new)
}

Write-Host '1/9 Replacing the fragile theme mutation layer...' -ForegroundColor Cyan
$appearance = @'
using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace PdfRescue.App.Services;

/// <summary>
/// Owns AsantePDF's semantic colour palette. Theme resources are updated in place so
/// DynamicResource consumers and existing brush references change together. A small,
/// symmetric legacy-colour mapper remains only for old hard-coded surfaces while they
/// are being retired. It never caches a control's current colour as its "original"
/// theme, which avoids mixed Light/Dark states for controls created after startup.
/// </summary>
public static class AppearanceService
{
    private sealed record ThemeColors(
        string Window,
        string Sidebar,
        string Surface,
        string Raised,
        string Hover,
        string Pressed,
        string Border,
        string Text,
        string Muted);

    private static readonly ThemeColors Dark = new(
        "#09131F", "#08111C", "#101C2A", "#162333", "#263B50", "#304B64", "#36506A", "#F3F7FC", "#B7C5D4");
    private static readonly ThemeColors Light = new(
        "#EEF3F8", "#F8FAFC", "#F5F8FB", "#FFFFFF", "#DCE6F0", "#C9D8E6", "#8EA3B7", "#0F172A", "#3F556B");

    private static readonly string[] ThemeBrushKeys =
    [
        "AppBackground", "SidebarBackground", "PanelBackground", "PanelRaisedBrush", "PanelHoverBrush",
        "PanelPressedBrush", "BorderBrushSoft", "PrimaryTextBrush", "MutedTextBrush", "AccentBrush",
        "DangerBrush", "SuccessBrush"
    ];

    // Transitional mapping for legacy literal colours still present in a few composed
    // controls. The mapping is deliberately symmetric. Dark -> Light and Light -> Dark
    // always derive from the colour that is on the element now, not from cached history.
    private static readonly Dictionary<string, string> DarkToLight = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#09131F"] = "#EEF3F8", ["#08111C"] = "#F8FAFC", ["#101C2A"] = "#F5F8FB",
        ["#162333"] = "#FFFFFF", ["#263B50"] = "#DCE6F0", ["#304B64"] = "#C9D8E6",
        ["#36506A"] = "#8EA3B7", ["#F3F7FC"] = "#0F172A", ["#B7C5D4"] = "#3F556B",
        ["#08121E"] = "#FFFFFF", ["#0D1A28"] = "#F5F7FA", ["#0D1926"] = "#FFFFFF",
        ["#0E1C2B"] = "#F7F9FB", ["#0B1724"] = "#F1F4F7", ["#132236"] = "#E6EDF5",
        ["#13202E"] = "#FFFFFF", ["#0F1B29"] = "#F7F9FB", ["#111C28"] = "#EEF2F6",
        ["#0C1723"] = "#FFFFFF", ["#101F2E"] = "#FFFFFF", ["#101D2A"] = "#F5F7FA",
        ["#172738"] = "#D7E0E8", ["#243D56"] = "#C2CED9", ["#24415F"] = "#C7D3DE",
        ["#24364A"] = "#CBD5DF", ["#0A1520"] = "#EEF2F6", ["#0A1420"] = "#EEF2F6",
        ["#0E1B29"] = "#F1F4F7", ["#17283A"] = "#FFFFFF", ["#102A45"] = "#DCE7F2",
        ["#35506B"] = "#B8C6D4", ["#122131"] = "#FFFFFF", ["#29425B"] = "#B8C6D4",
        ["#3A4A59"] = "#52677A", ["#41566C"] = "#4A6074", ["#53677C"] = "#455B70",
        ["#54708A"] = "#405970", ["#6282A1"] = "#46617B", ["#698096"] = "#435D75",
        ["#6F8399"] = "#40586F", ["#71869D"] = "#3E576E", ["#73879D"] = "#3E576E",
        ["#7E92A8"] = "#425C73", ["#7192B1"] = "#3B5871", ["#7990A7"] = "#3F5B73",
        ["#80B9FF"] = "#185D9C", ["#4D9BFF"] = "#155DA8", ["#627B94"] = "#455F77",
        ["#7890A8"] = "#405A72"
    };

    private static readonly Dictionary<string, string> LightToDark = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#EEF3F8"] = "#09131F", ["#F8FAFC"] = "#08111C", ["#F5F8FB"] = "#101C2A",
        ["#FFFFFF"] = "#162333", ["#DCE6F0"] = "#263B50", ["#C9D8E6"] = "#304B64",
        ["#8EA3B7"] = "#36506A", ["#0F172A"] = "#F3F7FC", ["#3F556B"] = "#B7C5D4",
        ["#F5F7FA"] = "#0D1A28", ["#F7F9FB"] = "#0E1C2B", ["#F1F4F7"] = "#0B1724",
        ["#E6EDF5"] = "#132236", ["#EEF2F6"] = "#111C28", ["#D7E0E8"] = "#172738",
        ["#C2CED9"] = "#243D56", ["#C7D3DE"] = "#24415F", ["#CBD5DF"] = "#24364A",
        ["#DCE7F2"] = "#102A45", ["#B8C6D4"] = "#29425B", ["#52677A"] = "#3A4A59",
        ["#4A6074"] = "#41566C", ["#455B70"] = "#53677C", ["#405970"] = "#54708A",
        ["#46617B"] = "#6282A1", ["#435D75"] = "#698096", ["#40586F"] = "#6F8399",
        ["#3E576E"] = "#71869D", ["#425C73"] = "#7E92A8", ["#3B5871"] = "#7192B1",
        ["#3F5B73"] = "#7990A7", ["#185D9C"] = "#80B9FF", ["#155DA8"] = "#4D9BFF",
        ["#455F77"] = "#627B94", ["#405A72"] = "#7890A8"
    };

    public static bool IsLight { get; private set; }

    public static void Apply(AppThemeMode mode)
    {
        IsLight = mode == AppThemeMode.Light || mode == AppThemeMode.FollowWindows && WindowsUsesLightTheme();
        var colors = IsLight ? Light : Dark;
        SetBrush("AppBackground", colors.Window);
        SetBrush("SidebarBackground", colors.Sidebar);
        SetBrush("PanelBackground", colors.Surface);
        SetBrush("PanelRaisedBrush", colors.Raised);
        SetBrush("PanelHoverBrush", colors.Hover);
        SetBrush("PanelPressedBrush", colors.Pressed);
        SetBrush("BorderBrushSoft", colors.Border);
        SetBrush("PrimaryTextBrush", colors.Text);
        SetBrush("MutedTextBrush", colors.Muted);

        foreach (Window window in Application.Current.Windows)
            ApplyToWindow(window);
    }

    public static void ApplyToWindow(Window window)
    {
        if (window is null) return;
        if (!window.Dispatcher.CheckAccess())
        {
            window.Dispatcher.Invoke(() => ApplyToWindow(window));
            return;
        }

        // Keep the top-level shell on the semantic resources. The brush objects are
        // mutated in place by Apply(), so even already-loaded windows switch atomically.
        window.Background = ResourceBrush("AppBackground");
        window.Foreground = ResourceBrush("PrimaryTextBrush");
        ApplyLegacyTree(window);
    }

    public static void ApplyToElement(DependencyObject root)
    {
        if (root is DispatcherObject dispatcherObject && !dispatcherObject.Dispatcher.CheckAccess())
        {
            dispatcherObject.Dispatcher.Invoke(() => ApplyToElement(root));
            return;
        }
        ApplyLegacyTree(root);
    }

    private static bool WindowsUsesLightTheme()
    {
        try
        {
            var value = Registry.GetValue(
                @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "AppsUseLightTheme",
                0);
            return Convert.ToInt32(value ?? 0) != 0;
        }
        catch { return false; }
    }

    private static void SetBrush(string key, string value)
    {
        var color = (Color)ColorConverter.ConvertFromString(value)!;
        if (Application.Current.Resources[key] is SolidColorBrush brush)
        {
            // Theme brushes are declared Freeze=False. Replacing a frozen brush would
            // strand StaticResource consumers on the old object, so fail loudly in
            // development instead of silently creating a mixed theme.
            if (brush.IsFrozen)
                throw new InvalidOperationException($"Theme brush '{key}' was unexpectedly frozen.");
            brush.Color = color;
            return;
        }
        Application.Current.Resources[key] = new SolidColorBrush(color);
    }

    private static Brush ResourceBrush(string key) =>
        Application.Current.Resources[key] as Brush ?? Brushes.Transparent;

    private static bool IsLiveThemeResourceBrush(SolidColorBrush brush)
    {
        foreach (var key in ThemeBrushKeys)
        {
            if (ReferenceEquals(Application.Current.Resources[key], brush)) return true;
        }
        return false;
    }

    private static string ToRgbKey(Color color) => $"#{color.R:X2}{color.G:X2}{color.B:X2}";

    private static Brush MapLegacyBrush(SolidColorBrush brush)
    {
        if (IsLiveThemeResourceBrush(brush)) return brush;
        var key = ToRgbKey(brush.Color);
        var map = IsLight ? DarkToLight : LightToDark;
        return map.TryGetValue(key, out var mapped)
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString(mapped)!)
            : brush;
    }

    private static void ApplyLegacyTree(DependencyObject root)
    {
        switch (root)
        {
            case Panel panel when panel.Background is SolidColorBrush panelBrush:
                panel.Background = MapLegacyBrush(panelBrush);
                break;
            case Border border:
                if (border.Background is SolidColorBrush background)
                    border.Background = MapLegacyBrush(background);
                if (border.BorderBrush is SolidColorBrush borderBrush)
                    border.BorderBrush = MapLegacyBrush(borderBrush);
                break;
            case Control control:
                if (control.Background is SolidColorBrush controlBackground)
                    control.Background = MapLegacyBrush(controlBackground);
                if (control.Foreground is SolidColorBrush controlForeground)
                    control.Foreground = MapLegacyBrush(controlForeground);
                if (control.BorderBrush is SolidColorBrush controlBorder)
                    control.BorderBrush = MapLegacyBrush(controlBorder);
                break;
            case TextBlock text when text.Foreground is SolidColorBrush textBrush:
                text.Foreground = MapLegacyBrush(textBrush);
                break;
            case Shape shape:
                if (shape.Fill is SolidColorBrush fill)
                    shape.Fill = MapLegacyBrush(fill);
                if (shape.Stroke is SolidColorBrush stroke)
                    shape.Stroke = MapLegacyBrush(stroke);
                break;
        }

        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++) ApplyLegacyTree(VisualTreeHelper.GetChild(root, i));
    }
}
'@
Write-Text 'src/PdfRescue.App/Services/AppearanceService.cs' $appearance

Write-Host '2/9 Converting all semantic palette references to DynamicResource...' -ForegroundColor Cyan
$themeKeys = @(
    'AppBackground','SidebarBackground','PanelBackground','PanelRaisedBrush','PanelHoverBrush',
    'PanelPressedBrush','BorderBrushSoft','PrimaryTextBrush','MutedTextBrush','AccentBrush',
    'DangerBrush','SuccessBrush'
)
$xamlFiles = Get-ChildItem (Join-Path $SourceRoot 'src\PdfRescue.App') -Filter '*.xaml' -File -Recurse
foreach ($file in $xamlFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $updated = $text
    foreach ($key in $themeKeys) {
        $updated = $updated.Replace("{StaticResource $key}", "{DynamicResource $key}")
    }
    if ($updated -ne $text) {
        [System.IO.File]::WriteAllText($file.FullName, $updated, [System.Text.UTF8Encoding]::new($false))
    }
}

Write-Host '3/9 Making late-created Recent files controls theme-aware...' -ForegroundColor Cyan
$recentCode = Read-Text 'src/PdfRescue.App/RecentFilesView.xaml.cs'
$recentCode = Replace-Required $recentCode @'
    private void RecentFilesView_Loaded(object sender, RoutedEventArgs e)
    {
        if (_service is not null) _ = RefreshAsync();
    }
'@ @'
    private void RecentFilesView_Loaded(object sender, RoutedEventArgs e)
    {
        // This view is created after the MainWindow has already loaded. DynamicResource
        // handles the semantic palette; this pass only normalizes legacy literal colours.
        AppearanceService.ApplyToElement(this);
        if (_service is not null) _ = RefreshAsync();
    }
'@ 'RecentFilesView loaded handler'
Write-Text 'src/PdfRescue.App/RecentFilesView.xaml.cs' $recentCode

$productShell = Read-Text 'src/PdfRescue.App/MainWindow.ProductShell.cs'
$productShell = Replace-Required $productShell @'
        HomeRecentSection.Children.Clear();
        HomeRecentSection.Children.Add(_recentFilesView);
'@ @'
        HomeRecentSection.Children.Clear();
        HomeRecentSection.Children.Add(_recentFilesView);
        AppearanceService.ApplyToElement(_recentFilesView);
'@ 'late-created RecentFilesView insertion'
Write-Text 'src/PdfRescue.App/MainWindow.ProductShell.cs' $productShell

Write-Host '4/9 Adding one global PDFium native execution gate...' -ForegroundColor Cyan
$pdfiumGate = @'
using PDFiumCore;

namespace PdfRescue.App.Services;

/// <summary>
/// PDFium is a process-global native library and is not safe for concurrent calls from
/// independent AsantePDF subsystems. Every direct PDFium entry point must hold this gate.
/// This prevents preview, thumbnail, search, outline, text and annotation work from racing
/// one another while a document is opening or closing.
/// </summary>
public static class PdfiumNativeGate
{
    private static readonly SemaphoreSlim Gate = new(1, 1);
    private static readonly object InitializationSync = new();
    private static bool _initialized;

    public static void EnsureInitialized()
    {
        if (_initialized) return;
        lock (InitializationSync)
        {
            if (_initialized) return;
            fpdfview.FPDF_InitLibrary();
            _initialized = true;
        }
    }

    public static async Task WaitAsync(CancellationToken token)
    {
        EnsureInitialized();
        await Gate.WaitAsync(token).ConfigureAwait(false);
    }

    public static void Wait(CancellationToken token = default)
    {
        EnsureInitialized();
        Gate.Wait(token);
    }

    public static IDisposable Enter(CancellationToken token = default)
    {
        Wait(token);
        return new Releaser();
    }

    public static void Release() => Gate.Release();

    private sealed class Releaser : IDisposable
    {
        private bool _released;
        public void Dispose()
        {
            if (_released) return;
            _released = true;
            Release();
        }
    }
}
'@
Write-Text 'src/PdfRescue.App/Services/PdfiumNativeGate.cs' $pdfiumGate

$renderer = Read-Text 'src/PdfRescue.App/PdfiumPdfRenderer.cs'
$renderer = $renderer.Replace('    private readonly SemaphoreSlim _gate = new(1, 1);' + [Environment]::NewLine, '')
$renderer = Replace-Required $renderer '        PdfiumRuntime.EnsureInitialized();' '        PdfiumNativeGate.EnsureInitialized();' 'renderer runtime initialization'
$renderer = $renderer.Replace('await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);', 'await PdfiumNativeGate.WaitAsync(cancellationToken).ConfigureAwait(false);')
$renderer = $renderer.Replace('_gate.Release();', 'PdfiumNativeGate.Release();')
$renderer = $renderer.Replace('_gate.Wait();', 'PdfiumNativeGate.Wait();')
$renderer = $renderer.Replace('            _gate.Dispose();' + [Environment]::NewLine, '')
if ($renderer.Contains('_gate.')) { throw 'Renderer still contains the old per-instance PDFium gate.' }
Write-Text 'src/PdfRescue.App/PdfiumPdfRenderer.cs' $renderer

$servicePatches = @(
    @('src/PdfRescue.App/Services/DocumentSearchService.cs', 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();', 'using var nativeGate = PdfiumNativeGate.Enter(token);'),
    @('src/PdfRescue.App/Services/DocumentTextSelectionService.cs', 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();', 'using var nativeGate = PdfiumNativeGate.Enter(token);'),
    @('src/PdfRescue.App/Services/DocumentOutlineService.cs', 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();', 'using var nativeGate = PdfiumNativeGate.Enter(token);'),
    @('src/PdfRescue.App/Services/DocumentAnnotationService.cs', 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();', 'using var nativeGate = PdfiumNativeGate.Enter(token);'),
    @('src/PdfRescue.App/Services/NativePdfAnnotationService.cs', 'using var runtimeAnchor = PdfRendererFactory.CreateProduction();', 'using var nativeGate = PdfiumNativeGate.Enter(token);')
)
foreach ($patch in $servicePatches) {
    $text = Read-Text $patch[0]
    $text = Replace-Required $text $patch[1] $patch[2] $patch[0]
    Write-Text $patch[0] $text
}

Write-Host '5/9 Adding runtime theme self-test...' -ForegroundColor Cyan
$themeSelfTest = @'
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace PdfRescue.App.Services;

public static class ThemeRuntimeSelfTest
{
    public static async Task RunAsync(string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);
        var host = new Window
        {
            Width = 900,
            Height = 600,
            ShowInTaskbar = false,
            WindowStyle = WindowStyle.None,
            Opacity = 0.01,
            Content = new RecentFilesView()
        };

        try
        {
            host.Show();
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Loaded);
            var recent = (RecentFilesView)host.Content;
            var grid = Require<Button>(recent, "GridViewButton");
            var compact = Require<Button>(recent, "CompactViewButton");
            var resume = Require<Button>(recent, "ResumeSessionButton");
            var sort = Require<ComboBox>(recent, "SortCombo");

            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(host);
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Render);
            AssertBrush(host.Background, "#EEF3F8", "Light window background");
            AssertBrush(grid.Foreground, "#0F172A", "Light Grid text");
            AssertBrush(compact.Foreground, "#0F172A", "Light Compact text");
            AssertBrush(resume.Foreground, "#0F172A", "Light Resume text");
            AssertBrush(sort.Background, "#FFFFFF", "Light sort background");
            AssertBrush(sort.Foreground, "#0F172A", "Light sort text");

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(host);
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Render);
            AssertBrush(host.Background, "#09131F", "Dark window background");
            AssertBrush(grid.Foreground, "#F3F7FC", "Dark Grid text");
            AssertBrush(compact.Foreground, "#F3F7FC", "Dark Compact text");
            AssertBrush(resume.Foreground, "#F3F7FC", "Dark Resume text");
            AssertBrush(sort.Background, "#162333", "Dark sort background");
            AssertBrush(sort.Foreground, "#F3F7FC", "Dark sort text");

            File.WriteAllText(Path.Combine(outputDirectory, "theme-runtime-pass.flag"), DateTimeOffset.Now.ToString("O"));
        }
        finally
        {
            host.Close();
        }
    }

    private static T Require<T>(FrameworkElement root, string name) where T : FrameworkElement =>
        root.FindName(name) as T ?? throw new InvalidOperationException($"Theme self-test could not find {name}.");

    private static void AssertBrush(Brush? brush, string expected, string label)
    {
        if (brush is not SolidColorBrush solid)
            throw new InvalidOperationException($"{label}: expected a solid colour brush.");
        var actual = $"#{solid.Color.R:X2}{solid.Color.G:X2}{solid.Color.B:X2}";
        if (!string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"{label}: expected {expected}, got {actual}.");
    }
}
'@
Write-Text 'src/PdfRescue.App/Services/ThemeRuntimeSelfTest.cs' $themeSelfTest

$app = Read-Text 'src/PdfRescue.App/App.xaml.cs'
$app = Replace-Required $app @'
            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-final", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunFinalCandidateSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            var pdfArgument = e.Args.FirstOrDefault(a =>
'@ @'
            if (e.Args.Length >= 3 && string.Equals(e.Args[0], "--selftest-final", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunFinalCandidateSelfTestAsync(e.Args[1], e.Args[2]);
                return;
            }

            if (e.Args.Length >= 2 && string.Equals(e.Args[0], "--selftest-theme", StringComparison.OrdinalIgnoreCase))
            {
                _ = RunThemeRuntimeSelfTestAsync(e.Args[1]);
                return;
            }

            var pdfArgument = e.Args.FirstOrDefault(a =>
'@ 'theme self-test command-line hook'

$app = Replace-Required $app @'
    private async Task RunFinalCandidateSelfTestAsync(string samplePdf, string outputDirectory)
'@ @'
    private async Task RunThemeRuntimeSelfTestAsync(string outputDirectory)
    {
        try
        {
            Log("Theme runtime self-test started.");
            await ThemeRuntimeSelfTest.RunAsync(outputDirectory);
            Log("Theme runtime self-test passed.");
            Shutdown(0);
        }
        catch (Exception ex)
        {
            Log("Theme runtime self-test failed: " + ex);
            try
            {
                Directory.CreateDirectory(outputDirectory);
                await File.WriteAllTextAsync(Path.Combine(outputDirectory, "theme-runtime-error.txt"), ex.ToString());
            }
            catch { }
            Shutdown(7);
        }
    }

    private async Task RunFinalCandidateSelfTestAsync(string samplePdf, string outputDirectory)
'@ 'theme self-test runner'
Write-Text 'src/PdfRescue.App/App.xaml.cs' $app

Write-Host '6/9 Expanding the PDF-open fixture to exercise real page/thumbnail concurrency...' -ForegroundColor Cyan
$sampleScript = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [ValidateRange(1, 50)]
    [int]$PageCount = 1
)

$ErrorActionPreference = 'Stop'
$encoding = [System.Text.Encoding]::ASCII
$fontObject = 3 + (2 * $PageCount)
$kids = @()
$objects = New-Object System.Collections.Generic.List[string]
$objects.Add('<< /Type /Catalog /Pages 2 0 R >>')
$objects.Add('')
for ($pageIndex = 0; $pageIndex -lt $PageCount; $pageIndex++) {
    $pageObject = 3 + (2 * $pageIndex)
    $contentObject = $pageObject + 1
    $kids += "$pageObject 0 R"
    $objects.Add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 $fontObject 0 R >> >> /Contents $contentObject 0 R >>")
    $content = "BT`n/F1 24 Tf`n72 700 Td`n(AsantePDF runtime page $($pageIndex + 1)) Tj`nET`n"
    $contentLength = $encoding.GetByteCount($content)
    $objects.Add("<< /Length $contentLength >>`nstream`n$content" + 'endstream')
}
$objects[1] = "<< /Type /Pages /Kids [$($kids -join ' ')] /Count $PageCount >>"
$objects.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')

$builder = New-Object System.Text.StringBuilder
[void]$builder.Append("%PDF-1.4`n")
$offsets = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $objects.Count; $i++) {
    $offsets.Add($encoding.GetByteCount($builder.ToString()))
    [void]$builder.Append(($i + 1).ToString()).Append(" 0 obj`n")
    [void]$builder.Append($objects[$i]).Append("`nendobj`n")
}
$xrefOffset = $encoding.GetByteCount($builder.ToString())
$size = $objects.Count + 1
[void]$builder.Append("xref`n0 $size`n")
[void]$builder.Append("0000000000 65535 f `n")
foreach ($offset in $offsets) {
    [void]$builder.Append($offset.ToString('D10')).Append(" 00000 n `n")
}
[void]$builder.Append("trailer`n<< /Size $size /Root 1 0 R >>`n")
[void]$builder.Append("startxref`n").Append($xrefOffset).Append("`n%%EOF`n")

$full = [System.IO.Path]::GetFullPath($OutputPath)
$directory = [System.IO.Path]::GetDirectoryName($full)
if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
[System.IO.File]::WriteAllBytes($full, $encoding.GetBytes($builder.ToString()))
Write-Host "Created $PageCount-page PDF test fixture: $full"
'@
Write-Text 'scripts/New-SamplePdf.ps1' $sampleScript

$main = Read-Text 'src/PdfRescue.App/MainWindow.xaml.cs'
$main = Replace-Required $main @'
            if (!_busy && generation == _documentGeneration)
                StatusText.Text = "Ready.";
'@ @'
            if (!_busy && generation == _documentGeneration)
            {
                StatusText.Text = "Ready.";
                App.Log($"Thumbnail rendering completed: {pageCount} pages.");
            }
'@ 'thumbnail completion logging'
Write-Text 'src/PdfRescue.App/MainWindow.xaml.cs' $main

Write-Host '7/9 Adding persistent source-contract audits...' -ForegroundColor Cyan
$themeAudit = @'
param([string]$Root = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = 'Stop'
$keys = 'AppBackground|SidebarBackground|PanelBackground|PanelRaisedBrush|PanelHoverBrush|PanelPressedBrush|BorderBrushSoft|PrimaryTextBrush|MutedTextBrush|AccentBrush|DangerBrush|SuccessBrush'
$violations = @()
Get-ChildItem (Join-Path $Root 'src\PdfRescue.App') -Filter '*.xaml' -File -Recurse | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $matches = [regex]::Matches($text, "\{StaticResource\s+($keys)\}")
    foreach ($match in $matches) { $violations += "$($_.FullName): $($match.Value)" }
}
if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw 'Theme contract failed: semantic palette brushes must use DynamicResource.'
}
Write-Host 'Theme resource contract passed.' -ForegroundColor Green
'@
Write-Text 'scripts/verify-ui-theme-contract.ps1' $themeAudit

$pdfiumAudit = @'
param([string]$Root = (Resolve-Path "$PSScriptRoot\.."))
$ErrorActionPreference = 'Stop'
$violations = @()
Get-ChildItem (Join-Path $Root 'src\PdfRescue.App') -Filter '*.cs' -File -Recurse | ForEach-Object {
    if ($_.Name -eq 'PdfiumNativeGate.cs') { return }
    $text = [System.IO.File]::ReadAllText($_.FullName)
    if ($text -match '\bfpdf(?:view|_doc|_text|_annot|_save)\.' -and $text -notmatch 'PdfiumNativeGate') {
        $violations += $_.FullName
    }
}
if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw 'PDFium serialization contract failed: direct native callers must use PdfiumNativeGate.'
}
Write-Host 'PDFium serialization contract passed.' -ForegroundColor Green
'@
Write-Text 'scripts/verify-pdfium-serialization.ps1' $pdfiumAudit

Write-Host '8/9 Strengthening installed-copy and development runtime gates...' -ForegroundColor Cyan
$verify = Read-Text 'scripts/verify-installed-release.ps1'
$verify = $verify.Replace("    reopenLastSession = `$false", "    reopenLastSession = `$true")
$verify = $verify.Replace("    trackRecentFiles = `$false", "    trackRecentFiles = `$true")
$verify = $verify.Replace("    showRecentThumbnails = `$false", "    showRecentThumbnails = `$true")
$verify = Replace-Required $verify @'
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
'@ @'
$themeOutput = Join-Path $OutputDirectory 'theme-runtime'
Remove-Item $themeOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $themeOutput | Out-Null
Write-Host 'Running installed-copy Light/Dark runtime contrast probe...' -ForegroundColor Cyan
$themeProbe = Start-Process -FilePath $installedExe -ArgumentList @('--selftest-theme', $themeOutput) -Wait -PassThru
if ($themeProbe.ExitCode -ne 0 -or -not (Test-Path (Join-Path $themeOutput 'theme-runtime-pass.flag'))) {
    $themeError = Join-Path $themeOutput 'theme-runtime-error.txt'
    if (Test-Path $themeError) { Get-Content $themeError | Write-Host }
    throw "Installed AsantePDF failed the runtime theme probe with exit code $($themeProbe.ExitCode)."
}

Write-Host 'Launching the installed copy in Light mode with a multi-page PDF and waiting for foreground + thumbnail completion...' -ForegroundColor Cyan
$app = Start-Process -FilePath $installedExe -ArgumentList @($sample) -PassThru
$ready = $false
$opened = $false
$thumbnails = $false
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Milliseconds 500
    $app.Refresh()
    if (Test-Path $readyFlag) { $ready = $true }
    if (Test-Path $startupLog) {
        $log = Get-Content $startupLog -Raw
        if ($log -match 'Opened PDF: foreground view refresh completed') { $opened = $true }
        if ($log -match 'Thumbnail rendering completed:') { $thumbnails = $true }
    }
    if ($app.HasExited -or ($ready -and $opened -and $thumbnails)) { break }
}
if (-not $ready -or -not $opened -or -not $thumbnails -or $app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    try { if (-not $app.HasExited) { $app.Kill() } } catch { }
    throw "Installed AsantePDF failed the multi-page PDF-open regression. Ready=$ready Opened=$opened Thumbnails=$thumbnails Exited=$($app.HasExited)."
}
Start-Sleep -Seconds 12
$app.Refresh()
if ($app.HasExited) {
    if (Test-Path $startupLog) { Get-Content $startupLog | Write-Host }
    throw "Installed AsantePDF completed the open path but then exited unexpectedly with code $($app.ExitCode)."
}
try { $app.Kill() } catch { }
'@ 'installed PDF-open regression block'
Write-Text 'scripts/verify-installed-release.ps1' $verify

$devWorkflow = Read-Text '.github/workflows/rc10-windows-gate.yml'
$devWorkflow = Replace-Required $devWorkflow @'
      - name: Restore and compile x64 Release
'@ @'
      - name: Verify theme and PDFium source contracts
        shell: pwsh
        run: |
          & .\scripts\verify-ui-theme-contract.ps1
          & .\scripts\verify-pdfium-serialization.ps1

      - name: Restore and compile x64 Release
'@ 'development contract audit step'
$devWorkflow = $devWorkflow.Replace("& .\\scripts\\New-SamplePdf.ps1 -OutputPath `$sample", "& .\\scripts\\New-SamplePdf.ps1 -OutputPath `$sample -PageCount 12")
$devWorkflow = $devWorkflow.Replace("            reopenLastSession = `$false", "            reopenLastSession = `$true")
$devWorkflow = $devWorkflow.Replace("            trackRecentFiles = `$false", "            trackRecentFiles = `$true")
$devWorkflow = $devWorkflow.Replace("            showRecentThumbnails = `$false", "            showRecentThumbnails = `$true")
$devWorkflow = $devWorkflow.Replace("          `$opened = `$false`n", "          `$opened = `$false`n          `$thumbnails = `$false`n")
$devWorkflow = $devWorkflow.Replace("              if (`$log -match 'Opened PDF:') { `$opened = `$true; break }", "              if (`$log -match 'Opened PDF: foreground view refresh completed') { `$opened = `$true }`n              if (`$log -match 'Thumbnail rendering completed:') { `$thumbnails = `$true }`n              if (`$opened -and `$thumbnails) { break }")
$devWorkflow = $devWorkflow.Replace("          if (-not `$opened) {", "          if (-not `$opened -or -not `$thumbnails) {")
$devWorkflow = $devWorkflow.Replace("            throw 'Normal UI did not report a successfully opened PDF within 20 seconds.'", "            throw \"Normal UI did not complete the multi-page open path. Opened=`$opened Thumbnails=`$thumbnails.\"")
$devWorkflow = $devWorkflow.Replace('          Start-Sleep -Seconds 3', '          Start-Sleep -Seconds 12')
Write-Text '.github/workflows/rc10-windows-gate.yml' $devWorkflow

$finalWorkflow = Read-Text '.github/workflows/final-windows-release-gate.yml'
$finalWorkflow = Replace-Required $finalWorkflow @'
      - name: Publish, bundle engines, self-test and build installer
'@ @'
      - name: Verify theme and PDFium source contracts
        shell: pwsh
        run: |
          & .\scripts\verify-ui-theme-contract.ps1
          & .\scripts\verify-pdfium-serialization.ps1

      - name: Publish, bundle engines, self-test and build installer
'@ 'final contract audit step'
$finalWorkflow = Replace-Required $finalWorkflow @'
      - name: Verify exact installed Program Files copy
        shell: pwsh
        run: |
          & .\scripts\verify-installed-release.ps1 `
            -InstallerPath '.\dist\installer\AsantePDF Setup.exe' `
            -SamplePdf '.\dist\release-sample.pdf'
'@ @'
      - name: Verify exact installed Program Files copy
        shell: pwsh
        run: |
          & .\scripts\New-SamplePdf.ps1 -OutputPath '.\dist\runtime-open-stress.pdf' -PageCount 12
          & .\scripts\verify-installed-release.ps1 `
            -InstallerPath '.\dist\installer\AsantePDF Setup.exe' `
            -SamplePdf '.\dist\runtime-open-stress.pdf'
'@ 'final installed-copy stress fixture'
Write-Text '.github/workflows/final-windows-release-gate.yml' $finalWorkflow

Write-Host '9/9 Running patch-time source audits...' -ForegroundColor Cyan
& (Join-Path $SourceRoot 'scripts\verify-ui-theme-contract.ps1') -Root $SourceRoot
& (Join-Path $SourceRoot 'scripts\verify-pdfium-serialization.ps1') -Root $SourceRoot

Write-Host 'Theme architecture, runtime contrast probe, global PDFium serialization and stronger open regression are staged.' -ForegroundColor Green
