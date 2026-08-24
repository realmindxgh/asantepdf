param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldN = Normalize $Old
    $newN = Normalize $New
    if (-not $text.Contains($oldN)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldN, $newN))
}

$xaml = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml'
Replace-Exact $xaml @'
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel Margin="16">
                                    <TextBlock Text="Document Details" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,14" />
'@ @'
                            <ScrollViewer VerticalScrollBarVisibility="Auto">
                                <StackPanel Margin="16">
                                    <Border x:Name="InspectorContextCard" Background="#101F2E" BorderBrush="#243D56" BorderThickness="1" CornerRadius="9" Padding="12" Margin="0,0,0,14">
                                        <StackPanel>
                                            <TextBlock x:Name="InspectorContextTitle" Text="Document" FontSize="14" FontWeight="SemiBold" />
                                            <TextBlock x:Name="InspectorContextSummary" Text="Select a page, text range or annotation to inspect its context." Foreground="{StaticResource MutedTextBrush}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,8" />
                                            <StackPanel x:Name="InspectorContextContent" />
                                        </StackPanel>
                                    </Border>
                                    <TextBlock Text="Document Details" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,14" />
'@ 'inspector context card'
Replace-Exact $xaml @'
                            <ColumnDefinition x:Name="InspectorColumn" Width="310" />
'@ @'
                            <ColumnDefinition x:Name="InspectorColumn" Width="310" MinWidth="260" MaxWidth="460" />
'@ 'inspector bounds'

$code = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $code @'
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
'@ @'
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        _selectedAnnotation = annotation;
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
        UpdateCommandStates();
'@ 'annotation selection context'

Replace-Exact $code @'
        var selectedPages = SelectedPages();
        if (selectedPages.Count > 1)
'@ @'
        var selectedPages = SelectedPages();
        if (PagesList.SelectedItem is PdfPageItem && _selectedAnnotation is not null)
            _selectedAnnotation = null;
        if (selectedPages.Count > 1)
'@ 'page selection clears annotation context'

Replace-Exact $code @'
        UpdateDocumentTitleDirtyIndicator();
    }

    private bool HasUnsavedLayoutChanges()
'@ @'
        UpdateDocumentTitleDirtyIndicator();
        UpdateInspectorContext();
    }

    private bool HasUnsavedLayoutChanges()
'@ 'command state updates inspector'

$nav = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.NavigationMetadata.cs'
Replace-Exact $nav @'
    private void ResetDocumentNavigationMetadataForDocumentChange()
    {
'@ @'
    private void ResetDocumentNavigationMetadataForDocumentChange()
    {
        _selectedAnnotation = null;
'@ 'reset inspector annotation context'

$text = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.TextSelection.cs'
Replace-Exact $text @'
        RefreshDocumentTextSelectionHighlights();
        StatusText.Text = HasDocumentTextSelection ? "PDF text selected. Press Ctrl+C or right-click to copy." : "Ready.";
        e.Handled = true;
'@ @'
        RefreshDocumentTextSelectionHighlights();
        StatusText.Text = HasDocumentTextSelection ? "PDF text selected. Press Ctrl+C or right-click to copy." : "Ready.";
        UpdateCommandStates();
        e.Handled = true;
'@ 'text selection updates inspector'
Replace-Exact $text @'
        TextSelectionCanvas.Children.Clear();
    }

    private void SetDocumentTextSelectionInteractionEnabled(bool enabled)
'@ @'
        TextSelectionCanvas.Children.Clear();
        UpdateCommandStates();
    }

    private void SetDocumentTextSelectionInteractionEnabled(bool enabled)
'@ 'text selection clear updates inspector'

$inspector = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Inspector.cs'
$inspectorContent = @'
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private PdfAnnotationItem? _selectedAnnotation;

    private void UpdateInspectorContext()
    {
        if (InspectorContextCard is null) return;

        var hasDocument = _currentPdf is not null && Pages.Count > 0;
        if (!hasDocument)
        {
            InspectorContextTitle.Text = "No document";
            InspectorContextSummary.Text = "Open a PDF to inspect document, page and selection context.";
            InspectorContextContent.Children.Clear();
            InspectorContextCard.Visibility = Visibility.Visible;
            return;
        }

        InspectorContextContent.Children.Clear();
        var selectedPages = SelectedPages();

        if (_selectedAnnotation is not null)
        {
            InspectorContextTitle.Text = "Annotation";
            InspectorContextSummary.Text = $"{_selectedAnnotation.TypeLabel} on page {_selectedAnnotation.SourcePageNumber:N0}";
            AddInspectorField("Type", _selectedAnnotation.TypeLabel);
            AddInspectorField("Author", string.IsNullOrWhiteSpace(_selectedAnnotation.Author) ? "Not recorded" : _selectedAnnotation.Author);
            AddInspectorField("Modified", string.IsNullOrWhiteSpace(_selectedAnnotation.Modified) ? "Not recorded" : _selectedAnnotation.Modified);
            if (!string.IsNullOrWhiteSpace(_selectedAnnotation.Contents))
                AddInspectorField("Comment", _selectedAnnotation.Contents, multiline: true);
            return;
        }

        if (HasDocumentTextSelection && _selectableTextPage is not null)
        {
            InspectorContextTitle.Text = "Text selection";
            var start = Math.Min(_textSelectionAnchor, _textSelectionFocus);
            var end = Math.Max(_textSelectionAnchor, _textSelectionFocus);
            var selectedText = start >= 0 && end >= start && end < _selectableTextPage.Text.Length
                ? _selectableTextPage.Text.Substring(start, end - start + 1)
                : string.Empty;
            var preview = selectedText.Replace("\r", " ").Replace("\n", " ").Trim();
            if (preview.Length > 120) preview = preview[..120] + "…";
            InspectorContextSummary.Text = $"{selectedText.Length:N0} characters on page {_selectableTextPagePosition:N0}";
            AddInspectorField("Selected text", string.IsNullOrWhiteSpace(preview) ? "(No text)" : preview, multiline: true);
            var copy = new Button
            {
                Content = "Copy selected text",
                Style = (Style)FindResource("FlatButtonStyle"),
                HorizontalAlignment = HorizontalAlignment.Left,
                Padding = new Thickness(10, 5, 10, 5),
                Margin = new Thickness(0, 5, 0, 0)
            };
            copy.Click += CopySelectedDocumentText_Click;
            InspectorContextContent.Children.Add(copy);
            return;
        }

        if (selectedPages.Count == 1)
        {
            var page = selectedPages[0];
            InspectorContextTitle.Text = "Page";
            InspectorContextSummary.Text = $"Working-layout page {page.Position:N0}";
            AddInspectorField("Position", page.Position.ToString("N0"));
            AddInspectorField("Source page", page.SourcePageNumber.ToString("N0"));
            AddInspectorField("Rotation", $"{NormalizeRotation(page.Rotation)}°");

            var actions = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 5, 0, 0) };
            actions.Children.Add(CreateInspectorAction("Rotate left", RotateLeft_Click));
            actions.Children.Add(CreateInspectorAction("Rotate right", RotateRight_Click));
            InspectorContextContent.Children.Add(actions);
            return;
        }

        if (selectedPages.Count > 1)
        {
            InspectorContextTitle.Text = "Page selection";
            InspectorContextSummary.Text = $"{selectedPages.Count:N0} pages selected";
            AddInspectorField("Positions", FormatPagePositionSummary(selectedPages));
            AddInspectorField("Source pages", FormatPagePositionSummary(selectedPages.Select(p => p.SourcePageNumber)));
            AddInspectorField("Rotations", string.Join(", ", selectedPages.GroupBy(p => NormalizeRotation(p.Rotation)).OrderBy(g => g.Key).Select(g => $"{g.Key}° × {g.Count():N0}")));
            return;
        }

        InspectorContextTitle.Text = "Document";
        InspectorContextSummary.Text = "No page-specific selection is active.";
        AddInspectorField("Current PDF", Path.GetFileName(_currentPdf!));
        AddInspectorField("Working pages", Pages.Count.ToString("N0"));
        AddInspectorField("Layout", HasLayoutChanges() ? "Modified working layout" : "Original page layout");
    }

    private Button CreateInspectorAction(string label, RoutedEventHandler handler)
    {
        var button = new Button
        {
            Content = label,
            Style = (Style)FindResource("FlatButtonStyle"),
            Padding = new Thickness(9, 5, 9, 5),
            Margin = new Thickness(0, 0, 7, 0),
            IsEnabled = !_busy
        };
        button.Click += handler;
        return button;
    }

    private void AddInspectorField(string label, string value, bool multiline = false)
    {
        var block = new StackPanel { Margin = new Thickness(0, 0, 0, 7) };
        block.Children.Add(new TextBlock
        {
            Text = label,
            Foreground = (Brush)FindResource("MutedTextBrush"),
            FontSize = 11
        });
        block.Children.Add(new TextBlock
        {
            Text = value,
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            MaxHeight = multiline ? 80 : double.PositiveInfinity,
            Margin = new Thickness(0, 2, 0, 0)
        });
        InspectorContextContent.Children.Add(block);
    }
}
'@
Write-Text $inspector $inspectorContent

$tests = Join-Path $SourceRoot 'tests\PdfRescue.SmokeTests\Program.cs'
Replace-Exact $tests @'
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING" && i.Category == "Structure" && i.ActionLabel == "Repair PDF"), "Structural warnings should expose a repair action.");
'@ @'
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING" && i.Category == "Structure" && i.ActionLabel == "Repair PDF"), "Structural warnings should expose a repair action.");
        Assert(report.StatusDescription.Contains("readable", StringComparison.OrdinalIgnoreCase), "Attention Needed should explain that the PDF remains readable.");
'@ 'inspector batch keeps doctor status contract'

Write-Host 'Context-aware Inspector batch staged.' -ForegroundColor Green
& cmd /c exit 0
