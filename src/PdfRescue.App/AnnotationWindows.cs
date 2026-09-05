using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed record AnnotationEditorResult(string Contents, NativeAnnotationStyle Style);

internal sealed class AnnotationStyleWindow : Window
{
    private readonly ComboBox _color = new();
    private readonly Slider _opacity = new() { Minimum = 10, Maximum = 100, TickFrequency = 5, IsSnapToTickEnabled = true };
    private readonly Slider _border = new() { Minimum = 0.5, Maximum = 6, TickFrequency = 0.5, IsSnapToTickEnabled = true };

    public NativeAnnotationStyle? SelectedStyle { get; private set; }

    public AnnotationStyleWindow(NativeAnnotationStyle current)
    {
        Title = "Annotation style";
        Width = 460;
        Height = 390;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        _color.ItemsSource = new[] { "Yellow", "Blue", "Green", "Red", "Black" };
        _color.SelectedIndex = ClosestColor(current);
        _opacity.Value = Math.Round(current.Alpha / 255d * 100d / 5d) * 5d;
        _border.Value = Math.Clamp(current.BorderWidth, 0.5, 6);

        var root = new StackPanel { Margin = new Thickness(26) };
        root.Children.Add(new TextBlock { Text = "Annotation style", FontSize = 25, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = "Used by text markup, notes and shape annotations.", Foreground = (Brush)FindResource("MutedTextBrush"), Margin = new Thickness(0, 5, 0, 20) });
        AddField(root, "Color", _color);
        AddField(root, "Opacity", _opacity);
        AddField(root, "Shape border width", _border);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle") };
        cancel.Click += (_, _) => Close();
        var apply = new Button { Content = "Use style", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        apply.Click += (_, _) =>
        {
            var rgb = _color.SelectedIndex switch
            {
                1 => (r: (byte)45, g: (byte)125, b: (byte)255),
                2 => (r: (byte)0, g: (byte)107, b: (byte)63),
                3 => (r: (byte)206, g: (byte)17, b: (byte)38),
                4 => (r: (byte)25, g: (byte)25, b: (byte)25),
                _ => (r: (byte)252, g: (byte)209, b: (byte)22)
            };
            SelectedStyle = new NativeAnnotationStyle(rgb.r, rgb.g, rgb.b,
                (byte)Math.Clamp((int)Math.Round(_opacity.Value / 100d * 255d), 1, 255), _border.Value);
            DialogResult = true;
            Close();
        };
        buttons.Children.Add(cancel); buttons.Children.Add(apply);
        root.Children.Add(buttons);
        Content = root;
    }

    private void AddField(Panel parent, string label, FrameworkElement control)
    {
        parent.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 5) });
        parent.Children.Add(control);
    }

    private static int ClosestColor(NativeAnnotationStyle style)
    {
        if (style.Red > 180 && style.Green < 90) return 3;
        if (style.Blue > 180 && style.Red < 120) return 1;
        if (style.Green > 80 && style.Red < 80) return 2;
        if (style.Red < 80 && style.Green < 80 && style.Blue < 80) return 4;
        return 0;
    }
}

internal sealed class AnnotationEditorWindow : Window
{
    private readonly TextBox _contents = new() { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Height = 140 };
    private NativeAnnotationStyle _style;

    public AnnotationEditorResult? Result { get; private set; }

    public AnnotationEditorWindow(string title, string existingContents, NativeAnnotationStyle style)
    {
        _style = style;
        Title = title;
        Width = 540;
        Height = 430;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        ResizeMode = ResizeMode.NoResize;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];
        _contents.Text = existingContents;

        var root = new StackPanel { Margin = new Thickness(26) };
        root.Children.Add(new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = "Comment / contents", FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 18, 0, 5) });
        root.Children.Add(_contents);
        var styleButton = new Button { Content = "Color and opacity…", Style = (Style)FindResource("FlatButtonStyle"), HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 10, 0, 0) };
        styleButton.Click += (_, _) =>
        {
            var dialog = new AnnotationStyleWindow(_style) { Owner = this };
            if (dialog.ShowDialog() == true && dialog.SelectedStyle is not null) _style = dialog.SelectedStyle;
        };
        root.Children.Add(styleButton);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle") };
        cancel.Click += (_, _) => Close();
        var save = new Button { Content = "Create copy", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        save.Click += (_, _) => { Result = new AnnotationEditorResult(_contents.Text, _style); DialogResult = true; Close(); };
        buttons.Children.Add(cancel); buttons.Children.Add(save); root.Children.Add(buttons);
        Content = root;
    }
}