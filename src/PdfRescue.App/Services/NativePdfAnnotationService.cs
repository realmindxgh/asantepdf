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
}

public readonly record struct NativeInkPoint(double X, double Y);

public sealed class NativePdfAnnotationService
{
    private const int AnnotText = 1;
    private const int AnnotSquare = 5;
    private const int AnnotCircle = 6;
    private const int AnnotHighlight = 9;
    private const int AnnotUnderline = 10;
    private const int AnnotStrikeOut = 12;
    private const int AnnotInk = 15;
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
                if (fpdf_annot.FPDFAnnotGetSubtype(annotation) is AnnotSquare or AnnotCircle or AnnotInk)
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
            using var nativeGate = PdfiumNativeGate.Enter(token);
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
    {
        private readonly Stream _stream;

        public PdfiumFileWriter(Stream stream)
        {
            _stream = stream;
            WriteBlock = Write;
        }

        private int Write(IntPtr pThis, IntPtr data, ulong size)
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