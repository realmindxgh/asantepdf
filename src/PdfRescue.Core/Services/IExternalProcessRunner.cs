using PdfRescue.Core.Models;

namespace PdfRescue.Core.Services;

public interface IExternalProcessRunner
{
    Task<ProcessResult> RunAsync(
        string executable,
        IReadOnlyList<string> arguments,
        CancellationToken cancellationToken = default);
}
