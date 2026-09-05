using System.Diagnostics;
using PdfRescue.Core.Models;
using PdfRescue.Core.Services;

namespace PdfRescue.Infrastructure.Processes;

public sealed class ExternalProcessRunner : IExternalProcessRunner
{
    public async Task<ProcessResult> RunAsync(
        string executable,
        IReadOnlyList<string> arguments,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(executable))
            throw new ArgumentException("Executable path is required.", nameof(executable));

        var startInfo = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        foreach (var argument in arguments)
            startInfo.ArgumentList.Add(argument);

        using var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        var stopwatch = Stopwatch.StartNew();

        try
        {
            if (!process.Start())
                throw new InvalidOperationException($"Could not start {executable}.");
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            throw new FileNotFoundException(
                $"Could not start '{executable}'. Make sure the PDF engine is installed or bundled with AsantePDF.",
                executable,
                ex);
        }

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();

        try
        {
            await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            await ExternalProcessCleanup.TerminateAndDrainAsync(
                process, stdoutTask, stderrTask).ConfigureAwait(false);
            throw;
        }

        var stdout = await stdoutTask.ConfigureAwait(false);
        var stderr = await stderrTask.ConfigureAwait(false);
        stopwatch.Stop();

        return new ProcessResult(process.ExitCode, stdout, stderr, stopwatch.Elapsed);
    }

}
