using System.IO;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfAnnotationItem(
    int Index,
    int SourcePageNumber,
    int Subtype,
    string TypeLabel,
    string Author,
    string Contents,
    string Modified)
{
    public string PageLabel => $"Page {SourcePageNumber:N0}";
    public string DisplayText => string.IsNullOrWhiteSpace(Contents) ? "(No comment text)" : Contents;
    public string MetaText
    {
        get
        {
            var parts = new List<string>();
            if (!string.IsNullOrWhiteSpace(Author)) parts.Add(Author);
            if (!string.IsNullOrWhiteSpace(Modified)) parts.Add(Modified);
            return string.Join("  •  ", parts);
        }
    }
}

public sealed class DocumentAnnotationService
{
    private const int MaxAnnotations = 20_000;
    private const ulong MaxStringBytes = 1024 * 1024;

    public Task<IReadOnlyList<PdfAnnotationItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    private static IReadOnlyList<PdfAnnotationItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var nativeGate = PdfiumNativeGate.Enter(token);
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for annotation navigation.");

        try
        {
            var results = new List<PdfAnnotationItem>();
            var pageCount = Math.Max(0, fpdfview.FPDF_GetPageCount(document));
            for (var pageIndex = 0; pageIndex < pageCount && results.Count < MaxAnnotations; pageIndex++)
            {
                token.ThrowIfCancellationRequested();
                var page = fpdfview.FPDF_LoadPage(document, pageIndex);
                if (page is null) continue;

                try
                {
                    var count = Math.Max(0, fpdf_annot.FPDFPageGetAnnotCount(page));
                    for (var annotationIndex = 0; annotationIndex < count && results.Count < MaxAnnotations; annotationIndex++)
                    {
                        token.ThrowIfCancellationRequested();
                        var annotation = fpdf_annot.FPDFPageGetAnnot(page, annotationIndex);
                        if (annotation is null) continue;

                        try
                        {
                            var subtype = fpdf_annot.FPDFAnnotGetSubtype(annotation);
                            if (!ShouldListSubtype(subtype)) continue;

                            results.Add(new PdfAnnotationItem(
                                annotationIndex,
                                pageIndex + 1,
                                subtype,
                                GetSubtypeLabel(subtype),
                                ReadString(annotation, "T"),
                                ReadString(annotation, "Contents"),
                                ReadString(annotation, "M")));
                        }
                        finally
                        {
                            fpdf_annot.FPDFPageCloseAnnot(annotation);
                        }
                    }
                }
                finally
                {
                    fpdfview.FPDF_ClosePage(page);
                }
            }

            return results;
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static bool ShouldListSubtype(int subtype) => subtype switch
    {
        1 => true,                // Text note
        >= 3 and <= 18 => true,  // FreeText through Sound
        >= 24 and <= 28 => true, // Watermark through Redact
        _ => false
    };

    private static string GetSubtypeLabel(int subtype) => subtype switch
    {
        1 => "Comment",
        3 => "Free text",
        4 => "Line",
        5 => "Square",
        6 => "Circle",
        7 => "Polygon",
        8 => "Polyline",
        9 => "Highlight",
        10 => "Underline",
        11 => "Squiggly",
        12 => "Strikeout",
        13 => "Stamp",
        14 => "Caret",
        15 => "Ink",
        16 => "Popup",
        17 => "File attachment note",
        18 => "Sound",
        24 => "Watermark",
        25 => "3D annotation",
        26 => "Rich media",
        27 => "XFA widget",
        28 => "Redaction mark",
        _ => $"Annotation {subtype}"
    };

    private static string ReadString(FpdfAnnotationT annotation, string key)
    {
        ushort scratch = 0;
        var required = fpdf_annot.FPDFAnnotGetStringValue(annotation, key, ref scratch, 0);
        if (required < 2 || required > MaxStringBytes) return string.Empty;

        var buffer = new ushort[checked((int)((required + 1) / 2))];
        var written = fpdf_annot.FPDFAnnotGetStringValue(annotation, key, ref buffer[0], required);
        if (written < 2) return string.Empty;

        var characters = Math.Min(buffer.Length, checked((int)(written / 2)));
        return new string(buffer.Take(characters).Select(value => (char)value).ToArray()).TrimEnd('\0').Trim();
    }
}