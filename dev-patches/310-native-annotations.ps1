param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$service = Join-Path $SourceRoot 'src\PdfRescue.App\Services\NativePdfAnnotationService.cs'
Write-Text $service @'
using System.IO;
using System.Runtime.InteropServices;
using PDFiumCore;
using PdfRescue.Core.Models;

namespace PdfRescue.App.Services;

public enum NativeTextMarkupKind
{
    Highlight,
    Underline,
    Strikeout
}

public sealed record NativeAnnotationStyle(byte Red, byte Green, byte Blue, byte Alpha, double BorderWidth = 1.5)
{
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
    public static NativeAnnotationStyle Blue { get; } = new(45, 125, 255, 220, 1.5);
    public static NativeAnnotationStyle Red { get; } = new(206, 17, 38, 220, 1.5);
}

public sealed class NativePdfAnnotationService
{
    private const int AnnotText = 1;
    private const int AnnotSquare = 5;
    private const int AnnotCircle = 6;
    private const int AnnotHighlight = 9;
    private const int AnnotUnderline = 10;
    private const int AnnotStrikeOut = 12;
    private const int ColorTypeStroke = 0;
    private const int ColorTypeInterior = 1;

    public Task AddTextMarkupAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        IReadOnlyList<PdfSearchRect> rectangles,
        NativeTextMarkupKind kind,
        NativeAnnotationStyle style,
        string contents = "",
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, _, _) =>
        {
            var usable = rectangles.Where(rect => rect.Width > 0 && rect.Height > 0).ToArray();
            if (usable.Length == 0) throw new InvalidOperationException("Select some PDF text before adding text markup.");

            var subtype = kind switch
            {
                NativeTextMarkupKind.Highlight => AnnotHighlight,
                NativeTextMarkupKind.Underline => AnnotUnderline,
                NativeTextMarkupKind.Strikeout => AnnotStrikeOut,
                _ => throw new ArgumentOutOfRangeException(nameof(kind))
            };
            var annotation = CreateAnnotation(page, subtype);
            try
            {
                SetStrokeColor(annotation, style);
                var pageWidth = fpdfview.FPDF_GetPageWidthF(page);
                var pageHeight = fpdfview.FPDF_GetPageHeightF(page);
                if (pageWidth <= 0 || pageHeight <= 0) throw new InvalidDataException("PDF page dimensions are invalid.");

                var boxes = usable.Select(rect => ToPdfRect(rect, pageWidth, pageHeight)).ToArray();
                var bounds = new FS_RECTF_
                {
                    Left = boxes.Min(box => box.Left),
                    Right = boxes.Max(box => box.Right),
                    Bottom = boxes.Min(box => box.Bottom),
                    Top = boxes.Max(box => box.Top)
                };
                if (fpdf_annot.FPDFAnnotSetRect(annotation, bounds) == 0)
                    throw new InvalidDataException("PDFium could not set the text-markup annotation bounds.");

                foreach (var box in boxes)
                {
                    var quad = new FS_QUADPOINTSF()
                    {
                        X1 = box.Left, Y1 = box.Top,
                        X2 = box.Right, Y2 = box.Top,
                        X3 = box.Left, Y3 = box.Bottom,
                        X4 = box.Right, Y4 = box.Bottom
                    };
                    if (fpdf_annot.FPDFAnnotAppendAttachmentPoints(annotation, quad) == 0)
                        throw new InvalidDataException("PDFium could not attach text markup to the selected text.");
                }
                SetString(annotation, "T", "AsantePDF");
                if (!string.IsNullOrWhiteSpace(contents)) SetString(annotation, "Contents", contents.Trim());
            }
            finally { fpdf_annot.FPDFPageCloseAnnot(annotation); }
        }, token);

    public Task AddShapeAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        NormalizedPdfRect rect,
        bool ellipse,
        NativeAnnotationStyle style,
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, width, height) =>
        {
            var annotation = CreateAnnotation(page, ellipse ? AnnotCircle : AnnotSquare);
            try
            {
                var pdfRect = ToPdfRect(new PdfSearchRect(rect.X, rect.Y, rect.Width, rect.Height), width, height);
                if (fpdf_annot.FPDFAnnotSetRect(annotation, pdfRect) == 0)
                    throw new InvalidDataException("PDFium could not set the shape annotation bounds.");
                SetStrokeColor(annotation, style);
                fpdf_annot.FPDFAnnotSetBorder(annotation, 0, 0, (float)Math.Max(0.5, style.BorderWidth));
                SetString(annotation, "T", "AsantePDF");
            }
            finally { fpdf_annot.FPDFPageCloseAnnot(annotation); }
        }, token);

    public Task AddNoteAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        double normalizedX,
        double normalizedY,
        string contents,
        NativeAnnotationStyle style,
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, width, height) =>
        {
            var annotation = CreateAnnotation(page, AnnotText);
            try
            {
                const double iconWidth = 0.045;
                const double iconHeight = 0.055;
                var rect = new PdfSearchRect(Math.Clamp(normalizedX, 0, 0.95), Math.Clamp(normalizedY, 0, 0.94), iconWidth, iconHeight);
                if (fpdf_annot.FPDFAnnotSetRect(annotation, ToPdfRect(rect, width, height)) == 0)
                    throw new InvalidDataException("PDFium could not position the note annotation.");
                SetStrokeColor(annotation, style);
                SetString(annotation, "T", "AsantePDF");
                SetString(annotation, "Contents", contents.Trim());
            }
            finally { fpdf_annot.FPDFPageCloseAnnot(annotation); }
        }, token);

    public Task UpdateAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        int annotationIndex,
        string contents,
        NativeAnnotationStyle style,
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, _, _) =>
        {
            var annotation = fpdf_annot.FPDFPageGetAnnot(page, annotationIndex);
            if (annotation is null || annotation.__Instance == IntPtr.Zero)
                throw new InvalidDataException("The selected annotation no longer exists at this position.");
            try
            {
                SetString(annotation, "Contents", contents.Trim());
                SetStrokeColor(annotation, style);
                if (fpdf_annot.FPDFAnnotGetSubtype(annotation) is AnnotSquare or AnnotCircle)
                {
                    fpdf_annot.FPDFAnnotSetBorder(annotation, 0, 0, (float)Math.Max(0.5, style.BorderWidth));
                }
            }
            finally { fpdf_annot.FPDFPageCloseAnnot(annotation); }
        }, token);

    public Task DeleteAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        int annotationIndex,
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, _, _) =>
        {
            if (fpdf_annot.FPDFPageRemoveAnnot(page, annotationIndex) == 0)
                throw new InvalidDataException("PDFium could not remove the selected annotation.");
        }, token);

    private static Task MutateAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        Action<FpdfPageT, float, float> mutation,
        CancellationToken token)
    {
        var input = Path.GetFullPath(inputPath);
        var output = Path.GetFullPath(outputPath);
        if (!File.Exists(input)) throw new FileNotFoundException("PDF file was not found.", input);
        if (string.Equals(input, output, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Native annotation output must be a different PDF file.");

        return Task.Run(() =>
        {
            token.ThrowIfCancellationRequested();
            using var runtimeAnchor = PdfRendererFactory.CreateProduction();
            var document = fpdfview.FPDF_LoadDocument(input, string.Empty);
            if (document is null) throw new InvalidDataException("PDFium could not open this PDF for annotation editing.");

            var staged = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                var pageCount = fpdfview.FPDF_GetPageCount(document);
                if (pageNumber < 1 || pageNumber > pageCount)
                    throw new ArgumentOutOfRangeException(nameof(pageNumber));
                var page = fpdfview.FPDF_LoadPage(document, pageNumber - 1);
                if (page is null) throw new InvalidDataException("PDFium could not open the target PDF page.");
                try
                {
                    token.ThrowIfCancellationRequested();
                    var width = fpdfview.FPDF_GetPageWidthF(page);
                    var height = fpdfview.FPDF_GetPageHeightF(page);
                    mutation(page, width, height);
                }
                finally { fpdfview.FPDF_ClosePage(page); }

                token.ThrowIfCancellationRequested();
                Directory.CreateDirectory(Path.GetDirectoryName(output)!);
                using (var stream = new FileStream(staged, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    var writer = new PdfiumFileWriter(stream);
                    if (fpdf_save.FPDF_SaveAsCopy(document, writer, 1) == 0)
                        throw new IOException("PDFium could not serialize the annotated PDF.");
                }
                token.ThrowIfCancellationRequested();
                File.Move(staged, output, true);
            }
            finally
            {
                fpdfview.FPDF_CloseDocument(document);
                try { if (File.Exists(staged)) File.Delete(staged); } catch { }
            }
        }, token);
    }

    private static FpdfAnnotationT CreateAnnotation(FpdfPageT page, int subtype)
    {
        var annotation = fpdf_annot.FPDFPageCreateAnnot(page, subtype);
        if (annotation is null || annotation.__Instance == IntPtr.Zero)
            throw new InvalidDataException("PDFium could not create the requested annotation.");
        return annotation;
    }

    private static FS_RECTF_ ToPdfRect(PdfSearchRect normalized, double pageWidth, double pageHeight)
    {
        var left = Math.Clamp(normalized.X, 0, 1) * pageWidth;
        var right = Math.Clamp(normalized.X + normalized.Width, 0, 1) * pageWidth;
        var top = (1 - Math.Clamp(normalized.Y, 0, 1)) * pageHeight;
        var bottom = (1 - Math.Clamp(normalized.Y + normalized.Height, 0, 1)) * pageHeight;
        return new FS_RECTF_
        {
            Left = (float)Math.Min(left, right),
            Right = (float)Math.Max(left, right),
            Bottom = (float)Math.Min(bottom, top),
            Top = (float)Math.Max(bottom, top)
        };
    }

    private static void SetStrokeColor(FpdfAnnotationT annotation, NativeAnnotationStyle style) =>
        fpdf_annot.FPDFAnnotSetColor(annotation, (FPDFANNOT_COLORTYPE)ColorTypeStroke,
            style.Red, style.Green, style.Blue, style.Alpha);

    private static void SetString(FpdfAnnotationT annotation, string key, string value)
    {
        var buffer = new ushort[value.Length + 1];
        for (var i = 0; i < value.Length; i++) buffer[i] = value[i];
        fpdf_annot.FPDFAnnotSetStringValue(annotation, key, ref buffer[0]);
    }

    private sealed class PdfiumFileWriter : FPDF_FILEWRITE_
    {
        private readonly Stream _stream;

        public PdfiumFileWriter(Stream stream)
        {
            _stream = stream;
            WriteBlock = Write;
        }

        private int Write(IntPtr pThis, IntPtr data, uint size)
        {
            try
            {
                var length = checked((int)size);
                var buffer = new byte[length];
                Marshal.Copy(data, buffer, 0, length);
                _stream.Write(buffer, 0, length);
                return 1;
            }
            catch { return 0; }
        }
    }
}
'@

$windows = Join-Path $SourceRoot 'src\PdfRescue.App\AnnotationWindows.cs'
Write-Text $windows @'
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

internal sealed record AnnotationEditorResult(string Contents, NativeAnnotationStyle Style);

internal sealed class AnnotationStyleWindow : Window
{
    private readonly ComboBox _color = new();
    private readonly Slider _opacity = new() { Minimum = 10, Maximum = 100, TickFrequency = 5, IsSnapToTickEnabled = true };
    private readonly Slider _border = new() { Minimum = 0.5, Maximum = 6, TickFrequency = 0.5, IsSnapToTickEnabled = true };

    public NativeAnnotationStyle? SelectedStyle { get; private set; }

    public AnnotationStyleWindow(NativeAnnotationStyle current)
    {
        Title = "Annotation style";
        Width = 460;
        Height = 390;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];

        _color.ItemsSource = new[] { "Yellow", "Blue", "Green", "Red", "Black" };
        _color.SelectedIndex = ClosestColor(current);
        _opacity.Value = Math.Round(current.Alpha / 255d * 100d / 5d) * 5d;
        _border.Value = Math.Clamp(current.BorderWidth, 0.5, 6);

        var root = new StackPanel { Margin = new Thickness(26) };
        root.Children.Add(new TextBlock { Text = "Annotation style", FontSize = 25, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = "Used by text markup, notes and shape annotations.", Foreground = (Brush)FindResource("MutedTextBrush"), Margin = new Thickness(0, 5, 0, 20) });
        AddField(root, "Color", _color);
        AddField(root, "Opacity", _opacity);
        AddField(root, "Shape border width", _border);

        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle") };
        cancel.Click += (_, _) => Close();
        var apply = new Button { Content = "Use style", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        apply.Click += (_, _) =>
        {
            var rgb = _color.SelectedIndex switch
            {
                1 => (r: (byte)45, g: (byte)125, b: (byte)255),
                2 => (r: (byte)0, g: (byte)107, b: (byte)63),
                3 => (r: (byte)206, g: (byte)17, b: (byte)38),
                4 => (r: (byte)25, g: (byte)25, b: (byte)25),
                _ => (r: (byte)252, g: (byte)209, b: (byte)22)
            };
            SelectedStyle = new NativeAnnotationStyle(rgb.r, rgb.g, rgb.b,
                (byte)Math.Clamp((int)Math.Round(_opacity.Value / 100d * 255d), 1, 255), _border.Value);
            DialogResult = true;
            Close();
        };
        buttons.Children.Add(cancel); buttons.Children.Add(apply);
        root.Children.Add(buttons);
        Content = root;
    }

    private void AddField(Panel parent, string label, FrameworkElement control)
    {
        parent.Children.Add(new TextBlock { Text = label, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 5) });
        parent.Children.Add(control);
    }

    private static int ClosestColor(NativeAnnotationStyle style)
    {
        if (style.Red > 180 && style.Green < 90) return 3;
        if (style.Blue > 180 && style.Red < 120) return 1;
        if (style.Green > 80 && style.Red < 80) return 2;
        if (style.Red < 80 && style.Green < 80 && style.Blue < 80) return 4;
        return 0;
    }
}

internal sealed class AnnotationEditorWindow : Window
{
    private readonly TextBox _contents = new() { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Height = 140 };
    private NativeAnnotationStyle _style;

    public AnnotationEditorResult? Result { get; private set; }

    public AnnotationEditorWindow(string title, string existingContents, NativeAnnotationStyle style)
    {
        _style = style;
        Title = title;
        Width = 540;
        Height = 430;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        ResizeMode = ResizeMode.NoResize;
        Background = (Brush)Application.Current.Resources["AppBackground"];
        Foreground = (Brush)Application.Current.Resources["PrimaryTextBrush"];
        _contents.Text = existingContents;

        var root = new StackPanel { Margin = new Thickness(26) };
        root.Children.Add(new TextBlock { Text = title, FontSize = 24, FontWeight = FontWeights.SemiBold });
        root.Children.Add(new TextBlock { Text = "Comment / contents", FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 18, 0, 5) });
        root.Children.Add(_contents);
        var styleButton = new Button { Content = "Color and opacity…", Style = (Style)FindResource("FlatButtonStyle"), HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 10, 0, 0) };
        styleButton.Click += (_, _) =>
        {
            var dialog = new AnnotationStyleWindow(_style) { Owner = this };
            if (dialog.ShowDialog() == true && dialog.SelectedStyle is not null) _style = dialog.SelectedStyle;
        };
        root.Children.Add(styleButton);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var cancel = new Button { Content = "Cancel", Style = (Style)FindResource("FlatButtonStyle") };
        cancel.Click += (_, _) => Close();
        var save = new Button { Content = "Create copy", IsDefault = true, Style = (Style)FindResource("PrimaryButtonStyle") };
        save.Click += (_, _) => { Result = new AnnotationEditorResult(_contents.Text, _style); DialogResult = true; Close(); };
        buttons.Children.Add(cancel); buttons.Children.Add(save); root.Children.Add(buttons);
        Content = root;
    }
}
'@

$nativeUi = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NativeAnnotations.cs'
Write-Text $nativeUi @'
using System.IO;
using System.Windows;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly NativePdfAnnotationService _nativeAnnotations = new();
    private NativeAnnotationStyle _annotationStyle = NativeAnnotationStyle.Yellow;
    private PdfAnnotationItem? _selectedPdfAnnotation;

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
'@

# Annotation navigation needs stable PDFium annotation index and subtype for edit/delete.
$annotationService = Join-Path $SourceRoot 'src\PdfRescue.App\Services\DocumentAnnotationService.cs'
Replace-Exact $annotationService @'
public sealed record PdfAnnotationItem(
    int SourcePageNumber,
    string TypeLabel,
    string Author,
    string Contents,
    string Modified)
'@ @'
public sealed record PdfAnnotationItem(
    int Index,
    int SourcePageNumber,
    int Subtype,
    string TypeLabel,
    string Author,
    string Contents,
    string Modified)
'@ 'annotation item identity'

Replace-Exact $annotationService @'
                            results.Add(new PdfAnnotationItem(
                                pageIndex + 1,
                                GetSubtypeLabel(subtype),
'@ @'
                            results.Add(new PdfAnnotationItem(
                                annotationIndex,
                                pageIndex + 1,
                                subtype,
                                GetSubtypeLabel(subtype),
'@ 'annotation index capture'

# Keep selected annotation context and invalidate selection when document changes.
$navigation = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NavigationMetadata.cs'
Replace-Exact $navigation @'
    private void AnnotationsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (AnnotationsList.SelectedItem is not PdfAnnotationItem annotation) return;
'@ @'
    private void AnnotationsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selectedPdfAnnotation = AnnotationsList.SelectedItem as PdfAnnotationItem;
        if (_selectedPdfAnnotation is not PdfAnnotationItem annotation)
        {
            UpdateInspectorContext();
            return;
        }
'@ 'annotation selection state'

Replace-Exact $navigation @'
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
'@ @'
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
        UpdateInspectorContext();
'@ 'annotation inspector refresh'

Replace-Exact $navigation @'
        _annotationsLoadedForPath = null;
        _attachmentsLoadedForPath = null;

        if (!_productShellInitialized || AnnotationsList is null || AttachmentsList is null) return;
'@ @'
        _annotationsLoadedForPath = null;
        _attachmentsLoadedForPath = null;
        _selectedPdfAnnotation = null;

        if (!_productShellInitialized || AnnotationsList is null || AttachmentsList is null) return;
'@ 'reset annotation selection'

# Inspector becomes annotation-aware and text selection gets direct markup commands.
$inspector = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.InspectorContext.cs'
Replace-Exact $inspector @'
            copy.Click += CopySelectedDocumentText_Click;
            InspectorContextContent.Children.Add(copy);
            return;
        }

        var selectedPages = SelectedPages();
'@ @'
            copy.Click += CopySelectedDocumentText_Click;
            InspectorContextContent.Children.Add(copy);
            var markup = new WrapPanel { Margin = new Thickness(0, 7, 0, 0) };
            markup.Children.Add(CreateInspectorAction("Highlight", HighlightSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Underline", UnderlineSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Strikeout", StrikeoutSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Style…", AnnotationStyle_Click));
            InspectorContextContent.Children.Add(markup);
            return;
        }

        if (_selectedPdfAnnotation is PdfAnnotationItem annotation)
        {
            InspectorContextTitle.Text = "Annotation";
            InspectorContextSummary.Text = $"{annotation.TypeLabel} on source page {annotation.SourcePageNumber:N0}";
            AddInspectorField("Type", annotation.TypeLabel);
            AddInspectorField("Author", string.IsNullOrWhiteSpace(annotation.Author) ? "Not specified" : annotation.Author);
            AddInspectorField("Contents", string.IsNullOrWhiteSpace(annotation.Contents) ? "(No comment text)" : annotation.Contents, true);
            AddInspectorField("Modified", string.IsNullOrWhiteSpace(annotation.Modified) ? "Not specified" : annotation.Modified);
            var actions = new WrapPanel { Margin = new Thickness(0, 5, 0, 0) };
            actions.Children.Add(CreateInspectorAction("Edit copy…", EditSelectedAnnotation_Click));
            actions.Children.Add(CreateInspectorAction("Delete from copy…", DeleteSelectedAnnotation_Click));
            InspectorContextContent.Children.Add(actions);
            return;
        }

        var selectedPages = SelectedPages();
'@ 'annotation inspector and text markup actions'

# Text-selection context menu receives semantic PDF annotation commands.
$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                                <ContextMenu Opened="TextSelectionContextMenu_Opened">
                                                    <MenuItem Header="Copy selected text" InputGestureText="Ctrl+C" Click="CopySelectedDocumentText_Click" />
                                                </ContextMenu>
'@ @'
                                                <ContextMenu Opened="TextSelectionContextMenu_Opened">
                                                    <MenuItem Header="Copy selected text" InputGestureText="Ctrl+C" Click="CopySelectedDocumentText_Click" />
                                                    <Separator />
                                                    <MenuItem Header="Highlight selected text" Click="HighlightSelectedText_Click" />
                                                    <MenuItem Header="Underline selected text" Click="UnderlineSelectedText_Click" />
                                                    <MenuItem Header="Strike out selected text" Click="StrikeoutSelectedText_Click" />
                                                    <MenuItem Header="Annotation color and opacity…" Click="AnnotationStyle_Click" />
                                                </ContextMenu>
'@ 'text annotation context menu'

# Expand ribbon annotation commands while preserving horizontal scroll behaviour.
Replace-Exact $xaml @'
                                            <Button x:Name="HighlightButton" Style="{StaticResource RibbonButtonStyle}" Click="HighlightMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE70F;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#F0B93A"/><TextBlock Text="Highlight" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button x:Name="CropButton" Style="{StaticResource RibbonButtonStyle}" Click="CropMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE7A8;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#D187FF"/><TextBlock Text="Crop" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
'@ @'
                                            <Button x:Name="HighlightButton" Style="{StaticResource RibbonButtonStyle}" Click="HighlightMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE70F;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#F0B93A"/><TextBlock Text="Highlight" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="UnderlineSelectedText_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="U" TextDecorations="Underline" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#49D6FF"/><TextBlock Text="Underline" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="StrikeoutSelectedText_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="S" TextDecorations="Strikethrough" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" Foreground="#EF5C5C"/><TextBlock Text="Strikeout" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="AddNoteAnnotation_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="&#xE8BD;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#FCD116"/><TextBlock Text="Note" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="AnnotationStyle_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="●" FontSize="21" HorizontalAlignment="Center" Foreground="#FCD116"/><TextBlock Text="Style" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button x:Name="CropButton" Style="{StaticResource RibbonButtonStyle}" Click="CropMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE7A8;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#D187FF"/><TextBlock Text="Crop" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
'@ 'native annotation ribbon actions'

# Existing area highlight/rectangle/ellipse workflows now emit proper PDF annotations instead of flattened painted rectangles.
$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
    private void HighlightMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        BeginMarkupMode(MarkupMode.Highlight,
            "Highlight mode: drag a rectangle over the area to highlight.");
    }
'@ @'
    private void HighlightMarkup_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        if (HasDocumentTextSelection)
        {
            HighlightSelectedText_Click(sender, e);
            return;
        }
        BeginMarkupMode(MarkupMode.Highlight,
            "Highlight mode: drag an area to create a native PDF highlight annotation. Select text first for line-accurate markup.");
    }
'@ 'semantic highlight entry'

Replace-Exact $main @'
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddHighlightAsync(working, output, pageNumber, rect, ct), token));
'@ @'
            RunAgainstWorkingLayoutAsync((working, ct) => _nativeAnnotations.AddTextMarkupAsync(
                working, output, pageNumber, [new PdfSearchRect(rect.X, rect.Y, rect.Width, rect.Height)],
                NativeTextMarkupKind.Highlight, _annotationStyle, string.Empty, ct), token));
'@ 'native area highlight'

Replace-Exact $main @'
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddRectangleAsync(working, output, pageNumber, rect, ct), token));
'@ @'
            RunAgainstWorkingLayoutAsync((working, ct) => _nativeAnnotations.AddShapeAsync(
                working, output, pageNumber, rect, ellipse: false, _annotationStyle, ct), token));
'@ 'native rectangle annotation'

Replace-Exact $main @'
            RunAgainstWorkingLayoutAsync((working, ct) => _markup.AddEllipseAsync(working, output, pageNumber, rect, ct), token));
'@ @'
            RunAgainstWorkingLayoutAsync((working, ct) => _nativeAnnotations.AddShapeAsync(
                working, output, pageNumber, rect, ellipse: true, _annotationStyle, ct), token));
'@ 'native ellipse annotation'

Write-Host 'Native PDF annotation system staged.' -ForegroundColor Green
