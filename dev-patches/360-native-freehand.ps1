param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false)) }
function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=Normalize([IO.File]::ReadAllText($Path)); $o=Normalize $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; Write-Text $Path ($t.Replace($o,(Normalize $New))) }

$service = Join-Path $SourceRoot 'src\PdfRescue.App\Services\NativePdfAnnotationService.cs'
Replace-Exact $service @'
public sealed record NativeAnnotationStyle(byte Red, byte Green, byte Blue, byte Alpha, double BorderWidth = 1.5)
{
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
}

public sealed class NativePdfAnnotationService
'@ @'
public sealed record NativeAnnotationStyle(byte Red, byte Green, byte Blue, byte Alpha, double BorderWidth = 1.5)
{
    public static NativeAnnotationStyle Yellow { get; } = new(252, 209, 22, 120, 1.5);
}

public readonly record struct NativeInkPoint(double X, double Y);

public sealed class NativePdfAnnotationService
'@ 'native ink point model'

Replace-Exact $service @'
    private const int AnnotStrikeOut = 12;
    private const int ColorTypeStroke = 0;
'@ @'
    private const int AnnotStrikeOut = 12;
    private const int AnnotInk = 15;
    private const int ColorTypeStroke = 0;
'@ 'ink subtype constant'

Replace-Exact $service @'
    public Task UpdateAsync(
        string inputPath,
'@ @'
    public Task AddInkAsync(
        string inputPath,
        string outputPath,
        int pageNumber,
        IReadOnlyList<NativeInkPoint> points,
        NativeAnnotationStyle style,
        CancellationToken token = default) =>
        MutateAsync(inputPath, outputPath, pageNumber, (page, width, height) =>
        {
            var usable = points
                .Where(point => double.IsFinite(point.X) && double.IsFinite(point.Y))
                .Select(point => new NativeInkPoint(Math.Clamp(point.X, 0, 1), Math.Clamp(point.Y, 0, 1)))
                .ToArray();
            if (usable.Length < 2) throw new InvalidOperationException("Draw a freehand stroke before creating an ink annotation.");

            var annotation = CreateAnnotation(page, AnnotInk);
            try
            {
                var native = usable.Select(point => new NativeFsPointF
                {
                    X = (float)(point.X * width),
                    Y = (float)((1 - point.Y) * height)
                }).ToArray();
                var pad = (float)Math.Max(2, style.BorderWidth * 2.5);
                var rect = new FS_RECTF_
                {
                    Left = Math.Max(0, native.Min(point => point.X) - pad),
                    Right = Math.Min(width, native.Max(point => point.X) + pad),
                    Bottom = Math.Max(0, native.Min(point => point.Y) - pad),
                    Top = Math.Min(height, native.Max(point => point.Y) + pad)
                };
                if (fpdf_annot.FPDFAnnotSetRect(annotation, rect) == 0)
                    throw new InvalidDataException("PDFium could not set the ink annotation bounds.");

                SetStrokeColor(annotation, style);
                fpdf_annot.FPDFAnnotSetBorder(annotation, 0, 0, (float)Math.Max(0.75, style.BorderWidth));
                if (FPDFAnnotAddInkStroke(annotation.__Instance, native, (UIntPtr)(uint)native.Length) < 0)
                    throw new InvalidDataException("PDFium could not add the freehand ink stroke.");
                SetString(annotation, "T", "AsantePDF");
            }
            finally { fpdf_annot.FPDFPageCloseAnnot(annotation); }
        }, token);

    public Task UpdateAsync(
        string inputPath,
'@ 'native ink mutation'

Replace-Exact $service @'
                if (fpdf_annot.FPDFAnnotGetSubtype(annotation) is AnnotSquare or AnnotCircle)
                {
                    fpdf_annot.FPDFAnnotSetBorder(annotation, 0, 0, (float)Math.Max(0.5, style.BorderWidth));
                }
'@ @'
                if (fpdf_annot.FPDFAnnotGetSubtype(annotation) is AnnotSquare or AnnotCircle or AnnotInk)
                {
                    fpdf_annot.FPDFAnnotSetBorder(annotation, 0, 0, (float)Math.Max(0.5, style.BorderWidth));
                }
'@ 'ink style editing'

Replace-Exact $service @'
    private sealed class PdfiumFileWriter : FPDF_FILEWRITE_
'@ @'
    [StructLayout(LayoutKind.Sequential)]
    private struct NativeFsPointF
    {
        public float X;
        public float Y;
    }

    // PDFiumCore 153 ships pdfium.dll on Windows. This API is public in the
    // matching PDFium generation but is not exposed by every generated binding surface.
    // AsantePDF is x64-only, where the native calling convention is unified.
    [DllImport("pdfium.dll", EntryPoint = "FPDFAnnot_AddInkStroke", CallingConvention = CallingConvention.Cdecl)]
    private static extern int FPDFAnnotAddInkStroke(
        IntPtr annotation,
        [In] NativeFsPointF[] points,
        UIntPtr pointCount);

    private sealed class PdfiumFileWriter : FPDF_FILEWRITE_
'@ 'ink native API binding'

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="AnnotationStyle_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="●" FontSize="21" HorizontalAlignment="Center" Foreground="#FCD116"/><TextBlock Text="Style" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button x:Name="CropButton" Style="{StaticResource RibbonButtonStyle}" Click="CropMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE7A8;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#D187FF"/><TextBlock Text="Crop" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
'@ @'
                                            <Button Style="{StaticResource RibbonButtonStyle}" Click="AnnotationStyle_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}"><StackPanel><TextBlock Text="●" FontSize="21" HorizontalAlignment="Center" Foreground="#FCD116"/><TextBlock Text="Style" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button x:Name="FreehandButton" Style="{StaticResource RibbonButtonStyle}" Click="FreehandMarkup_Click" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" ToolTip="Draw a native PDF ink annotation"><StackPanel><TextBlock Text="&#xE70F;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#38C986"/><TextBlock Text="Draw" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
                                            <Button x:Name="CropButton" Style="{StaticResource RibbonButtonStyle}" Click="CropMarkup_Click" IsEnabled="False"><StackPanel><TextBlock Text="&#xE7A8;" FontFamily="Segoe MDL2 Assets" FontSize="21" HorizontalAlignment="Center" Foreground="#D187FF"/><TextBlock Text="Crop" FontSize="12" Margin="0,5,0,0"/></StackPanel></Button>
'@ 'freehand ribbon command'

Replace-Exact $xaml @'
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
                                                MouseLeftButtonDown="MarkupCanvas_MouseLeftButtonDown" MouseMove="MarkupCanvas_MouseMove" MouseLeftButtonUp="MarkupCanvas_MouseLeftButtonUp">
                                            <Rectangle x:Name="MarkupSelectionRectangle" Visibility="Collapsed" Stroke="#2D7DFF" StrokeThickness="2" StrokeDashArray="4,3" Fill="#332D7DFF" />
                                        </Canvas>
'@ @'
                                        <Canvas x:Name="MarkupCanvas" Background="Transparent" Visibility="Collapsed" Cursor="Cross"
                                                MouseLeftButtonDown="MarkupCanvas_MouseLeftButtonDown" MouseMove="MarkupCanvas_MouseMove" MouseLeftButtonUp="MarkupCanvas_MouseLeftButtonUp">
                                            <Rectangle x:Name="MarkupSelectionRectangle" Visibility="Collapsed" Stroke="#2D7DFF" StrokeThickness="2" StrokeDashArray="4,3" Fill="#332D7DFF" />
                                            <Polyline x:Name="FreehandPreviewPolyline" Visibility="Collapsed" Stroke="#38C986" StrokeThickness="3" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" IsHitTestVisible="False" />
                                        </Canvas>
'@ 'freehand preview overlay'

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
        Rectangle,
        Ellipse,
        Crop,
'@ @'
        Rectangle,
        Ellipse,
        Freehand,
        Crop,
'@ 'freehand markup mode'

Replace-Exact $main @'
    private void BeginMarkupMode(MarkupMode mode, string instruction)
    {
        if (_busy || _currentPdf is null || PreviewImage.Source is null) return;
'@ @'
    private void BeginMarkupMode(MarkupMode mode, string instruction)
    {
        if (_busy || _currentPdf is null || PreviewImage.Source is null) return;
        if (!IsSinglePageViewActive)
        {
            StatusText.Text = "Switch to Single Page view before using canvas editing or freehand annotations.";
            return;
        }
'@ 'canvas editing requires single page'

Replace-Exact $main @'
        MarkupSelectionRectangle.Visibility = Visibility.Collapsed;
        MarkupCanvas.Visibility = Visibility.Collapsed;
        UpdateDocumentTextSelectionInteractionState();
'@ @'
        MarkupSelectionRectangle.Visibility = Visibility.Collapsed;
        ResetFreehandPreview();
        MarkupCanvas.Visibility = Visibility.Collapsed;
        UpdateDocumentTextSelectionInteractionState();
'@ 'freehand cleanup'

Replace-Exact $main @'
        _markupStartPoint = point;
        _markupDragging = true;
        MarkupCanvas.CaptureMouse();
'@ @'
        if (_markupMode == MarkupMode.Freehand)
        {
            BeginFreehandStroke(point);
            e.Handled = true;
            return;
        }

        _markupStartPoint = point;
        _markupDragging = true;
        MarkupCanvas.CaptureMouse();
'@ 'freehand mouse down'

Replace-Exact $main @'
    private void MarkupCanvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        UpdateMarkupSelection(ClampMarkupPoint(e.GetPosition(MarkupCanvas)));
    }
'@ @'
    private void MarkupCanvas_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        var point = ClampMarkupPoint(e.GetPosition(MarkupCanvas));
        if (_markupMode == MarkupMode.Freehand)
        {
            ContinueFreehandStroke(point);
            return;
        }
        UpdateMarkupSelection(point);
    }
'@ 'freehand mouse move'

Replace-Exact $main @'
    private async void MarkupCanvas_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        var current = ClampMarkupPoint(e.GetPosition(MarkupCanvas));
        UpdateMarkupSelection(current);
        _markupDragging = false;
        try { MarkupCanvas.ReleaseMouseCapture(); } catch { }

        var page = PagesList.SelectedItem as PdfPageItem;
'@ @'
    private async void MarkupCanvas_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_markupDragging || _markupMode is MarkupMode.None or MarkupMode.AddText) return;
        var current = ClampMarkupPoint(e.GetPosition(MarkupCanvas));
        if (_markupMode == MarkupMode.Freehand)
        {
            ContinueFreehandStroke(current, force: true);
            _markupDragging = false;
            try { MarkupCanvas.ReleaseMouseCapture(); } catch { }
            var inkPage = PagesList.SelectedItem as PdfPageItem;
            var points = GetNormalizedFreehandPoints();
            EndMarkupMode();
            if (inkPage is null || points.Count < 2)
                StatusText.Text = "The freehand stroke was too short. No change was made.";
            else
                await ApplyFreehandAnnotationAsync(inkPage.Position, points);
            e.Handled = true;
            return;
        }

        UpdateMarkupSelection(current);
        _markupDragging = false;
        try { MarkupCanvas.ReleaseMouseCapture(); } catch { }

        var page = PagesList.SelectedItem as PdfPageItem;
'@ 'freehand mouse up'

$nativeUi = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NativeAnnotations.cs'
Replace-Exact $nativeUi @'
using System.IO;
using System.Windows;
using PdfRescue.App.Services;
'@ @'
using System.IO;
using System.Windows;
using System.Windows.Media;
using PdfRescue.App.Services;
'@ 'freehand WPF imports'

Replace-Exact $nativeUi @'
    private PdfAnnotationItem? _selectedPdfAnnotation;

    private IReadOnlyList<PdfSearchRect> SelectedTextAnnotationRects()
'@ @'
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
'@ 'freehand interaction implementation'

Write-Host 'Native PDF freehand ink annotations staged.' -ForegroundColor Green
