param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference = 'Stop'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n") }
function Write-Text([string]$Path, [string]$Text) {
    $directory = Split-Path -Parent $Path
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [IO.File]::WriteAllText($Path, (Normalize $Text).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string]$Path,[string]$Old,[string]$New,[string]$Label) {
    $text = Normalize ([IO.File]::ReadAllText($Path))
    $oldText = Normalize $Old
    if (-not $text.Contains($oldText)) { throw "Target not found: $Label" }
    Write-Text $Path ($text.Replace($oldText, (Normalize $New)))
}

$main = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.xaml.cs'
Replace-Exact $main @'
            if (!await ConfirmDocumentReplacementAsync("closing AsantePDF")) return;
            if (!ConfirmDiscardInactiveDirtyTabsForExit()) return;

            _closeAfterConfirmation = true;
'@ @'
            if (!await ConfirmDocumentReplacementAsync("closing AsantePDF")) return;
            if (!await ResolveInactiveDirtyTabsForExitAsync()) return;

            _closeAfterConfirmation = true;
'@ 'multi-tab exit resolution call'

Replace-Exact $main @'
        var choice = MessageBox.Show(this,
            $"You have unsaved page-layout changes. Save them before {action}?\n\n" +
            "Yes = Save a copy first\nNo = Discard the unsaved layout changes\nCancel = Stay with this document",
            "Unsaved AsantePDF changes", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning);

        if (choice == MessageBoxResult.Yes)
            return await SaveCopyCurrentLayoutAsync(showSuccessMessage: false);

        return choice == MessageBoxResult.No;
'@ @'
        var choice = MessageBox.Show(this,
            $"You have unsaved page-layout changes. Save them before {action}?\n\n" +
            "Yes = Save changes to this PDF\nNo = Don't save these changes\nCancel = Stay with this document",
            "Unsaved AsantePDF changes", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning);

        if (choice == MessageBoxResult.Yes)
            return await SaveInPlaceAsync(showSuccessMessage: false);

        return choice == MessageBoxResult.No;
'@ 'standard save dont-save cancel prompt'

$tabs = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.DocumentTabs.cs'
Replace-Exact $tabs @'
    private bool ConfirmDiscardInactiveDirtyTabsForExit()
    {
        var dirty = DocumentTabs.Where(tab => !ReferenceEquals(tab, _activeDocumentTab) && tab.IsDirty).ToArray();
        if (dirty.Length == 0) return true;

        var names = string.Join("\n", dirty.Take(5).Select(tab => "• " + tab.Name));
        if (dirty.Length > 5) names += $"\n• and {dirty.Length - 5:N0} more";
        var choice = MessageBox.Show(this,
            $"Other open tabs also contain unsaved page-layout changes:\n\n{names}\n\nClose AsantePDF and discard those unsaved tab changes?",
            "Unsaved AsantePDF tabs", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        return choice == MessageBoxResult.Yes;
    }
'@ @'
    private async Task<bool> ResolveInactiveDirtyTabsForExitAsync()
    {
        var dirty = DocumentTabs
            .Where(tab => !ReferenceEquals(tab, _activeDocumentTab) && tab.IsDirty)
            .ToArray();
        if (dirty.Length == 0) return true;

        foreach (var tab in dirty)
        {
            if (!DocumentTabs.Contains(tab) || !tab.IsDirty) continue;
            var choice = MessageBox.Show(this,
                $"{tab.Name} also has unsaved page-layout changes.\n\n" +
                "Yes = Save changes to this PDF\nNo = Don't save these changes\nCancel = Stay in AsantePDF",
                "Unsaved AsantePDF tab", MessageBoxButton.YesNoCancel, MessageBoxImage.Warning);

            if (choice == MessageBoxResult.Cancel) return false;
            if (choice == MessageBoxResult.No)
            {
                DiscardDocumentTabWorkingChanges(tab);
                continue;
            }

            await ActivateDocumentTabAsync(tab);
            if (!ReferenceEquals(_activeDocumentTab, tab)) return false;
            if (!await SaveInPlaceAsync(showSuccessMessage: false)) return false;
            CaptureActiveDocumentTabState();
        }

        return true;
    }
'@ 'multi-tab save resolution implementation'

$productShell = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.ProductShell.cs'
Replace-Exact $productShell @'
        InitializePageViewModes();
        InitializeResponsiveLayout();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@ @'
        InitializePageViewModes();
        InitializeResponsiveLayout();
        InitializeAccessibilityMetadata();
        _pendingRecoverySnapshot = RecoverySnapshotService.Current.BeginSession();
'@ 'accessibility initialization'

$accessibility = Join-Path $SourceRoot 'src\PdfRescue.App\MainWindow.Accessibility.cs'
Write-Text $accessibility @'
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
'@

$installer = Join-Path $SourceRoot 'installer\AsantePDF.iss'
Replace-Exact $installer @'
function IsVCRuntimeInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result := RegQueryDWordValue(
    HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed',
    Installed) and (Installed = 1);
end;
'@ @'
function IsVCRuntimeInstalled: Boolean;
var
  Installed, Major: Cardinal;
begin
  Result :=
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed',
      Installed) and (Installed = 1) and
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Major',
      Major) and (Major >= 14);
end;
'@ 'VC runtime suitability check'

$svg = Join-Path $SourceRoot 'assets\asantepdf-mark.svg'
Write-Text $svg @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" role="img" aria-label="AsantePDF Ghana-inspired document mark">
  <rect x="8" y="8" width="240" height="240" rx="52" fill="#111111"/>
  <path d="M48 30h112l54 54v142H48z" fill="#F7F7F4" stroke="#FCD116" stroke-width="7" stroke-linejoin="round"/>
  <path d="M160 30v54h54" fill="#E8E8E3" stroke="#111111" stroke-width="7" stroke-linejoin="round"/>
  <rect x="67" y="102" width="128" height="30" rx="4" fill="#CE1126"/>
  <rect x="67" y="132" width="128" height="30" fill="#FCD116"/>
  <rect x="67" y="162" width="128" height="30" rx="0 0 4 4" fill="#006B3F"/>
  <path d="M92 190l36-91 36 91M106 155h44" fill="none" stroke="#111111" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
'@

# Build the actual Windows .ico from the same visual language. The title-bar vector
# and this icon share the black/document/red-gold-green/A construction so Windows,
# setup, taskbar and the in-app identity no longer drift apart.
try { Add-Type -AssemblyName System.Drawing.Common -ErrorAction Stop } catch { Add-Type -AssemblyName System.Drawing }
$size = 256
$bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

function New-RoundedPath([single]$x,[single]$y,[single]$w,[single]$h,[single]$r) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $r * 2
    $path.AddArc($x,$y,$d,$d,180,90)
    $path.AddArc($x+$w-$d,$y,$d,$d,270,90)
    $path.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90)
    $path.AddArc($x,$y+$h-$d,$d,$d,90,90)
    $path.CloseFigure()
    return $path
}

$backgroundPath = New-RoundedPath 8 8 240 240 52
$black = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,17,17,17))
$graphics.FillPath($black, $backgroundPath)

$page = [System.Drawing.Drawing2D.GraphicsPath]::new()
$page.AddPolygon([System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(48,30),
    [System.Drawing.PointF]::new(160,30),
    [System.Drawing.PointF]::new(214,84),
    [System.Drawing.PointF]::new(214,226),
    [System.Drawing.PointF]::new(48,226)))
$page.CloseFigure()
$pageBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,247,247,244))
$goldPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255,252,209,22),7)
$goldPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$graphics.FillPath($pageBrush, $page)
$graphics.DrawPath($goldPen, $page)

$fold = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(160,30),
    [System.Drawing.PointF]::new(214,84),
    [System.Drawing.PointF]::new(160,84))
$foldBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,232,232,227))
$graphics.FillPolygon($foldBrush,$fold)
$foldPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255,17,17,17),7)
$foldPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$graphics.DrawLines($foldPen,[System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(160,30),
    [System.Drawing.PointF]::new(160,84),
    [System.Drawing.PointF]::new(214,84)))

$red = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,206,17,38))
$gold = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,252,209,22))
$green = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,0,107,63))
$graphics.FillRectangle($red,67,102,128,30)
$graphics.FillRectangle($gold,67,132,128,30)
$graphics.FillRectangle($green,67,162,128,30)

$aPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255,17,17,17),15)
$aPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$aPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$aPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$graphics.DrawLine($aPen,92,190,128,99)
$graphics.DrawLine($aPen,128,99,164,190)
$graphics.DrawLine($aPen,106,155,150,155)

$iconPath = Join-Path $SourceRoot 'assets\asantepdf.ico'
$handle = $bitmap.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($handle)
$stream = [IO.File]::Open($iconPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose() }

$aPen.Dispose(); $green.Dispose(); $gold.Dispose(); $red.Dispose(); $foldPen.Dispose(); $foldBrush.Dispose();
$goldPen.Dispose(); $pageBrush.Dispose(); $page.Dispose(); $black.Dispose(); $backgroundPath.Dispose();
$graphics.Dispose(); $bitmap.Dispose()

$global:LASTEXITCODE = 0
Write-Host 'Final contract polish staged: multi-tab Save flow, accessibility metadata, VC runtime check, and Ghana-inspired Windows identity.' -ForegroundColor Green
