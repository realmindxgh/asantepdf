using System.IO;
using System.Windows;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly NativePdfAnnotationService _nativeAnnotations = new();
    private NativeAnnotationStyle _annotationStyle = NativeAnnotationStyle.Yellow;
    private PdfAnnotationItem? _selectedPdfAnnotation;
    private readonly List<Point> _freehandPoints = [];

    private void FreehandMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Freehand, "Freehand mode: draw on the current page. Release the mouse to create a native PDF ink annotation.");
    }

    private void BeginFreehandStroke(Point point)
    {
        _freehandPoints.Clear();
        _freehandPoints.Add(point);
        FreehandPreviewPolyline.Points.Clear();
        FreehandPreviewPolyline.Points.Add(point);
        FreehandPreviewPolyline.Stroke = new SolidColorBrush(Color.FromArgb(
            _annotationStyle.Alpha, _annotationStyle.Red, _annotationStyle.Green, _annotationStyle.Blue));
        FreehandPreviewPolyline.StrokeThickness = Math.Max(1.5, _annotationStyle.BorderWidth * 1.6);
        FreehandPreviewPolyline.Visibility = Visibility.Visible;
        MarkupSelectionRectangle.Visibility = Visibility.Collapsed;
        _markupDragging = true;
        MarkupCanvas.CaptureMouse();
    }

    private void ContinueFreehandStroke(Point point, bool force = false)
    {
        if (_freehandPoints.Count > 0 && !force)
        {
            var prior = _freehandPoints[^1];
            var dx = point.X - prior.X;
            var dy = point.Y - prior.Y;
            if ((dx * dx) + (dy * dy) < 2.25) return;
        }
        _freehandPoints.Add(point);
        FreehandPreviewPolyline.Points.Add(point);
    }

    private IReadOnlyList<NativeInkPoint> GetNormalizedFreehandPoints()
    {
        var width = Math.Max(1d, MarkupCanvas.ActualWidth);
        var height = Math.Max(1d, MarkupCanvas.ActualHeight);
        return _freehandPoints
            .Select(point => new NativeInkPoint(point.X / width, point.Y / height))
            .ToArray();
    }

    private void ResetFreehandPreview()
    {
        _freehandPoints.Clear();
        if (FreehandPreviewPolyline is null) return;
        FreehandPreviewPolyline.Points.Clear();
        FreehandPreviewPolyline.Visibility = Visibility.Collapsed;
    }

    private async Task ApplyFreehandAnnotationAsync(int pageNumber, IReadOnlyList<NativeInkPoint> points)
    {
        if (_currentPdf is null || points.Count < 2) return;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF with freehand ink", SuggestName(source, "ink"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Adding freehand ink…", "Freehand ink added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) =>
                _nativeAnnotations.AddInkAsync(working, output, pageNumber, points, _annotationStyle, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Freehand annotation complete",
                $"Created a copy with a native PDF ink annotation on page {pageNumber:N0}. The source PDF was preserved.",
                source, output, () => FreehandMarkup_Click(this, new RoutedEventArgs()));
    }

    private IReadOnlyList<PdfSearchRect> SelectedTextAnnotationRects()
    {
        if (!HasDocumentTextSelection || _selectableTextPage is null) return [];
        var start = Math.Min(_textSelectionAnchor, _textSelectionFocus);
        var end = Math.Max(_textSelectionAnchor, _textSelectionFocus);
        if (start < 0 || end < start || end >= _selectableTextPage.CharacterRectangles.Count) return [];
        return MergeSelectionRectangles(_selectableTextPage.CharacterRectangles
            .Skip(start).Take(end - start + 1).OfType<PdfSearchRect>());
    }

    private string SelectedTextAnnotationContents()
    {
        if (!HasDocumentTextSelection || _selectableTextPage is null) return string.Empty;
        var start = Math.Min(_textSelectionAnchor, _textSelectionFocus);
        var end = Math.Max(_textSelectionAnchor, _textSelectionFocus);
        return start >= 0 && end >= start && end < _selectableTextPage.Text.Length
            ? _selectableTextPage.Text.Substring(start, end - start + 1).Trim()
            : string.Empty;
    }

    private void AnnotationStyle_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new AnnotationStyleWindow(_annotationStyle) { Owner = this };
        if (dialog.ShowDialog() == true && dialog.SelectedStyle is not null)
        {
            _annotationStyle = dialog.SelectedStyle;
            StatusText.Text = "Annotation color and opacity updated.";
        }
    }

    private async void HighlightSelectedText_Click(object sender, RoutedEventArgs e) =>
        await ApplySelectedTextAnnotationAsync(NativeTextMarkupKind.Highlight, "highlighted");

    private async void UnderlineSelectedText_Click(object sender, RoutedEventArgs e) =>
        await ApplySelectedTextAnnotationAsync(NativeTextMarkupKind.Underline, "underlined");

    private async void StrikeoutSelectedText_Click(object sender, RoutedEventArgs e) =>
        await ApplySelectedTextAnnotationAsync(NativeTextMarkupKind.Strikeout, "struck-out");

    private async Task ApplySelectedTextAnnotationAsync(NativeTextMarkupKind kind, string suffix)
    {
        if (_currentPdf is null || !HasDocumentTextSelection)
        {
            StatusText.Text = "Select PDF text first, then choose Highlight, Underline or Strikeout.";
            return;
        }
        var rectangles = SelectedTextAnnotationRects();
        if (rectangles.Count == 0) return;
        var source = _currentPdf;
        var pagePosition = Math.Max(1, _selectableTextPagePosition);
        var output = AskSavePath($"Save {suffix} PDF", SuggestName(source, suffix));
        if (output is null) return;
        var contents = SelectedTextAnnotationContents();
        var success = await RunPdfOutputOperationAsync($"Adding {suffix} text annotation…", $"Text {suffix}.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _nativeAnnotations.AddTextMarkupAsync(
                working, output, pagePosition, rectangles, kind, _annotationStyle, contents, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Annotation complete", $"Created a copy with native PDF text markup on page {pagePosition:N0}.", source, output,
                () => ApplySelectedTextAnnotationAsync(kind, suffix).Forget());
    }

    private async void AddNoteAnnotation_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || PagesList.SelectedItem is not PdfPageItem page) return;
        var dialog = new AnnotationEditorWindow("Add note", string.Empty, _annotationStyle) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.Result is null || string.IsNullOrWhiteSpace(dialog.Result.Contents)) return;
        _annotationStyle = dialog.Result.Style;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF with note", SuggestName(source, "noted"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Adding PDF note…", "Note added.", output, token =>
            RunAgainstWorkingLayoutAsync((working, ct) => _nativeAnnotations.AddNoteAsync(
                working, output, page.Position, 0.08, 0.08, dialog.Result.Contents, dialog.Result.Style, ct), token));
        if (success)
            await ShowPdfResultWorkflowAsync("Note complete", $"Created a copy with a native note annotation on page {page.Position:N0}.", source, output,
                () => AddNoteAnnotation_Click(this, new RoutedEventArgs()));
    }

    private async void EditSelectedAnnotation_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || _selectedPdfAnnotation is null) return;
        if (HasLayoutChanges())
        {
            MessageBox.Show(this, "Save or discard page-layout changes before editing an existing annotation. This keeps the source-page annotation index unambiguous.",
                "Edit annotation", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var annotation = _selectedPdfAnnotation;
        var dialog = new AnnotationEditorWindow("Edit annotation", annotation.Contents, _annotationStyle) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.Result is null) return;
        _annotationStyle = dialog.Result.Style;
        var source = _currentPdf;
        var output = AskSavePath("Save edited annotation copy", SuggestName(source, "annotation-edited"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Editing annotation…", "Annotation edited.", output, token =>
            _nativeAnnotations.UpdateAsync(source, output, annotation.SourcePageNumber, annotation.Index,
                dialog.Result.Contents, dialog.Result.Style, token));
        if (success)
            await ShowPdfResultWorkflowAsync("Annotation edited", "Created a copy with the selected annotation updated.", source, output,
                () => EditSelectedAnnotation_Click(this, new RoutedEventArgs()));
    }

    private async void DeleteSelectedAnnotation_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || _selectedPdfAnnotation is null) return;
        if (HasLayoutChanges())
        {
            MessageBox.Show(this, "Save or discard page-layout changes before deleting an existing annotation.",
                "Delete annotation", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }
        var annotation = _selectedPdfAnnotation;
        if (MessageBox.Show(this, $"Remove this {annotation.TypeLabel.ToLowerInvariant()} from a new PDF copy?",
                "Delete annotation", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        var source = _currentPdf;
        var output = AskSavePath("Save PDF without annotation", SuggestName(source, "annotation-removed"));
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync("Removing annotation…", "Annotation removed.", output, token =>
            _nativeAnnotations.DeleteAsync(source, output, annotation.SourcePageNumber, annotation.Index, token));
        if (success)
            await ShowPdfResultWorkflowAsync("Annotation removed", "Created a copy without the selected annotation. The source PDF was preserved.", source, output,
                () => DeleteSelectedAnnotation_Click(this, new RoutedEventArgs()));
    }
}

internal static class FireAndForgetTaskExtensions
{
    public static void Forget(this Task task) { }
}