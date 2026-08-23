using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;

namespace PdfRescue.App;

public partial class MainWindow
{
    private sealed record HomeRecentItem(string Name, string Path, string Detail, bool Missing)
    {
        public bool Available => !Missing;
    }

    private HomeRecentItem[] _homeRecentItems = [];

    private void ProductShell_Loaded(object sender, RoutedEventArgs e)
    {
        LoadHomeRecents();
        PagesList.SelectionChanged += ProductShell_PagesSelectionChanged;
        RefreshProductShellMode();
    }

    private void RefreshProductShellMode()
    {
        if (_currentPdf is null)
        {
            EmptyPanel.Visibility = Visibility.Visible;
            PreviewScroll.Visibility = Visibility.Collapsed;
        }
    }

    private void WindowDrag_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;
            return;
        }
        if (e.LeftButton == MouseButtonState.Pressed) DragMove();
    }

    private void MinimizeWindow_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void MaximizeWindow_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    private void CloseWindow_Click(object sender, RoutedEventArgs e) => Close();

    private void HomeNav_Click(object sender, RoutedEventArgs e)
    {
        EmptyPanel.Visibility = Visibility.Visible;
        LoadHomeRecents();
    }

    private void DocumentNav_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        EmptyPanel.Visibility = Visibility.Collapsed;
        PreviewScroll.Visibility = Visibility.Visible;
    }

    private async Task<string?> SelectPdfForStandaloneToolAsync(string title)
    {
        var dialog = new OpenFileDialog
        {
            Title = title,
            Filter = "PDF files (*.pdf)|*.pdf",
            CheckFileExists = true,
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != true) return null;
        await OpenPdfAsync(dialog.FileName);
        return _currentPdf;
    }

    private async void HomeOcr_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to OCR") is not null)
            OcrPdf_Click(sender, e);
    }

    private async void HomeCompress_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to compress") is not null)
            Compress_Click(sender, e);
    }

    private async void HomeDoctor_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to inspect") is not null)
            Doctor_Click(sender, e);
    }

    private async void HomeSplit_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to split") is not null)
            Split_Click(sender, e);
    }

    private async void HomeToWord_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Word") is not null)
            PdfToWord_Click(sender, e);
    }

    private async void RecentItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string path } && File.Exists(path))
            await OpenPdfAsync(path);
    }

    private void LoadHomeRecents()
    {
        if (HomeRecentList is null) return;
        string[] paths;
        try
        {
            paths = File.Exists(RecentDocumentsPath)
                ? File.ReadAllLines(RecentDocumentsPath).Where(p => !string.IsNullOrWhiteSpace(p)).Take(12).ToArray()
                : [];
        }
        catch
        {
            paths = [];
        }

        var items = paths.Select(path =>
        {
            var missing = !File.Exists(path);
            var detail = missing
                ? "File moved or unavailable"
                : $"{new FileInfo(path).Length / 1024d / 1024d:0.##} MB  •  {Path.GetDirectoryName(path)}";
            return new HomeRecentItem(Path.GetFileName(path), path, detail, missing);
        }).ToArray();

        _homeRecentItems = items;
        HomeRecentList.ItemsSource = items;
        HomeNoRecentText.Visibility = items.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void HomeSearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (HomeRecentList is null) return;
        var query = HomeSearchBox.Text.Trim();
        var filtered = string.IsNullOrWhiteSpace(query)
            ? _homeRecentItems
            : _homeRecentItems.Where(item =>
                item.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                item.Path.Contains(query, StringComparison.OrdinalIgnoreCase)).ToArray();
        HomeRecentList.ItemsSource = filtered;
        HomeNoRecentText.Visibility = filtered.Length == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void HomeRecentNav_Click(object sender, RoutedEventArgs e)
    {
        EmptyPanel.Visibility = Visibility.Visible;
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
    }

    private void ProductShell_PagesSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (PageNumberBox is null || PageCountText is null) return;
        var current = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 0;
        PageNumberBox.Text = current == 0 ? string.Empty : current.ToString();
        PageCountText.Text = $"/ {Pages.Count:N0}";
    }

    private void PreviousPage_Click(object sender, RoutedEventArgs e)
    {
        if (PagesList.Items.Count == 0) return;
        PagesList.SelectedIndex = Math.Max(0, PagesList.SelectedIndex - 1);
        PagesList.ScrollIntoView(PagesList.SelectedItem);
    }

    private void NextPage_Click(object sender, RoutedEventArgs e)
    {
        if (PagesList.Items.Count == 0) return;
        PagesList.SelectedIndex = Math.Min(PagesList.Items.Count - 1, PagesList.SelectedIndex + 1);
        PagesList.ScrollIntoView(PagesList.SelectedItem);
    }

    private void PageNumberBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || PagesList.Items.Count == 0) return;
        if (int.TryParse(PageNumberBox.Text, out var page))
        {
            page = Math.Clamp(page, 1, PagesList.Items.Count);
            PagesList.SelectedIndex = page - 1;
            PagesList.ScrollIntoView(PagesList.SelectedItem);
        }
        e.Handled = true;
    }

    private void FitPageShell_Click(object sender, RoutedEventArgs e)
    {
        if (PreviewImage.Source is not System.Windows.Media.Imaging.BitmapSource bitmap) return;
        var viewportWidth = PreviewScroll.ViewportWidth > 100 ? PreviewScroll.ViewportWidth : PreviewScroll.ActualWidth;
        var viewportHeight = PreviewScroll.ViewportHeight > 100 ? PreviewScroll.ViewportHeight : PreviewScroll.ActualHeight;
        if (viewportWidth <= 100 || viewportHeight <= 100) return;
        var widthByHeight = bitmap.PixelWidth * Math.Max(0.1, (viewportHeight - 64) / Math.Max(1, bitmap.PixelHeight));
        _previewWidth = (uint)Math.Clamp((int)Math.Round(Math.Min(viewportWidth - 64, widthByHeight)), 320, 2000);
        _ = RerenderSelectedPageAsync();
    }

    private void ActualSizeShell_Click(object sender, RoutedEventArgs e)
    {
        _previewWidth = 1100;
        _ = RerenderSelectedPageAsync();
    }

    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        NavigationPlaceholder.Visibility = Visibility.Collapsed;
    }

    private void PageModePlaceholder_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Collapsed;
        NavigationPlaceholder.Visibility = Visibility.Visible;
    }
}