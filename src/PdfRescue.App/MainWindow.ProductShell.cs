using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly RecentDocumentService _recentDocuments = new();
    private readonly TaskCenterService _taskCenterService = new();
    private BackgroundTaskQueueService? _backgroundTasks;
    private RecentFilesView? _recentFilesView;
    private TaskCenterView? _taskCenterView;
    private UIElement? _homeContent;
    private TaskCenterItem? _activeTaskCenterItem;
    private DispatcherTimer? _sessionPersistTimer;
    private string? _lastRecentRecordedPath;
    private bool _productShellInitialized;

    private void ProductShell_Loaded(object sender, RoutedEventArgs e)
    {
        if (_productShellInitialized) return;
        _productShellInitialized = true;
        InitializeAppearanceAndSettings();

        _homeContent = EmptyPanel.Child;
        _backgroundTasks = new BackgroundTaskQueueService(_taskCenterService);
        _taskCenterView = new TaskCenterView(_taskCenterService);
        _taskCenterView.ResultOptionsRequested += ShowTaskResultWorkflowAsync;
        _taskCenterService.Changed += (_, _) => RefreshTaskCenterIndicator();
        RefreshTaskCenterIndicator();
        InitializeDocumentTabs();
        InitializeDocumentOutline();
        InitializeDocumentTextSelection();
        InitializeDocumentNavigationMetadata();
        InitializePageViewModes();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();

        _recentFilesView = new RecentFilesView();
        _recentFilesView.SetService(_recentDocuments);
        _recentFilesView.OpenRequested += OpenRecentFromLibraryAsync;
        _recentFilesView.ResumeRequested += ResumeWorkspaceSessionAsync;
        HomeRecentSection.Children.Clear();
        HomeRecentSection.Children.Add(_recentFilesView);

        _sessionPersistTimer = new DispatcherTimer(DispatcherPriority.Background, Dispatcher)
        {
            Interval = TimeSpan.FromMilliseconds(450)
        };
        _sessionPersistTimer.Tick += (_, _) =>
        {
            _sessionPersistTimer.Stop();
            WriteWorkspacePosition();
        };

        PagesList.SelectionChanged += ProductShell_PagesSelectionChanged;
        PreviewImage.SizeChanged += ProductShell_PreviewSizeChanged;
        Closing += ProductShell_Closing;
        Closed += async (_, _) =>
        {
            RecoverySnapshotService.Current.MarkCleanShutdown();
            if (_backgroundTasks is not null)
                await _backgroundTasks.DisposeAsync();
        };

        LoadHomeRecents();
        RefreshResumeCommandState();
        RefreshProductShellMode();
        _ = Dispatcher.BeginInvoke(DispatcherPriority.ApplicationIdle, new Action(async () =>
            await OfferStartupRecoveryAndOnboardingAsync()));
    }

    private void RefreshProductShellMode()
    {
        if (_currentPdf is null)
        {
            ShowHomeContent();
            PreviewScroll.Visibility = Visibility.Collapsed;
        }
    }

    private void ShowHomeContent()
    {
        if (_homeContent is not null && !ReferenceEquals(EmptyPanel.Child, _homeContent))
            EmptyPanel.Child = _homeContent;
        EmptyPanel.Visibility = Visibility.Visible;
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
        PersistWorkspacePosition(immediate: true);
        ShowHomeContent();
        _recentFilesView?.SetPinnedOnly(false);
        LoadHomeRecents();
    }

    private void HomeRecentNav_Click(object sender, RoutedEventArgs e)
    {
        ShowHomeContent();
        _recentFilesView?.SetPinnedOnly(false);
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
    }

    private void HomeStarredNav_Click(object sender, RoutedEventArgs e)
    {
        ShowHomeContent();
        _recentFilesView?.SetPinnedOnly(true);
        LoadHomeRecents();
        HomeRecentSection.BringIntoView();
    }

    private void RefreshTaskCenterIndicator()
    {
        if (TaskCenterActiveBadge is null || TaskCenterActiveCountText is null || TaskCenterNavButton is null) return;
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(RefreshTaskCenterIndicator);
            return;
        }

        var counts = _taskCenterService.GetCounts();
        var active = counts.Running + counts.Queued;
        TaskCenterActiveCountText.Text = active > 99 ? "99+" : active.ToString("N0");
        TaskCenterActiveBadge.Visibility = active > 0 ? Visibility.Visible : Visibility.Collapsed;
        TaskCenterNavButton.ToolTip = active > 0
            ? $"Task Center · {counts.Running:N0} running, {counts.Queued:N0} queued"
            : counts.Failed > 0
                ? $"Task Center · {counts.Failed:N0} failed task(s) need attention"
                : "View running and completed PDF tasks";
    }

    private void TaskCenterNav_Click(object sender, RoutedEventArgs e)
    {
        PersistWorkspacePosition(immediate: true);
        if (_taskCenterView is null) return;
        EmptyPanel.Child = _taskCenterView;
        EmptyPanel.Visibility = Visibility.Visible;
    }

    private async void ResumeLastSession_Click(object sender, RoutedEventArgs e)
    {
        var session = _recentDocuments.GetLastSession();
        if (session is not null) await ResumeWorkspaceSessionAsync(session);
    }

    private void DocumentNav_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null) return;
        EmptyPanel.Visibility = Visibility.Collapsed;
        ApplyPageViewVisibility();
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

        var selectedPath = Path.GetFullPath(dialog.FileName);
        await OpenPdfAsync(selectedPath);
        return _currentPdf is not null &&
               string.Equals(Path.GetFullPath(_currentPdf), selectedPath, StringComparison.OrdinalIgnoreCase)
            ? _currentPdf
            : null;
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

    private async void HomeRepair_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to repair") is not null)
            Repair_Click(sender, e);
    }

    private async void HomeOptimize_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to optimize for web viewing") is not null)
            Linearize_Click(sender, e);
    }

    private async void HomeProtect_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to protect with a password") is not null)
            Protect_Click(sender, e);
    }

    private void HomeUnlock_Click(object sender, RoutedEventArgs e) => Unlock_Click(sender, e);

    private async void HomeToExcel_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to Excel") is not null)
            PdfToExcel_Click(sender, e);
    }

    private async void HomeToPowerPoint_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to convert to PowerPoint") is not null)
            PdfToPowerPoint_Click(sender, e);
    }

    private void HomeOfficeToPdf_Click(object sender, RoutedEventArgs e) => OfficeToPdf_Click(sender, e);

    private async void HomeExportImages_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose pages you want to export as images") is not null)
            ExportPagesAsImages_Click(sender, e);
    }

    private async void HomeOcrText_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose text you want to extract with OCR") is not null)
            ExtractOcrText_Click(sender, e);
    }

    private async void HomeWatermark_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to watermark") is not null)
            Watermark_Click(sender, e);
    }

    private async void HomePageNumbers_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to add page numbers to") is not null)
            PageNumbers_Click(sender, e);
    }

    private async void HomeHeaderFooter_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF for header/footer editing") is not null)
            HeaderFooter_Click(sender, e);
    }

    private async void HomeMetadata_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF whose metadata you want to edit") is not null)
            Metadata_Click(sender, e);
    }

    private async void HomeStampImage_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF to stamp with an image") is not null)
            StampImage_Click(sender, e);
    }

    private async void HomeFillForm_Click(object sender, RoutedEventArgs e)
    {
        if (await SelectPdfForStandaloneToolAsync("Choose a PDF form to fill") is not null)
            FillForm_Click(sender, e);
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
        RefreshResumeCommandState();
    }

    private void HomeSearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        _recentFilesView?.SetSearch(HomeSearchBox.Text);
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

    private void ProductShell_Closing(object? sender, CancelEventArgs e)
    {
        _sessionPersistTimer?.Stop();
        PersistWorkspacePosition(immediate: true);
    }

    private void PersistWorkspacePosition(bool immediate = false)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var page = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;

        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.TrackRecentFiles && !string.Equals(_lastRecentRecordedPath, _currentPdf, StringComparison.OrdinalIgnoreCase))
        {
            _recentDocuments.RecordOpened(_currentPdf, page, _previewWidth);
            _lastRecentRecordedPath = _currentPdf;
            if (_recentFilesView is not null) _ = _recentFilesView.RefreshAsync();
            RefreshResumeCommandState();
        }

        if (immediate || _sessionPersistTimer is null)
        {
            WriteWorkspacePosition();
            return;
        }

        _sessionPersistTimer.Stop();
        _sessionPersistTimer.Start();
    }

    private void WriteWorkspacePosition()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var page = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;
        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.TrackRecentFiles)
            _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        CaptureActiveDocumentTabState();
        if (preferences.ReopenLastSession)
            _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        else
            _recentDocuments.ClearLastSession();
        SaveRecoverySnapshot();
        RefreshResumeCommandState();
    }

    private void RefreshResumeCommandState()
    {
        if (ResumeSessionButton is null) return;
        var preferences = AppSettingsService.Current.Preferences;
        var session = preferences.ReopenLastSession ? _recentDocuments.GetLastSession() : null;
        var available = session?.Documents.Where(document => File.Exists(document.Path)).ToArray() ?? [];
        var hasSession = available.Length > 0;
        ResumeSessionButton.IsEnabled = hasSession;
        ResumeSessionButton.Visibility = hasSession ? Visibility.Visible : Visibility.Collapsed;
        ResumeSessionButton.ToolTip = hasSession
            ? available.Length == 1
                ? $"Restore {Path.GetFileName(available[0].Path)} at page {available[0].PageNumber:N0}"
                : $"Restore {available.Length:N0} PDFs from the previous session"
            : null;
    }

    private async Task OpenRecentFromLibraryAsync(string path)
    {
        if (!File.Exists(path)) return;
        var openTab = FindOpenDocumentTab(path);
        if (openTab is not null)
        {
            await ActivateDocumentTabAsync(openTab);
            return;
        }

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
                await RenderSelectedPageForActiveViewAsync(page);
        }
        PersistWorkspacePosition(immediate: true);
    }

    private async Task ResumeWorkspaceSessionAsync(WorkspaceSessionState session)
    {
        await RestoreWorkspaceTabsFromSessionAsync(session);
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
        if (!IsSinglePageViewActive)
        {
            _previewWidth = CalculateFitWidthRenderWidth();
            PersistWorkspacePosition();
            _ = RerenderSelectedPageAsync();
            return;
        }
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
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
    }
}
