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