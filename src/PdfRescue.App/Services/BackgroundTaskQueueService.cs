using System.Collections.Concurrent;
using PdfRescue.Core.Jobs;
using PdfRescue.Core.Models;

namespace PdfRescue.App.Services;

public sealed class BackgroundTaskContext
{
    private readonly TaskCenterService _taskCenter;
    private readonly TaskCenterItem _item;

    internal BackgroundTaskContext(TaskCenterService taskCenter, TaskCenterItem item)
    {
        _taskCenter = taskCenter;
        _item = item;
    }

    public void ReportProgress(double progress, string stage) =>
        _taskCenter.ReportProgress(_item, progress, stage);

    public void ReportStage(string stage) =>
        _taskCenter.ReportProgress(_item, _item.Progress, stage);
}

public sealed class BackgroundTaskQueueService : IAsyncDisposable
{
    private readonly PdfJobQueue _queue = new();
    private readonly TaskCenterService _taskCenter;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly ConcurrentDictionary<Guid, CancellationTokenSource> _tokens = new();
    private readonly ConcurrentDictionary<Guid, Task> _executions = new();
    private int _disposed;

    public BackgroundTaskQueueService(TaskCenterService taskCenter)
    {
        _taskCenter = taskCenter ?? throw new ArgumentNullException(nameof(taskCenter));
    }

    public TaskCenterItem Enqueue(
        PdfJobType type,
        string title,
        Func<BackgroundTaskContext, CancellationToken, Task<string?>> operation,
        bool retryable = true)
    {
        ObjectDisposedException.ThrowIf(Volatile.Read(ref _disposed) != 0, this);
        ArgumentNullException.ThrowIfNull(operation);

        var job = new PdfJob(type, title);
        job.TransitionTo(PdfJobState.Queued, "Queued");

        var cts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        _tokens[job.Id] = cts;

        Task RetryAsync()
        {
            if (Volatile.Read(ref _disposed) == 0)
                Enqueue(type, title, operation, retryable: true);
            return Task.CompletedTask;
        }

        var item = _taskCenter.Track(job, cts.Cancel, retryable ? RetryAsync : null);
        var execution = ExecuteAsync(job, item, operation, cts);
        _executions[job.Id] = execution;
        _ = execution.ContinueWith(
            completed =>
            {
                _executions.TryRemove(job.Id, out var removedExecution);
            },
            CancellationToken.None,
            TaskContinuationOptions.ExecuteSynchronously,
            TaskScheduler.Default);
        return item;
    }

    private async Task ExecuteAsync(
        PdfJob job,
        TaskCenterItem item,
        Func<BackgroundTaskContext, CancellationToken, Task<string?>> operation,
        CancellationTokenSource cts)
    {
        try
        {
            var runTask = _queue.RunAsync(job, async (_, token) =>
            {
                _taskCenter.RefreshTracked(item);
                var context = new BackgroundTaskContext(_taskCenter, item);
                return await operation(context, token).ConfigureAwait(false);
            }, cts.Token);

            _taskCenter.RefreshTracked(item);
            var output = await runTask.ConfigureAwait(false);
            if (!string.IsNullOrWhiteSpace(output))
                _taskCenter.SetOutput(item, output);
            _taskCenter.RefreshTracked(item);
        }
        catch (OperationCanceledException)
        {
            _taskCenter.RefreshTracked(item);
        }
        catch (Exception ex)
        {
            App.Log($"Background task failed [{job.Title}]: {ex}");
            _taskCenter.RefreshTracked(item);
        }
        finally
        {
            if (_tokens.TryRemove(job.Id, out var tokenSource))
                tokenSource.Dispose();
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0) return;

        _lifetime.Cancel();
        foreach (var token in _tokens.Values)
        {
            try { token.Cancel(); }
            catch (ObjectDisposedException) { }
        }

        var running = _executions.Values.ToArray();
        if (running.Length > 0)
        {
            try { await Task.WhenAll(running).ConfigureAwait(false); }
            catch { }
        }

        foreach (var token in _tokens.Values) token.Dispose();
        _tokens.Clear();
        _lifetime.Dispose();
        await _queue.DisposeAsync();
    }
}
