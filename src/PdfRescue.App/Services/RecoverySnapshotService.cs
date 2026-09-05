using System.IO;
using System.Text;
using System.Text.Json;
using PdfRescue.App;

namespace PdfRescue.App.Services;

public sealed record RecoveryDocumentState(
    string Path,
    bool IsDirty,
    int SelectedPage,
    uint PreviewWidth,
    double HorizontalOffset,
    double VerticalOffset,
    IReadOnlyList<DocumentTabPageState> WorkingLayout,
    IReadOnlyList<DocumentTabPageState> SavedLayout,
    IReadOnlyList<DocumentTabLayoutSnapshot> UndoHistory,
    IReadOnlyList<DocumentTabLayoutSnapshot> RedoHistory);

public sealed record RecoverySnapshot(
    IReadOnlyList<RecoveryDocumentState> Documents,
    int ActiveDocumentIndex,
    DateTimeOffset SavedUtc);

public sealed class RecoverySnapshotService
{
    private static readonly Lazy<RecoverySnapshotService> LazyCurrent = new(() => new RecoverySnapshotService());
    public static RecoverySnapshotService Current => LazyCurrent.Value;

    private readonly object _sync = new();
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private bool _sessionStarted;

    private static string RootDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AsantePDF", "Recovery");
    private static string SnapshotPath => Path.Combine(RootDirectory, "workspace-recovery.json");
    private static string RunningMarkerPath => Path.Combine(RootDirectory, "session-running.marker");

    public RecoverySnapshot? BeginSession()
    {
        lock (_sync)
        {
            if (_sessionStarted) return null;
            Directory.CreateDirectory(RootDirectory);
            var previousWasUnclean = File.Exists(RunningMarkerPath);
            var recovery = previousWasUnclean ? LoadSnapshotCore() : null;
            File.WriteAllText(RunningMarkerPath, $"{Environment.ProcessId}|{DateTimeOffset.UtcNow:O}", Encoding.UTF8);
            _sessionStarted = true;
            return recovery;
        }
    }

    public void SaveSnapshot(IEnumerable<DocumentTabSession> tabs, int activeIndex)
    {
        var documents = tabs
            .Where(tab => !string.IsNullOrWhiteSpace(tab.Path))
            .Select(tab => new RecoveryDocumentState(
                tab.Path,
                tab.IsDirty,
                Math.Max(1, tab.SelectedPage),
                Math.Clamp(tab.PreviewWidth, 320u, 4000u),
                Math.Max(0, tab.HorizontalOffset),
                Math.Max(0, tab.VerticalOffset),
                tab.WorkingLayout.ToArray(),
                tab.SavedLayout.ToArray(),
                tab.UndoHistory.ToArray(),
                tab.RedoHistory.ToArray()))
            .ToArray();

        lock (_sync)
        {
            Directory.CreateDirectory(RootDirectory);
            if (documents.Length == 0)
            {
                TryDelete(SnapshotPath);
                return;
            }

            var snapshot = new RecoverySnapshot(
                documents,
                Math.Clamp(activeIndex, 0, documents.Length - 1),
                DateTimeOffset.UtcNow);
            var staged = SnapshotPath + ".tmp";
            File.WriteAllText(staged, JsonSerializer.Serialize(snapshot, _json), Encoding.UTF8);
            File.Move(staged, SnapshotPath, true);
        }
    }

    public void DiscardSnapshot()
    {
        lock (_sync) TryDelete(SnapshotPath);
    }

    public void MarkCleanShutdown()
    {
        lock (_sync)
        {
            TryDelete(SnapshotPath);
            TryDelete(RunningMarkerPath);
            _sessionStarted = false;
        }
    }

    private RecoverySnapshot? LoadSnapshotCore()
    {
        try
        {
            if (!File.Exists(SnapshotPath)) return null;
            var snapshot = JsonSerializer.Deserialize<RecoverySnapshot>(File.ReadAllText(SnapshotPath), _json);
            if (snapshot is null || snapshot.Documents.Count == 0) return null;
            var available = snapshot.Documents.Where(document => File.Exists(document.Path)).ToArray();
            return available.Length == 0
                ? null
                : snapshot with
                {
                    Documents = available,
                    ActiveDocumentIndex = Math.Clamp(snapshot.ActiveDocumentIndex, 0, available.Length - 1)
                };
        }
        catch (Exception ex)
        {
            App.Log("Could not load crash-recovery snapshot: " + ex.Message);
            return null;
        }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); }
        catch { }
    }
}