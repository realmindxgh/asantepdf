using System.Windows;
using System.Windows.Controls;

namespace PdfRescue.App;

internal enum PrintPageScope
{
    All,
    Current,
    Selected,
    Custom
}

internal sealed record PrintOptions(int[] Pages, bool Landscape, bool FitToPrintableArea);

internal sealed class PrintOptionsWindow : Window
{
    private readonly int _pageCount;
    private readonly int _currentPage;
    private readonly int[] _selectedPages;
    private readonly ComboBox _scope = new();
    private readonly TextBox _customRange = new();
    private readonly ComboBox _orientation = new();
    private readonly CheckBox _fit = new() { Content = "Fit each page to the printer's printable area", IsChecked = true };

    public PrintOptions? Options { get; private set; }

    public PrintOptionsWindow(int pageCount, int currentPage, int[] selectedPages)
    {
        _pageCount = Math.Max(1, pageCount);
        _currentPage = Math.Clamp(currentPage, 1, _pageCount);
        _selectedPages = selectedPages.Where(page => page >= 1 && page <= _pageCount).Distinct().OrderBy(page => page).ToArray();

        Title = "Print AsantePDF document";
        Width = 520;
        Height = 470;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (System.Windows.Media.Brush)Application.Current.Resources["AppBackground"];
        Foreground = (System.Windows.Media.Brush)Application.Current.Resources["PrimaryTextBrush"];

        _scope.ItemsSource = new[] { "All pages", $"Current page ({_currentPage})", _selectedPages.Length > 0 ? $"Selected pages ({FormatPages(_selectedPages)})" : "Selected pages (none)", "Custom range" };
        _scope.SelectedIndex = _selectedPages.Length > 1 ? 2 : 0;
        _scope.SelectionChanged += (_, _) => _customRange.IsEnabled = _scope.SelectedIndex == 3;
        _customRange.Text = "1-" + _pageCount;
        _customRange.IsEnabled = false;
        _orientation.ItemsSource = new[] { "Printer default / Portrait", "Landscape" };
        _orientation.SelectedIndex = 0;

        var content = new StackPanel { Margin = new Thickness(24) };
        content.Children.Add(new TextBlock { Text = "Print", FontSize = 26, FontWeight = FontWeights.SemiBold });
        content.Children.Add(new TextBlock { Text = "Choose pages and layout, then select the printer and number of copies in the Windows print dialog.", TextWrapping = TextWrapping.Wrap, Foreground = (System.Windows.Media.Brush)FindResource("MutedTextBrush"), Margin = new Thickness(0, 5, 0, 18) });
        AddField(content, "Pages", _scope);
        AddField(content, "Custom range", _customRange, "Examples: 1-3,5,8-10");
        AddField(content, "Orientation", _orientation);
        content.Children.Add(_fit);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 24, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle"), Padding = new Thickness(15, 8, 15, 8) };
        cancel.Click += (_, _) => Close();
        var next = new Button { Content = "Choose Printer", Style = (Style)FindResource("PrimaryButtonStyle"), Padding = new Thickness(16, 8, 16, 8) };
        next.Click += Next_Click;
        buttons.Children.Add(cancel); buttons.Children.Add(next); content.Children.Add(buttons);
        Content = content;
        Loaded += (_, _) => PdfRescue.App.Services.AppearanceService.ApplyToWindow(this);
    }

    private void Next_Click(object sender, RoutedEventArgs e)
    {
        int[] pages;
        switch (_scope.SelectedIndex)
        {
            case 1: pages = [_currentPage]; break;
            case 2:
                if (_selectedPages.Length == 0)
                {
                    MessageBox.Show(this, "No pages are selected in the document.", "Print", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                pages = _selectedPages;
                break;
            case 3:
                if (!PageScopeParser.TryParse(_customRange.Text, _pageCount, out pages, out var error))
                {
                    MessageBox.Show(this, error, "Print range", MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }
                break;
            default: pages = Enumerable.Range(1, _pageCount).ToArray(); break;
        }

        Options = new PrintOptions(pages, _orientation.SelectedIndex == 1, _fit.IsChecked == true);
        DialogResult = true;
    }

    private static void AddField(Panel panel, string label, UIElement control, string? help = null)
    {
        panel.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 4) });
        panel.Children.Add(control);
        if (!string.IsNullOrWhiteSpace(help)) panel.Children.Add(new TextBlock { Text = help, FontSize = 11, Foreground = (System.Windows.Media.Brush)Application.Current.Resources["MutedTextBrush"], Margin = new Thickness(0, 3, 0, 0) });
    }

    private static string FormatPages(IEnumerable<int> pages) => string.Join(", ", pages.Take(6)) + (pages.Count() > 6 ? "…" : string.Empty);
}