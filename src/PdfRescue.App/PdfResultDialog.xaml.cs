using System.IO;
using System.Windows;

namespace PdfRescue.App;

public enum PdfResultAction
{
    Close,
    OpenNewTab,
    ReplaceCurrent,
    OpenFolder,
    SaveCopy,
    RunAgain
}

public partial class PdfResultDialog : Window
{
    public PdfResultDialog(
        string operationTitle,
        string summary,
        string originalPath,
        string resultPath,
        bool canReplaceCurrent,
        bool canRunAgain)
    {
        InitializeComponent();
        OperationTitleText.Text = operationTitle;
        SummaryText.Text = summary;
        OriginalNameText.Text = Path.GetFileName(originalPath);
        OriginalPathText.Text = originalPath;
        ResultNameText.Text = Path.GetFileName(resultPath);
        ResultPathText.Text = resultPath;

        try
        {
            var info = new FileInfo(resultPath);
            ResultMetaText.Text = info.Exists ? FormatBytes(info.Length) : "Result file unavailable";
        }
        catch
        {
            ResultMetaText.Text = "Result file";
        }

        ReplaceCurrentButton.IsEnabled = canReplaceCurrent;
        ReplaceCurrentButton.ToolTip = canReplaceCurrent
            ? "Open the result and close the original tab"
            : "The original tab has unsaved changes or is not the active source tab";
        RunAgainButton.IsEnabled = canRunAgain;
    }

    public PdfResultAction SelectedAction { get; private set; } = PdfResultAction.Close;

    private void OpenNewTab_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.OpenNewTab);
    private void ReplaceCurrent_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.ReplaceCurrent);
    private void OpenFolder_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.OpenFolder);
    private void SaveCopy_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.SaveCopy);
    private void RunAgain_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.RunAgain);
    private void Close_Click(object sender, RoutedEventArgs e) => Finish(PdfResultAction.Close);

    private void Finish(PdfResultAction action)
    {
        SelectedAction = action;
        DialogResult = true;
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }
        return $"{value:0.##} {units[unit]}";
    }
}
