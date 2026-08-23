using System.Collections.Concurrent;
using System.IO;
using System.Text;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfSearchRect(double X, double Y, double Width, double Height);

public sealed record PdfSearchMatch(
    int SourcePageNumber,
    int MatchIndexOnPage,
    string Snippet,
    IReadOnlyList<PdfSearchRect> Rectangles);

public sealed class DocumentSearchService
{
    private sealed record IndexedPage(string Text, PdfSearchRect?[] Rectangles);
    private sealed record CachedIndex(long Length, long LastWriteTicks, IReadOnlyList<IndexedPage> Pages);

    private readonly ConcurrentDictionary<string, CachedIndex> _cache = new(StringComparer.OrdinalIgnoreCase);

    public async Task<IReadOnlyList<PdfSearchMatch>> SearchAsync(
        string path,
        string query,
        CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(query)) return [];
        var fullPath = Path.GetFullPath(path);
        var index = await GetOrBuildIndexAsync(fullPath, token);
        return await Task.Run(() => FindMatches(index, query.Trim(), token), token);
    }

    public void Invalidate(string path)
    {
        try { _cache.TryRemove(Path.GetFullPath(path), out _); }
        catch { }
    }

    private async Task<CachedIndex> GetOrBuildIndexAsync(string fullPath, CancellationToken token)
    {
        var file = new FileInfo(fullPath);
        if (!file.Exists) throw new FileNotFoundException("PDF file was not found.", fullPath);

        if (_cache.TryGetValue(fullPath, out var cached) &&
            cached.Length == file.Length && cached.LastWriteTicks == file.LastWriteTimeUtc.Ticks)
            return cached;

        var built = await Task.Run(() => BuildIndex(fullPath, file, token), token);
        _cache[fullPath] = built;
        return built;
    }

    private static CachedIndex BuildIndex(string path, FileInfo file, CancellationToken token)
    {
        // Creating the production renderer initializes PDFium through the same
        // guarded runtime path used by the preview engine. No document is opened
        // on this anchor renderer.
        using var runtimeAnchor = PdfRendererFactory.CreateProduction();
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for text search.");

        try
        {
            var pageCount = fpdfview.FPDF_GetPageCount(document);
            if (pageCount < 1)
                return new CachedIndex(file.Length, file.LastWriteTimeUtc.Ticks, []);

            var pages = new List<IndexedPage>(pageCount);
            for (var pageIndex = 0; pageIndex < pageCount; pageIndex++)
            {
                token.ThrowIfCancellationRequested();
                var page = fpdfview.FPDF_LoadPage(document, pageIndex);
                if (page is null)
                {
                    pages.Add(new IndexedPage(string.Empty, []));
                    continue;
                }

                try
                {
                    var pageWidth = fpdfview.FPDF_GetPageWidthF(page);
                    var pageHeight = fpdfview.FPDF_GetPageHeightF(page);
                    var textPage = fpdf_text.FPDFTextLoadPage(page);
                    if (textPage is null)
                    {
                        pages.Add(new IndexedPage(string.Empty, []));
                        continue;
                    }

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

                        pages.Add(new IndexedPage(text.ToString(), rectangles.ToArray()));
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

            return new CachedIndex(file.Length, file.LastWriteTimeUtc.Ticks, pages);
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static IReadOnlyList<PdfSearchMatch> FindMatches(CachedIndex index, string query, CancellationToken token)
    {
        var results = new List<PdfSearchMatch>();
        for (var pageIndex = 0; pageIndex < index.Pages.Count; pageIndex++)
        {
            token.ThrowIfCancellationRequested();
            var page = index.Pages[pageIndex];
            if (page.Text.Length == 0) continue;

            var start = 0;
            var matchNumber = 0;
            while (start <= page.Text.Length - query.Length)
            {
                token.ThrowIfCancellationRequested();
                var found = page.Text.IndexOf(query, start, StringComparison.OrdinalIgnoreCase);
                if (found < 0) break;
                matchNumber++;

                var end = Math.Min(page.Rectangles.Length, found + query.Length);
                var rectangles = MergeRectangles(page.Rectangles.Skip(found).Take(Math.Max(0, end - found)).OfType<PdfSearchRect>());
                results.Add(new PdfSearchMatch(
                    pageIndex + 1,
                    matchNumber,
                    BuildSnippet(page.Text, found, query.Length),
                    rectangles));

                start = Math.Max(found + Math.Max(1, query.Length), found + 1);
            }
        }
        return results;
    }

    private static IReadOnlyList<PdfSearchRect> MergeRectangles(IEnumerable<PdfSearchRect> source)
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

    private static string BuildSnippet(string text, int matchStart, int matchLength)
    {
        var start = Math.Max(0, matchStart - 48);
        var end = Math.Min(text.Length, matchStart + matchLength + 64);
        var raw = text[start..end];
        var normalized = string.Join(' ', raw.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (start > 0) normalized = "…" + normalized;
        if (end < text.Length) normalized += "…";
        return normalized;
    }
}
