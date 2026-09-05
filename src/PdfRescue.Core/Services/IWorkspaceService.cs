namespace PdfRescue.Core.Services;

public interface IWorkspaceService
{
    Task<WorkspaceHandle> CreateAsync(string sourcePath, CancellationToken cancellationToken = default);
}

public sealed class WorkspaceHandle : IAsyncDisposable
{
    private int _disposed;

    public WorkspaceHandle(string rootPath, string workingFilePath)
    {
        RootPath = rootPath;
        WorkingFilePath = workingFilePath;
    }

    public string RootPath { get; }
    public string WorkingFilePath { get; }

    public ValueTask DisposeAsync()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0)
            return ValueTask.CompletedTask;

        try
        {
            if (Directory.Exists(RootPath))
                Directory.Delete(RootPath, recursive: true);
        }
        catch
        {
            // Best-effort cleanup. A startup janitor will remove stale workspaces later.
        }

        return ValueTask.CompletedTask;
    }
}
