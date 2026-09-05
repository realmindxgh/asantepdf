using System.IO;
using System.Runtime.InteropServices;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfOutlineItem(
    string Title,
    int? SourcePageNumber,
    IReadOnlyList<PdfOutlineItem> Children,
    bool IsInitiallyExpanded)
{
    public string PageLabel => SourcePageNumber is int page ? $"Page {page:N0}" : string.Empty;
}

public sealed class DocumentOutlineService
{
    private const int MaxOutlineDepth = 64;
    private const int MaxOutlineNodes = 10_000;
    private const ulong MaxTitleBytes = 1024 * 1024;

    public Task<IReadOnlyList<PdfOutlineItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    private static IReadOnlyList<PdfOutlineItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);

        using var nativeGate = PdfiumNativeGate.Enter(token);
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for outline navigation.");

        try
        {
            var first = fpdf_doc.FPDFBookmarkGetFirstChild(document, null);
            if (first is null) return [];

            var visited = new HashSet<IntPtr>();
            var total = 0;
            return ReadSiblings(document, first, visited, ref total, 0, token);
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static IReadOnlyList<PdfOutlineItem> ReadSiblings(
        FpdfDocumentT document,
        FpdfBookmarkT first,
        HashSet<IntPtr> visited,
        ref int total,
        int depth,
        CancellationToken token)
    {
        var items = new List<PdfOutlineItem>();
        if (depth > MaxOutlineDepth) return items;

        var current = first;
        while (current is not null && total < MaxOutlineNodes)
        {
            token.ThrowIfCancellationRequested();

            var handle = current.__Instance;
            if (handle == IntPtr.Zero || !visited.Add(handle)) break;
            total++;

            var title = ReadTitle(current);
            var sourcePage = ResolveSourcePageNumber(document, current);
            IReadOnlyList<PdfOutlineItem> children = [];

            if (depth < MaxOutlineDepth)
            {
                var child = fpdf_doc.FPDFBookmarkGetFirstChild(document, current);
                if (child is not null)
                    children = ReadSiblings(document, child, visited, ref total, depth + 1, token);
            }

            items.Add(new PdfOutlineItem(
                title,
                sourcePage,
                children,
                children.Count > 0));

            current = fpdf_doc.FPDFBookmarkGetNextSibling(document, current);
        }

        return items;
    }

    private static string ReadTitle(FpdfBookmarkT bookmark)
    {
        var required = fpdf_doc.FPDFBookmarkGetTitle(bookmark, IntPtr.Zero, 0);
        if (required < 2 || required > MaxTitleBytes) return "Untitled bookmark";

        var buffer = Marshal.AllocHGlobal(checked((int)required));
        try
        {
            var written = fpdf_doc.FPDFBookmarkGetTitle(bookmark, buffer, required);
            if (written == 0) return "Untitled bookmark";
            var title = (Marshal.PtrToStringUni(buffer) ?? string.Empty).TrimEnd('\0').Trim();
            return string.IsNullOrWhiteSpace(title) ? "Untitled bookmark" : title;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static int? ResolveSourcePageNumber(FpdfDocumentT document, FpdfBookmarkT bookmark)
    {
        var destination = fpdf_doc.FPDFBookmarkGetDest(document, bookmark);
        if (destination is null)
        {
            var action = fpdf_doc.FPDFBookmarkGetAction(bookmark);
            if (action is not null)
                destination = fpdf_doc.FPDFActionGetDest(document, action);
        }

        if (destination is null) return null;
        var pageIndex = fpdf_doc.FPDFDestGetDestPageIndex(document, destination);
        return pageIndex >= 0 ? pageIndex + 1 : null;
    }
}