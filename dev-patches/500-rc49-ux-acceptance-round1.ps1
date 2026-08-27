param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)

function Read-Text([string]$relative) {
    $path = Join-Path $SourceRoot $relative
    if (-not (Test-Path $path)) { throw "Missing source file: $relative" }
    return [IO.File]::ReadAllText($path, $utf8)
}
function Write-Text([string]$relative, [string]$content) {
    $path = Join-Path $SourceRoot $relative
    $parent = Split-Path $path -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($path, $content, $utf8)
}
function Replace-Exact([string]$text, [string]$old, [string]$new, [string]$label) {
    if (-not $text.Contains($old)) { throw "Anchor not found: $label" }
    return $text.Replace($old, $new)
}

# 1. Make theme resources mutable, strengthen interaction states, and theme popup/input controls.
$appPath = 'src/PdfRescue.App/App.xaml'
$app = Read-Text $appPath
$app = Replace-Exact $app '             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"' '             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"`r`n             xmlns:presentationOptions="http://schemas.microsoft.com/winfx/2006/xaml/presentation/options"' 'App.xaml presentationOptions namespace'
$app = $app.Replace('<Color x:Key="Color.SurfaceHover">#1B2B3D</Color>', '<Color x:Key="Color.SurfaceHover">#263B50</Color>`r`n        <Color x:Key="Color.SurfacePressed">#304B64</Color>')
$app = $app.Replace('<Color x:Key="Color.Border">#26374A</Color>', '<Color x:Key="Color.Border">#36506A</Color>')
$app = $app.Replace('<Color x:Key="Color.Muted">#9FB0C3</Color>', '<Color x:Key="Color.Muted">#B7C5D4</Color>')
$app = $app.Replace('<SolidColorBrush x:Key="PanelHoverBrush" Color="{StaticResource Color.SurfaceHover}" />', '<SolidColorBrush x:Key="PanelHoverBrush" Color="{StaticResource Color.SurfaceHover}" presentationOptions:Freeze="False" />`r`n        <SolidColorBrush x:Key="PanelPressedBrush" Color="{StaticResource Color.SurfacePressed}" presentationOptions:Freeze="False" />')
foreach ($key in @('AppBackground','SidebarBackground','PanelBackground','PanelRaisedBrush','BorderBrushSoft','PrimaryTextBrush','MutedTextBrush','AccentBrush','DangerBrush','SuccessBrush')) {
    $pattern = '<SolidColorBrush x:Key="' + $key + '" Color="{StaticResource '
    $index = $app.IndexOf($pattern, [StringComparison]::Ordinal)
    if ($index -lt 0) { throw "Theme brush not found: $key" }
    $lineEnd = $app.IndexOf('/>', $index, [StringComparison]::Ordinal)
    $line = $app.Substring($index, $lineEnd - $index + 2)
    if ($line -notmatch 'presentationOptions:Freeze') {
        $app = $app.Replace($line, $line.Substring(0, $line.Length - 3) + ' presentationOptions:Freeze="False" />')
    }
}
$app = $app.Replace('<Setter TargetName="Root" Property="BorderBrush" Value="{StaticResource BorderBrushSoft}" />', '<Setter TargetName="Root" Property="BorderBrush" Value="{StaticResource AccentBrush}" />')
$app = $app.Replace('<Trigger Property="IsPressed" Value="True">`r`n                                <Setter TargetName="Root" Property="Opacity" Value="0.78" />`r`n                            </Trigger>', '<Trigger Property="IsPressed" Value="True">`r`n                                <Setter TargetName="Root" Property="Background" Value="{StaticResource PanelPressedBrush}" />`r`n                                <Setter TargetName="Root" Property="BorderBrush" Value="{StaticResource AccentBrush}" />`r`n                                <Setter TargetName="Root" Property="Opacity" Value="1" />`r`n                            </Trigger>')
$app = $app.Replace('<Setter TargetName="Root" Property="Opacity" Value="0.34" />', '<Setter TargetName="Root" Property="Opacity" Value="0.58" />')
$app = $app.Replace('<Setter Property="MinWidth" Value="58" />`r`n            <Setter Property="MinHeight" Value="62" />', '<Setter Property="MinWidth" Value="64" />`r`n            <Setter Property="MinHeight" Value="72" />')
$app = $app.Replace('<Setter Property="Background" Value="#0D1926" />', '<Setter Property="Background" Value="{StaticResource PanelRaisedBrush}" />')
$app = $app.Replace('<Setter Property="CaretBrush" Value="White" />', '<Setter Property="CaretBrush" Value="{StaticResource PrimaryTextBrush}" />')

$comboStyles = @'

        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="Background" Value="{StaticResource PanelRaisedBrush}" />
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrushSoft}" />
            <Setter Property="BorderThickness" Value="1" />
            <Setter Property="Padding" Value="9,5" />
            <Setter Property="MinHeight" Value="32" />
            <Setter Property="VerticalContentAlignment" Value="Center" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="DropDownToggle" Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border x:Name="ToggleRoot" Background="{Binding Background, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                                                BorderBrush="{Binding BorderBrush, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                                                BorderThickness="{Binding BorderThickness, RelativeSource={RelativeSource AncestorType=ComboBox}}" CornerRadius="5">
                                            <ContentPresenter />
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ToggleRoot" Property="Background" Value="{StaticResource PanelHoverBrush}"/><Setter TargetName="ToggleRoot" Property="BorderBrush" Value="{StaticResource AccentBrush}"/></Trigger>
                                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="ToggleRoot" Property="Background" Value="{StaticResource PanelPressedBrush}"/></Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="28"/></Grid.ColumnDefinitions>
                                    <ContentPresenter Margin="{TemplateBinding Padding}" VerticalAlignment="Center" HorizontalAlignment="Left"
                                                      Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" />
                                    <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe MDL2 Assets" FontSize="11"
                                               Foreground="{StaticResource MutedTextBrush}" HorizontalAlignment="Center" VerticalAlignment="Center" />
                                </Grid>
                            </ToggleButton>
                            <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                                <Border Background="{StaticResource PanelRaisedBrush}" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1" CornerRadius="5"
                                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" Padding="3" Margin="0,2,0,0">
                                    <ScrollViewer MaxHeight="340"><ItemsPresenter /></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsKeyboardFocusWithin" Value="True"><Setter Property="BorderBrush" Value="{StaticResource AccentBrush}"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.58"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="Background" Value="{StaticResource PanelRaisedBrush}" />
            <Setter Property="Padding" Value="10,7" />
            <Setter Property="HorizontalContentAlignment" Value="Stretch" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="ItemRoot" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="ItemRoot" Property="Background" Value="{StaticResource PanelHoverBrush}"/></Trigger>
                            <Trigger Property="IsSelected" Value="True"><Setter TargetName="ItemRoot" Property="Background" Value="{StaticResource PanelPressedBrush}"/></Trigger>
                            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.58"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource PrimaryTextBrush}" />
            <Setter Property="VerticalContentAlignment" Value="Center" />
        </Style>
'@
$app = Replace-Exact $app '        <Style TargetType="Separator">' ($comboStyles + "`r`n        <Style TargetType=`"Separator`">") 'insert themed combo/check styles'
Write-Text $appPath $app

# 2. Replace the brittle theme translator with original-color-aware, bidirectional recoloring.
$appearance = @'
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
        "#F4F7FA", "#FFFFFF", "#F7F9FB", "#FFFFFF", "#E4EBF2", "#D4E0EA", "#AEBFCE", "#17212B", "#53687B");

    private static readonly string[] ThemeBrushKeys =
    [
        "AppBackground", "SidebarBackground", "PanelBackground", "PanelRaisedBrush", "PanelHoverBrush",
        "PanelPressedBrush", "BorderBrushSoft", "PrimaryTextBrush", "MutedTextBrush", "AccentBrush",
        "DangerBrush", "SuccessBrush"
    ];

    private static readonly ConditionalWeakTable<DependencyObject, OriginalBrushes> OriginalTreeBrushes = new();

    private static readonly Dictionary<string, string> DarkToLight = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#09131F"] = "#F4F7FA", ["#08111C"] = "#FFFFFF", ["#101C2A"] = "#F7F9FB",
        ["#162333"] = "#FFFFFF", ["#263B50"] = "#E4EBF2", ["#304B64"] = "#D4E0EA",
        ["#36506A"] = "#AEBFCE", ["#F3F7FC"] = "#17212B", ["#B7C5D4"] = "#53687B",
        ["#08121E"] = "#FFFFFF", ["#0D1A28"] = "#F5F7FA", ["#0D1926"] = "#FFFFFF",
        ["#0E1C2B"] = "#F7F9FB", ["#0B1724"] = "#F1F4F7", ["#132236"] = "#E6EDF5",
        ["#13202E"] = "#FFFFFF", ["#0F1B29"] = "#F7F9FB", ["#111C28"] = "#EEF2F6",
        ["#0C1723"] = "#FFFFFF", ["#101F2E"] = "#FFFFFF", ["#101D2A"] = "#F5F7FA",
        ["#172738"] = "#D7E0E8", ["#243D56"] = "#C2CED9", ["#24415F"] = "#C7D3DE",
        ["#24364A"] = "#CBD5DF", ["#0A1520"] = "#EEF2F6", ["#0A1420"] = "#EEF2F6",
        ["#0E1B29"] = "#F1F4F7", ["#17283A"] = "#FFFFFF", ["#102A45"] = "#DCE7F2",
        ["#35506B"] = "#B8C6D4", ["#122131"] = "#FFFFFF", ["#29425B"] = "#B8C6D4",
        ["#3A4A59"] = "#A8B7C6", ["#41566C"] = "#8092A3", ["#53677C"] = "#6D7F90",
        ["#54708A"] = "#5B7288", ["#6282A1"] = "#58748D", ["#698096"] = "#596F84",
        ["#6F8399"] = "#637588", ["#71869D"] = "#607488", ["#73879D"] = "#607488",
        ["#7E92A8"] = "#62778C", ["#7192B1"] = "#536F88", ["#7990A7"] = "#5E7489"
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
'@
Write-Text 'src/PdfRescue.App/Services/AppearanceService.cs' $appearance

# 3. Make first launch DPI-safe with scrollable content and a fixed, always-visible footer.
$lifecyclePath = 'src/PdfRescue.App/LifecycleWindows.cs'
$lifecycle = Read-Text $lifecyclePath
$oldFirstLaunch = @'
        Width = 650;
        Height = 520;
        MinWidth = 560;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new StackPanel { Margin = new Thickness(34) };
        root.Children.Add(new TextBlock { Text = "Welcome to AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock
        {
            Text = "A free, local-first PDF workspace built for real document work.",
            FontSize = 15,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 7, 0, 26)
        });
        AddCard(root, "Free means free", "There is no Premium tier, subscription, feature lock or usage limit in AsantePDF.");
        AddCard(root, "Your files stay local", "Normal viewing, editing, OCR, conversion and PDF processing happen on this computer.");
        AddCard(root, "Start from Home", "Open a PDF, drag one into the window, or choose a standalone tool without opening a document first.");
        AddCard(root, "Your workspace can recover", "AsantePDF can remember normal sessions and separately keep a local crash-recovery snapshot for unsaved page-layout work.");

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        var settings = new Button { Content = "You can change themes and privacy in Settings", IsEnabled = false, Style = (Style)FindResource("FlatButtonStyle"), Margin = new Thickness(0, 0, 10, 0) };
        var start = new Button { Content = "Start using AsantePDF", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(18, 9, 18, 9) };
        start.Click += (_, _) => { DialogResult = true; Close(); };
        buttons.Children.Add(settings);
        buttons.Children.Add(start);
        root.Children.Add(buttons);
        Content = root;
'@
$newFirstLaunch = @'
        Width = 700;
        Height = Math.Min(640, Math.Max(500, SystemParameters.WorkArea.Height - 80));
        MinWidth = 600;
        MinHeight = 500;
        ResizeMode = ResizeMode.CanResizeWithGrip;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        var root = new Grid { Margin = new Thickness(30, 26, 30, 24) };
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var content = new StackPanel { Margin = new Thickness(0, 0, 8, 0) };
        content.Children.Add(new TextBlock { Text = "Welcome to AsantePDF", FontSize = 30, FontWeight = FontWeights.SemiBold });
        content.Children.Add(new TextBlock
        {
            Text = "A free, local-first PDF workspace built for real document work.",
            FontSize = 15,
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            Margin = new Thickness(0, 7, 0, 24)
        });
        AddCard(content, "Free means free", "There is no Premium tier, subscription, feature lock or usage limit in AsantePDF.");
        AddCard(content, "Your files stay local", "Normal viewing, editing, OCR, conversion and PDF processing happen on this computer.");
        AddCard(content, "Start from Home", "Open a PDF, drag one into the window, or choose a standalone tool without opening a document first.");
        AddCard(content, "Your workspace can recover", "AsantePDF can remember normal sessions and separately keep a local crash-recovery snapshot for unsaved page-layout work.");

        var scroll = new ScrollViewer
        {
            Content = content,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        root.Children.Add(scroll);

        var footer = new Grid { Margin = new Thickness(0, 18, 0, 0) };
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var settingsNote = new TextBlock
        {
            Text = "Themes, privacy, recovery and defaults are available in Settings.",
            Foreground = (Brush)Application.Current.Resources["MutedTextBrush"],
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 18, 0)
        };
        footer.Children.Add(settingsNote);
        var start = new Button { Content = "Start using AsantePDF", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(18, 9, 18, 9) };
        start.Click += (_, _) => { DialogResult = true; Close(); };
        Grid.SetColumn(start, 1);
        footer.Children.Add(start);
        Grid.SetRow(footer, 1);
        root.Children.Add(footer);
        Content = root;
'@
$lifecycle = Replace-Exact $lifecycle $oldFirstLaunch $newFirstLaunch 'FirstLaunchWindow fixed layout'
Write-Text $lifecyclePath $lifecycle

# 4. Respect the Windows work area when the custom borderless window is maximized.
$chrome = @'
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace PdfRescue.App;

public partial class MainWindow
{
    private const int WmGetMinMaxInfo = 0x0024;
    private const uint MonitorDefaultToNearest = 0x00000002;

    private void InitializeWindowWorkAreaBehavior()
    {
        SourceInitialized += (_, _) =>
        {
            if (PresentationSource.FromVisual(this) is HwndSource source)
                source.AddHook(WindowWorkAreaHook);
        };
        StateChanged += (_, _) => UpdateMaximizeButtonAccessibility();
    }

    private IntPtr WindowWorkAreaHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg != WmGetMinMaxInfo) return IntPtr.Zero;

        var info = Marshal.PtrToStructure<MinMaxInfo>(lParam);
        var monitor = MonitorFromWindow(hwnd, MonitorDefaultToNearest);
        if (monitor != IntPtr.Zero)
        {
            var monitorInfo = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
            if (GetMonitorInfo(monitor, ref monitorInfo))
            {
                var work = monitorInfo.WorkArea;
                var bounds = monitorInfo.MonitorArea;
                info.MaxPosition.X = Math.Abs(work.Left - bounds.Left);
                info.MaxPosition.Y = Math.Abs(work.Top - bounds.Top);
                info.MaxSize.X = Math.Abs(work.Right - work.Left);
                info.MaxSize.Y = Math.Abs(work.Bottom - work.Top);
                info.MaxTrackSize = info.MaxSize;
            }
        }

        Marshal.StructureToPtr(info, lParam, true);
        handled = true;
        return IntPtr.Zero;
    }

    private void UpdateMaximizeButtonAccessibility()
    {
        if (MaximizeWindowButton is null || MaximizeWindowGlyph is null) return;
        var maximized = WindowState == WindowState.Maximized;
        MaximizeWindowGlyph.Text = maximized ? "\uE923" : "\uE922";
        MaximizeWindowButton.ToolTip = maximized ? "Restore" : "Maximize";
        System.Windows.Automation.AutomationProperties.SetName(MaximizeWindowButton, maximized ? "Restore AsantePDF window" : "Maximize AsantePDF window");
    }

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MinMaxInfo
    {
        public NativePoint Reserved;
        public NativePoint MaxSize;
        public NativePoint MaxPosition;
        public NativePoint MinTrackSize;
        public NativePoint MaxTrackSize;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MonitorInfo
    {
        public int Size;
        public NativeRect MonitorArea;
        public NativeRect WorkArea;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect { public int Left; public int Top; public int Right; public int Bottom; }
}
'@
Write-Text 'src/PdfRescue.App/MainWindow.WindowChrome.cs' $chrome

$mainCsPath = 'src/PdfRescue.App/MainWindow.xaml.cs'
$mainCs = Read-Text $mainCsPath
$mainCs = Replace-Exact $mainCs '        InitializeComponent();`r`n        PagesList.ItemsSource = Pages;' '        InitializeComponent();`r`n        InitializeWindowWorkAreaBehavior();`r`n        PagesList.ItemsSource = Pages;' 'initialize work-area-aware window chrome'
Write-Text $mainCsPath $mainCs

# 5. Move Task Center out of the Home/document replacement surface into a dedicated drawer.
$productPath = 'src/PdfRescue.App/MainWindow.ProductShell.cs'
$product = Read-Text $productPath
$oldTask = @'
    private void TaskCenterNav_Click(object sender, RoutedEventArgs e)
    {
        PersistWorkspacePosition(immediate: true);
        if (_taskCenterView is null) return;
        EmptyPanel.Child = _taskCenterView;
        EmptyPanel.Visibility = Visibility.Visible;
    }
'@
$newTask = @'
    private void TaskCenterNav_Click(object sender, RoutedEventArgs e)
    {
        PersistWorkspacePosition(immediate: true);
        if (_taskCenterView is null || TaskCenterDrawer is null || TaskCenterHost is null) return;
        TaskCenterHost.Content = _taskCenterView;
        TaskCenterDrawer.Visibility = TaskCenterDrawer.Visibility == Visibility.Visible
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    private void TaskCenterClose_Click(object sender, RoutedEventArgs e)
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
    }

    private void CloseTaskCenterDrawer()
    {
        if (TaskCenterDrawer is not null) TaskCenterDrawer.Visibility = Visibility.Collapsed;
    }
'@
$product = Replace-Exact $product $oldTask $newTask 'Task Center non-destructive drawer behavior'
$product = $product.Replace('    private void HomeNav_Click(object sender, RoutedEventArgs e)`r`n    {`r`n        PersistWorkspacePosition(immediate: true);', '    private void HomeNav_Click(object sender, RoutedEventArgs e)`r`n    {`r`n        CloseTaskCenterDrawer();`r`n        PersistWorkspacePosition(immediate: true);')
$product = $product.Replace('    private void DocumentNav_Click(object sender, RoutedEventArgs e)`r`n    {`r`n        if (_currentPdf is null) return;', '    private void DocumentNav_Click(object sender, RoutedEventArgs e)`r`n    {`r`n        CloseTaskCenterDrawer();`r`n        if (_currentPdf is null) return;')
Write-Text $productPath $product

# 6. Main-window visual fixes: task drawer, stronger theme tokens, maximize glyph state, and ribbon alignment/icon corrections.
$xamlPath = 'src/PdfRescue.App/MainWindow.xaml'
$xaml = Read-Text $xamlPath
$xaml = $xaml.Replace('<Button Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MaximizeWindow_Click" ToolTip="Maximize" AutomationProperties.Name="Maximize or restore AsantePDF window"><TextBlock Text="&#xE922;" FontFamily="Segoe MDL2 Assets" /></Button>', '<Button x:Name="MaximizeWindowButton" Style="{StaticResource FlatButtonStyle}" Width="46" Margin="0" Click="MaximizeWindow_Click" ToolTip="Maximize" AutomationProperties.Name="Maximize AsantePDF window"><TextBlock x:Name="MaximizeWindowGlyph" Text="&#xE922;" FontFamily="Segoe MDL2 Assets" /></Button>')

# Route low-contrast structural copy through the theme token.
foreach ($color in @('#6F8399','#71869D','#73879D','#698096','#6282A1','#7E92A8','#7192B1')) {
    $xaml = $xaml.Replace('Foreground="' + $color + '"', 'Foreground="{StaticResource MutedTextBrush}"')
}

# Normalize the Edit & Annotate group baseline and replace the clearest wrong glyphs.
$xaml = $xaml.Replace('<TextBlock Text="&#xE70F;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#F0B93A"/><TextBlock Text="Highlight" FontSize="12" Margin="0,5,0,0"/>', '<Grid Width="28" Height="28" HorizontalAlignment="Center"><Border Width="22" Height="8" Background="#F0B93A" CornerRadius="2" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5"><Border.RenderTransform><RotateTransform Angle="-8"/></Border.RenderTransform></Border></Grid><TextBlock Text="Highlight" FontSize="12" Margin="0,4,0,0"/>')
$xaml = $xaml.Replace('<TextBlock Text="●" FontSize="21" HorizontalAlignment="Center" Foreground="#FCD116"/><TextBlock Text="Style" FontSize="12" Margin="0,5,0,0"/>', '<Grid Width="28" Height="28" HorizontalAlignment="Center"><StackPanel VerticalAlignment="Center"><Border Height="2" Width="22" Background="#FCD116" Margin="0,2"/><Border Height="2" Width="16" Background="#FCD116" Margin="0,2"/><Border Height="2" Width="20" Background="#FCD116" Margin="0,2"/></StackPanel></Grid><TextBlock Text="Style" FontSize="12" Margin="0,4,0,0"/>')
$xaml = $xaml.Replace('<TextBlock Text="&#xE8D7;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#EF5C8B"/><TextBlock Text="Redact" FontSize="12" Margin="0,5,0,0"/>', '<Grid Width="28" Height="28" HorizontalAlignment="Center"><Border Width="23" Height="15" Background="#111111" BorderBrush="#EF5C8B" BorderThickness="1" CornerRadius="2" VerticalAlignment="Center"><Border Height="3" Background="#EF5C5C" Margin="3,0"/></Border></Grid><TextBlock Text="Redact" FontSize="12" Margin="0,4,0,0"/>')
$xaml = $xaml.Replace('<TextBlock Text="&#xE8B0;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#4D9BFF"/><TextBlock Text="Duplicate" FontSize="12" Margin="0,5,0,0"/>', '<Grid Width="28" Height="28" HorizontalAlignment="Center"><Border Width="15" Height="18" BorderBrush="#4D9BFF" BorderThickness="2" CornerRadius="1" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="4,3,0,0"/><Border Width="15" Height="18" BorderBrush="#4D9BFF" BorderThickness="2" CornerRadius="1" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,4,3"/></Grid><TextBlock Text="Duplicate" FontSize="12" Margin="0,4,0,0"/>')
$xaml = $xaml.Replace('Text="OCR" FontSize="12" Margin="0,8,0,0"', 'Text="OCR" FontSize="12" Margin="0,5,0,0"')

# Make document search surface use the theme rather than a fixed dark fill.
$xaml = $xaml.Replace('<Border Grid.Column="2" Background="#101D2A"', '<Border Grid.Column="2" Background="{StaticResource PanelRaisedBrush}"')

$drawer = @'

                <!-- Task Center is a non-destructive workspace drawer, not a replacement for Home/document mode. -->
                <Border x:Name="TaskCenterDrawer" Panel.ZIndex="60" Visibility="Collapsed" HorizontalAlignment="Right"
                        Width="720" MaxWidth="780" Background="{StaticResource AppBackground}"
                        BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="1,0,0,0">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="48"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <Border Background="{StaticResource PanelRaisedBrush}" BorderBrush="{StaticResource BorderBrushSoft}" BorderThickness="0,0,0,1">
                            <Grid Margin="16,0,10,0">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="17" Foreground="{StaticResource AccentBrush}" Margin="0,0,9,0"/>
                                    <TextBlock Text="Task Center" FontWeight="SemiBold" FontSize="15"/>
                                    <TextBlock Text="  ·  background work continues while you return to documents" Foreground="{StaticResource MutedTextBrush}" FontSize="12" VerticalAlignment="Center"/>
                                </StackPanel>
                                <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Width="36" Height="32" Padding="0" Margin="0"
                                        Click="TaskCenterClose_Click" ToolTip="Close Task Center" AutomationProperties.Name="Close Task Center drawer">
                                    <TextBlock Text="&#xE8BB;" FontFamily="Segoe MDL2 Assets" FontSize="13"/>
                                </Button>
                            </Grid>
                        </Border>
                        <ContentControl x:Name="TaskCenterHost" Grid.Row="1" />
                    </Grid>
                </Border>
'@
$xaml = Replace-Exact $xaml '                </Border>`r`n            </Grid>`r`n        </Grid>`r`n`r`n        <!-- Status / active task strip -->' ('                </Border>' + $drawer + "`r`n            </Grid>`r`n        </Grid>`r`n`r`n        <!-- Status / active task strip -->") 'Task Center drawer host'
Write-Text $xamlPath $xaml

# 7. Task Center contrast and density cleanup for the drawer.
$taskPath = 'src/PdfRescue.App/TaskCenterView.xaml'
$task = Read-Text $taskPath
$task = $task.Replace('Margin="42,32,42,16"', 'Margin="24,22,24,14"')
$task = $task.Replace('Margin="42,0,42,18"', 'Margin="24,0,24,16"')
$task = $task.Replace('Margin="42,0,42,32"', 'Margin="24,0,24,24"')
$task = $task.Replace('FontSize="30"', 'FontSize="26"')
foreach ($color in @('#7990A7','#53677C','#54708A')) {
    $task = $task.Replace('Foreground="' + $color + '"', 'Foreground="{StaticResource MutedTextBrush}"')
}
Write-Text $taskPath $task

Write-Host 'RC49 UX acceptance round 1 staged successfully.' -ForegroundColor Green
