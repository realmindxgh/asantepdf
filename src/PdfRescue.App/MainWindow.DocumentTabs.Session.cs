using System.IO;
using System.Windows;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private IReadOnlyList<DocumentResumeState> BuildWorkspaceSessionDocuments() =>
        DocumentTabs
            .Where(tab => !string.IsNullOrWhiteSpace(tab.Path))
            .Select(tab => new DocumentResumeState(
                tab.Path,
                Math.Max(1, tab.SelectedPage),
                Math.Clamp(tab.PreviewWidth, 320u, 4000u),
                Math.Max(0, tab.HorizontalOffset),
                Math.Max(0, tab.VerticalOffset)))
            .ToArray();

    private int GetActiveDocumentTabIndex()
    {
        if (_activeDocumentTab is null) return 0;
        var index = DocumentTabs.IndexOf(_activeDocumentTab);
        return index < 0 ? 0 : index;
    }

    private DocumentTabSession? FindOpenDocumentTab(string path)
    {
        string fullPath;
        try { fullPath = Path.GetFullPath(path); }
        catch { fullPath = path; }
        return DocumentTabs.FirstOrDefault(tab =>
            string.Equals(tab.Path, fullPath, StringComparison.OrdinalIgnoreCase));
    }

    private async Task RestoreWorkspaceTabsFromSessionAsync(WorkspaceSessionState session)
    {
        if (_busy || session.Documents.Count == 0) return;

        var available = session.Documents.Where(document => File.Exists(document.Path)).ToArray();
        if (available.Length == 0)
        {
            MessageBox.Show(this, "The PDFs from the last session are no longer available at their saved locations.",
                "Resume Last Session", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        foreach (var document in available)
        {
            var tab = FindOpenDocumentTab(document.Path);
            if (tab is null)
            {
                _previewWidth = document.RenderWidth;
                await OpenPdfAsync(document.Path);
                tab = FindOpenDocumentTab(document.Path);
            }

            if (tab is null) continue;
            await ApplyResumeStateToTabAsync(tab, document);
        }

        var requestedActiveIndex = Math.Clamp(session.ActiveDocumentIndex, 0, session.Documents.Count - 1);
        var requestedActive = session.Documents[requestedActiveIndex];
        var target = FindOpenDocumentTab(requestedActive.Path) ?? FindOpenDocumentTab(available[0].Path);
        if (target is not null)
            await ActivateDocumentTabAsync(target);

        CaptureActiveDocumentTabState();
        PersistWorkspacePosition(immediate: true);
    }

    private async Task ApplyResumeStateToTabAsync(DocumentTabSession tab, DocumentResumeState state)
    {
        tab.SelectedPage = Math.Max(1, state.PageNumber);
        tab.PreviewWidth = Math.Clamp(state.RenderWidth, 320u, 4000u);
        tab.HorizontalOffset = Math.Max(0, state.HorizontalOffset);
        tab.VerticalOffset = Math.Max(0, state.VerticalOffset);

        if (!ReferenceEquals(tab, _activeDocumentTab) || _currentPdf is null ||
            !string.Equals(tab.Path, _currentPdf, StringComparison.OrdinalIgnoreCase) || Pages.Count == 0)
            return;

        _previewWidth = tab.PreviewWidth;
        var target = Math.Clamp(tab.SelectedPage, 1, Pages.Count) - 1;
        PagesList.SelectedIndex = target;
        PagesList.ScrollIntoView(PagesList.SelectedItem);
        if (PagesList.SelectedItem is PdfPageItem page)
            await RenderPreviewAsync(page);

        _ = Dispatcher.BeginInvoke(() =>
        {
            PreviewScroll.ScrollToHorizontalOffset(tab.HorizontalOffset);
            PreviewScroll.ScrollToVerticalOffset(tab.VerticalOffset);
        });
        CaptureActiveDocumentTabState();
    }

    private static void DiscardDocumentTabWorkingChanges(DocumentTabSession tab)
    {
        tab.WorkingLayout = tab.SavedLayout.ToArray();
        tab.UndoHistory = [];
        tab.RedoHistory = [];
        tab.IsDirty = false;
    }
}