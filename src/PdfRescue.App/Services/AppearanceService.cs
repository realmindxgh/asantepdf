using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace PdfRescue.App.Services;

public static class AppearanceService
{
    private sealed record ThemeColors(
        string Window,
        string Sidebar,
        string Surface,
        string Raised,
        string Hover,
        string Border,
        string Text,
        string Muted);

    private static readonly ThemeColors Dark = new(
        "#09131F", "#08111C", "#101C2A", "#162333", "#1B2B3D", "#26374A", "#F3F7FC", "#9FB0C3");
    private static readonly ThemeColors Light = new(
        "#F4F7FA", "#FFFFFF", "#F7F9FB", "#FFFFFF", "#E7EDF3", "#CBD5DF", "#17212B", "#607184");

    private static readonly Dictionary<string, string> DarkToLight = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#09131F"] = "#F4F7FA", ["#08111C"] = "#FFFFFF", ["#101C2A"] = "#F7F9FB",
        ["#162333"] = "#FFFFFF", ["#1B2B3D"] = "#E7EDF3", ["#26374A"] = "#CBD5DF",
        ["#F3F7FC"] = "#17212B", ["#9FB0C3"] = "#607184", ["#08121E"] = "#FFFFFF",
        ["#0D1A28"] = "#F5F7FA", ["#0D1926"] = "#FFFFFF", ["#0E1C2B"] = "#F7F9FB",
        ["#0B1724"] = "#F1F4F7", ["#132236"] = "#E6EDF5", ["#13202E"] = "#FFFFFF",
        ["#0F1B29"] = "#F7F9FB", ["#111C28"] = "#EEF2F6", ["#0C1723"] = "#FFFFFF",
        ["#101F2E"] = "#FFFFFF", ["#172738"] = "#D7E0E8", ["#243D56"] = "#C2CED9",
        ["#24415F"] = "#C7D3DE", ["#24364A"] = "#CBD5DF", ["#0A1520"] = "#EEF2F6",
        ["#0E1B29"] = "#F1F4F7", ["#17283A"] = "#FFFFFF", ["#102A45"] = "#DCE7F2",
        ["#35506B"] = "#B8C6D4", ["#6F8399"] = "#637588", ["#71869D"] = "#607488",
        ["#73879D"] = "#607488", ["#7E92A8"] = "#62778C", ["#7192B1"] = "#536F88"
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
        window.Background = ResourceBrush("AppBackground");
        ApplyTree(window, IsLight);
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
        if (Application.Current.Resources[key] is SolidColorBrush brush && !brush.IsFrozen)
            brush.Color = color;
        else
            Application.Current.Resources[key] = new SolidColorBrush(color);
    }

    private static Brush ResourceBrush(string key) =>
        Application.Current.Resources[key] as Brush ?? Brushes.Transparent;

    private static void ApplyTree(DependencyObject root, bool light)
    {
        switch (root)
        {
            case Panel panel when panel.Background is SolidColorBrush panelBrush:
                panel.Background = MapBrush(panelBrush, light);
                break;
            case Border border:
                if (border.Background is SolidColorBrush background) border.Background = MapBrush(background, light);
                if (border.BorderBrush is SolidColorBrush borderBrush) border.BorderBrush = MapBrush(borderBrush, light);
                break;
            case Control control:
                if (control.Background is SolidColorBrush controlBackground) control.Background = MapBrush(controlBackground, light);
                if (control.Foreground is SolidColorBrush controlForeground) control.Foreground = MapBrush(controlForeground, light);
                if (control.BorderBrush is SolidColorBrush controlBorder) control.BorderBrush = MapBrush(controlBorder, light);
                break;
            case TextBlock text when text.Foreground is SolidColorBrush textBrush:
                text.Foreground = MapBrush(textBrush, light);
                break;
            case Shape shape:
                if (shape.Fill is SolidColorBrush fill) shape.Fill = MapBrush(fill, light);
                if (shape.Stroke is SolidColorBrush stroke) shape.Stroke = MapBrush(stroke, light);
                break;
        }

        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++) ApplyTree(VisualTreeHelper.GetChild(root, i), light);
    }

    private static Brush MapBrush(SolidColorBrush brush, bool light)
    {
        var current = brush.Color.ToString();
        if (light && DarkToLight.TryGetValue(current, out var lightColor))
            return new SolidColorBrush((Color)ColorConverter.ConvertFromString(lightColor)!);
        if (!light)
        {
            var pair = DarkToLight.FirstOrDefault(item => string.Equals(item.Value, current, StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrWhiteSpace(pair.Key))
                return new SolidColorBrush((Color)ColorConverter.ConvertFromString(pair.Key)!);
        }
        return brush;
    }
}