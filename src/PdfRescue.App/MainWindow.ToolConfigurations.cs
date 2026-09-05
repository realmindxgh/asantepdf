using System.IO;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async Task<IReadOnlyList<string>> SplitByPageGroupsAsync(
        string workingPath,
        IReadOnlyList<string> pageGroups,
        string outputBase,
        CancellationToken token)
    {
        if (pageGroups.Count == 0) throw new ArgumentException("At least one split page group is required.", nameof(pageGroups));

        var fullBase = Path.GetFullPath(outputBase);
        var outputDirectory = Path.GetDirectoryName(fullBase)!;
        Directory.CreateDirectory(outputDirectory);
        var stem = Path.GetFileNameWithoutExtension(fullBase);
        var destinations = Enumerable.Range(1, pageGroups.Count)
            .Select(index => Path.Combine(outputDirectory, $"{stem}-{index:00}.pdf"))
            .ToArray();
        var collisions = destinations.Where(File.Exists).ToArray();
        if (collisions.Length > 0)
            throw new IOException($"Split stopped because {collisions.Length:N0} output file(s) already exist. Choose a different base name.");

        var stagingDirectory = Path.Combine(Path.GetTempPath(), "AsantePDF", "split-groups", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stagingDirectory);
        var staged = new string[pageGroups.Count];
        try
        {
            for (var index = 0; index < pageGroups.Count; index++)
            {
                token.ThrowIfCancellationRequested();
                StatusText.Text = $"Preparing split group {index + 1:N0} of {pageGroups.Count:N0}…";
                staged[index] = Path.Combine(stagingDirectory, $"group-{index + 1:00}.pdf");
                await _operations.ExtractAsync(workingPath, pageGroups[index], staged[index], token);
            }

            token.ThrowIfCancellationRequested();
            for (var index = 0; index < staged.Length; index++)
                File.Move(staged[index], destinations[index]);
            return destinations;
        }
        finally
        {
            try { Directory.Delete(stagingDirectory, recursive: true); } catch { }
        }
    }
}