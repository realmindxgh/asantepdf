using System.Collections.Concurrent;
using PdfRescue.Core.Models;

namespace PdfRescue.Core.Jobs;

public sealed class PdfJobQueue : IAsyncDisposable
{
    private readonly SemaphoreSlim _singleWorker = new(1, 1);
    private readonly ConcurrentDictionary<Guid, PdfJob> _jobs = new();
    private bool _disposed;

    public IReadOnlyCollection<PdfJob> Jobs => _jobs.Values.OrderByDescending(j => j.CreatedAt).ToArray();

    public async Task<T> RunAsync<T>(
        PdfJob job,
        Func<PdfJob, CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentNullException.ThrowIfNull(job);
        ArgumentNullException.ThrowIfNull(operation);

        if (!_jobs.TryAdd(job.Id, job))
            throw new InvalidOperationException($"Job {job.Id} is already queued.");

        job.TransitionTo(PdfJobState.Queued, "Waiting");

        try
        {
            await _singleWorker.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            job.TransitionTo(PdfJobState.Cancelled, "Cancelled");
            throw;
        }

        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            job.TransitionTo(PdfJobState.Running, "Starting");
            var result = await operation(job, cancellationToken).ConfigureAwait(false);
            job.TransitionTo(PdfJobState.Completed, "Completed");
            return result;
        }
        catch (OperationCanceledException)
        {
            if (job.State is not PdfJobState.Cancelled)
                job.TransitionTo(PdfJobState.Cancelled, "Cancelled");
            throw;
        }
        catch (Exception ex)
        {
            job.TransitionTo(PdfJobState.Failed, "Failed", ex.Message);
            throw;
        }
        finally
        {
            _singleWorker.Release();
        }
    }

    public ValueTask DisposeAsync()
    {
        if (_disposed)
            return ValueTask.CompletedTask;

        _disposed = true;
        _singleWorker.Dispose();
        return ValueTask.CompletedTask;
    }
}
