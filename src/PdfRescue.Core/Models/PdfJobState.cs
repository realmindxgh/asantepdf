namespace PdfRescue.Core.Models;

public enum PdfJobState
{
    Created,
    Queued,
    Running,
    Paused,
    Completed,
    Failed,
    Cancelled
}
