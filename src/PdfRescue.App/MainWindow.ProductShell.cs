using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly RecentDocumentService _recentDocuments = new();
    private RecentFilesView? _recentFilesView;
    private string? _lastRecentRecordedPath;
    private bool _productShellInitialized;

    private void ProductShell_Loaded(object sender, RoutedEventArgs e)
    {
        if (_productShellInitialized) return;
        _productShellInitialized = true;

        _recentFilesView = new RecentFilesView();
        _recentFilesView.SetService(_recentDocuments);
        _recentFilesView.OpenRequested += OpenRecentFromLibraryAsync;
        _recentFilesView.ResumeRequested += ResumeWorkspaceSessionAsync;
        HomeRecentSection.Children.Clear();
        HomeRecentSection.Children.Add(_recentFilesView);

        PagesList.SelectionChanged += ProductShell_PagesSelectionChanged;
        PreviewImage.SizeChanged += ProductShell_PreviewSizeChanged;
        Closing += ProductShell_Closing;

        LoadHomeRecents();
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
        PersistWorkspacePosition();
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
        if (sender is not Button { Tag: string path }) return;
        if (!File.Exists(path))
        {
            MessageBox.Show(this, "This recent PDF has moved or is unavailable.",
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        await OpenRecentFromLibraryAsync(path);
    }

    private void LoadHomeRecents()
    {
        if (_recentFilesView is not null)
            _ = _recentFilesView.RefreshAsync();
    }

    private void HomeSearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _recentFilesView?.SetSearch(HomeSearchBox.Text);
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
        PersistWorkspacePosition();
    }

    private void ProductShell_PreviewSizeChanged(object sender, SizeChangedEventArgs e) => PersistWorkspacePosition();

    private void ProductShell_Closing(object? sender, CancelEventArgs e) => PersistWorkspacePosition();

    private void PersistWorkspacePosition()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var page = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;

        if (!string.Equals(_lastRecentRecordedPath, _currentPdf, StringComparison.OrdinalIgnoreCase))
        {
            _recentDocuments.RecordOpened(_currentPdf, page, _previewWidth);
            _lastRecentRecordedPath = _currentPdf;
            if (_recentFilesView is not null) _ = _recentFilesView.RefreshAsync();
        }
        else
        {
            _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        }

        _recentDocuments.SaveLastSession(_currentPdf, page, _previewWidth);
    }

    private async Task OpenRecentFromLibraryAsync(string path)
    {
        if (!File.Exists(path)) return;
        var resume = _recentDocuments.GetResumeState(path);
        if (resume is not null) _previewWidth = resume.RenderWidth;

        await OpenPdfAsync(path);
        if (_currentPdf is null || !string.Equals(Path.GetFullPath(path), _currentPdf, StringComparison.OrdinalIgnoreCase)) return;

        if (resume is not null && Pages.Count > 0)
        {
            var target = Math.Clamp(resume.PageNumber, 1, Pages.Count) - 1;
            PagesList.SelectedIndex = target;
            PagesList.ScrollIntoView(PagesList.SelectedItem);
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderPreviewAsync(page);
        }
    }

    private async Task ResumeWorkspaceSessionAsync(WorkspaceSessionState session)
    {
        if (session.Documents.Count == 0) return;
        var preferredIndex = Math.Clamp(session.ActiveDocumentIndex, 0, session.Documents.Count - 1);
        var candidates = session.Documents
            .Skip(preferredIndex)
            .Concat(session.Documents.Take(preferredIndex))
            .Where(document => File.Exists(document.Path))
            .ToArray();
        if (candidates.Length == 0)
        {
            MessageBox.Show(this, "The PDFs from the last session are no longer available at their saved locations.",
                "Resume Last Session", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var document = candidates[0];
        _previewWidth = document.RenderWidth;
        await OpenPdfAsync(document.Path);
        if (_currentPdf is null || Pages.Count == 0) return;

        var target = Math.Clamp(document.PageNumber, 1, Pages.Count) - 1;
        PagesList.SelectedIndex = target;
        PagesList.ScrollIntoView(PagesList.SelectedItem);
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);
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
        PersistWorkspacePosition();
        _ = RerenderSelectedPageAsync();
    }

    private void ActualSizeShell_Click(object sender, RoutedEventArgs e)
    {
        _previewWidth = 1100;
        PersistWorkspacePosition();
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
