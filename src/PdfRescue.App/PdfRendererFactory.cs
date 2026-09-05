namespace PdfRescue.App;

public static class PdfRendererFactory
{
    public static IPdfRenderer CreateProduction() => new PdfiumPdfRenderer();
}
