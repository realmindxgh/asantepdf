using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Media.Imaging;

namespace PdfRescue.App;

public sealed class PdfPageItem : INotifyPropertyChanged
{
    private BitmapSource? _thumbnail;
    private int _rotation;
    private int _position;

    public PdfPageItem(int sourcePageNumber, int position)
    {
        SourcePageNumber = sourcePageNumber;
        _position = position;
    }

    public int SourcePageNumber { get; }
    public int Position { get => _position; set { _position = value; OnPropertyChanged(); OnPropertyChanged(nameof(Label)); } }
    public int Rotation { get => _rotation; set { _rotation = ((value % 360) + 360) % 360; OnPropertyChanged(); } }
    public BitmapSource? Thumbnail { get => _thumbnail; set { _thumbnail = value; OnPropertyChanged(); } }
    public string Label => $"Page {Position}";

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
