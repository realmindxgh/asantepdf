using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace PdfRescue.App.Services;

public static class ThemeRuntimeSelfTest
{
    private const double SevereContrastFloor = 3.0;

    public static async Task RunAsync(string outputDirectory, string? samplePdf = null)
    {
        Directory.CreateDirectory(outputDirectory);
        await VerifyRecentFilesControlsAsync(outputDirectory);
        await VerifySettingsAndTaskCenterAsync(outputDirectory);
        await VerifyWholeShellAsync(outputDirectory, samplePdf);
        File.WriteAllText(Path.Combine(outputDirectory, "theme-runtime-pass.flag"), DateTimeOffset.Now.ToString("O"));
    }

    private static async Task VerifyRecentFilesControlsAsync(string outputDirectory)
    {
        var host = new Window
        {
            Width = 1100,
            Height = 720,
            ShowInTaskbar = false,
            WindowStyle = WindowStyle.None,
            Left = -12000,
            Top = -12000,
            Content = new RecentFilesView()
        };

        try
        {
            host.Show();
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Loaded);
            var recent = (RecentFilesView)host.Content;
            var grid = Require<Button>(recent, "GridViewButton");
            var list = Require<Button>(recent, "ListViewButton");
            var compact = Require<Button>(recent, "CompactViewButton");
            var resume = Require<Button>(recent, "ResumeSessionButton");
            var sort = Require<ComboBox>(recent, "SortCombo");

            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(host);
            await RenderCycleAsync();
            AssertBrush(host.Background, "#EEF3F8", "Light recent-files background");
            AssertBrush(grid.Foreground, "#0F172A", "Light Grid text");
            AssertBrush(list.Foreground, "#0F172A", "Light List text");
            AssertBrush(compact.Foreground, "#0F172A", "Light Compact text");
            AssertBrush(resume.Foreground, "#0F172A", "Light Resume text");
            AssertBrush(sort.Background, "#FFFFFF", "Light sort background");
            AssertBrush(sort.Foreground, "#0F172A", "Light sort text");
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
            AppearanceService.ApplyToWindow(host);
            await RenderCycleAsync();
            AssertBrush(host.Background, "#09131F", "Dark recent-files background");
            AssertBrush(grid.Foreground, "#F3F7FC", "Dark Grid text");
            AssertBrush(list.Foreground, "#F3F7FC", "Dark List text");
            AssertBrush(compact.Foreground, "#F3F7FC", "Dark Compact text");
            AssertBrush(resume.Foreground, "#F3F7FC", "Dark Resume text");
            AssertBrush(sort.Background, "#162333", "Dark sort background");
            AssertBrush(sort.Foreground, "#F3F7FC", "Dark sort text");
            Capture(host, Path.Combine(outputDirectory, "recent-grid-dark.png"));
            list.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-list-dark.png"));
            compact.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
            await RenderCycleAsync();
            Capture(host, Path.Combine(outputDirectory, "recent-compact-dark.png"));
        }
        finally
        {
            host.Close();
        }
    }

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
    private static async Task VerifyWholeShellAsync(string outputDirectory, string? samplePdf)
    {
        var window = new MainWindow
        {
            Width = 1600,
            Height = 940,
            ShowInTaskbar = false,
            Left = -12000,
            Top = -12000
        };

        try
        {
            window.Show();
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Loaded);
            await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.ApplicationIdle);

            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#EEF3F8", "Light MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: true);
            AssertThemeText(window, "Get started with AsantePDF", isLight: true);
            AssertThemeText(window, "Quick Tools", isLight: true);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-light.txt"), "Light");
            Capture(window, Path.Combine(outputDirectory, "home-light.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#09131F", "Dark MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: false);
            AssertThemeText(window, "Get started with AsantePDF", isLight: false);
            AssertThemeText(window, "Quick Tools", isLight: false);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark.txt"), "Dark");
            Capture(window, Path.Combine(outputDirectory, "home-dark.png"));

            // The installed acceptance failure appeared after live theme switching, so
            // startup-only tests are insufficient. Exercise a full round trip on the
            // same visual tree and assert that no control remembers the previous theme.
            AppearanceService.Apply(AppThemeMode.Light);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#EEF3F8", "Round-trip Light MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: true);
            AssertThemeText(window, "Get started with AsantePDF", isLight: true);
            AssertThemeText(window, "Quick Tools", isLight: true);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-light-roundtrip.txt"), "Light round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-light-roundtrip.png"));

            AppearanceService.Apply(AppThemeMode.Dark);
            AppearanceService.ApplyToWindow(window);
            await RenderCycleAsync();
            AssertBrush(window.Background, "#09131F", "Round-trip Dark MainWindow background");
            AssertThemeText(window, "Welcome to AsantePDF", isLight: false);
            AssertThemeText(window, "Get started with AsantePDF", isLight: false);
            AssertThemeText(window, "Quick Tools", isLight: false);
            WriteContrastReport(window, Path.Combine(outputDirectory, "contrast-dark-roundtrip.txt"), "Dark round-trip");
            Capture(window, Path.Combine(outputDirectory, "home-dark-roundtrip.png"));
            await VerifyResponsiveMatrixAsync(window, outputDirectory, "home");

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
                await VerifyResponsiveMatrixAsync(window, outputDirectory, "workspace");
            }
        }
        finally
        {
            window.Close();
        }
    }

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
    private static async Task RenderCycleAsync()
    {
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.DataBind);
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Loaded);
        await Application.Current.Dispatcher.InvokeAsync(() => { }, DispatcherPriority.Render);
    }

    private static void AssertThemeText(DependencyObject root, string text, bool isLight)
    {
        var block = Descendants(root)
            .OfType<TextBlock>()
            .FirstOrDefault(item => string.Equals(item.Text?.Trim(), text, StringComparison.Ordinal));
        if (block is null)
            throw new InvalidOperationException($"Theme self-test could not find shell text '{text}'.");

        var expected = isLight ? "#0F172A" : "#F3F7FC";
        AssertBrush(block.Foreground, expected, $"{(isLight ? "Light" : "Dark")} '{text}' foreground");
    }

    private static void WriteContrastReport(DependencyObject root, string path, string themeName)
    {
        var lines = new List<string> { $"{themeName} theme text contrast audit" };
        var severe = new List<string>();

        foreach (var text in Descendants(root).OfType<TextBlock>())
        {
            if (!text.IsVisible || text.ActualWidth <= 0 || text.ActualHeight <= 0 || text.Opacity < 0.5)
                continue;
            if (string.IsNullOrWhiteSpace(text.Text))
                continue;
            if (!IsEffectivelyEnabled(text))
                continue;
            if (text.Foreground is not SolidColorBrush foreground || foreground.Opacity < 0.85)
                continue;
            var background = FindOpaqueBackground(text);
            if (background is null)
                continue;

            var ratio = ContrastRatio(foreground.Color, background.Color);
            var label = text.Text.Trim().Replace("\r", " ").Replace("\n", " ");
            if (label.Length > 90) label = label[..90] + "…";
            lines.Add($"{ratio:F2}\t{ToRgb(foreground.Color)} on {ToRgb(background.Color)}\t{label}");
            if (ratio < SevereContrastFloor)
                severe.Add($"{ratio:F2}: '{label}' ({ToRgb(foreground.Color)} on {ToRgb(background.Color)})");
        }

        File.WriteAllLines(path, lines);
        if (severe.Count > 0)
            throw new InvalidOperationException($"{themeName} theme contains unreadable text below {SevereContrastFloor:F1}:1 contrast.\n" + string.Join("\n", severe.Take(20)));
    }

    private static bool IsEffectivelyEnabled(DependencyObject element)
    {
        for (DependencyObject? current = element; current is not null; current = VisualTreeHelper.GetParent(current))
        {
            if (current is UIElement ui && !ui.IsEnabled) return false;
        }
        return true;
    }

    private static SolidColorBrush? FindOpaqueBackground(DependencyObject element)
    {
        for (DependencyObject? current = VisualTreeHelper.GetParent(element); current is not null; current = VisualTreeHelper.GetParent(current))
        {
            Brush? brush = current switch
            {
                Border border => border.Background,
                Panel panel => panel.Background,
                Window window => window.Background,
                Control control => control.Background,
                _ => null
            };
            if (brush is SolidColorBrush solid && solid.Opacity >= 0.95 && solid.Color.A >= 240)
                return solid;
        }
        return null;
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

    private static double ContrastRatio(Color a, Color b)
    {
        var lighter = Math.Max(Luminance(a), Luminance(b));
        var darker = Math.Min(Luminance(a), Luminance(b));
        return (lighter + 0.05) / (darker + 0.05);
    }

    private static double Luminance(Color color)
    {
        static double Channel(byte value)
        {
            var c = value / 255.0;
            return c <= 0.04045 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * Channel(color.R) + 0.7152 * Channel(color.G) + 0.0722 * Channel(color.B);
    }

    private static string ToRgb(Color color) => $"#{color.R:X2}{color.G:X2}{color.B:X2}";

    private static void Capture(FrameworkElement element, string path)
    {
        element.UpdateLayout();
        var width = Math.Max(1, (int)Math.Ceiling(element.ActualWidth));
        var height = Math.Max(1, (int)Math.Ceiling(element.ActualHeight));
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(element);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
    }

    private static T Require<T>(FrameworkElement root, string name) where T : FrameworkElement =>
        root.FindName(name) as T ?? throw new InvalidOperationException($"Theme self-test could not find {name}.");

    private static void AssertBrush(Brush? brush, string expected, string label)
    {
        if (brush is not SolidColorBrush solid)
            throw new InvalidOperationException($"{label}: expected a solid colour brush.");
        var actual = ToRgb(solid.Color);
        if (!string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"{label}: expected {expected}, got {actual}.");
    }
}
