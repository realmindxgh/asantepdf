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

    public static async Task RunAsync(string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);
        await VerifyRecentFilesControlsAsync(outputDirectory);
        await VerifyWholeShellAsync(outputDirectory);
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
            Capture(host, Path.Combine(outputDirectory, "recent-light.png"));

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
            Capture(host, Path.Combine(outputDirectory, "recent-dark.png"));
        }
        finally
        {
            host.Close();
        }
    }

    private static async Task VerifyWholeShellAsync(string outputDirectory)
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
        }
        finally
        {
            window.Close();
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
                Control control => control.Background,
                Window window => window.Background,
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
