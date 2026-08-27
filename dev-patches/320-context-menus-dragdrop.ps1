param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false)) }
function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label) { $t=Normalize([IO.File]::ReadAllText($Path)); $o=Normalize $Old; if(-not $t.Contains($o)){throw "Target not found: $Label"}; Write-Text $Path ($t.Replace($o,(Normalize $New))) }

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                                        <Grid MinWidth="190" MaxWidth="280" Height="40" Margin="4,0">
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
'@ @'
                                        <Grid MinWidth="190" MaxWidth="280" Height="40" Margin="4,0">
                                            <Grid.ContextMenu>
                                                <ContextMenu DataContext="{Binding PlacementTarget.DataContext, RelativeSource={RelativeSource Self}}">
                                                    <MenuItem Header="Close tab" InputGestureText="Ctrl+W" Click="TabContextClose_Click" />
                                                    <MenuItem Header="Close other tabs" Click="TabContextCloseOthers_Click" />
                                                    <Separator />
                                                    <MenuItem Header="Compare side by side" Click="TabContextCompare_Click" />
                                                    <MenuItem Header="Show in folder" Click="TabContextShowInFolder_Click" />
                                                </ContextMenu>
                                            </Grid.ContextMenu>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
'@ 'tab context menu'

Replace-Exact $xaml @'
                                            <Border x:Name="PageThumbnailCard" Padding="8" Margin="5,3" CornerRadius="5" BorderBrush="#29425B" BorderThickness="1" Background="#122131">
                                                <StackPanel>
'@ @'
                                            <Border x:Name="PageThumbnailCard" Padding="8" Margin="5,3" CornerRadius="5" BorderBrush="#29425B" BorderThickness="1" Background="#122131">
                                                <Border.ContextMenu>
                                                    <ContextMenu DataContext="{Binding PlacementTarget.DataContext, RelativeSource={RelativeSource Self}}">
                                                        <MenuItem Header="Rotate left" Click="PageContextRotateLeft_Click" />
                                                        <MenuItem Header="Rotate right" Click="PageContextRotateRight_Click" />
                                                        <MenuItem Header="Duplicate" InputGestureText="Ctrl+D" Click="PageContextDuplicate_Click" />
                                                        <MenuItem Header="Extract selected page(s)…" Click="PageContextExtract_Click" />
                                                        <Separator />
                                                        <MenuItem Header="Select all pages" InputGestureText="Ctrl+A" Click="PageContextSelectAll_Click" />
                                                        <MenuItem Header="Delete selected page(s)" InputGestureText="Delete" Click="PageContextDelete_Click" />
                                                    </ContextMenu>
                                                </Border.ContextMenu>
                                                <StackPanel>
'@ 'page context menu'

Replace-Exact $xaml @'
                            <ScrollViewer x:Name="PreviewScroll" Visibility="Collapsed" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
                                <Border Margin="28" Background="#FFFFFF" BorderBrush="#3A4A59" BorderThickness="1" Padding="12" HorizontalAlignment="Center" VerticalAlignment="Top">
'@ @'
                            <ScrollViewer x:Name="PreviewScroll" Visibility="Collapsed" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
                                <ScrollViewer.ContextMenu>
                                    <ContextMenu>
                                        <MenuItem Header="Fit width" Click="FitWidth_Click" />
                                        <MenuItem Header="Fit page" Click="FitPageShell_Click" />
                                        <MenuItem Header="Actual size / 100%" Click="ActualSizeShell_Click" />
                                        <Separator />
                                        <MenuItem Header="Add note annotation…" Click="AddNoteAnnotation_Click" />
                                        <MenuItem Header="Comments / Annotations" Click="PageModeAnnotations_Click" />
                                        <Separator />
                                        <MenuItem Header="Print…" InputGestureText="Ctrl+P" Click="Print_Click" />
                                    </ContextMenu>
                                </ScrollViewer.ContextMenu>
                                <Border Margin="28" Background="#FFFFFF" BorderBrush="#3A4A59" BorderThickness="1" Padding="12" HorizontalAlignment="Center" VerticalAlignment="Top">
'@ 'canvas context menu'

$code = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ContextMenusAndDrop.cs'
Write-Text $code @'
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;

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
'@

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
    private void Window_DragOver(object sender, DragEventArgs e)
    {
        var pdfs = GetDroppedPdfs(e.Data);
        if (pdfs.Length == 0) return;
        e.Effects = DragDropEffects.Copy;
        e.Handled = true;
    }
'@ @'
    private void Window_DragOver(object sender, DragEventArgs e)
    {
        var pdfs = GetDroppedPdfs(e.Data);
        var images = GetDroppedImages(e.Data);
        if (pdfs.Length == 0 && images.Length == 0) return;
        e.Effects = DragDropEffects.Copy;
        e.Handled = true;
    }
'@ 'window drag accepts images'

Replace-Exact $main @'
    private async void Window_Drop(object sender, DragEventArgs e)
    {
        var pdfs = GetDroppedPdfs(e.Data);
        if (pdfs.Length == 0) return;
        e.Handled = true;

        if (pdfs.Length == 1)
'@ @'
    private async void Window_Drop(object sender, DragEventArgs e)
    {
        var images = GetDroppedImages(e.Data);
        var pdfs = GetDroppedPdfs(e.Data);
        if (images.Length > 0 && pdfs.Length == 0)
        {
            e.Handled = true;
            await CreatePdfFromDroppedImagesAsync(images);
            return;
        }
        if (pdfs.Length == 0) return;
        e.Handled = true;

        if (pdfs.Length == 1)
'@ 'window image drop workflow'

Write-Host 'Context menus and drag-drop expansion staged.' -ForegroundColor Green
