using System.ComponentModel;
using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml.Media.Imaging;

namespace PdfRescue.App.ViewModels;

public sealed class PageThumbnailViewModel : INotifyPropertyChanged
{
    private BitmapImage? _thumbnail;
    private int _rotationClockwise;
    private int _currentPosition;

    public PageThumbnailViewModel(int sourcePageNumber)
    {
        SourcePageNumber = sourcePageNumber;
        CurrentPosition = sourcePageNumber;
    }

    public int SourcePageNumber { get; }

    public int CurrentPosition
    {
        get => _currentPosition;
        set
        {
            if (SetField(ref _currentPosition, value))
                OnPropertyChanged(nameof(PageLabel));
        }
    }

    public string PageLabel => $"Page {CurrentPosition}";

    public BitmapImage? Thumbnail
    {
        get => _thumbnail;
        set => SetField(ref _thumbnail, value);
    }

    public int RotationClockwise
    {
        get => _rotationClockwise;
        set
        {
            var normalized = ((value % 360) + 360) % 360;
            if (SetField(ref _rotationClockwise, normalized))
                OnPropertyChanged(nameof(RotationText));
        }
    }

    public string RotationText => RotationClockwise == 0 ? string.Empty : $"↻ {RotationClockwise}°";

    public event PropertyChangedEventHandler? PropertyChanged;

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
