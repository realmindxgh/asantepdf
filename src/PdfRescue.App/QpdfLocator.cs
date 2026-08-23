using System.IO;

namespace PdfRescue.App;

public static class QpdfLocator
{
    public static string Resolve()
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "engines", "qpdf", "qpdf.exe");
        return File.Exists(bundled) ? bundled : "qpdf";
    }

    public static bool IsBundled => File.Exists(Path.Combine(AppContext.BaseDirectory, "engines", "qpdf", "qpdf.exe"));
}
