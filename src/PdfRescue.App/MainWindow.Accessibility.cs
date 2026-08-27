using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;

namespace PdfRescue.App;

public partial class MainWindow
{
    private void InitializeAccessibilityMetadata()
    {
        Name(DocumentTabsList, "Open PDF tabs", "Use Ctrl+Tab and Ctrl+Shift+Tab to move between open PDFs.");
        Name(PagesList, "PDF pages", "Use Ctrl or Shift while selecting thumbnails to work with multiple pages.");
        Name(PageNumberBox, "Current page number", "Type a page number and press Enter to navigate.");
        Name(PageViewModeCombo, "Page view mode", "Choose Single Page, Continuous or Two Page viewing.");
        Name(ZoomButton, "Zoom percentage", "Activate to return to actual size / 100 percent.");
        Name(DocumentSearchBox, "Search active PDF", "Press Ctrl+F to focus search. Use the adjacent buttons for previous and next matches.");
        Name(SearchPreviousButton, "Previous search result");
        Name(SearchNextButton, "Next search result");
        Name(SearchClearButton, "Clear document search");
        Name(PreviewScroll, "Single-page PDF viewer");
        Name(ContinuousPagesList, "Continuous PDF viewer", "Scroll through pages. The current-page indicator follows the visible page.");
        Name(TwoPageScroll, "Two-page PDF viewer");
        Name(TaskCenterNavButton, "Task Center", "View running, queued, completed, failed and cancelled PDF operations.");
        Name(CompareTabsButton, "Compare two PDFs side by side");
        Name(ThemeToggleButton, "Toggle light or dark theme");
        Name(SettingsButton, "AsantePDF Settings");
        Name(SplitLeftDocumentCombo, "Left comparison PDF");
        Name(SplitRightDocumentCombo, "Right comparison PDF");
        Name(SplitLinkedScrollCheck, "Link comparison scrolling");
        Name(SplitLinkedZoomCheck, "Synchronize comparison zoom");
        Name(OutlineTree, "PDF bookmarks and outline");
        Name(SearchResultsList, "PDF search results");
        Name(AnnotationsList, "PDF comments and annotations");
        Name(AttachmentsList, "PDF attachments");

        KeyboardNavigation.SetTabNavigation(DocumentWorkspaceRoot, KeyboardNavigationMode.Continue);
        KeyboardNavigation.SetDirectionalNavigation(DocumentWorkspaceRoot, KeyboardNavigationMode.Contained);
    }

    private static void Name(DependencyObject element, string name, string? help = null)
    {
        AutomationProperties.SetName(element, name);
        if (!string.IsNullOrWhiteSpace(help)) AutomationProperties.SetHelpText(element, help);
    }
}