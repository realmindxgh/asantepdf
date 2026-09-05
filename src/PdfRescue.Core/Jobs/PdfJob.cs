using PdfRescue.Core.Models;

namespace PdfRescue.Core.Jobs;

public sealed class PdfJob
{
    private static readonly IReadOnlyDictionary<PdfJobState, HashSet<PdfJobState>> AllowedTransitions =
        new Dictionary<PdfJobState, HashSet<PdfJobState>>
        {
            [PdfJobState.Created] = [PdfJobState.Queued, PdfJobState.Cancelled],
            [PdfJobState.Queued] = [PdfJobState.Running, PdfJobState.Cancelled],
            [PdfJobState.Running] = [PdfJobState.Paused, PdfJobState.Completed, PdfJobState.Failed, PdfJobState.Cancelled],
            [PdfJobState.Paused] = [PdfJobState.Running, PdfJobState.Cancelled],
            [PdfJobState.Completed] = [],
            [PdfJobState.Failed] = [],
            [PdfJobState.Cancelled] = []
        };

    private readonly object _gate = new();

    public PdfJob(PdfJobType type, string title)
    {
        Id = Guid.NewGuid();
        Type = type;
        Title = string.IsNullOrWhiteSpace(title) ? type.ToString() : title.Trim();
        CreatedAt = DateTimeOffset.UtcNow;
    }

    public Guid Id { get; }
    public PdfJobType Type { get; }
    public string Title { get; }
    public PdfJobState State { get; private set; } = PdfJobState.Created;
    public double Progress { get; private set; }
    public string? StatusText { get; private set; }
    public string? ErrorMessage { get; private set; }
    public DateTimeOffset CreatedAt { get; }
    public DateTimeOffset? StartedAt { get; private set; }
    public DateTimeOffset? FinishedAt { get; private set; }

    public void TransitionTo(PdfJobState next, string? statusText = null, string? error = null)
    {
        lock (_gate)
        {
            if (!AllowedTransitions[State].Contains(next))
            {
                throw new InvalidOperationException($"Invalid PDF job transition {State} -> {next}.");
            }

            State = next;
            StatusText = statusText;
            ErrorMessage = error;

            if (next == PdfJobState.Running && StartedAt is null)
                StartedAt = DateTimeOffset.UtcNow;

            if (next is PdfJobState.Completed or PdfJobState.Failed or PdfJobState.Cancelled)
            {
                FinishedAt = DateTimeOffset.UtcNow;
                if (next == PdfJobState.Completed)
                    Progress = 1;
            }
        }
    }

    public void ReportProgress(double value, string? statusText = null)
    {
        lock (_gate)
        {
            if (State is not (PdfJobState.Running or PdfJobState.Paused))
                throw new InvalidOperationException("Progress can only be updated while a job is running or paused.");

            Progress = Math.Clamp(value, 0, 1);
            if (!string.IsNullOrWhiteSpace(statusText))
                StatusText = statusText;
        }
    }
}
