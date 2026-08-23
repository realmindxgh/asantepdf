using PdfRescue.Core.Models;

namespace PdfRescue.Core.Services;

public interface IPdfInspector
{
    Task<PdfInspectionResult> InspectAsync(string path, CancellationToken cancellationToken = default);
}
