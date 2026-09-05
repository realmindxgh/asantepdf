using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace PdfRescue.App.Services;

internal sealed class PdfPrintService
{
    public async Task<FixedDocument> BuildAsync(
        string pdfPath,
        IReadOnlyList<int> pages,
        double printableWidth,
        double printableHeight,
        bool landscape,
        bool fitToPrintableArea,
        CancellationToken token)
    {
        using var renderer = PdfRendererFactory.CreateProduction();
        await renderer.OpenAsync(pdfPath, token);

        var document = new FixedDocument();
        var pageWidth = landscape ? Math.Max(printableWidth, printableHeight) : Math.Min(printableWidth, printableHeight);
        var pageHeight = landscape ? Math.Min(printableWidth, printableHeight) : Math.Max(printableWidth, printableHeight);
        pageWidth = Math.Max(100, pageWidth);
        pageHeight = Math.Max(100, pageHeight);
        document.DocumentPaginator.PageSize = new Size(pageWidth, pageHeight);

        foreach (var pageNumber in pages)
        {
            token.ThrowIfCancellationRequested();
            if (pageNumber < 1 || pageNumber > renderer.PageCount) continue;
            var targetRenderWidth = fitToPrintableArea ? Math.Clamp((uint)Math.Round(pageWidth * 2.2), 900u, 2600u) : 1100u;
            var bitmap = await renderer.RenderAsync(pageNumber, targetRenderWidth, token);
            token.ThrowIfCancellationRequested();

            var availableWidth = Math.Max(1, pageWidth - 28);
            var availableHeight = Math.Max(1, pageHeight - 28);
            var scale = fitToPrintableArea
                ? Math.Min(availableWidth / bitmap.PixelWidth, availableHeight / bitmap.PixelHeight)
                : Math.Min(1d, Math.Min(availableWidth / bitmap.PixelWidth, availableHeight / bitmap.PixelHeight));
            var imageWidth = Math.Max(1, bitmap.PixelWidth * scale);
            var imageHeight = Math.Max(1, bitmap.PixelHeight * scale);

            var image = new Image { Source = bitmap, Width = imageWidth, Height = imageHeight, Stretch = Stretch.Uniform };
            var canvas = new Canvas { Width = pageWidth, Height = pageHeight, Background = Brushes.White };
            Canvas.SetLeft(image, (pageWidth - imageWidth) / 2);
            Canvas.SetTop(image, (pageHeight - imageHeight) / 2);
            canvas.Children.Add(image);

            var fixedPage = new FixedPage { Width = pageWidth, Height = pageHeight, Background = Brushes.White };
            fixedPage.Children.Add(canvas);
            var pageContent = new PageContent();
            ((System.Windows.Markup.IAddChild)pageContent).AddChild(fixedPage);
            document.Pages.Add(pageContent);
        }

        return document;
    }
}