using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private async void TabContextClose_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: DocumentTabSession tab })
            await CloseDocumentTabAsync(tab);
    }

    private async void TabContextCloseOthers_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DocumentTabSession keep }) return;
        var others = DocumentTabs.Where(tab => !ReferenceEquals(tab, keep)).ToArray();
        foreach (var tab in others)
            if (!await CloseDocumentTabAsync(tab)) break;
        if (DocumentTabs.Contains(keep)) await ActivateDocumentTabAsync(keep);
    }

    private async void TabContextCompare_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DocumentTabSession tab } || DocumentTabs.Count < 2) return;
        await ActivateDocumentTabAsync(tab);
        OpenSplitView_Click(this, new RoutedEventArgs());
    }

    private void TabContextShowInFolder_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DocumentTabSession tab } || !File.Exists(tab.Path)) return;
        try { Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{tab.Path}\"") { UseShellExecute = true }); }
        catch (Exception ex) { App.Log("Tab Show in Folder failed: " + ex.Message); }
    }

    private void EnsureContextPageSelected(object sender)
    {
        if (sender is not FrameworkElement { DataContext: PdfPageItem page }) return;
        if (PagesList.SelectedItems.Contains(page)) return;
        PagesList.SelectedItems.Clear();
        PagesList.SelectedItems.Add(page);
        PagesList.ScrollIntoView(page);
    }

    private void PageContextRotateLeft_Click(object sender, RoutedEventArgs e) { EnsureContextPageSelected(sender); RotateLeft_Click(sender, e); }
    private void PageContextRotateRight_Click(object sender, RoutedEventArgs e) { EnsureContextPageSelected(sender); RotateRight_Click(sender, e); }
    private void PageContextDuplicate_Click(object sender, RoutedEventArgs e) { EnsureContextPageSelected(sender); DuplicatePages_Click(sender, e); }
    private void PageContextExtract_Click(object sender, RoutedEventArgs e) { EnsureContextPageSelected(sender); Extract_Click(sender, e); }
    private void PageContextDelete_Click(object sender, RoutedEventArgs e) { EnsureContextPageSelected(sender); DeletePages_Click(sender, e); }
    private void PageContextSelectAll_Click(object sender, RoutedEventArgs e) => SelectAllPages_Click(sender, e);

    private static string[] GetDroppedImages(IDataObject data)
    {
        if (!data.GetDataPresent(DataFormats.FileDrop)) return [];
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff" };
        return (data.GetData(DataFormats.FileDrop) as string[] ?? [])
            .Where(File.Exists)
            .Where(path => allowed.Contains(Path.GetExtension(path)))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private async Task CreatePdfFromDroppedImagesAsync(string[] images)
    {
        if (_busy || images.Length == 0) return;
        var output = AskSavePath("Create PDF from dropped images", "images.pdf");
        if (output is null) return;
        var success = await RunPdfOutputOperationAsync(
            "Building PDF from dropped images…", "Image PDF created.", output,
            token => ImagePdfBuilder.CreateFromImageFilesAsync(images, output, token));
        if (success)
            await ShowResultWorkflowAsync(
                "Image PDF complete",
                $"Created a PDF from {images.Length:N0} dropped image(s).",
                images[0], output, resultIsPdf: true,
                () => ImagesToPdf_Click(this, new RoutedEventArgs()),
                $"{images.Length:N0} source images");
    }
}