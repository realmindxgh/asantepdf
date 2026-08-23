using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly DocumentTextSelectionService _documentTextSelection = new();
    private CancellationTokenSource? _textSelectionLoadCts;
    private PdfSelectableTextPage? _selectableTextPage;
    private string? _selectableTextPath;
    private int _selectableTextSourcePage;
    private int _selectableTextPagePosition;
    private int _textSelectionAnchor = -1;
    private int _textSelectionFocus = -1;
    private bool _textSelectionDragging;

    private bool HasDocumentTextSelection =>
        _selectableTextPage is not null && _textSelectionAnchor >= 0 && _textSelectionFocus >= 0;

    private void InitializeDocumentTextSelection()
    {
        Closed += (_, _) =>
        {
            _textSelectionLoadCts?.Cancel();
            _textSelectionLoadCts?.Dispose();
            _textSelectionLoadCts = null;
        };
    }

    private void PrepareDocumentTextSelectionForPage(PdfPageItem page, BitmapSource bitmap, int renderGeneration)
    {
        TextSelectionCanvas.Width = bitmap.PixelWidth;
        TextSelectionCanvas.Height = bitmap.PixelHeight;
        TextSelectionCanvas.LayoutTransform = new RotateTransform(page.Rotation);
        TextSelectionCanvas.Visibility = Visibility.Visible;

        var samePage = _selectableTextPage is not null &&
            _currentPdf is not null &&
            string.Equals(_selectableTextPath, _currentPdf, StringComparison.OrdinalIgnoreCase) &&
            _selectableTextSourcePage == page.SourcePageNumber &&
            _selectableTextPagePosition == page.Position;

        if (samePage)
        {
            RefreshDocumentTextSelectionHighlights();
            UpdateDocumentTextSelectionInteractionState();
            return;
        }

        _textSelectionLoadCts?.Cancel();
        _textSelectionLoadCts?.Dispose();
        _textSelectionLoadCts = null;
        _selectableTextPage = null;
        _selectableTextPath = _currentPdf;
        _selectableTextSourcePage = page.SourcePageNumber;
        _selectableTextPagePosition = page.Position;
        ClearDocumentTextSelectionRange();
        UpdateDocumentTextSelectionInteractionState();

        if (_currentPdf is null) return;
        var path = _currentPdf;
        var generation = _documentGeneration;
        _textSelectionLoadCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _textSelectionLoadCts.Token;
        _ = LoadSelectableTextPageAsync(path, page.SourcePageNumber, page.Position, generation, renderGeneration, token);
    }

    private async Task LoadSelectableTextPageAsync(
        string path,
        int sourcePageNumber,
        int pagePosition,
        int documentGeneration,
        int renderGeneration,
        CancellationToken token)
    {
        try
        {
            var layout = await _documentTextSelection.GetPageAsync(path, sourcePageNumber, token);
            if (token.IsCancellationRequested || documentGeneration != _documentGeneration || renderGeneration != _previewGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase) ||
                PagesList.SelectedItem is not PdfPageItem selected || selected.SourcePageNumber != sourcePageNumber || selected.Position != pagePosition)
                return;

            _selectableTextPage = layout;
            _selectableTextPath = path;
            _selectableTextSourcePage = sourcePageNumber;
            _selectableTextPagePosition = pagePosition;
            UpdateDocumentTextSelectionInteractionState();
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF text-selection load failed: " + ex);
            if (documentGeneration == _documentGeneration)
                UpdateDocumentTextSelectionInteractionState();
        }
    }

    private void TextSelectionCanvas_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left || _busy || _markupMode != MarkupMode.None || _selectableTextPage is null)
            return;

        var index = FindSelectableCharacterIndex(e.GetPosition(TextSelectionCanvas), allowNearest: false);
        if (index < 0)
        {
            ClearDocumentTextSelectionRange();
            return;
        }

        _textSelectionAnchor = index;
        _textSelectionFocus = index;
        _textSelectionDragging = true;
        TextSelectionCanvas.Focus();
        TextSelectionCanvas.CaptureMouse();
        RefreshDocumentTextSelectionHighlights();
        e.Handled = true;
    }

    private void TextSelectionCanvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_textSelectionDragging || e.LeftButton != MouseButtonState.Pressed || _selectableTextPage is null) return;
        var index = FindSelectableCharacterIndex(e.GetPosition(TextSelectionCanvas), allowNearest: true);
        if (index < 0 || index == _textSelectionFocus) return;
        _textSelectionFocus = index;
        RefreshDocumentTextSelectionHighlights();
        e.Handled = true;
    }

    private void TextSelectionCanvas_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_textSelectionDragging) return;
        _textSelectionDragging = false;
        try { TextSelectionCanvas.ReleaseMouseCapture(); } catch { }

        var index = FindSelectableCharacterIndex(e.GetPosition(TextSelectionCanvas), allowNearest: true);
        if (index >= 0) _textSelectionFocus = index;
        RefreshDocumentTextSelectionHighlights();
        StatusText.Text = HasDocumentTextSelection ? "PDF text selected. Press Ctrl+C or right-click to copy." : "Ready.";
        e.Handled = true;
    }

    private int FindSelectableCharacterIndex(Point point, bool allowNearest)
    {
        var page = _selectableTextPage;
        if (page is null || page.CharacterRectangles.Count == 0) return -1;

        var width = Math.Max(1d, TextSelectionCanvas.ActualWidth > 0 ? TextSelectionCanvas.ActualWidth : TextSelectionCanvas.Width);
        var height = Math.Max(1d, TextSelectionCanvas.ActualHeight > 0 ? TextSelectionCanvas.ActualHeight : TextSelectionCanvas.Height);
        var x = Math.Clamp(point.X / width, 0, 1);
        var y = Math.Clamp(point.Y / height, 0, 1);
        const double padX = 0.0045;
        const double padY = 0.0045;

        var bestIndex = -1;
        var bestScore = double.MaxValue;

        for (var i = 0; i < page.CharacterRectangles.Count; i++)
        {
            var rect = page.CharacterRectangles[i];
            if (rect is null || rect.Width <= 0 || rect.Height <= 0) continue;

            var inside = x >= rect.X - padX && x <= rect.X + rect.Width + padX &&
                         y >= rect.Y - padY && y <= rect.Y + rect.Height + padY;
            if (!inside && !allowNearest) continue;

            var dx = x < rect.X ? rect.X - x : x > rect.X + rect.Width ? x - (rect.X + rect.Width) : 0;
            var dy = y < rect.Y ? rect.Y - y : y > rect.Y + rect.Height ? y - (rect.Y + rect.Height) : 0;
            var score = dx * dx + dy * dy;
            if (inside)
            {
                var centerX = rect.X + rect.Width / 2;
                var centerY = rect.Y + rect.Height / 2;
                score = (x - centerX) * (x - centerX) + (y - centerY) * (y - centerY);
            }

            if (score >= bestScore) continue;
            bestScore = score;
            bestIndex = i;
        }

        return bestIndex;
    }

    private void RefreshDocumentTextSelectionHighlights()
    {
        TextSelectionCanvas.Children.Clear();
        if (!HasDocumentTextSelection || _selectableTextPage is null) return;

        var start = Math.Min(_textSelectionAnchor, _textSelectionFocus);
        var end = Math.Max(_textSelectionAnchor, _textSelectionFocus);
        if (start < 0 || end >= _selectableTextPage.CharacterRectangles.Count) return;

        var rectangles = MergeSelectionRectangles(
            _selectableTextPage.CharacterRectangles.Skip(start).Take(end - start + 1).OfType<PdfSearchRect>());

        foreach (var rect in rectangles)
        {
            var highlight = new Rectangle
            {
                Width = Math.Max(2, rect.Width * TextSelectionCanvas.Width),
                Height = Math.Max(2, rect.Height * TextSelectionCanvas.Height),
                Fill = new SolidColorBrush(Color.FromArgb(105, 71, 149, 255)),
                Stroke = new SolidColorBrush(Color.FromArgb(175, 64, 133, 245)),
                StrokeThickness = 0.8,
                IsHitTestVisible = false
            };
            Canvas.SetLeft(highlight, rect.X * TextSelectionCanvas.Width);
            Canvas.SetTop(highlight, rect.Y * TextSelectionCanvas.Height);
            TextSelectionCanvas.Children.Add(highlight);
        }
    }

    private static IReadOnlyList<PdfSearchRect> MergeSelectionRectangles(IEnumerable<PdfSearchRect> source)
    {
        var ordered = source
            .Where(rect => rect.Width > 0 && rect.Height > 0)
            .OrderBy(rect => rect.Y)
            .ThenBy(rect => rect.X)
            .ToArray();
        if (ordered.Length == 0) return [];

        var merged = new List<PdfSearchRect>();
        foreach (var rect in ordered)
        {
            if (merged.Count == 0)
            {
                merged.Add(rect);
                continue;
            }

            var previous = merged[^1];
            var sameLine = Math.Abs(previous.Y - rect.Y) <= Math.Max(previous.Height, rect.Height) * 0.55;
            var close = rect.X <= previous.X + previous.Width + 0.012;
            if (sameLine && close)
            {
                var left = Math.Min(previous.X, rect.X);
                var top = Math.Min(previous.Y, rect.Y);
                var right = Math.Max(previous.X + previous.Width, rect.X + rect.Width);
                var bottom = Math.Max(previous.Y + previous.Height, rect.Y + rect.Height);
                merged[^1] = new PdfSearchRect(left, top, right - left, bottom - top);
            }
            else
            {
                merged.Add(rect);
            }
        }
        return merged;
    }

    private void CopySelectedDocumentText_Click(object sender, RoutedEventArgs e) => CopySelectedDocumentText();

    private void TextSelectionContextMenu_Opened(object sender, RoutedEventArgs e)
    {
        if (sender is ContextMenu menu && menu.Items.Count > 0 && menu.Items[0] is MenuItem copy)
            copy.IsEnabled = HasDocumentTextSelection;
    }

    private bool TryCopySelectedDocumentTextFromKeyboard()
    {
        if (!HasDocumentTextSelection || Keyboard.FocusedElement is TextBox or PasswordBox) return false;
        CopySelectedDocumentText();
        return true;
    }

    private void CopySelectedDocumentText()
    {
        var page = _selectableTextPage;
        if (page is null || !HasDocumentTextSelection) return;

        var start = Math.Min(_textSelectionAnchor, _textSelectionFocus);
        var end = Math.Max(_textSelectionAnchor, _textSelectionFocus);
        if (start < 0 || end < start || end >= page.Text.Length) return;

        var selected = page.Text.Substring(start, end - start + 1);
        if (selected.Length == 0) return;

        try
        {
            Clipboard.SetText(selected);
            StatusText.Text = $"Copied {selected.Length:N0} character(s) from the PDF.";
        }
        catch (Exception ex)
        {
            App.Log("Could not copy selected PDF text: " + ex.Message);
            StatusText.Text = "Could not copy the selected PDF text to the clipboard.";
        }
    }

    private void ClearDocumentTextSelectionRange()
    {
        _textSelectionAnchor = -1;
        _textSelectionFocus = -1;
        _textSelectionDragging = false;
        try { TextSelectionCanvas.ReleaseMouseCapture(); } catch { }
        TextSelectionCanvas.Children.Clear();
    }

    private void SetDocumentTextSelectionInteractionEnabled(bool enabled)
    {
        TextSelectionCanvas.IsHitTestVisible = enabled && _selectableTextPage is not null && _selectableTextPage.CharacterRectangles.Any(rect => rect is not null);
        TextSelectionCanvas.Cursor = TextSelectionCanvas.IsHitTestVisible ? Cursors.IBeam : Cursors.Arrow;
    }

    private void UpdateDocumentTextSelectionInteractionState() =>
        SetDocumentTextSelectionInteractionEnabled(_markupMode == MarkupMode.None && !_busy && _currentPdf is not null);

    private void ResetDocumentTextSelectionForDocumentChange()
    {
        _textSelectionLoadCts?.Cancel();
        _textSelectionLoadCts?.Dispose();
        _textSelectionLoadCts = null;
        _selectableTextPage = null;
        _selectableTextPath = null;
        _selectableTextSourcePage = 0;
        _selectableTextPagePosition = 0;
        ClearDocumentTextSelectionRange();
        TextSelectionCanvas.IsHitTestVisible = false;
        TextSelectionCanvas.Visibility = Visibility.Collapsed;
    }
}