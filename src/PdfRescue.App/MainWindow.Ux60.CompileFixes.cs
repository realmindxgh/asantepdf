namespace PdfRescue.App;

public partial class MainWindow
{
    // The command-palette implementation accepts an optional initial query. A true
    // zero-argument overload keeps WPF/Dispatcher Action method-group binding exact.
    private void ShowUxCommandPalette() => ShowUxCommandPalette(string.Empty);
}
