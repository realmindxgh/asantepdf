using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace PdfRescue.App;

public partial class MainWindow
{
    private IPdfRenderer? _splitLeftRenderer;
    private IPdfRenderer? _splitRightRenderer;
    private CancellationTokenSource? _splitLeftCts;
    private CancellationTokenSource? _splitRightCts;
    private DocumentTabSession? _splitLeftTab;
    private DocumentTabSession? _splitRightTab;
    private int _splitLeftPage = 1;
    private int _splitRightPage = 1;
    private uint _splitLeftRenderWidth = 900;
    private uint _splitRightRenderWidth = 900;
    private bool _splitUpdatingSelection;
    private bool _splitSyncingScroll;
    private bool _splitLifecycleHooked;

    private bool SplitLinkedScroll => SplitLinkedScrollCheck?.IsChecked == true;
    private bool SplitLinkedZoom => SplitLinkedZoomCheck?.IsChecked == true;

    private async void OpenSplitView_Click(object sender, RoutedEventArgs e) => await OpenSplitViewAsync();

    private async Task OpenSplitViewAsync(DocumentTabSession? preferredLeft = null, DocumentTabSession? preferredRight = null)
    {
        if (DocumentTabs.Count < 2)
        {
            MessageBox.Show(this, "Open at least two PDFs before starting comparison.", "Compare PDFs", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        EnsureSplitLifecycle();
        CaptureActiveDocumentTabState();
        var left = preferredLeft ?? _activeDocumentTab ?? DocumentTabs[0];
        var right = preferredRight ?? DocumentTabs.First(tab => !ReferenceEquals(tab, left));
        if (ReferenceEquals(left, right)) right = DocumentTabs.First(tab => !ReferenceEquals(tab, left));

        _splitUpdatingSelection = true;
        try
        {
            SplitLeftDocumentCombo.ItemsSource = DocumentTabs;
            SplitRightDocumentCombo.ItemsSource = DocumentTabs;
            SplitLeftDocumentCombo.SelectedItem = left;
            SplitRightDocumentCombo.SelectedItem = right;
        }
        finally { _splitUpdatingSelection = false; }

        SplitComparisonPanel.Visibility = Visibility.Visible;
        PreviewScroll.Visibility = Visibility.Collapsed;
        EmptyPanel.Visibility = Visibility.Collapsed;
        await LoadSplitPaneAsync(true, left);
        await LoadSplitPaneAsync(false, right);
        StatusText.Text = $"Comparing {left.Name} with {right.Name}.";
    }

    internal async Task OpenResultComparisonAsync(string originalPath, string resultPath)
    {
        if (!File.Exists(originalPath) || !File.Exists(resultPath)) return;
        await OpenPdfAsync(originalPath);
        var original = FindOpenDocumentTab(originalPath);
        await OpenPdfAsync(resultPath);
        var result = FindOpenDocumentTab(resultPath);
        if (original is not null && result is not null && !ReferenceEquals(original, result))
            await OpenSplitViewAsync(original, result);
    }

    private void EnsureSplitLifecycle()
    {
        if (_splitLifecycleHooked) return;
        _splitLifecycleHooked = true;
        Closed += (_, _) =>
        {
            _splitLeftCts?.Cancel(); _splitRightCts?.Cancel();
            _splitLeftCts?.Dispose(); _splitRightCts?.Dispose();
            _splitLeftRenderer?.Dispose(); _splitRightRenderer?.Dispose();
        };
    }

    private async Task LoadSplitPaneAsync(bool left, DocumentTabSession tab)
    {
        if (!File.Exists(tab.Path)) return;
        var cts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        if (left)
        {
            _splitLeftCts?.Cancel(); _splitLeftCts?.Dispose(); _splitLeftCts = cts;
            _splitLeftRenderer ??= PdfRendererFactory.CreateProduction();
            _splitLeftTab = tab;
            await _splitLeftRenderer.OpenAsync(tab.Path, cts.Token);
            _splitLeftPage = Math.Clamp(tab.SelectedPage, 1, checked((int)_splitLeftRenderer.PageCount));
            await RenderSplitPaneAsync(true, cts.Token);
        }
        else
        {
            _splitRightCts?.Cancel(); _splitRightCts?.Dispose(); _splitRightCts = cts;
            _splitRightRenderer ??= PdfRendererFactory.CreateProduction();
            _splitRightTab = tab;
            await _splitRightRenderer.OpenAsync(tab.Path, cts.Token);
            _splitRightPage = Math.Clamp(tab.SelectedPage, 1, checked((int)_splitRightRenderer.PageCount));
            await RenderSplitPaneAsync(false, cts.Token);
        }
    }

    private async Task RenderSplitPaneAsync(bool left, CancellationToken token)
    {
        try
        {
            if (left)
            {
                if (_splitLeftRenderer is null || _splitLeftRenderer.PageCount == 0) return;
                _splitLeftPage = Math.Clamp(_splitLeftPage, 1, checked((int)_splitLeftRenderer.PageCount));
                SplitLeftImage.Source = await _splitLeftRenderer.RenderAsync(_splitLeftPage, _splitLeftRenderWidth, token);
                token.ThrowIfCancellationRequested();
                SplitLeftPageBox.Text = _splitLeftPage.ToString();
                SplitLeftPageCountText.Text = $"/ {_splitLeftRenderer.PageCount:N0}";
                SplitLeftZoomText.Text = FormatSplitZoom(_splitLeftRenderWidth);
            }
            else
            {
                if (_splitRightRenderer is null || _splitRightRenderer.PageCount == 0) return;
                _splitRightPage = Math.Clamp(_splitRightPage, 1, checked((int)_splitRightRenderer.PageCount));
                SplitRightImage.Source = await _splitRightRenderer.RenderAsync(_splitRightPage, _splitRightRenderWidth, token);
                token.ThrowIfCancellationRequested();
                SplitRightPageBox.Text = _splitRightPage.ToString();
                SplitRightPageCountText.Text = $"/ {_splitRightRenderer.PageCount:N0}";
                SplitRightZoomText.Text = FormatSplitZoom(_splitRightRenderWidth);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { App.Log("Split-view render failed: " + ex); StatusText.Text = "One comparison pane could not be rendered."; }
    }

    private static string FormatSplitZoom(uint width) => $"{Math.Clamp((int)Math.Round(width / 9d), 40, 260)}%";

    private async void SplitLeftDocumentCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_splitUpdatingSelection || SplitLeftDocumentCombo.SelectedItem is not DocumentTabSession tab) return;
        if (ReferenceEquals(tab, _splitRightTab)) return;
        await LoadSplitPaneAsync(true, tab);
    }

    private async void SplitRightDocumentCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_splitUpdatingSelection || SplitRightDocumentCombo.SelectedItem is not DocumentTabSession tab) return;
        if (ReferenceEquals(tab, _splitLeftTab)) return;
        await LoadSplitPaneAsync(false, tab);
    }

    private async void SplitLeftPrevious_Click(object sender, RoutedEventArgs e) { if (_splitLeftRenderer is null) return; _splitLeftPage = Math.Max(1, _splitLeftPage - 1); await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token); }
    private async void SplitLeftNext_Click(object sender, RoutedEventArgs e) { if (_splitLeftRenderer is null) return; _splitLeftPage = Math.Min(checked((int)_splitLeftRenderer.PageCount), _splitLeftPage + 1); await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token); }
    private async void SplitRightPrevious_Click(object sender, RoutedEventArgs e) { if (_splitRightRenderer is null) return; _splitRightPage = Math.Max(1, _splitRightPage - 1); await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token); }
    private async void SplitRightNext_Click(object sender, RoutedEventArgs e) { if (_splitRightRenderer is null) return; _splitRightPage = Math.Min(checked((int)_splitRightRenderer.PageCount), _splitRightPage + 1); await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token); }

    private async void SplitLeftPageBox_KeyDown(object sender, KeyEventArgs e) { if (e.Key != Key.Enter || _splitLeftRenderer is null) return; if (int.TryParse(SplitLeftPageBox.Text, out var page)) { _splitLeftPage = Math.Clamp(page, 1, checked((int)_splitLeftRenderer.PageCount)); await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token); } e.Handled = true; }
    private async void SplitRightPageBox_KeyDown(object sender, KeyEventArgs e) { if (e.Key != Key.Enter || _splitRightRenderer is null) return; if (int.TryParse(SplitRightPageBox.Text, out var page)) { _splitRightPage = Math.Clamp(page, 1, checked((int)_splitRightRenderer.PageCount)); await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token); } e.Handled = true; }

    private async void SplitLeftZoomOut_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(true, -120);
    private async void SplitLeftZoomIn_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(true, 120);
    private async void SplitRightZoomOut_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(false, -120);
    private async void SplitRightZoomIn_Click(object sender, RoutedEventArgs e) => await ChangeSplitZoomAsync(false, 120);

    private async Task ChangeSplitZoomAsync(bool left, int delta)
    {
        if (left)
        {
            _splitLeftRenderWidth = (uint)Math.Clamp((long)_splitLeftRenderWidth + delta, 360, 2400);
            if (SplitLinkedZoom) _splitRightRenderWidth = _splitLeftRenderWidth;
            await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
            if (SplitLinkedZoom) await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
        }
        else
        {
            _splitRightRenderWidth = (uint)Math.Clamp((long)_splitRightRenderWidth + delta, 360, 2400);
            if (SplitLinkedZoom) _splitLeftRenderWidth = _splitRightRenderWidth;
            await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
            if (SplitLinkedZoom) await RenderSplitPaneAsync(true, _splitLeftCts?.Token ?? _lifetime.Token);
        }
    }

    private async void SplitLinkedZoomCheck_Changed(object sender, RoutedEventArgs e)
    {
        if (!SplitLinkedZoom || SplitComparisonPanel.Visibility != Visibility.Visible) return;
        _splitRightRenderWidth = _splitLeftRenderWidth;
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private void SplitLeftScroll_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (!SplitLinkedScroll || _splitSyncingScroll || e.VerticalChange == 0 && e.HorizontalChange == 0) return;
        SyncSplitScroll(SplitLeftScroll, SplitRightScroll);
    }

    private void SplitRightScroll_ScrollChanged(object sender, ScrollChangedEventArgs e)
    {
        if (!SplitLinkedScroll || _splitSyncingScroll || e.VerticalChange == 0 && e.HorizontalChange == 0) return;
        SyncSplitScroll(SplitRightScroll, SplitLeftScroll);
    }

    private void SyncSplitScroll(ScrollViewer source, ScrollViewer target)
    {
        _splitSyncingScroll = true;
        try
        {
            var v = source.ScrollableHeight <= 0 ? 0 : source.VerticalOffset / source.ScrollableHeight;
            var h = source.ScrollableWidth <= 0 ? 0 : source.HorizontalOffset / source.ScrollableWidth;
            target.ScrollToVerticalOffset(v * target.ScrollableHeight);
            target.ScrollToHorizontalOffset(h * target.ScrollableWidth);
        }
        finally { _splitSyncingScroll = false; }
    }

    private async void SplitAlignPages_Click(object sender, RoutedEventArgs e)
    {
        if (_splitRightRenderer is null) return;
        _splitRightPage = Math.Clamp(_splitLeftPage, 1, checked((int)_splitRightRenderer.PageCount));
        await RenderSplitPaneAsync(false, _splitRightCts?.Token ?? _lifetime.Token);
    }

    private async void SplitSwap_Click(object sender, RoutedEventArgs e)
    {
        if (_splitLeftTab is null || _splitRightTab is null) return;
        var left = _splitLeftTab; var right = _splitRightTab;
        _splitUpdatingSelection = true;
        SplitLeftDocumentCombo.SelectedItem = right; SplitRightDocumentCombo.SelectedItem = left;
        _splitUpdatingSelection = false;
        await LoadSplitPaneAsync(true, right); await LoadSplitPaneAsync(false, left);
    }

    private void SplitExit_Click(object sender, RoutedEventArgs e) => ExitSplitViewCore();

    private void ExitSplitViewCore()
    {
        if (SplitComparisonPanel is null) return;
        SplitComparisonPanel.Visibility = Visibility.Collapsed;
        if (_currentPdf is not null) PreviewScroll.Visibility = Visibility.Visible;
        StatusText.Text = "Ready.";
    }
}