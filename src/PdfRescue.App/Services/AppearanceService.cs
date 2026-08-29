using Microsoft.Win32;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

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
        "DangerBrush", "SuccessBrush", "IconChipTextBrush", "CommandBlueBrush", "CommandCyanBrush",
        "CommandGoldBrush", "CommandGreenBrush", "CommandPurpleBrush", "CommandOrangeBrush",
        "CommandTealBrush", "CommandLimeBrush", "CommandDangerBrush"
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
        SetBrush("IconChipTextBrush", "#FFFFFF");

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
        if (Application.Current.Resources[key] is SolidColorBrush brush && !brush.IsFrozen)
        {
            brush.Color = color;
            return;
        }

        // WPF may freeze application-level Freezables while loading resources. This is
        // safe because the theme contract requires every semantic palette consumer to
        // use DynamicResource, so replacing a frozen resource is observed immediately.
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

    private static bool IsExpressionValue(DependencyObject target, DependencyProperty property) =>
        DependencyPropertyHelper.GetValueSource(target, property).IsExpression;

    private static void ApplyLegacyTree(DependencyObject root)
    {
        switch (root)
        {
            case Panel panel when panel.Background is SolidColorBrush panelBrush &&
                                  !IsExpressionValue(panel, Panel.BackgroundProperty):
                panel.Background = MapLegacyBrush(panelBrush);
                break;
            case Border border:
                if (border.Background is SolidColorBrush background &&
                    !IsExpressionValue(border, Border.BackgroundProperty))
                    border.Background = MapLegacyBrush(background);
                if (border.BorderBrush is SolidColorBrush borderBrush &&
                    !IsExpressionValue(border, Border.BorderBrushProperty))
                    border.BorderBrush = MapLegacyBrush(borderBrush);
                break;
            case Control control:
                if (control.Background is SolidColorBrush controlBackground &&
                    !IsExpressionValue(control, Control.BackgroundProperty))
                    control.Background = MapLegacyBrush(controlBackground);
                if (control.Foreground is SolidColorBrush controlForeground &&
                    !IsExpressionValue(control, Control.ForegroundProperty))
                    control.Foreground = MapLegacyBrush(controlForeground);
                if (control.BorderBrush is SolidColorBrush controlBorder &&
                    !IsExpressionValue(control, Control.BorderBrushProperty))
                    control.BorderBrush = MapLegacyBrush(controlBorder);
                break;
            case TextBlock text when text.Foreground is SolidColorBrush textBrush &&
                                     !IsExpressionValue(text, TextBlock.ForegroundProperty):
                text.Foreground = MapLegacyBrush(textBrush);
                break;
            case Shape shape:
                if (shape.Fill is SolidColorBrush fill && !IsExpressionValue(shape, Shape.FillProperty))
                    shape.Fill = MapLegacyBrush(fill);
                if (shape.Stroke is SolidColorBrush stroke && !IsExpressionValue(shape, Shape.StrokeProperty))
                    shape.Stroke = MapLegacyBrush(stroke);
                break;
        }

        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++) ApplyLegacyTree(VisualTreeHelper.GetChild(root, i));
    }
}