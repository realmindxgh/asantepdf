using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;

namespace PdfRescue.App;

public partial class MainWindow
{
    private void InitializeAccessibilityMetadata()
    {
        SetAutomationMetadata(DocumentTabsList, "Open PDF tabs", "Use Ctrl+Tab and Ctrl+Shift+Tab to move between open PDFs.");
        SetAutomationMetadata(PagesList, "PDF pages", "Use Ctrl or Shift while selecting thumbnails to work with multiple pages.");
        SetAutomationMetadata(PageNumberBox, "Current page number", "Type a page number and press Enter to navigate.");
        SetAutomationMetadata(PageViewModeCombo, "Page view mode", "Choose Single Page, Continuous or Two Page viewing.");
        SetAutomationMetadata(ZoomPercentBox, "Custom zoom percentage", "Type a percentage from 30 to 350 and press Enter. Use the 1:1 button for 100 percent.");
        SetAutomationMetadata(DocumentSearchBox, "Search active PDF", "Press Ctrl+F to focus search. Use the adjacent buttons for previous and next matches.");
        SetAutomationMetadata(SearchPreviousButton, "Previous search result");
        SetAutomationMetadata(SearchNextButton, "Next search result");
        SetAutomationMetadata(SearchClearButton, "Clear document search");
        SetAutomationMetadata(PreviewScroll, "Single-page PDF viewer");
        SetAutomationMetadata(ContinuousPagesList, "Continuous PDF viewer", "Scroll through pages. The current-page indicator follows the visible page.");
        SetAutomationMetadata(TwoPageScroll, "Two-page PDF viewer");
        SetAutomationMetadata(TaskCenterNavButton, "Task Center", "View running, queued, completed, failed and cancelled PDF operations.");
        SetAutomationMetadata(CompareTabsButton, "Compare two PDFs side by side");
        SetAutomationMetadata(ThemeToggleButton, "Toggle light or dark theme");
        SetAutomationMetadata(SettingsButton, "AsantePDF Settings");
        SetAutomationMetadata(SplitLeftDocumentCombo, "Left comparison PDF");
        SetAutomationMetadata(SplitRightDocumentCombo, "Right comparison PDF");
        SetAutomationMetadata(SplitLinkedScrollCheck, "Link comparison scrolling");
        SetAutomationMetadata(SplitLinkedZoomCheck, "Synchronize comparison zoom");
        SetAutomationMetadata(OutlineTree, "PDF bookmarks and outline");
        SetAutomationMetadata(SearchResultsList, "PDF search results");
        SetAutomationMetadata(AnnotationsList, "PDF comments and annotations");
        SetAutomationMetadata(AttachmentsList, "PDF attachments");

        KeyboardNavigation.SetTabNavigation(DocumentWorkspaceRoot, KeyboardNavigationMode.Continue);
        KeyboardNavigation.SetDirectionalNavigation(DocumentWorkspaceRoot, KeyboardNavigationMode.Contained);
    }

    private static void SetAutomationMetadata(DependencyObject element, string name, string? help = null)
    {
        AutomationProperties.SetName(element, name);
        if (!string.IsNullOrWhiteSpace(help)) AutomationProperties.SetHelpText(element, help);
    }
}