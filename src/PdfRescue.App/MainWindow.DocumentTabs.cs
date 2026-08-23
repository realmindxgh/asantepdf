using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;

namespace PdfRescue.App;

public partial class MainWindow
{
    private const string DocumentTabDragFormat = "AsantePDF.DocumentTab";

    public ObservableCollection<DocumentTabSession> DocumentTabs { get; } = [];

    private readonly Stack<DocumentTabSession> _closedDocumentTabs = new();
    private DocumentTabSession? _activeDocumentTab;
    private DocumentTabSession? _tabActivationTarget;
    private bool _switchingDocumentTab;
    private bool _suppressDocumentTabSelection;
    private Point _documentTabDragStart;

    private void InitializeDocumentTabs()
    {
        DocumentTabsList.ItemsSource = DocumentTabs;
        PreviewScroll.ScrollChanged += (_, _) =>
        {
            if (_activeDocumentTab is null || _switchingDocumentTab) return;
            _activeDocumentTab.HorizontalOffset = PreviewScroll.HorizontalOffset;
            _activeDocumentTab.VerticalOffset = PreviewScroll.VerticalOffset;
            PersistWorkspacePosition();
        };
    }

    private async Task<bool> TryActivateExistingDocumentTabAsync(string fullPath)
    {
        if (!_productShellInitialized || _switchingDocumentTab) return false;

        var existing = DocumentTabs.FirstOrDefault(tab =>
            string.Equals(tab.Path, fullPath, StringComparison.OrdinalIgnoreCase));
        if (existing is not null)
        {
            await ActivateDocumentTabAsync(existing);
            return true;
        }

        CaptureActiveDocumentTabState();
        return false;
    }

    private async Task SynchronizeDocumentTabAfterOpenAsync(string fullPath)
    {
        if (!_productShellInitialized) return;

        if (_switchingDocumentTab && _tabActivationTarget is not null)
        {
            _activeDocumentTab = _tabActivationTarget;
            _activeDocumentTab.LastActivatedUtc = DateTimeOffset.UtcNow;
            await RestoreDocumentTabStateAsync(_activeDocumentTab);
            SelectDocumentTab(_activeDocumentTab);
            return;
        }

        var tab = DocumentTabs.FirstOrDefault(item =>
            string.Equals(item.Path, fullPath, StringComparison.OrdinalIgnoreCase));
        if (tab is null)
        {
            tab = new DocumentTabSession(fullPath);
            DocumentTabs.Add(tab);
        }

        _activeDocumentTab = tab;
        tab.LastActivatedUtc = DateTimeOffset.UtcNow;
        CaptureActiveDocumentTabState();
        SelectDocumentTab(tab);
    }

    private void CaptureActiveDocumentTabState()
    {
        var tab = _activeDocumentTab;
        if (tab is null || _currentPdf is null ||
            !string.Equals(tab.Path, _currentPdf, StringComparison.OrdinalIgnoreCase) || Pages.Count == 0)
            return;

        tab.WorkingLayout = Pages
            .Select(page => new DocumentTabPageState(page.SourcePageNumber, NormalizeRotation(page.Rotation)))
            .ToArray();
        tab.SavedLayout = _savedLayoutBaseline?.Pages
            .Select(page => new DocumentTabPageState(page.SourcePageNumber, NormalizeRotation(page.Rotation)))
            .ToArray() ?? [];
        tab.UndoHistory = _undo.Select(ToDocumentTabSnapshot).ToArray();
        tab.RedoHistory = _redo.Select(ToDocumentTabSnapshot).ToArray();
        tab.SelectedPage = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;
        tab.PreviewWidth = _previewWidth;
        tab.HorizontalOffset = PreviewScroll.HorizontalOffset;
        tab.VerticalOffset = PreviewScroll.VerticalOffset;
        tab.IsDirty = HasUnsavedLayoutChanges();
    }

    private async Task RestoreDocumentTabStateAsync(DocumentTabSession tab)
    {
        _previewWidth = tab.PreviewWidth;

        if (tab.WorkingLayout.Count > 0)
        {
            Pages.Clear();
            foreach (var state in tab.WorkingLayout)
            {
                Pages.Add(new PdfPageItem(state.SourcePageNumber, Pages.Count + 1)
                {
                    Rotation = state.Rotation,
                    Thumbnail = GetCachedThumbnail(state.SourcePageNumber)
                });
            }
        }

        _savedLayoutBaseline = tab.SavedLayout.Count > 0
            ? ToPageLayoutSnapshot(new DocumentTabLayoutSnapshot(tab.SavedLayout, []))
            : CaptureLayout();

        _undo.Clear();
        foreach (var snapshot in tab.UndoHistory.Reverse())
            _undo.Push(ToPageLayoutSnapshot(snapshot));

        _redo.Clear();
        foreach (var snapshot in tab.RedoHistory.Reverse())
            _redo.Push(ToPageLayoutSnapshot(snapshot));

        Renumber();
        if (Pages.Count > 0)
        {
            var index = Math.Clamp(tab.SelectedPage, 1, Pages.Count) - 1;
            PagesList.SelectedIndex = index;
            PagesList.ScrollIntoView(PagesList.SelectedItem);
            if (PagesList.SelectedItem is PdfPageItem page)
                await RenderPreviewAsync(page);
        }

        tab.IsDirty = HasUnsavedLayoutChanges();
        UpdateCommandStates();

        Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>
        {
            PreviewScroll.ScrollToHorizontalOffset(tab.HorizontalOffset);
            PreviewScroll.ScrollToVerticalOffset(tab.VerticalOffset);
        });
    }

    private async Task ActivateDocumentTabAsync(DocumentTabSession tab)
    {
        if (_busy || ReferenceEquals(tab, _activeDocumentTab))
        {
            if (ReferenceEquals(tab, _activeDocumentTab)) SelectDocumentTab(tab);
            return;
        }

        if (!File.Exists(tab.Path))
        {
            MessageBox.Show(this, "This PDF is no longer available at its saved location.",
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Information);
            SelectDocumentTab(_activeDocumentTab);
            return;
        }

        CaptureActiveDocumentTabState();
        _switchingDocumentTab = true;
        _tabActivationTarget = tab;
        _previewWidth = tab.PreviewWidth;
        try
        {
            await OpenPdfAsync(tab.Path);
        }
        finally
        {
            _tabActivationTarget = null;
            _switchingDocumentTab = false;
        }
    }

    private void SelectDocumentTab(DocumentTabSession? tab)
    {
        _suppressDocumentTabSelection = true;
        try
        {
            DocumentTabsList.SelectedItem = tab;
            if (tab is not null) DocumentTabsList.ScrollIntoView(tab);
        }
        finally
        {
            _suppressDocumentTabSelection = false;
        }
    }

    private async void DocumentTabsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressDocumentTabSelection) return;
        if (DocumentTabsList.SelectedItem is not DocumentTabSession tab) return;
        if (_busy)
        {
            SelectDocumentTab(_activeDocumentTab);
            return;
        }
        await ActivateDocumentTabAsync(tab);
    }

    private async void DocumentTabClose_Click(object sender, RoutedEventArgs e)
    {
        e.Handled = true;
        if (sender is FrameworkElement { DataContext: DocumentTabSession tab })
            await CloseDocumentTabAsync(tab);
    }

    private async Task<bool> CloseDocumentTabAsync(DocumentTabSession tab)
    {
        if (_busy || !DocumentTabs.Contains(tab)) return false;
        var active = ReferenceEquals(tab, _activeDocumentTab);

        if (tab.IsDirty)
        {
            if (active)
            {
                if (!await ConfirmDocumentReplacementAsync("closing this tab")) return false;
                if (HasUnsavedLayoutChanges() && _savedLayoutBaseline is not null)
                    RestoreLayout(_savedLayoutBaseline);
                CaptureActiveDocumentTabState();
            }
            else
            {
                var discard = MessageBox.Show(this,
                    $"{tab.Name} has unsaved page-layout changes. Close the tab and discard those changes?",
                    "Unsaved AsantePDF changes", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (discard != MessageBoxResult.Yes) return false;
                DiscardDocumentTabWorkingChanges(tab);
            }
        }
        else if (active)
        {
            CaptureActiveDocumentTabState();
        }

        var oldIndex = DocumentTabs.IndexOf(tab);
        RememberClosedDocumentTab(tab);
        DocumentTabs.Remove(tab);

        if (!active) return true;

        _activeDocumentTab = null;
        if (DocumentTabs.Count == 0)
        {
            ClearDocumentWorkspaceAfterLastTab();
            return true;
        }

        var nextIndex = Math.Clamp(oldIndex, 0, DocumentTabs.Count - 1);
        await ActivateDocumentTabAsync(DocumentTabs[nextIndex]);
        return true;
    }

    private void RememberClosedDocumentTab(DocumentTabSession tab)
    {
        _closedDocumentTabs.Push(tab.CloneForReopen());
        if (_closedDocumentTabs.Count <= 12) return;

        var keep = _closedDocumentTabs.Take(12).Reverse().ToArray();
        _closedDocumentTabs.Clear();
        foreach (var item in keep) _closedDocumentTabs.Push(item);
    }

    private async Task ReopenLastClosedDocumentTabAsync()
    {
        if (_busy) return;
        while (_closedDocumentTabs.Count > 0)
        {
            var tab = _closedDocumentTabs.Pop();
            if (!File.Exists(tab.Path)) continue;

            var existing = DocumentTabs.FirstOrDefault(item =>
                string.Equals(item.Path, tab.Path, StringComparison.OrdinalIgnoreCase));
            if (existing is not null)
            {
                await ActivateDocumentTabAsync(existing);
                return;
            }

            CaptureActiveDocumentTabState();
            DocumentTabs.Add(tab);
            _switchingDocumentTab = true;
            _tabActivationTarget = tab;
            _previewWidth = tab.PreviewWidth;
            try
            {
                await OpenPdfAsync(tab.Path);
                if (_currentPdf is null || !string.Equals(_currentPdf, tab.Path, StringComparison.OrdinalIgnoreCase))
                    DocumentTabs.Remove(tab);
            }
            finally
            {
                _tabActivationTarget = null;
                _switchingDocumentTab = false;
            }
            return;
        }
    }

    private async Task ActivateAdjacentDocumentTabAsync(bool backwards)
    {
        if (_busy || DocumentTabs.Count < 2) return;
        var currentIndex = _activeDocumentTab is null ? -1 : DocumentTabs.IndexOf(_activeDocumentTab);
        if (currentIndex < 0) currentIndex = 0;
        var next = backwards
            ? (currentIndex - 1 + DocumentTabs.Count) % DocumentTabs.Count
            : (currentIndex + 1) % DocumentTabs.Count;
        await ActivateDocumentTabAsync(DocumentTabs[next]);
    }

    private void ClearDocumentWorkspaceAfterLastTab()
    {
        _thumbnailCts?.Cancel();
        _previewCts?.Cancel();
        _currentPdf = null;
        _documentGeneration++;
        _undo.Clear();
        _redo.Clear();
        _thumbnailCache.Clear();
        Pages.Clear();
        _savedLayoutBaseline = null;
        PreviewImage.Source = null;
        ResetDocumentSearchForDocumentChange();
        DocumentTitle.Text = "No document open";
        DocumentMeta.Text = string.Empty;
        InspectorFile.Text = "—";
        InspectorPages.Text = "—";
        InspectorSize.Text = "—";
        InspectorVersion.Text = "Not checked";
        InspectorSecurity.Text = "Not checked";
        InspectorFeatures.Text = "Run PDF Doctor to inspect";
        HealthText.Text = "Not analysed yet";
        FindingsList.ItemsSource = null;
        PreviewScroll.Visibility = Visibility.Collapsed;
        ShowHomeContent();
        UpdateCommandStates();
    }

    private void UpdateActiveDocumentTabDirtyState()
    {
        if (_activeDocumentTab is null) return;
        _activeDocumentTab.IsDirty = HasUnsavedLayoutChanges();
    }

    private bool HasInactiveDirtyDocumentTabs() =>
        DocumentTabs.Any(tab => !ReferenceEquals(tab, _activeDocumentTab) && tab.IsDirty);

    private bool ConfirmDiscardInactiveDirtyTabsForExit()
    {
        var dirty = DocumentTabs.Where(tab => !ReferenceEquals(tab, _activeDocumentTab) && tab.IsDirty).ToArray();
        if (dirty.Length == 0) return true;

        var names = string.Join("\n", dirty.Take(5).Select(tab => "• " + tab.Name));
        if (dirty.Length > 5) names += $"\n• and {dirty.Length - 5:N0} more";
        var choice = MessageBox.Show(this,
            $"Other open tabs also contain unsaved page-layout changes:\n\n{names}\n\nClose AsantePDF and discard those unsaved tab changes?",
            "Unsaved AsantePDF tabs", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        return choice == MessageBoxResult.Yes;
    }

    private static DocumentTabLayoutSnapshot ToDocumentTabSnapshot(PageLayoutSnapshot snapshot) => new(
        snapshot.Pages.Select(page => new DocumentTabPageState(page.SourcePageNumber, NormalizeRotation(page.Rotation))).ToArray(),
        snapshot.SelectedPositions.ToArray());

    private static PageLayoutSnapshot ToPageLayoutSnapshot(DocumentTabLayoutSnapshot snapshot) => new(
        snapshot.Pages.Select(page => new PageState(page.SourcePageNumber, page.Rotation, null)).ToArray(),
        snapshot.SelectedPositions.ToArray());

    private void DocumentTabsList_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e) =>
        _documentTabDragStart = e.GetPosition(DocumentTabsList);

    private void DocumentTabsList_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _busy) return;
        var point = e.GetPosition(DocumentTabsList);
        if (Math.Abs(point.X - _documentTabDragStart.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(point.Y - _documentTabDragStart.Y) < SystemParameters.MinimumVerticalDragDistance)
            return;

        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (container?.DataContext is not DocumentTabSession tab) return;
        DragDrop.DoDragDrop(DocumentTabsList, new DataObject(DocumentTabDragFormat, tab), DragDropEffects.Move);
    }

    private void DocumentTabsList_DragOver(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DocumentTabDragFormat)) return;
        e.Effects = DragDropEffects.Move;
        e.Handled = true;
    }

    private void DocumentTabsList_Drop(object sender, DragEventArgs e)
    {
        if (_busy || e.Data.GetData(DocumentTabDragFormat) is not DocumentTabSession dragged) return;
        var targetContainer = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        var target = targetContainer?.DataContext as DocumentTabSession;
        if (target is null || ReferenceEquals(target, dragged)) return;

        var oldIndex = DocumentTabs.IndexOf(dragged);
        var newIndex = DocumentTabs.IndexOf(target);
        if (oldIndex < 0 || newIndex < 0) return;
        DocumentTabs.Move(oldIndex, newIndex);
        SelectDocumentTab(_activeDocumentTab);
        e.Handled = true;
    }

    private async void DocumentTabsList_PreviewMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Middle) return;
        var container = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (container?.DataContext is not DocumentTabSession tab) return;
        e.Handled = true;
        await CloseDocumentTabAsync(tab);
    }
}
