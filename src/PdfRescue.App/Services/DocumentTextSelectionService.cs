using System.Collections.Concurrent;
using System.IO;
using System.Text;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfSelectableTextPage(
    string Text,
    IReadOnlyList<PdfSearchRect?> CharacterRectangles);

public sealed class DocumentTextSelectionService
{
    private sealed record CachedPage(long Length, long LastWriteTicks, PdfSelectableTextPage Page);

    private readonly ConcurrentDictionary<string, CachedPage> _cache = new(StringComparer.OrdinalIgnoreCase);

    public async Task<PdfSelectableTextPage> GetPageAsync(
        string path,
        int sourcePageNumber,
        CancellationToken token = default)
    {
        if (sourcePageNumber < 1) throw new ArgumentOutOfRangeException(nameof(sourcePageNumber));
        var fullPath = Path.GetFullPath(path);
        var file = new FileInfo(fullPath);
        if (!file.Exists) throw new FileNotFoundException("PDF file was not found.", fullPath);

        var key = BuildCacheKey(fullPath, sourcePageNumber);
        if (_cache.TryGetValue(key, out var cached) &&
            cached.Length == file.Length && cached.LastWriteTicks == file.LastWriteTimeUtc.Ticks)
            return cached.Page;

        var page = await Task.Run(() => ReadPage(fullPath, sourcePageNumber, token), token);
        _cache[key] = new CachedPage(file.Length, file.LastWriteTimeUtc.Ticks, page);
        return page;
    }

    public void Invalidate(string path)
    {
        string prefix;
        try { prefix = Path.GetFullPath(path) + "\u001f"; }
        catch { return; }

        foreach (var key in _cache.Keys.Where(key => key.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
            _cache.TryRemove(key, out _);
    }

    private static string BuildCacheKey(string path, int sourcePageNumber) =>
        path + "\u001f" + sourcePageNumber.ToString(System.Globalization.CultureInfo.InvariantCulture);

    private static PdfSelectableTextPage ReadPage(string path, int sourcePageNumber, CancellationToken token)
    {
        using var nativeGate = PdfiumNativeGate.Enter(token);
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for text selection.");

        try
        {
            var pageCount = fpdfview.FPDF_GetPageCount(document);
            if (sourcePageNumber > pageCount)
                throw new ArgumentOutOfRangeException(nameof(sourcePageNumber));

            var page = fpdfview.FPDF_LoadPage(document, sourcePageNumber - 1);
            if (page is null) return new PdfSelectableTextPage(string.Empty, []);

            try
            {
                var pageWidth = fpdfview.FPDF_GetPageWidthF(page);
                var pageHeight = fpdfview.FPDF_GetPageHeightF(page);
                var textPage = fpdf_text.FPDFTextLoadPage(page);
                if (textPage is null) return new PdfSelectableTextPage(string.Empty, []);

                try
                {
                    var count = Math.Max(0, fpdf_text.FPDFTextCountChars(textPage));
                    var text = new StringBuilder(count);
                    var rectangles = new List<PdfSearchRect?>(count);

                    for (var characterIndex = 0; characterIndex < count; characterIndex++)
                    {
                        token.ThrowIfCancellationRequested();
                        var unicode = fpdf_text.FPDFTextGetUnicode(textPage, characterIndex);
                        if (unicode == 0 || unicode > 0x10FFFF) continue;

                        string value;
                        try { value = char.ConvertFromUtf32((int)unicode); }
                        catch { continue; }

                        PdfSearchRect? rect = null;
                        if (pageWidth > 0 && pageHeight > 0)
                        {
                            double left = 0, right = 0, bottom = 0, top = 0;
                            if (fpdf_text.FPDFTextGetCharBox(textPage, characterIndex, ref left, ref right, ref bottom, ref top) != 0 &&
                                right > left && top > bottom)
                            {
                                rect = new PdfSearchRect(
                                    Math.Clamp(left / pageWidth, 0, 1),
                                    Math.Clamp((pageHeight - top) / pageHeight, 0, 1),
                                    Math.Clamp((right - left) / pageWidth, 0, 1),
                                    Math.Clamp((top - bottom) / pageHeight, 0, 1));
                            }
                        }

                        foreach (var character in value)
                        {
                            text.Append(character);
                            rectangles.Add(rect);
                        }
                    }

                    return new PdfSelectableTextPage(text.ToString(), rectangles.ToArray());
                }
                finally
                {
                    fpdf_text.FPDFTextClosePage(textPage);
                }
            }
            finally
            {
                fpdfview.FPDF_ClosePage(page);
            }
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }
}