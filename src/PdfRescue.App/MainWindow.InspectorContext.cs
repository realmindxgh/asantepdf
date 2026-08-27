using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private void UpdateInspectorContext()
    {
        if (InspectorContextCard is null) return;

        InspectorContextContent.Children.Clear();
        var hasDocument = _currentPdf is not null && Pages.Count > 0;
        if (!hasDocument)
        {
            InspectorContextTitle.Text = "No document";
            InspectorContextSummary.Text = "Open a PDF to inspect document, page and selection context.";
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
            if (preview.Length > 180) preview = preview[..180] + "…";

            InspectorContextSummary.Text = $"{selectedText.Length:N0} characters on page {_selectableTextPagePosition:N0}";
            AddInspectorField("Selected text", string.IsNullOrWhiteSpace(preview) ? "(No text)" : preview, true);

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
            var markup = new WrapPanel { Margin = new Thickness(0, 7, 0, 0) };
            markup.Children.Add(CreateInspectorAction("Highlight", HighlightSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Underline", UnderlineSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Strikeout", StrikeoutSelectedText_Click));
            markup.Children.Add(CreateInspectorAction("Style…", AnnotationStyle_Click));
            InspectorContextContent.Children.Add(markup);
            return;
        }

        if (_selectedPdfAnnotation is PdfAnnotationItem annotation)
        {
            InspectorContextTitle.Text = "Annotation";
            InspectorContextSummary.Text = $"{annotation.TypeLabel} on source page {annotation.SourcePageNumber:N0}";
            AddInspectorField("Type", annotation.TypeLabel);
            AddInspectorField("Author", string.IsNullOrWhiteSpace(annotation.Author) ? "Not specified" : annotation.Author);
            AddInspectorField("Contents", string.IsNullOrWhiteSpace(annotation.Contents) ? "(No comment text)" : annotation.Contents, true);
            AddInspectorField("Modified", string.IsNullOrWhiteSpace(annotation.Modified) ? "Not specified" : annotation.Modified);
            var actions = new WrapPanel { Margin = new Thickness(0, 5, 0, 0) };
            actions.Children.Add(CreateInspectorAction("Edit copy…", EditSelectedAnnotation_Click));
            actions.Children.Add(CreateInspectorAction("Delete from copy…", DeleteSelectedAnnotation_Click));
            InspectorContextContent.Children.Add(actions);
            return;
        }

        var selectedPages = SelectedPages();
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
            AddInspectorField("Source pages", FormatPagePositionSummary(selectedPages.Select(page => page.SourcePageNumber)));
            AddInspectorField(
                "Rotations",
                string.Join(", ", selectedPages
                    .GroupBy(page => NormalizeRotation(page.Rotation))
                    .OrderBy(group => group.Key)
                    .Select(group => $"{group.Key}° × {group.Count():N0}")));
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
        var block = new StackPanel { Margin = new Thickness(0, 0,0, 7) };
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
            MaxHeight = multiline ? 90 : double.PositiveInfinity,
            Margin = new Thickness(0, 2, 0, 0)
        });
        InspectorContextContent.Children.Add(block);
    }
}