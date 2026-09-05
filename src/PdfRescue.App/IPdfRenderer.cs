using System.Windows.Media.Imaging;

namespace PdfRescue.App;

public interface IPdfRenderer : IDisposable
{
    uint PageCount { get; }

    Task OpenAsync(string path, CancellationToken cancellationToken = default);

    Task<BitmapSource> RenderAsync(
        int oneBasedPageNumber,
        uint width,
        CancellationToken cancellationToken = default);
}
