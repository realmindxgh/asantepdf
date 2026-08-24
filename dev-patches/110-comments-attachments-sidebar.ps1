param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $oldN = $Old.Replace("`r`n", "`n")
    $newN = $New.Replace("`r`n", "`n")
    if (-not $text.Contains($oldN)) { throw "Could not find patch target: $Label in $Path" }
    $text = $text.Replace($oldN, $newN)
    [IO.File]::WriteAllText($Path, $text.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

function Set-TextFile([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    [IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n").Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}

$annotationServicePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\DocumentAnnotationService.cs'
Set-TextFile $annotationServicePath @'
using System.IO;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfAnnotationItem(
    int SourcePageNumber,
    string TypeLabel,
    string Author,
    string Contents,
    string Modified)
{
    public string PageLabel => $"Page {SourcePageNumber:N0}";
    public string DisplayText => string.IsNullOrWhiteSpace(Contents) ? "(No comment text)" : Contents;
    public string MetaText
    {
        get
        {
            var parts = new List<string>();
            if (!string.IsNullOrWhiteSpace(Author)) parts.Add(Author);
            if (!string.IsNullOrWhiteSpace(Modified)) parts.Add(Modified);
            return string.Join("  •  ", parts);
        }
    }
}

public sealed class DocumentAnnotationService
{
    private const int MaxAnnotations = 20_000;
    private const ulong MaxStringBytes = 1024 * 1024;

    public Task<IReadOnlyList<PdfAnnotationItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    private static IReadOnlyList<PdfAnnotationItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var runtimeAnchor = PdfRendererFactory.CreateProduction();
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for annotation navigation.");

        try
        {
            var results = new List<PdfAnnotationItem>();
            var pageCount = Math.Max(0, fpdfview.FPDF_GetPageCount(document));
            for (var pageIndex = 0; pageIndex < pageCount && results.Count < MaxAnnotations; pageIndex++)
            {
                token.ThrowIfCancellationRequested();
                var page = fpdfview.FPDF_LoadPage(document, pageIndex);
                if (page is null) continue;

                try
                {
                    var count = Math.Max(0, fpdf_annot.FPDFPageGetAnnotCount(page));
                    for (var annotationIndex = 0; annotationIndex < count && results.Count < MaxAnnotations; annotationIndex++)
                    {
                        token.ThrowIfCancellationRequested();
                        var annotation = fpdf_annot.FPDFPageGetAnnot(page, annotationIndex);
                        if (annotation is null) continue;

                        try
                        {
                            var subtype = fpdf_annot.FPDFAnnotGetSubtype(annotation);
                            if (!ShouldListSubtype(subtype)) continue;

                            results.Add(new PdfAnnotationItem(
                                pageIndex + 1,
                                GetSubtypeLabel(subtype),
                                ReadString(annotation, "T"),
                                ReadString(annotation, "Contents"),
                                ReadString(annotation, "M")));
                        }
                        finally
                        {
                            fpdf_annot.FPDFPageCloseAnnot(annotation);
                        }
                    }
                }
                finally
                {
                    fpdfview.FPDF_ClosePage(page);
                }
            }

            return results;
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static bool ShouldListSubtype(int subtype) => subtype switch
    {
        1 => true,                // Text note
        >= 3 and <= 18 => true,  // FreeText through Sound
        >= 24 and <= 28 => true, // Watermark through Redact
        _ => false
    };

    private static string GetSubtypeLabel(int subtype) => subtype switch
    {
        1 => "Comment",
        3 => "Free text",
        4 => "Line",
        5 => "Square",
        6 => "Circle",
        7 => "Polygon",
        8 => "Polyline",
        9 => "Highlight",
        10 => "Underline",
        11 => "Squiggly",
        12 => "Strikeout",
        13 => "Stamp",
        14 => "Caret",
        15 => "Ink",
        16 => "Popup",
        17 => "File attachment note",
        18 => "Sound",
        24 => "Watermark",
        25 => "3D annotation",
        26 => "Rich media",
        27 => "XFA widget",
        28 => "Redaction mark",
        _ => $"Annotation {subtype}"
    };

    private static string ReadString(FpdfAnnotationT annotation, string key)
    {
        ushort scratch = 0;
        var required = fpdf_annot.FPDFAnnotGetStringValue(annotation, key, ref scratch, 0);
        if (required < 2 || required > MaxStringBytes) return string.Empty;

        var buffer = new ushort[checked((int)((required + 1) / 2))];
        var written = fpdf_annot.FPDFAnnotGetStringValue(annotation, key, ref buffer[0], required);
        if (written < 2) return string.Empty;

        var characters = Math.Min(buffer.Length, checked((int)(written / 2)));
        return new string(buffer.Take(characters).Select(value => (char)value).ToArray()).TrimEnd('\0').Trim();
    }
}
'@

$attachmentServicePath = Join-Path $SourceRoot 'src\PdfRescue.App\Services\DocumentAttachmentService.cs'
Set-TextFile $attachmentServicePath @'
using System.IO;
using System.Runtime.InteropServices;
using PDFiumCore;

namespace PdfRescue.App.Services;

public sealed record PdfAttachmentItem(
    int Index,
    string Name,
    string Description,
    string MimeType,
    long SizeBytes)
{
    public string DisplayName => string.IsNullOrWhiteSpace(Name) ? $"Attachment {Index + 1:N0}" : Name;
    public string DetailText
    {
        get
        {
            var details = new List<string>();
            if (SizeBytes >= 0) details.Add(FormatBytes(SizeBytes));
            if (!string.IsNullOrWhiteSpace(MimeType)) details.Add(MimeType);
            return string.Join("  •  ", details);
        }
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes:N0} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024d:N1} KB";
        if (bytes < 1024L * 1024 * 1024) return $"{bytes / (1024d * 1024):N1} MB";
        return $"{bytes / (1024d * 1024 * 1024):N1} GB";
    }
}

public sealed class DocumentAttachmentService
{
    private const int MaxAttachments = 10_000;
    private const ulong MaxStringBytes = 1024 * 1024;
    private const ulong MaxExtractBytes = 512UL * 1024 * 1024;

    public Task<IReadOnlyList<PdfAttachmentItem>> LoadAsync(string path, CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(path)) throw new ArgumentException("A PDF path is required.", nameof(path));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => Load(fullPath, token), token);
    }

    public Task<byte[]> ReadFileAsync(string path, int index, CancellationToken token = default)
    {
        if (index < 0) throw new ArgumentOutOfRangeException(nameof(index));
        var fullPath = Path.GetFullPath(path);
        return Task.Run(() => ReadFile(fullPath, index, token), token);
    }

    private static IReadOnlyList<PdfAttachmentItem> Load(string path, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var runtimeAnchor = PdfRendererFactory.CreateProduction();
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF for attachment navigation.");

        try
        {
            var count = Math.Clamp(fpdf_attachment.FPDFDocGetAttachmentCount(document), 0, MaxAttachments);
            var results = new List<PdfAttachmentItem>(count);
            for (var index = 0; index < count; index++)
            {
                token.ThrowIfCancellationRequested();
                var attachment = fpdf_attachment.FPDFDocGetAttachment(document, index);
                if (attachment is null) continue;

                ulong size = 0;
                var readable = fpdf_attachment.FPDFAttachmentGetFile(attachment, IntPtr.Zero, 0, ref size) != 0;
                var sizeBytes = readable && size <= long.MaxValue ? (long)size : -1;
                results.Add(new PdfAttachmentItem(
                    index,
                    ReadName(attachment),
                    ReadDescription(attachment),
                    ReadSubtype(attachment),
                    sizeBytes));
            }
            return results;
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static byte[] ReadFile(string path, int index, CancellationToken token)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("PDF file was not found.", path);
        using var runtimeAnchor = PdfRendererFactory.CreateProduction();
        token.ThrowIfCancellationRequested();

        var document = fpdfview.FPDF_LoadDocument(path, string.Empty);
        if (document is null)
            throw new InvalidDataException("PDFium could not open the PDF attachment.");

        try
        {
            var count = fpdf_attachment.FPDFDocGetAttachmentCount(document);
            if (index >= count) throw new ArgumentOutOfRangeException(nameof(index));
            var attachment = fpdf_attachment.FPDFDocGetAttachment(document, index)
                ?? throw new InvalidDataException("The selected PDF attachment could not be opened.");

            ulong required = 0;
            if (fpdf_attachment.FPDFAttachmentGetFile(attachment, IntPtr.Zero, 0, ref required) == 0)
                throw new InvalidDataException("The selected PDF attachment is unreadable.");
            if (required > MaxExtractBytes)
                throw new InvalidDataException("This embedded file is too large to extract safely in one operation.");
            if (required == 0) return [];

            var pointer = Marshal.AllocHGlobal(checked((int)required));
            try
            {
                token.ThrowIfCancellationRequested();
                ulong written = 0;
                if (fpdf_attachment.FPDFAttachmentGetFile(attachment, pointer, required, ref written) == 0 || written > required)
                    throw new InvalidDataException("PDFium could not extract the selected attachment.");

                var bytes = new byte[checked((int)written)];
                Marshal.Copy(pointer, bytes, 0, bytes.Length);
                return bytes;
            }
            finally
            {
                Marshal.FreeHGlobal(pointer);
            }
        }
        finally
        {
            fpdfview.FPDF_CloseDocument(document);
        }
    }

    private static string ReadName(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetName(attachment, ref buffer, length));

    private static string ReadDescription(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetDescription(attachment, ref buffer, length));

    private static string ReadSubtype(FpdfAttachmentT attachment) => ReadUtf16((ref ushort buffer, ulong length) =>
        fpdf_attachment.FPDFAttachmentGetSubtype(attachment, ref buffer, length));

    private delegate ulong Utf16Reader(ref ushort buffer, ulong length);

    private static string ReadUtf16(Utf16Reader reader)
    {
        ushort scratch = 0;
        var required = reader(ref scratch, 0);
        if (required < 2 || required > MaxStringBytes) return string.Empty;
        var buffer = new ushort[checked((int)((required + 1) / 2))];
        var written = reader(ref buffer[0], required);
        if (written < 2) return string.Empty;
        var characters = Math.Min(buffer.Length, checked((int)(written / 2)));
        return new string(buffer.Take(characters).Select(value => (char)value).ToArray()).TrimEnd('\0').Trim();
    }
}
'@

$navigationPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NavigationMetadata.cs'
Set-TextFile $navigationPath @'
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly DocumentAnnotationService _documentAnnotations = new();
    private readonly DocumentAttachmentService _documentAttachments = new();
    private CancellationTokenSource? _annotationNavigationCts;
    private CancellationTokenSource? _attachmentNavigationCts;
    private string? _annotationsLoadedForPath;
    private string? _attachmentsLoadedForPath;

    private void InitializeDocumentNavigationMetadata()
    {
        Closed += (_, _) =>
        {
            _annotationNavigationCts?.Cancel();
            _annotationNavigationCts?.Dispose();
            _attachmentNavigationCts?.Cancel();
            _attachmentNavigationCts?.Dispose();
            _annotationNavigationCts = null;
            _attachmentNavigationCts = null;
        };
    }

    private async void PageModeAnnotations_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        ShowAnnotationsSidebar();
        await LoadDocumentAnnotationsAsync();
    }

    private async void PageModeAttachments_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        ShowAttachmentsSidebar();
        await LoadDocumentAttachmentsAsync();
    }

    private void ShowAnnotationsSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Visible;
    }

    private void ShowAttachmentsSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Visible;
    }

    private async Task LoadDocumentAnnotationsAsync()
    {
        if (_currentPdf is null) return;
        var path = _currentPdf;
        if (string.Equals(_annotationsLoadedForPath, path, StringComparison.OrdinalIgnoreCase))
        {
            UpdateAnnotationsEmptyState();
            return;
        }

        _annotationNavigationCts?.Cancel();
        _annotationNavigationCts?.Dispose();
        _annotationNavigationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _annotationNavigationCts.Token;
        var generation = _documentGeneration;
        AnnotationsList.ItemsSource = null;
        AnnotationsEmptyText.Text = "Loading comments and annotations…";
        AnnotationsEmptyText.Visibility = Visibility.Visible;

        try
        {
            var annotations = await _documentAnnotations.LoadAsync(path, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase)) return;
            _annotationsLoadedForPath = path;
            AnnotationsList.ItemsSource = annotations;
            UpdateAnnotationsEmptyState();
            StatusText.Text = annotations.Count == 0
                ? "This PDF does not contain comment-style annotations."
                : $"Loaded {annotations.Count:N0} comment/annotation item(s).";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF annotation navigation load failed: " + ex);
            if (generation != _documentGeneration) return;
            AnnotationsList.ItemsSource = null;
            AnnotationsEmptyText.Text = "Could not read this PDF's comments and annotations.";
            AnnotationsEmptyText.Visibility = Visibility.Visible;
            StatusText.Text = "PDF annotation navigation could not be loaded.";
        }
    }

    private async Task LoadDocumentAttachmentsAsync()
    {
        if (_currentPdf is null) return;
        var path = _currentPdf;
        if (string.Equals(_attachmentsLoadedForPath, path, StringComparison.OrdinalIgnoreCase))
        {
            UpdateAttachmentsEmptyState();
            return;
        }

        _attachmentNavigationCts?.Cancel();
        _attachmentNavigationCts?.Dispose();
        _attachmentNavigationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _attachmentNavigationCts.Token;
        var generation = _documentGeneration;
        AttachmentsList.ItemsSource = null;
        AttachmentsEmptyText.Text = "Loading embedded files…";
        AttachmentsEmptyText.Visibility = Visibility.Visible;

        try
        {
            var attachments = await _documentAttachments.LoadAsync(path, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase)) return;
            _attachmentsLoadedForPath = path;
            AttachmentsList.ItemsSource = attachments;
            UpdateAttachmentsEmptyState();
            StatusText.Text = attachments.Count == 0
                ? "This PDF does not contain embedded file attachments."
                : $"Loaded {attachments.Count:N0} embedded file attachment(s).";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF attachment navigation load failed: " + ex);
            if (generation != _documentGeneration) return;
            AttachmentsList.ItemsSource = null;
            AttachmentsEmptyText.Text = "Could not read this PDF's embedded attachments.";
            AttachmentsEmptyText.Visibility = Visibility.Visible;
            StatusText.Text = "PDF attachment navigation could not be loaded.";
        }
    }

    private void UpdateAnnotationsEmptyState()
    {
        var hasItems = AnnotationsList.Items.Count > 0;
        AnnotationsList.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        AnnotationsEmptyText.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;
        if (!hasItems) AnnotationsEmptyText.Text = "This PDF does not contain comment-style annotations.";
    }

    private void UpdateAttachmentsEmptyState()
    {
        var hasItems = AttachmentsList.Items.Count > 0;
        AttachmentsList.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        SaveAttachmentButton.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        AttachmentsEmptyText.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;
        if (!hasItems) AttachmentsEmptyText.Text = "This PDF does not contain embedded file attachments.";
    }

    private void AnnotationsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (AnnotationsList.SelectedItem is not PdfAnnotationItem annotation) return;
        var target = Pages.FirstOrDefault(page => page.SourcePageNumber == annotation.SourcePageNumber);
        if (target is null)
        {
            StatusText.Text = $"This annotation belongs to source page {annotation.SourcePageNumber:N0}, which is not in the working layout.";
            return;
        }
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
    }

    private async void SaveAttachment_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || AttachmentsList.SelectedItem is not PdfAttachmentItem attachment) return;
        var suggestedName = Path.GetFileName(attachment.DisplayName);
        if (string.IsNullOrWhiteSpace(suggestedName)) suggestedName = $"attachment-{attachment.Index + 1:N0}.bin";
        var dialog = new SaveFileDialog
        {
            Title = "Save embedded PDF attachment",
            FileName = suggestedName,
            Filter = "All files (*.*)|*.*",
            AddExtension = false,
            OverwritePrompt = true
        };
        if (dialog.ShowDialog(this) != true) return;

        var sourcePath = _currentPdf;
        try
        {
            StatusText.Text = $"Extracting {attachment.DisplayName}…";
            var bytes = await _documentAttachments.ReadFileAsync(sourcePath, attachment.Index, _lifetime.Token);
            await File.WriteAllBytesAsync(dialog.FileName, bytes, _lifetime.Token);
            StatusText.Text = $"Saved embedded attachment: {Path.GetFileName(dialog.FileName)}";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF attachment extraction failed: " + ex);
            MessageBox.Show(this, "The embedded attachment could not be saved.\n\n" + ex.Message,
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Warning);
            StatusText.Text = "Embedded attachment extraction failed.";
        }
    }

    private void ResetDocumentNavigationMetadataForDocumentChange()
    {
        _annotationNavigationCts?.Cancel();
        _annotationNavigationCts?.Dispose();
        _annotationNavigationCts = null;
        _attachmentNavigationCts?.Cancel();
        _attachmentNavigationCts?.Dispose();
        _attachmentNavigationCts = null;
        _annotationsLoadedForPath = null;
        _attachmentsLoadedForPath = null;

        if (!_productShellInitialized || AnnotationsList is null || AttachmentsList is null) return;
        AnnotationsList.ItemsSource = null;
        AttachmentsList.ItemsSource = null;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SaveAttachmentButton.Visibility = Visibility.Collapsed;
    }
}
'@

$xamlPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xamlPath @'
                                    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
                                    <Button Grid.Column="0" Style="{StaticResource FlatButtonStyle}" Click="PageModePages_Click" Content="Pages" Padding="5" />
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModeBookmarks_Click" Content="Bookmarks" Padding="5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModeSearch_Click" Content="Search" Padding="5" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}" />
                                    <Button Grid.Column="3" Style="{StaticResource FlatButtonStyle}" Click="CollapsePagesSidebar_Click" Content="‹" Padding="0" Margin="2,0,0,0" ToolTip="Collapse navigation sidebar" />
'@ @'
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition Width="30"/>
                                    </Grid.ColumnDefinitions>
                                    <Button Grid.Column="0" Style="{StaticResource FlatButtonStyle}" Click="PageModePages_Click" Padding="4" ToolTip="Pages">
                                        <TextBlock Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" />
                                    </Button>
                                    <Button Grid.Column="1" Style="{StaticResource FlatButtonStyle}" Click="PageModeBookmarks_Click" Padding="4" ToolTip="Bookmarks / Outline" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}">
                                        <TextBlock Text="&#xE734;" FontFamily="Segoe MDL2 Assets" />
                                    </Button>
                                    <Button Grid.Column="2" Style="{StaticResource FlatButtonStyle}" Click="PageModeSearch_Click" Padding="4" ToolTip="Search Results" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}">
                                        <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" />
                                    </Button>
                                    <Button Grid.Column="3" Style="{StaticResource FlatButtonStyle}" Click="PageModeAnnotations_Click" Padding="4" ToolTip="Comments / Annotations" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}">
                                        <TextBlock Text="&#xE8BD;" FontFamily="Segoe MDL2 Assets" />
                                    </Button>
                                    <Button Grid.Column="4" Style="{StaticResource FlatButtonStyle}" Click="PageModeAttachments_Click" Padding="4" ToolTip="Attachments" IsEnabled="{Binding IsEnabled, ElementName=SaveButton}">
                                        <TextBlock Text="&#xE723;" FontFamily="Segoe MDL2 Assets" />
                                    </Button>
                                    <Button Grid.Column="5" Style="{StaticResource FlatButtonStyle}" Click="CollapsePagesSidebar_Click" Content="‹" Padding="0" Margin="2,0,0,0" ToolTip="Collapse navigation sidebar" />
'@ 'five-mode sidebar toolbar'

Replace-Exact $xamlPath @'
                                    <ListBox.ItemTemplate>
                                        <DataTemplate>
                                            <Border Padding="8" Margin="5,3" CornerRadius="5" BorderBrush="#29425B" BorderThickness="1" Background="#122131">
                                                <StackPanel>
                                                    <Image Source="{Binding Thumbnail}" Height="148" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality">
                                                        <Image.LayoutTransform><RotateTransform Angle="{Binding Rotation}" /></Image.LayoutTransform>
                                                    </Image>
                                                    <TextBlock Text="{Binding Label}" HorizontalAlignment="Center" Margin="0,6,0,0" FontSize="12" />
                                                </StackPanel>
                                            </Border>
                                        </DataTemplate>
                                    </ListBox.ItemTemplate>
'@ @'
                                    <ListBox.ItemTemplate>
                                        <DataTemplate>
                                            <Border x:Name="PageThumbnailCard" Padding="8" Margin="5,3" CornerRadius="5" BorderBrush="#29425B" BorderThickness="1" Background="#122131">
                                                <StackPanel>
                                                    <Image Source="{Binding Thumbnail}" Height="148" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality">
                                                        <Image.LayoutTransform><RotateTransform Angle="{Binding Rotation}" /></Image.LayoutTransform>
                                                    </Image>
                                                    <TextBlock Text="{Binding Label}" HorizontalAlignment="Center" Margin="0,6,0,0" FontSize="12" />
                                                </StackPanel>
                                            </Border>
                                            <DataTemplate.Triggers>
                                                <DataTrigger Binding="{Binding IsSelected, RelativeSource={RelativeSource AncestorType=ListBoxItem}}" Value="True">
                                                    <Setter TargetName="PageThumbnailCard" Property="BorderBrush" Value="#4D9BFF" />
                                                    <Setter TargetName="PageThumbnailCard" Property="BorderThickness" Value="2" />
                                                    <Setter TargetName="PageThumbnailCard" Property="Background" Value="#17304A" />
                                                </DataTrigger>
                                            </DataTemplate.Triggers>
                                        </DataTemplate>
                                    </ListBox.ItemTemplate>
'@ 'explicit selected thumbnail state'

Replace-Exact $xamlPath @'
                                    <TextBlock x:Name="SearchEmptyText" Text="Enter text above or press Ctrl+F to search this PDF."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18" />
                                </Grid>
                            </Grid>
'@ @'
                                    <TextBlock x:Name="SearchEmptyText" Text="Enter text above or press Ctrl+F to search this PDF."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18" />
                                </Grid>
                                <Grid x:Name="AnnotationsPanel" Grid.Row="1" Visibility="Collapsed">
                                    <ListBox x:Name="AnnotationsList" Background="Transparent" BorderThickness="0" Margin="6"
                                             SelectionChanged="AnnotationsList_SelectionChanged" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                        <ListBox.ItemTemplate>
                                            <DataTemplate>
                                                <Border Background="#122131" BorderBrush="#29425B" BorderThickness="1" CornerRadius="6" Padding="9" Margin="0,0,0,6">
                                                    <StackPanel>
                                                        <Grid>
                                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                                            <TextBlock Text="{Binding TypeLabel}" Foreground="#72B5FF" FontSize="11" FontWeight="SemiBold" />
                                                            <TextBlock Grid.Column="1" Text="{Binding PageLabel}" Foreground="{StaticResource MutedTextBrush}" FontSize="10" />
                                                        </Grid>
                                                        <TextBlock Text="{Binding DisplayText}" TextWrapping="Wrap" FontSize="12" Margin="0,5,0,0" MaxHeight="72" />
                                                        <TextBlock Text="{Binding MetaText}" Foreground="{StaticResource MutedTextBrush}" FontSize="10" Margin="0,5,0,0" TextTrimming="CharacterEllipsis" />
                                                    </StackPanel>
                                                </Border>
                                            </DataTemplate>
                                        </ListBox.ItemTemplate>
                                    </ListBox>
                                    <TextBlock x:Name="AnnotationsEmptyText" Text="Open Comments / Annotations to inspect this PDF."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18" IsHitTestVisible="False" />
                                </Grid>
                                <Grid x:Name="AttachmentsPanel" Grid.Row="1" Visibility="Collapsed">
                                    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                    <ListBox x:Name="AttachmentsList" Grid.Row="0" Background="Transparent" BorderThickness="0" Margin="6"
                                             ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                                        <ListBox.ItemTemplate>
                                            <DataTemplate>
                                                <Border Background="#122131" BorderBrush="#29425B" BorderThickness="1" CornerRadius="6" Padding="9" Margin="0,0,0,6">
                                                    <StackPanel>
                                                        <TextBlock Text="{Binding DisplayName}" FontWeight="SemiBold" FontSize="12" TextTrimming="CharacterEllipsis" ToolTip="{Binding Name}" />
                                                        <TextBlock Text="{Binding DetailText}" Foreground="#72B5FF" FontSize="10" Margin="0,4,0,0" />
                                                        <TextBlock Text="{Binding Description}" Foreground="{StaticResource MutedTextBrush}" FontSize="10" TextWrapping="Wrap" Margin="0,4,0,0" />
                                                    </StackPanel>
                                                </Border>
                                            </DataTemplate>
                                        </ListBox.ItemTemplate>
                                    </ListBox>
                                    <Button x:Name="SaveAttachmentButton" Grid.Row="1" Style="{StaticResource FlatButtonStyle}" Content="Save selected attachment…"
                                            Click="SaveAttachment_Click" Margin="8,4,8,8" Padding="8,6" Visibility="Collapsed" />
                                    <TextBlock x:Name="AttachmentsEmptyText" Grid.RowSpan="2" Text="Open Attachments to inspect embedded files in this PDF."
                                               Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" TextAlignment="Center"
                                               HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="190" Margin="18" IsHitTestVisible="False" />
                                </Grid>
                            </Grid>
'@ 'annotation and attachment sidebar panels'

$productShellPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShellPath @'
        InitializeDocumentTabs();
        InitializeDocumentOutline();
        InitializeDocumentTextSelection();
'@ @'
        InitializeDocumentTabs();
        InitializeDocumentOutline();
        InitializeDocumentTextSelection();
        InitializeDocumentNavigationMetadata();
'@ 'navigation metadata initialization'

Replace-Exact $productShellPath @'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
    }
'@ @'
    private void PageModePages_Click(object sender, RoutedEventArgs e)
    {
        PagesList.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
    }
'@ 'pages mode hides extended navigation panels'

$bookmarksPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Bookmarks.cs'
Replace-Exact $bookmarksPath @'
    private void ShowBookmarksSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Visible;
    }
'@ @'
    private void ShowBookmarksSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Visible;
    }
'@ 'bookmarks mode hides extended navigation panels'

$searchPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Search.cs'
Replace-Exact $searchPath @'
    private void ShowSearchSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Visible;
        UpdateSearchEmptyState();
    }
'@ @'
    private void ShowSearchSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Visible;
        UpdateSearchEmptyState();
    }
'@ 'search mode hides extended navigation panels'

$mainPath = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $mainPath @'
            ResetDocumentSearchForDocumentChange();
            ResetDocumentOutlineForDocumentChange();
            ResetDocumentTextSelectionForDocumentChange();
            _documentGeneration++;
'@ @'
            ResetDocumentSearchForDocumentChange();
            ResetDocumentOutlineForDocumentChange();
            ResetDocumentTextSelectionForDocumentChange();
            ResetDocumentNavigationMetadataForDocumentChange();
            _documentGeneration++;
'@ 'navigation metadata reset on document change'

Write-Host 'Comments/annotations, attachments and explicit selected-page sidebar state patch applied.' -ForegroundColor Green
