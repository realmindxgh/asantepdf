using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using PdfRescue.Core.Jobs;
using PdfRescue.Core.Models;

namespace PdfRescue.App.Services;

public sealed class TaskCenterItem : INotifyPropertyChanged
{
    private readonly PdfJob _job;
    private readonly Action? _cancelAction;

    internal TaskCenterItem(PdfJob job, Action? cancelAction)
    {
        _job = job;
        _cancelAction = cancelAction;
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
    public bool ShowProgress => State is PdfJobState.Queued or PdfJobState.Running or PdfJobState.Paused;
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

    internal void Refresh()
    {
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(StateLabel));
        OnPropertyChanged(nameof(Stage));
        OnPropertyChanged(nameof(ErrorMessage));
        OnPropertyChanged(nameof(Progress));
        OnPropertyChanged(nameof(ProgressPercent));
        OnPropertyChanged(nameof(IsFinished));
        OnPropertyChanged(nameof(CanCancel));
        OnPropertyChanged(nameof(ShowProgress));
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

    public TaskCenterItem Start(string status, Action? cancelAction = null)
    {
        var title = CleanTitle(status);
        var job = new PdfJob(InferType(status), title);
        job.TransitionTo(PdfJobState.Queued, "Queued");
        job.TransitionTo(PdfJobState.Running, string.IsNullOrWhiteSpace(status) ? "Starting" : status.Trim());
        var item = new TaskCenterItem(job, cancelAction);
        Items.Insert(0, item);
        item.Refresh();
        Changed?.Invoke(this, EventArgs.Empty);
        return item;
    }

    public void ReportProgress(TaskCenterItem? item, double progress, string stage)
    {
        if (item is null || item.Job.State is not (PdfJobState.Running or PdfJobState.Paused)) return;
        item.Job.ReportProgress(progress, stage);
        item.Refresh();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void Complete(TaskCenterItem? item, string stage = "Completed")
    {
        if (item is null || item.Job.State is not (PdfJobState.Running or PdfJobState.Paused)) return;
        item.Job.TransitionTo(PdfJobState.Completed, stage);
        item.Refresh();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void Cancel(TaskCenterItem? item, string stage = "Cancelled")
    {
        if (item is null || item.Job.State is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled) return;
        item.Job.TransitionTo(PdfJobState.Cancelled, stage);
        item.Refresh();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void Fail(TaskCenterItem? item, Exception error)
    {
        if (item is null || item.Job.State is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled) return;
        item.Job.TransitionTo(PdfJobState.Failed, "Failed", error.Message);
        item.Refresh();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void ClearFinished()
    {
        for (var i = Items.Count - 1; i >= 0; i--)
            if (Items[i].IsFinished) Items.RemoveAt(i);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void RefreshElapsed()
    {
        foreach (var item in Items.Where(item => !item.IsFinished)) item.RefreshElapsed();
    }

    public (int Running, int Queued, int Completed, int Failed, int Cancelled) GetCounts() =>
        (
            Items.Count(item => item.State is PdfJobState.Running or PdfJobState.Paused),
            Items.Count(item => item.State == PdfJobState.Queued),
            Items.Count(item => item.State == PdfJobState.Completed),
            Items.Count(item => item.State == PdfJobState.Failed),
            Items.Count(item => item.State == PdfJobState.Cancelled)
        );

    private static string CleanTitle(string status)
    {
        var value = string.IsNullOrWhiteSpace(status) ? "PDF operation" : status.Trim();
        value = value.TrimEnd('.');
        if (value.EndsWith("ing", StringComparison.OrdinalIgnoreCase)) return value;
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
