using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;

namespace PdfRescue.App;

public sealed record DocumentTabPageState(int SourcePageNumber, int Rotation);
public sealed record DocumentTabLayoutSnapshot(
    IReadOnlyList<DocumentTabPageState> Pages,
    IReadOnlyList<int> SelectedPositions);

public sealed class DocumentTabSession : INotifyPropertyChanged
{
    private bool _isDirty;

    public DocumentTabSession(string path)
    {
        Path = System.IO.Path.GetFullPath(path);
        Name = System.IO.Path.GetFileName(Path);
    }

    public Guid Id { get; } = Guid.NewGuid();
    public string Path { get; }
    public string Name { get; }
    public bool IsDirty
    {
        get => _isDirty;
        set
        {
            if (_isDirty == value) return;
            _isDirty = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(DisplayTitle));
        }
    }

    public string DisplayTitle => IsDirty ? Name + " *" : Name;
    public int SelectedPage { get; set; } = 1;
    public uint PreviewWidth { get; set; } = 1100;
    public double HorizontalOffset { get; set; }
    public double VerticalOffset { get; set; }
    public IReadOnlyList<DocumentTabPageState> WorkingLayout { get; set; } = [];
    public IReadOnlyList<DocumentTabPageState> SavedLayout { get; set; } = [];
    public IReadOnlyList<DocumentTabLayoutSnapshot> UndoHistory { get; set; } = [];
    public IReadOnlyList<DocumentTabLayoutSnapshot> RedoHistory { get; set; } = [];
    public DateTimeOffset LastActivatedUtc { get; set; } = DateTimeOffset.UtcNow;

    public bool IsAvailable => File.Exists(Path);

    public DocumentTabSession CloneForReopen() => new(Path)
    {
        IsDirty = IsDirty,
        SelectedPage = SelectedPage,
        PreviewWidth = PreviewWidth,
        HorizontalOffset = HorizontalOffset,
        VerticalOffset = VerticalOffset,
        WorkingLayout = WorkingLayout.ToArray(),
        SavedLayout = SavedLayout.ToArray(),
        UndoHistory = UndoHistory.Select(CloneSnapshot).ToArray(),
        RedoHistory = RedoHistory.Select(CloneSnapshot).ToArray(),
        LastActivatedUtc = LastActivatedUtc
    };

    public event PropertyChangedEventHandler? PropertyChanged;

    private static DocumentTabLayoutSnapshot CloneSnapshot(DocumentTabLayoutSnapshot snapshot) =>
        new(snapshot.Pages.ToArray(), snapshot.SelectedPositions.ToArray());

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}