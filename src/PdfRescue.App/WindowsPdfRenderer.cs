using System.Windows.Media.Imaging;

namespace PdfRescue.App;

/// <summary>
/// Compatibility shim for older AsantePDF code. Production rendering now uses PDFium.
/// New code should depend on IPdfRenderer and PdfRendererFactory instead.
/// </summary>
[Obsolete("Use IPdfRenderer with PdfRendererFactory.CreateProduction().")]
public sealed class WindowsPdfRenderer : IPdfRenderer
{
    private readonly IPdfRenderer _inner = PdfRendererFactory.CreateProduction();

    public uint PageCount => _inner.PageCount;

    public Task OpenAsync(string path, CancellationToken cancellationToken = default) =>
        _inner.OpenAsync(path, cancellationToken);

    public Task<BitmapSource> RenderAsync(
        int oneBasedPageNumber,
        uint width,
        CancellationToken cancellationToken = default) =>
        _inner.RenderAsync(oneBasedPageNumber, width, cancellationToken);

    public void Dispose() => _inner.Dispose();
}
