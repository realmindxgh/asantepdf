param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Description) {
    $text = (Get-Content $Path -Raw).Replace("`r`n", "`n")
    $oldNormalized = $Old.Replace("`r`n", "`n")
    $newNormalized = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldNormalized)) {
        throw "Could not apply $Description. Expected source text was not found in $Path."
    }
    $updated = $text.Replace($oldNormalized, $newNormalized)
    Set-Content -Path $Path -Value $updated -Encoding UTF8 -NoNewline
    Write-Host "Applied: $Description" -ForegroundColor Green
}

$recentPath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\RecentDocumentService.cs'
Replace-Exact $recentPath `
    'public sealed record DocumentResumeState(string Path, int PageNumber, uint RenderWidth);' `
    'public sealed record DocumentResumeState(string Path, int PageNumber, uint RenderWidth, double HorizontalOffset = 0, double VerticalOffset = 0);' `
    'session resume scroll state'

$oldResumeMap = @'
                    .Select(document => new DocumentResumeState(
                        document.Path,
                        Math.Max(1, document.PageNumber),
                        Math.Clamp(document.RenderWidth, 320u, 4000u)))
'@
$newResumeMap = @'
                    .Select(document => new DocumentResumeState(
                        document.Path,
                        Math.Max(1, document.PageNumber),
                        Math.Clamp(document.RenderWidth, 320u, 4000u),
                        Math.Max(0, document.HorizontalOffset),
                        Math.Max(0, document.VerticalOffset)))
'@
Replace-Exact $recentPath $oldResumeMap $newResumeMap 'session scroll-state loading'

$oldTogglePin = @'
    public void TogglePin(string path)
'@
$newTogglePin = @'
    public void SaveLastSession(IReadOnlyList<DocumentResumeState> documents, int activeDocumentIndex)
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            var normalized = documents
                .Where(document => !string.IsNullOrWhiteSpace(document.Path))
                .Select(document => new PersistedSessionDocument
                {
                    Path = NormalizePath(document.Path),
                    PageNumber = Math.Max(1, document.PageNumber),
                    RenderWidth = Math.Clamp(document.RenderWidth, 320u, 4000u),
                    HorizontalOffset = Math.Max(0, document.HorizontalOffset),
                    VerticalOffset = Math.Max(0, document.VerticalOffset)
                })
                .ToList();

            if (normalized.Count == 0)
            {
                state.LastSession = null;
                SaveStateCore(state);
                return;
            }

            state.LastSession = new PersistedWorkspaceSession
            {
                SavedUtc = DateTimeOffset.UtcNow,
                ActiveDocumentIndex = Math.Clamp(activeDocumentIndex, 0, normalized.Count - 1),
                Documents = normalized
            };
            SaveStateCore(state);
        }
    }

    public void TogglePin(string path)
'@
Replace-Exact $recentPath $oldTogglePin $newTogglePin 'multi-document session save overload'

$oldPersistedSessionDocument = @'
    private sealed class PersistedSessionDocument
    {
        public string Path { get; set; } = string.Empty;
        public int PageNumber { get; set; } = 1;
        public uint RenderWidth { get; set; } = 1100;
    }
'@
$newPersistedSessionDocument = @'
    private sealed class PersistedSessionDocument
    {
        public string Path { get; set; } = string.Empty;
        public int PageNumber { get; set; } = 1;
        public uint RenderWidth { get; set; } = 1100;
        public double HorizontalOffset { get; set; }
        public double VerticalOffset { get; set; }
    }
'@
Replace-Exact $recentPath $oldPersistedSessionDocument $newPersistedSessionDocument 'persisted session scroll offsets'

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
$oldWritePosition = @'
    private void WriteWorkspacePosition()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var page = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;
        _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        _recentDocuments.SaveLastSession(_currentPdf, page, _previewWidth);
        RefreshResumeCommandState();
    }
'@
$newWritePosition = @'
    private void WriteWorkspacePosition()
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        var page = PagesList.SelectedIndex >= 0 ? PagesList.SelectedIndex + 1 : 1;
        _recentDocuments.UpdatePosition(_currentPdf, page, _previewWidth);
        CaptureActiveDocumentTabState();
        _recentDocuments.SaveLastSession(BuildWorkspaceSessionDocuments(), GetActiveDocumentTabIndex());
        RefreshResumeCommandState();
    }
'@
Replace-Exact $productShellPath $oldWritePosition $newWritePosition 'multi-tab workspace session persistence'

$oldRecentOpen = @'
    private async Task OpenRecentFromLibraryAsync(string path)
    {
        if (!File.Exists(path)) return;
        var resume = _recentDocuments.GetResumeState(path);
'@
$newRecentOpen = @'
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
'@
Replace-Exact $productShellPath $oldRecentOpen $newRecentOpen 'avoid stale Recent state for already-open tabs'

$oldResumeSession = @'
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
        PersistWorkspacePosition(immediate: true);
    }
'@
$newResumeSession = @'
    private async Task ResumeWorkspaceSessionAsync(WorkspaceSessionState session)
    {
        await RestoreWorkspaceTabsFromSessionAsync(session);
    }
'@
Replace-Exact $productShellPath $oldResumeSession $newResumeSession 'restore all saved workspace tabs'

$tabsPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
$oldScroll = @'
            _activeDocumentTab.HorizontalOffset = PreviewScroll.HorizontalOffset;
            _activeDocumentTab.VerticalOffset = PreviewScroll.VerticalOffset;
'@
$newScroll = @'
            _activeDocumentTab.HorizontalOffset = PreviewScroll.HorizontalOffset;
            _activeDocumentTab.VerticalOffset = PreviewScroll.VerticalOffset;
            PersistWorkspacePosition();
'@
Replace-Exact $tabsPath $oldScroll $newScroll 'debounced scroll-position persistence'

$oldClose = @'
        if (tab.IsDirty)
        {
            if (active)
            {
                if (!await ConfirmDocumentReplacementAsync("closing this tab")) return false;
                CaptureActiveDocumentTabState();
            }
            else
            {
                var discard = MessageBox.Show(this,
                    $"{tab.Name} has unsaved page-layout changes. Close the tab and discard those changes?",
                    "Unsaved AsantePDF changes", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (discard != MessageBoxResult.Yes) return false;
            }
        }

        var oldIndex = DocumentTabs.IndexOf(tab);
'@
$newClose = @'
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
'@
Replace-Exact $tabsPath $oldClose $newClose 'discard-safe close and reopen state'
