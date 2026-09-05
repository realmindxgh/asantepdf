using PdfRescue.Core.Services;

namespace PdfRescue.Infrastructure.Storage;

public sealed class WorkspaceService : IWorkspaceService
{
    private readonly string _basePath;

    public WorkspaceService(string? basePath = null)
    {
        _basePath = basePath ?? Path.Combine(Path.GetTempPath(), "AsantePDF", "workspaces");
    }

    public async Task<WorkspaceHandle> CreateAsync(string sourcePath, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("Source PDF was not found.", sourcePath);

        Directory.CreateDirectory(_basePath);
        var workspaceRoot = Path.Combine(_basePath, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(workspaceRoot);

        var extension = Path.GetExtension(sourcePath);
        var workingPath = Path.Combine(workspaceRoot, $"working{extension}");

        try
        {
            await using var input = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024, useAsync: true);
            await using var output = new FileStream(workingPath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1024 * 1024, useAsync: true);
            await input.CopyToAsync(output, cancellationToken).ConfigureAwait(false);
            await output.FlushAsync(cancellationToken).ConfigureAwait(false);
            return new WorkspaceHandle(workspaceRoot, workingPath);
        }
        catch
        {
            try { Directory.Delete(workspaceRoot, recursive: true); } catch { }
            throw;
        }
    }

    public int CleanupStaleWorkspaces(TimeSpan olderThan)
    {
        if (!Directory.Exists(_basePath))
            return 0;

        var removed = 0;
        var cutoff = DateTime.UtcNow - olderThan;
        foreach (var directory in Directory.EnumerateDirectories(_basePath))
        {
            try
            {
                if (Directory.GetLastWriteTimeUtc(directory) < cutoff)
                {
                    Directory.Delete(directory, recursive: true);
                    removed++;
                }
            }
            catch
            {
                // Ignore active or protected workspace folders.
            }
        }

        return removed;
    }
}
