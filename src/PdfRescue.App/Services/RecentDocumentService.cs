using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Media.Imaging;

namespace PdfRescue.App.Services;

public enum RecentViewMode
{
    Grid,
    List,
    Compact
}

public enum RecentSortMode
{
    LastOpened,
    Name,
    Modified
}

public sealed record DocumentResumeState(string Path, int PageNumber, uint RenderWidth, double HorizontalOffset = 0, double VerticalOffset = 0);

public sealed record WorkspaceSessionState(
    IReadOnlyList<DocumentResumeState> Documents,
    int ActiveDocumentIndex,
    DateTimeOffset SavedUtc);

public sealed record RecentThumbnailResult(BitmapSource Thumbnail, int PageCount);

public sealed class RecentDocumentItem : INotifyPropertyChanged
{
    private BitmapSource? _thumbnail;
    private int _pageCount;
    private bool _isPinned;

    internal RecentDocumentItem(
        string path,
        DateTimeOffset lastOpenedUtc,
        int pageCount,
        int resumePage,
        uint resumeWidth,
        bool isPinned)
    {
        Path = path;
        LastOpenedUtc = lastOpenedUtc;
        _pageCount = pageCount;
        ResumePage = Math.Max(1, resumePage);
        ResumeWidth = Math.Clamp(resumeWidth, 320u, 4000u);
        _isPinned = isPinned;

        var file = new FileInfo(path);
        Missing = !file.Exists;
        Name = System.IO.Path.GetFileName(path);
        Location = System.IO.Path.GetDirectoryName(path) ?? string.Empty;
        if (!Missing)
        {
            ModifiedUtc = file.LastWriteTimeUtc;
            FileSize = file.Length;
        }
    }

    public string Path { get; }
    public string Name { get; }
    public string Location { get; }
    public bool Missing { get; }
    public bool Available => !Missing;
    public DateTimeOffset LastOpenedUtc { get; }
    public DateTime? ModifiedUtc { get; }
    public long? FileSize { get; }
    public int ResumePage { get; }
    public uint ResumeWidth { get; }

    public bool IsPinned
    {
        get => _isPinned;
        internal set
        {
            if (_isPinned == value) return;
            _isPinned = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(PinGlyph));
            OnPropertyChanged(nameof(PinLabel));
        }
    }

    public int PageCount
    {
        get => _pageCount;
        internal set
        {
            if (_pageCount == value) return;
            _pageCount = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(PageCountLabel));
            OnPropertyChanged(nameof(MetadataLine));
        }
    }

    public BitmapSource? Thumbnail
    {
        get => _thumbnail;
        internal set
        {
            if (ReferenceEquals(_thumbnail, value)) return;
            _thumbnail = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(HasThumbnail));
        }
    }

    public bool HasThumbnail => Thumbnail is not null;
    public string PinGlyph => IsPinned ? "★" : "☆";
    public string PinLabel => IsPinned ? "Unpin" : "Pin";
    public string PageCountLabel => PageCount > 0 ? $"{PageCount:N0} page{(PageCount == 1 ? string.Empty : "s")}" : "Pages not scanned yet";
    public string LastOpenedLabel => $"Opened {LastOpenedUtc.LocalDateTime:g}";
    public string ModifiedLabel => ModifiedUtc is DateTime modified ? modified.ToLocalTime().ToString("g") : "Unavailable";
    public string FileSizeLabel => FileSize is long bytes ? FormatBytes(bytes) : "Unavailable";
    public string AvailabilityLabel => Missing ? "File moved or unavailable" : "Available";
    public string MetadataLine => Missing
        ? "File moved or unavailable"
        : $"{PageCountLabel}  •  {FileSizeLabel}  •  Modified {ModifiedLabel}";

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        double value = bytes;
        var i = 0;
        while (value >= 1024 && i < units.Length - 1)
        {
            value /= 1024;
            i++;
        }
        return $"{value:0.##} {units[i]}";
    }
}

public sealed class RecentDocumentService
{
    private const int MaxDocuments = 100;
    private readonly object _sync = new();
    private readonly JsonSerializerOptions _jsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private static string RootDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AsantePDF");

    private static string StatePath => Path.Combine(RootDirectory, "workspace-state.json");
    private static string LegacyRecentPath => Path.Combine(RootDirectory, "recent.txt");
    private static string ThumbnailDirectory => Path.Combine(RootDirectory, "cache", "recent-thumbnails");

    public RecentViewMode PreferredView
    {
        get
        {
            lock (_sync) return LoadStateCore().PreferredView;
        }
    }

    public RecentSortMode PreferredSort
    {
        get
        {
            lock (_sync) return LoadStateCore().PreferredSort;
        }
    }

    public IReadOnlyList<RecentDocumentItem> LoadItems()
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            return state.Documents
                .Where(document => !string.IsNullOrWhiteSpace(document.Path))
                .Select(document => new RecentDocumentItem(
                    document.Path,
                    document.LastOpenedUtc,
                    document.PageCount,
                    document.ResumePage,
                    document.ResumeWidth,
                    document.IsPinned))
                .ToArray();
        }
    }

    public DocumentResumeState? GetResumeState(string path)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var document = LoadStateCore().Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            return document is null
                ? null
                : new DocumentResumeState(document.Path, Math.Max(1, document.ResumePage), Math.Clamp(document.ResumeWidth, 320u, 4000u));
        }
    }

    public WorkspaceSessionState? GetLastSession()
    {
        lock (_sync)
        {
            var session = LoadStateCore().LastSession;
            if (session is null || session.Documents.Count == 0) return null;
            return new WorkspaceSessionState(
                session.Documents
                    .Where(document => !string.IsNullOrWhiteSpace(document.Path))
                    .Select(document => new DocumentResumeState(
                        document.Path,
                        Math.Max(1, document.PageNumber),
                        Math.Clamp(document.RenderWidth, 320u, 4000u),
                        Math.Max(0, document.HorizontalOffset),
                        Math.Max(0, document.VerticalOffset)))
                    .ToArray(),
                Math.Clamp(session.ActiveDocumentIndex, 0, Math.Max(0, session.Documents.Count - 1)),
                session.SavedUtc);
        }
    }

    public void RecordOpened(string path, int pageNumber, uint renderWidth)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var state = LoadStateCore();
            var document = state.Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            if (document is null)
            {
                document = new PersistedRecentDocument { Path = fullPath };
                state.Documents.Add(document);
            }

            document.Path = fullPath;
            document.LastOpenedUtc = DateTimeOffset.UtcNow;
            document.ResumePage = Math.Max(1, pageNumber);
            document.ResumeWidth = Math.Clamp(renderWidth, 320u, 4000u);
            TrimDocuments(state);
            SaveStateCore(state);
        }
    }

    public void UpdatePosition(string path, int pageNumber, uint renderWidth)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var state = LoadStateCore();
            var document = state.Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            if (document is null) return;
            document.ResumePage = Math.Max(1, pageNumber);
            document.ResumeWidth = Math.Clamp(renderWidth, 320u, 4000u);
            SaveStateCore(state);
        }
    }

    public void SaveLastSession(string path, int pageNumber, uint renderWidth)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var state = LoadStateCore();
            state.LastSession = new PersistedWorkspaceSession
            {
                SavedUtc = DateTimeOffset.UtcNow,
                ActiveDocumentIndex = 0,
                Documents =
                [
                    new PersistedSessionDocument
                    {
                        Path = fullPath,
                        PageNumber = Math.Max(1, pageNumber),
                        RenderWidth = Math.Clamp(renderWidth, 320u, 4000u)
                    }
                ]
            };
            SaveStateCore(state);
        }
    }

    public void SaveLastSession(IReadOnlyList<DocumentResumeState> documents, int activeDocumentIndex)
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            var normalized = documents
                .Where(document => !string.IsNullOrWhiteSpace(document.Path))
                .Select(document => new PersistedSessionDocument
                {
                    Path = NormalizePath(document.Path),
                    PageNumber = Math.Max(1, document.PageNumber),
                    RenderWidth = Math.Clamp(document.RenderWidth, 320u, 4000u),
                    HorizontalOffset = Math.Max(0, document.HorizontalOffset),
                    VerticalOffset = Math.Max(0, document.VerticalOffset)
                })
                .ToList();

            if (normalized.Count == 0)
            {
                state.LastSession = null;
                SaveStateCore(state);
                return;
            }

            state.LastSession = new PersistedWorkspaceSession
            {
                SavedUtc = DateTimeOffset.UtcNow,
                ActiveDocumentIndex = Math.Clamp(activeDocumentIndex, 0, normalized.Count - 1),
                Documents = normalized
            };
            SaveStateCore(state);
        }
    }

    public void TogglePin(string path)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var state = LoadStateCore();
            var document = state.Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            if (document is null) return;
            document.IsPinned = !document.IsPinned;
            SaveStateCore(state);
        }
    }

    public void Remove(string path)
    {
        var fullPath = NormalizePath(path);
        lock (_sync)
        {
            var state = LoadStateCore();
            state.Documents.RemoveAll(item => PathEquals(item.Path, fullPath));
            SaveStateCore(state);
        }
    }

    public void SetViewMode(RecentViewMode viewMode)
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            state.PreferredView = viewMode;
            SaveStateCore(state);
        }
    }

    public void SetSortMode(RecentSortMode sortMode)
    {
        lock (_sync)
        {
            var state = LoadStateCore();
            state.PreferredSort = sortMode;
            SaveStateCore(state);
        }
    }

    public async Task<RecentThumbnailResult?> GetThumbnailAsync(string path, CancellationToken token)
    {
        var fullPath = NormalizePath(path);
        var file = new FileInfo(fullPath);
        if (!file.Exists) return null;

        Directory.CreateDirectory(ThumbnailDirectory);
        var cachePath = GetThumbnailCachePath(file);
        int persistedPageCount;
        lock (_sync)
        {
            var document = LoadStateCore().Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            persistedPageCount = document?.PageCount ?? 0;
        }

        if (File.Exists(cachePath) && persistedPageCount > 0)
        {
            try
            {
                return new RecentThumbnailResult(LoadBitmap(cachePath), persistedPageCount);
            }
            catch
            {
                TryDelete(cachePath);
            }
        }

        using var renderer = PdfRendererFactory.CreateProduction();
        await renderer.OpenAsync(fullPath, token);
        token.ThrowIfCancellationRequested();
        var pageCount = checked((int)renderer.PageCount);
        var thumbnail = await renderer.RenderAsync(1, 230, token);
        token.ThrowIfCancellationRequested();
        SaveBitmap(thumbnail, cachePath);

        lock (_sync)
        {
            var state = LoadStateCore();
            var document = state.Documents.FirstOrDefault(item => PathEquals(item.Path, fullPath));
            if (document is not null)
            {
                document.PageCount = pageCount;
                SaveStateCore(state);
            }
        }

        return new RecentThumbnailResult(thumbnail, pageCount);
    }

    private PersistedRecentState LoadStateCore()
    {
        Directory.CreateDirectory(RootDirectory);
        PersistedRecentState state;
        try
        {
            state = File.Exists(StatePath)
                ? JsonSerializer.Deserialize<PersistedRecentState>(File.ReadAllText(StatePath), _jsonOptions) ?? new PersistedRecentState()
                : new PersistedRecentState();
        }
        catch (Exception ex)
        {
            App.Log("Could not read workspace-state.json: " + ex.Message);
            state = new PersistedRecentState();
        }

        if (state.Documents.Count == 0 && File.Exists(LegacyRecentPath))
        {
            try
            {
                var now = DateTimeOffset.UtcNow;
                var index = 0;
                foreach (var raw in File.ReadAllLines(LegacyRecentPath))
                {
                    if (string.IsNullOrWhiteSpace(raw)) continue;
                    var path = NormalizePath(raw);
                    if (state.Documents.Any(item => PathEquals(item.Path, path))) continue;
                    state.Documents.Add(new PersistedRecentDocument
                    {
                        Path = path,
                        LastOpenedUtc = now.AddMinutes(-index++),
                        ResumePage = 1,
                        ResumeWidth = 1100
                    });
                }
                SaveStateCore(state);
            }
            catch (Exception ex)
            {
                App.Log("Could not migrate legacy recent documents: " + ex.Message);
            }
        }

        return state;
    }

    private void SaveStateCore(PersistedRecentState state)
    {
        Directory.CreateDirectory(RootDirectory);
        var staged = StatePath + ".tmp";
        var json = JsonSerializer.Serialize(state, _jsonOptions);
        File.WriteAllText(staged, json, Encoding.UTF8);
        File.Move(staged, StatePath, true);
    }

    private static void TrimDocuments(PersistedRecentState state)
    {
        if (state.Documents.Count <= MaxDocuments) return;
        var keep = state.Documents
            .OrderByDescending(document => document.IsPinned)
            .ThenByDescending(document => document.LastOpenedUtc)
            .Take(MaxDocuments)
            .Select(document => document.Path)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        state.Documents.RemoveAll(document => !keep.Contains(document.Path));
    }

    private static string NormalizePath(string path)
    {
        try { return Path.GetFullPath(path.Trim()); }
        catch { return path.Trim(); }
    }

    private static bool PathEquals(string left, string right) =>
        string.Equals(left, right, StringComparison.OrdinalIgnoreCase);

    private static string GetThumbnailCachePath(FileInfo file)
    {
        var identity = $"{file.FullName.ToUpperInvariant()}|{file.LastWriteTimeUtc.Ticks}|{file.Length}";
        var digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity))).ToLowerInvariant();
        return Path.Combine(ThumbnailDirectory, digest + ".png");
    }

    private static BitmapSource LoadBitmap(string path)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.StreamSource = stream;
        image.EndInit();
        image.Freeze();
        return image;
    }

    private static void SaveBitmap(BitmapSource bitmap, string path)
    {
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
        encoder.Save(stream);
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); }
        catch { }
    }

    private sealed class PersistedRecentState
    {
        public RecentViewMode PreferredView { get; set; } = RecentViewMode.Grid;
        public RecentSortMode PreferredSort { get; set; } = RecentSortMode.LastOpened;
        public List<PersistedRecentDocument> Documents { get; set; } = [];
        public PersistedWorkspaceSession? LastSession { get; set; }
    }

    private sealed class PersistedRecentDocument
    {
        public string Path { get; set; } = string.Empty;
        public DateTimeOffset LastOpenedUtc { get; set; } = DateTimeOffset.UtcNow;
        public int PageCount { get; set; }
        public int ResumePage { get; set; } = 1;
        public uint ResumeWidth { get; set; } = 1100;
        public bool IsPinned { get; set; }
    }

    private sealed class PersistedWorkspaceSession
    {
        public List<PersistedSessionDocument> Documents { get; set; } = [];
        public int ActiveDocumentIndex { get; set; }
        public DateTimeOffset SavedUtc { get; set; } = DateTimeOffset.UtcNow;
    }

    private sealed class PersistedSessionDocument
    {
        public string Path { get; set; } = string.Empty;
        public int PageNumber { get; set; } = 1;
        public uint RenderWidth { get; set; } = 1100;
        public double HorizontalOffset { get; set; }
        public double VerticalOffset { get; set; }
    }
}
