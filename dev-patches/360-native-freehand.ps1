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
    private static FPDF_FILEWRITE_ CreateFileWriter(Stream stream) => new PdfiumFileWriter(stream);
'@ @'
    private static FPDF_FILEWRITE_ CreateFileWriter(Stream stream) => new PdfiumFileWriter(stream);
'@ 'noop probe placeholder'
