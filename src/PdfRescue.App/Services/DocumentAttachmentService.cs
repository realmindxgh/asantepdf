using System.IO;
using System.Runtime.InteropServices;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfAttachmentItem(
    int Index,
    string Name,
    string Description,
    string MimeType,
    long SizeBytes)
{
    public string DisplayName => string.IsNullOrWhiteSpace(Name) ? $"Attachment {Index + 1:N0}" : Name;
    public string DetailText
    {
        get
        {
            var details = new List<string>();
            if (SizeBytes >= 0) details.Add(FormatBytes(SizeBytes));
            if (!string.IsNullOrWhiteSpace(MimeType)) details.Add(MimeType);
            return string.Join("  •  ", details);
        }
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes:N0} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024d:N1} KB";
        if (bytes < 1024L * 1024 * 1024) return $"{bytes / (1024d * 1024):N1} MB";
        return $"{bytes / (1024d * 1024 * 1024):N1} GB";
    }
}

public sealed class DocumentAttachmentService
{
    private const int MaxAttachments = 10_000;
    private const ulong MaxStringBytes = 1024 * 1024;
    private const ulong MaxExtractBytes = 512UL * 1024 * 1024;

    public Task<IReadOnlyList<PdfAttachmentItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    public Task<byte[]> ReadFileAsync(string path, int index, CancellationToken token = default)
    {
        if (index < 0) throw new ArgumentOutOfRangeException(nameof(index));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => ReadFile(fullPath, index, token), token);
    }

    private static IReadOnlyList<PdfAttachmentItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var nativeGate = PdfiumNativeGate.Enter(token);
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for attachment navigation.");

        try
        {
            var count = Math.Clamp(fpdf_attachment.FPDFDocGetAttachmentCount(document), 0, MaxAttachments);
            var results = new List<PdfAttachmentItem>(count);
            for (var index = 0; index < count; index++)
            {
                token.ThrowIfCancellationRequested();
                var attachment = fpdf_attachment.FPDFDocGetAttachment(document, index);
                if (attachment is null) continue;

                ulong size = 0;
                var readable = fpdf_attachment.FPDFAttachmentGetFile(attachment, IntPtr.Zero, 0, ref size) != 0;
                var sizeBytes = readable && size <= long.MaxValue ? (long)size : -1;
                results.Add(new PdfAttachmentItem(
                    index,
                    ReadName(attachment),
                    ReadDescription(attachment),
                    ReadSubtype(attachment),
                    sizeBytes));
            }
            return results;
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static byte[] ReadFile(string path, int index, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var nativeGate = PdfiumNativeGate.Enter(token);
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF attachment.");

        try
        {
            var count = fpdf_attachment.FPDFDocGetAttachmentCount(document);
            if (index >= count) throw new ArgumentOutOfRangeException(nameof(index));
            var attachment = fpdf_attachment.FPDFDocGetAttachment(document, index)
                ?? throw new InvalidDataException("The selected PDF attachment could not be opened.");

            ulong required = 0;
            if (fpdf_attachment.FPDFAttachmentGetFile(attachment, IntPtr.Zero, 0, ref required) == 0)
                throw new InvalidDataException("The selected PDF attachment is unreadable.");
            if (required > MaxExtractBytes)
                throw new InvalidDataException("This embedded file is too large to extract safely in one operation.");
            if (required == 0) return [];

            var pointer = Marshal.AllocHGlobal(checked((int)required));
            try
            {
                token.ThrowIfCancellationRequested();
                ulong written = 0;
                if (fpdf_attachment.FPDFAttachmentGetFile(attachment, pointer, required, ref written) == 0 || written > required)
                    throw new InvalidDataException("PDFium could not extract the selected attachment.");

                var bytes = new byte[checked((int)written)];
                Marshal.Copy(pointer, bytes, 0, bytes.Length);
                return bytes;
            }
            finally
            {
                Marshal.FreeHGlobal(pointer);
            }
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static string ReadName(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetName(attachment, ref buffer, length));

    private static string ReadDescription(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetDescription(attachment, ref buffer, length));

    private static string ReadSubtype(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetSubtype(attachment, ref buffer, length));

    private delegate ulong Utf16Reader(ref ushort buffer, ulong length);

    private static string ReadUtf16(Utf16Reader reader)
    {
        ushort scratch = 0;
        var required = reader(ref scratch, 0);
        if (required < 2 || required > MaxStringBytes) return string.Empty;
        var buffer = new ushort[checked((int)((required + 1) / 2))];
        var written = reader(ref buffer[0], required);
        if (written < 2) return string.Empty;
        var characters = Math.Min(buffer.Length, checked((int)(written / 2)));
        return new string(buffer.Take(characters).Select(value => (char)value).ToArray()).TrimEnd('\0').Trim();
    }
}