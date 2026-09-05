using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Data.Pdf;
using Windows.Storage;
using Windows.Storage.Streams;

namespace PdfRescue.App.Preview;

public sealed class PdfPreviewSession : IDisposable
{
    private readonly PdfDocument _document;
    private bool _disposed;

    private PdfPreviewSession(string sourcePath, PdfDocument document)
    {
        SourcePath = sourcePath;
        _document = document;
    }

    public string SourcePath { get; }
    public uint PageCount => _document.PageCount;

    public static async Task<PdfPreviewSession> OpenAsync(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            throw new FileNotFoundException("PDF file was not found.", path);

        var file = await StorageFile.GetFileFromPathAsync(Path.GetFullPath(path));
        var document = await PdfDocument.LoadFromFileAsync(file);
        return new PdfPreviewSession(Path.GetFullPath(path), document);
    }

    public async Task<BitmapImage> RenderPageAsync(int oneBasedPageNumber, uint targetWidth, CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (oneBasedPageNumber < 1 || oneBasedPageNumber > PageCount)
            throw new ArgumentOutOfRangeException(nameof(oneBasedPageNumber));

        cancellationToken.ThrowIfCancellationRequested();
        using var page = _document.GetPage((uint)(oneBasedPageNumber - 1));
        using var stream = new InMemoryRandomAccessStream();
        var options = new PdfPageRenderOptions
        {
            DestinationWidth = targetWidth == 0 ? 1u : targetWidth,
            IsIgnoringHighContrast = true
        };

        await page.RenderToStreamAsync(stream, options);
        cancellationToken.ThrowIfCancellationRequested();
        stream.Seek(0);

        var bitmap = new BitmapImage();
        await bitmap.SetSourceAsync(stream);
        return bitmap;
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
    }
}
