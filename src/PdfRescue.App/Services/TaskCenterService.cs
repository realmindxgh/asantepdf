using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Windows;
using PdfRescue.Core.Jobs;
using PdfRescue.Core.Models;

namespace PdfRescue.App.Services;

public sealed class TaskCenterItem : INotifyPropertyChanged
{
    private readonly PdfJob _job;
    private readonly Action? _cancelAction;
    private readonly Func<Task>? _retryAction;
    private bool _retryRequested;
    private string? _outputPath;
    private readonly string? _sourcePath;
    private readonly string _sourceLabel;
    private readonly Func<Task>? _runAgainAction;

    internal TaskCenterItem(
        PdfJob job,
        Action? cancelAction,
        Func<Task>? retryAction = null,
        string? sourcePath = null,
        string? sourceLabel = null,
        Func<Task>? runAgainAction = null)
    {
        _job = job;
        _cancelAction = cancelAction;
        _retryAction = retryAction;
        _sourcePath = string.IsNullOrWhiteSpace(sourcePath) ? null : Path.GetFullPath(sourcePath);
        _sourceLabel = !string.IsNullOrWhiteSpace(sourceLabel)
            ? sourceLabel.Trim()
            : _sourcePath is null ? "Source" : Path.GetFileName(_sourcePath);
        _runAgainAction = runAgainAction;
    }

    public Guid Id => _job.Id;
    public PdfJobType Type => _job.Type;
    public string Title => _job.Title;
    public PdfJobState State => _job.State;
    public string StateLabel => State.ToString();
    public string Stage => string.IsNullOrWhiteSpace(_job.StatusText) ? StateLabel : _job.StatusText!;
    public string? ErrorMessage => _job.ErrorMessage;
    public double Progress => _job.Progress;
    public int ProgressPercent => (int)Math.Round(Progress * 100d);
    public bool IsFinished => State is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled;
    public bool CanCancel => State is PdfJobState.Queued or PdfJobState.Running or PdfJobState.Paused;
    public bool CanRetry => !_retryRequested && _retryAction is not null && State is PdfJobState.Failed or PdfJobState.Cancelled;
    public bool ShowProgress => State is PdfJobState.Queued or PdfJobState.Running or PdfJobState.Paused;

    // A zero value is not treated as a made-up percentage. Until an operation reports
    // measurable progress, the UI presents a real indeterminate state plus stage text.
    public bool IsIndeterminate => ShowProgress && Progress <= 0d;
    public string ProgressLabel => !ShowProgress
        ? StateLabel
        : IsIndeterminate ? "Working…" : $"{ProgressPercent}%";

    public string? OutputPath => _outputPath;
    public string OutputName => string.IsNullOrWhiteSpace(_outputPath) ? string.Empty : Path.GetFileName(_outputPath);
    public string? SourcePath => _sourcePath;
    public string SourceLabel => _sourceLabel;
    public bool CanOpenOutput => State == PdfJobState.Completed && !string.IsNullOrWhiteSpace(_outputPath) && File.Exists(_outputPath);
    public bool CanShowOutputFolder => State == PdfJobState.Completed && !string.IsNullOrWhiteSpace(_outputPath) &&
                                       Directory.Exists(Path.GetDirectoryName(_outputPath));
    public bool CanShowErrorDetails => State == PdfJobState.Failed && !string.IsNullOrWhiteSpace(ErrorMessage);
    public bool CanRunAgain => State == PdfJobState.Completed && _runAgainAction is not null;
    public DateTimeOffset CreatedAt => _job.CreatedAt;
    public DateTimeOffset? StartedAt => _job.StartedAt;
    public DateTimeOffset? FinishedAt => _job.FinishedAt;
    public string ElapsedLabel
    {
        get
        {
            var start = StartedAt ?? CreatedAt;
            var end = FinishedAt ?? DateTimeOffset.UtcNow;
            var elapsed = end - start;
            return elapsed.TotalHours >= 1
                ? $"{(int)elapsed.TotalHours}:{elapsed.Minutes:00}:{elapsed.Seconds:00}"
                : $"{elapsed.Minutes:00}:{elapsed.Seconds:00}";
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public void RequestCancel()
    {
        if (!CanCancel) return;
        _cancelAction?.Invoke();
    }

    public async Task RequestRetryAsync()
    {
        if (!CanRetry || _retryAction is null) return;
        _retryRequested = true;
        OnPropertyChanged(nameof(CanRetry));
        try
        {
            await _retryAction();
        }
        catch
        {
            _retryRequested = false;
            OnPropertyChanged(nameof(CanRetry));
            throw;
        }
    }

    public Task RequestRunAgainAsync() =>
        CanRunAgain && _runAgainAction is not null ? _runAgainAction() : Task.CompletedTask;

    internal void SetOutput(string? path)
    {
        _outputPath = string.IsNullOrWhiteSpace(path) ? null : Path.GetFullPath(path);
        OnPropertyChanged(nameof(OutputPath));
        OnPropertyChanged(nameof(OutputName));
        OnPropertyChanged(nameof(CanOpenOutput));
        OnPropertyChanged(nameof(CanShowOutputFolder));
    }

    internal void Refresh()
    {
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(StateLabel));
        OnPropertyChanged(nameof(Stage));
        OnPropertyChanged(nameof(ErrorMessage));
        OnPropertyChanged(nameof(Progress));
        OnPropertyChanged(nameof(ProgressPercent));
        OnPropertyChanged(nameof(ProgressLabel));
        OnPropertyChanged(nameof(IsIndeterminate));
        OnPropertyChanged(nameof(IsFinished));
        OnPropertyChanged(nameof(CanCancel));
        OnPropertyChanged(nameof(CanRetry));
        OnPropertyChanged(nameof(ShowProgress));
        OnPropertyChanged(nameof(CanOpenOutput));
        OnPropertyChanged(nameof(CanShowOutputFolder));
        OnPropertyChanged(nameof(CanShowErrorDetails));
        OnPropertyChanged(nameof(CanRunAgain));
        OnPropertyChanged(nameof(StartedAt));
        OnPropertyChanged(nameof(FinishedAt));
        OnPropertyChanged(nameof(ElapsedLabel));
    }

    internal void RefreshElapsed() => OnPropertyChanged(nameof(ElapsedLabel));

    internal PdfJob Job => _job;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}

public sealed class TaskCenterService
{
    public ObservableCollection<TaskCenterItem> Items { get; } = [];
    public event EventHandler? Changed;

    public TaskCenterItem Track(
        PdfJob job,
        Action? cancelAction = null,
        Func<Task>? retryAction = null,
        string? sourcePath = null,
        string? sourceLabel = null,
        Func<Task>? runAgainAction = null)
    {
        ArgumentNullException.ThrowIfNull(job);
        TaskCenterItem? created = null;
        RunOnUi(() =>
        {
            created = new TaskCenterItem(job, cancelAction, retryAction, sourcePath, sourceLabel, runAgainAction);
            Items.Insert(0, created);
            created.Refresh();
            Changed?.Invoke(this, EventArgs.Empty);
        });
        return created!;
    }

    public TaskCenterItem Start(string status, Action? cancelAction = null)
    {
        var title = CleanTitle(status);
        var job = new PdfJob(InferType(status), title);
        job.TransitionTo(PdfJobState.Queued, "Queued");
        job.TransitionTo(PdfJobState.Running, string.IsNullOrWhiteSpace(status) ? "Starting" : status.Trim());
        return Track(job, cancelAction);
    }

    public void RefreshTracked(TaskCenterItem? item)
    {
        if (item is null) return;
        RunOnUi(() =>
        {
            item.Refresh();
            Changed?.Invoke(this, EventArgs.Empty);
        });
    }

    public void ReportProgress(TaskCenterItem? item, double progress, string stage)
    {
        if (item is null || item.Job.State is not (PdfJobState.Running or PdfJobState.Paused)) return;
        item.Job.ReportProgress(progress, stage);
        RefreshTracked(item);
    }

    public void SetOutput(TaskCenterItem? item, string? outputPath)
    {
        if (item is null || string.IsNullOrWhiteSpace(outputPath)) return;
        RunOnUi(() =>
        {
            item.SetOutput(outputPath);
            Changed?.Invoke(this, EventArgs.Empty);
        });
    }

    public void Complete(TaskCenterItem? item, string stage = "Completed")
    {
        if (item is null || item.Job.State is not (PdfJobState.Running or PdfJobState.Paused)) return;
        item.Job.TransitionTo(PdfJobState.Completed, stage);
        RefreshTracked(item);
    }

    public void Cancel(TaskCenterItem? item, string stage = "Cancelled")
    {
        if (item is null || item.Job.State is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled) return;
        item.Job.TransitionTo(PdfJobState.Cancelled, stage);
        RefreshTracked(item);
    }

    public void Fail(TaskCenterItem? item, Exception error)
    {
        if (item is null || item.Job.State is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled) return;
        item.Job.TransitionTo(PdfJobState.Failed, "Failed", error.Message);
        RefreshTracked(item);
    }

    public void ClearFinished()
    {
        RunOnUi(() =>
        {
            for (var i = Items.Count - 1; i >= 0; i--)
                if (Items[i].IsFinished) Items.RemoveAt(i);
            Changed?.Invoke(this, EventArgs.Empty);
        });
    }

    public void RefreshElapsed()
    {
        RunOnUi(() =>
        {
            foreach (var item in Items.Where(item => !item.IsFinished)) item.RefreshElapsed();
        });
    }

    public (int Running, int Queued, int Completed, int Failed, int Cancelled) GetCounts() =>
        (
            Items.Count(item => item.State is PdfJobState.Running or PdfJobState.Paused),
            Items.Count(item => item.State == PdfJobState.Queued),
            Items.Count(item => item.State == PdfJobState.Completed),
            Items.Count(item => item.State == PdfJobState.Failed),
            Items.Count(item => item.State == PdfJobState.Cancelled)
        );

    private static void RunOnUi(Action action)
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is not null && !dispatcher.CheckAccess())
            dispatcher.Invoke(action);
        else
            action();
    }

    private static string CleanTitle(string status)
    {
        var value = string.IsNullOrWhiteSpace(status) ? "PDF operation" : status.Trim();
        value = value.TrimEnd('.');
        return value;
    }

    private static PdfJobType InferType(string status)
    {
        var value = status ?? string.Empty;
        if (value.Contains("OCR", StringComparison.OrdinalIgnoreCase) || value.Contains("recogn", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Ocr;
        if (value.Contains("compress", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Compress;
        if (value.Contains("convert", StringComparison.OrdinalIgnoreCase) || value.Contains("Word", StringComparison.OrdinalIgnoreCase) || value.Contains("Excel", StringComparison.OrdinalIgnoreCase) || value.Contains("PowerPoint", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Convert;
        if (value.Contains("repair", StringComparison.OrdinalIgnoreCase) || value.Contains("optim", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Repair;
        if (value.Contains("merge", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Merge;
        if (value.Contains("split", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Split;
        if (value.Contains("extract", StringComparison.OrdinalIgnoreCase) || value.Contains("export", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Extract;
        if (value.Contains("inspect", StringComparison.OrdinalIgnoreCase) || value.Contains("doctor", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Inspect;
        if (value.Contains("rotate", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Rotate;
        if (value.Contains("reorder", StringComparison.OrdinalIgnoreCase)) return PdfJobType.Reorder;
        return PdfJobType.Edit;
    }
}
