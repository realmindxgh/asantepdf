using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace PdfRescue.App;

public enum MultiResultAction
{
    None,
    OpenSelected,
    SaveSelected,
    OpenFolder,
    RunAgain
}

public sealed record MultiResultItem(string Name, string Path, string SizeLabel);

public partial class MultiResultDialog : Window
{
    public MultiResultAction SelectedAction { get; private set; }
    public string? SelectedPath => (ResultsList.SelectedItem as MultiResultItem)?.Path;

    public MultiResultDialog(
        string title,
        string summary,
        string sourcePath,
        IReadOnlyList<string> resultPaths,
        bool canRunAgain,
        string? sourceLabel = null,
        string? sourceDescription = null)
    {
        InitializeComponent();
        Title = title;
        TitleText.Text = title;
        SummaryText.Text = summary;
        SourceNameText.Text = string.IsNullOrWhiteSpace(sourceLabel) ? Path.GetFileName(sourcePath) : sourceLabel;
        SourcePathText.Text = string.IsNullOrWhiteSpace(sourceDescription) ? sourcePath : sourceDescription;

        var paths = resultPaths
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (paths.Length == 0) throw new ArgumentException("At least one result is required.", nameof(resultPaths));

        var folder = Path.GetDirectoryName(paths[0]) ?? string.Empty;
        ResultFolderText.Text = folder;
        ResultFolderText.ToolTip = folder;
        ResultCountText.Text = $"{paths.Length:N0} file{(paths.Length == 1 ? string.Empty : "s")}";
        ResultsList.ItemsSource = paths.Select(path => new MultiResultItem(
            Path.GetFileName(path),
            path,
            File.Exists(path) ? FormatBytes(new FileInfo(path).Length) : "Unavailable")).ToArray();
        ResultsList.SelectedIndex = 0;
        RunAgainButton.IsEnabled = canRunAgain;
        RefreshSelectionActions();
    }

    private void ResultsList_SelectionChanged(object sender, SelectionChangedEventArgs e) => RefreshSelectionActions();

    private void RefreshSelectionActions()
    {
        var available = SelectedPath is { } path && File.Exists(path);
        OpenSelectedButton.IsEnabled = available;
        SaveSelectedButton.IsEnabled = available;
    }

    private void Complete(MultiResultAction action)
    {
        SelectedAction = action;
        DialogResult = true;
    }

    private void OpenSelected_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.OpenSelected);
    private void SaveSelected_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.SaveSelected);
    private void OpenFolder_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.OpenFolder);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Complete(MultiResultAction.RunAgain);
    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private static string FormatBytes(long bytes)
    {
        if (bytes >= 1024L * 1024 * 1024) return $"{bytes / (1024d * 1024 * 1024):0.##} GB";
        if (bytes >= 1024L * 1024) return $"{bytes / (1024d * 1024):0.##} MB";
        if (bytes >= 1024L) return $"{bytes / 1024d:0.##} KB";
        return $"{bytes:N0} B";
    }
}