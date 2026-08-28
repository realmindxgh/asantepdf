using Microsoft.Win32;
using System.Runtime.CompilerServices;
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
        string Pressed,
        string Border,
        string Text,
        string Muted);

    private sealed class OriginalBrushes
    {
        public Dictionary<string, Color> Colors { get; } = new(StringComparer.Ordinal);
    }

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

    private static readonly ConditionalWeakTable<DependencyObject, OriginalBrushes> OriginalTreeBrushes = new();

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
        if (Application.Current.Resources[key] is SolidColorBrush brush)
        {
            if (brush.IsFrozen)
                Application.Current.Resources[key] = new SolidColorBrush(color);
            else
                brush.Color = color;
        }
        else
        {
            Application.Current.Resources[key] = new SolidColorBrush(color);
        }
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

    private static Brush ThemeTreeBrush(DependencyObject owner, string slot, SolidColorBrush brush, bool light)
    {
        if (IsLiveThemeResourceBrush(brush)) return brush;

        var originals = OriginalTreeBrushes.GetOrCreateValue(owner);
        if (!originals.Colors.TryGetValue(slot, out var original))
        {
            original = brush.Color;
            originals.Colors[slot] = original;
        }

        if (!light) return new SolidColorBrush(original);
        return DarkToLight.TryGetValue(ToRgbKey(original), out var mapped)
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString(mapped)!)
            : new SolidColorBrush(original);
    }

    private static string ToRgbKey(Color color) => $"#{color.R:X2}{color.G:X2}{color.B:X2}";

    private static void ApplyTree(DependencyObject root, bool light)
    {
        switch (root)
        {
            case Panel panel when panel.Background is SolidColorBrush panelBrush:
                panel.Background = ThemeTreeBrush(panel, "Background", panelBrush, light);
                break;
            case Border border:
                if (border.Background is SolidColorBrush background)
                    border.Background = ThemeTreeBrush(border, "Background", background, light);
                if (border.BorderBrush is SolidColorBrush borderBrush)
                    border.BorderBrush = ThemeTreeBrush(border, "BorderBrush", borderBrush, light);
                break;
            case Control control:
                if (control.Background is SolidColorBrush controlBackground)
                    control.Background = ThemeTreeBrush(control, "Background", controlBackground, light);
                if (control.Foreground is SolidColorBrush controlForeground)
                    control.Foreground = ThemeTreeBrush(control, "Foreground", controlForeground, light);
                if (control.BorderBrush is SolidColorBrush controlBorder)
                    control.BorderBrush = ThemeTreeBrush(control, "BorderBrush", controlBorder, light);
                break;
            case TextBlock text when text.Foreground is SolidColorBrush textBrush:
                text.Foreground = ThemeTreeBrush(text, "Foreground", textBrush, light);
                break;
            case Shape shape:
                if (shape.Fill is SolidColorBrush fill)
                    shape.Fill = ThemeTreeBrush(shape, "Fill", fill, light);
                if (shape.Stroke is SolidColorBrush stroke)
                    shape.Stroke = ThemeTreeBrush(shape, "Stroke", stroke, light);
                break;
        }

        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++) ApplyTree(VisualTreeHelper.GetChild(root, i), light);
    }
}