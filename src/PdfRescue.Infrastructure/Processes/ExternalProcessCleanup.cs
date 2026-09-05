using System.Diagnostics;

namespace PdfRescue.Infrastructure.Processes;

public static class ExternalProcessCleanup
{
    private const int DefaultTimeoutMilliseconds = 2000;

    public static async Task TerminateAndDrainAsync(
        Process process,
        Task stdoutTask,
        Task stderrTask,
        int timeoutMilliseconds = DefaultTimeoutMilliseconds)
    {
        TryKill(process);

        var completion = Task.WhenAll(
            ObserveAsync(WaitForExitSafelyAsync(process)),
            ObserveAsync(stdoutTask),
            ObserveAsync(stderrTask));

        try
        {
            await Task.WhenAny(
                completion,
                Task.Delay(timeoutMilliseconds)).ConfigureAwait(false);
        }
        catch
        {
            // Cleanup is best-effort and must not replace the original cancellation.
        }
    }

    public static void TerminateAndDrain(
        Process process,
        Task stdoutTask,
        Task stderrTask,
        int timeoutMilliseconds = DefaultTimeoutMilliseconds)
    {
        try
        {
            TerminateAndDrainAsync(
                process,
                stdoutTask,
                stderrTask,
                timeoutMilliseconds).GetAwaiter().GetResult();
        }
        catch
        {
            // Cleanup is best-effort and must not replace the original cancellation.
        }
    }

    private static async Task WaitForExitSafelyAsync(Process process)
    {
        try
        {
            if (!process.HasExited)
                await process.WaitForExitAsync().ConfigureAwait(false);
        }
        catch
        {
            // Process may already be exiting or disposed.
        }
    }

    private static async Task ObserveAsync(Task task)
    {
        try
        {
            await task.ConfigureAwait(false);
        }
        catch
        {
            // Redirected output tasks may fault or cancel during forced shutdown.
        }
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
                process.Kill(entireProcessTree: true);
        }
        catch
        {
            // Cancellation must not be hidden by a kill failure.
        }
    }
}
