using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shell;
using System.Windows.Threading;
using Microsoft.Win32;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private sealed class UxCommand
    {
        public UxCommand(string title, string detail, string shortcut, string keywords, Func<Task> execute)
        {
            Title = title;
            Detail = detail;
            Shortcut = shortcut;
            Keywords = keywords;
            Execute = execute;
        }

        public string Title { get; }
        public string Detail { get; }
        public string Shortcut { get; }
        public string Keywords { get; }
        public Func<Task> Execute { get; }
        public string SearchText => $"{Title} {Detail} {Shortcut} {Keywords}";
        public override string ToString() => string.IsNullOrWhiteSpace(Shortcut)
            ? $"{Title}    {Detail}"
            : $"{Title}    {Shortcut}    {Detail}";
    }

    private sealed record UxButtonState(object? Content, bool IsHitTestVisible, bool Focusable, object? ToolTip);

    private bool _ux60Initialized;
    private readonly Dictionary<Guid, PdfJobState> _uxTaskStates = new();
    private readonly Dictionary<Guid, Button> _uxTaskButtons = new();
    private readonly Dictionary<Button, UxButtonState> _uxBusyButtons = new();
    private readonly List<string> _uxUndoLabels = [];
    private readonly List<string> _uxRedoLabels = [];
    private readonly List<UxCommand> _uxCommands = [];
    private Button? _uxPendingButton;
    private DateTimeOffset _uxPendingButtonAt;
    private Button? _uxActivityChip;
    private TextBlock? _uxActivityText;
    private ProgressBar? _uxActivityProgress;
    private StackPanel? _uxToastHost;
    private Grid? _uxCommandPaletteLayer;
    private TextBox? _uxCommandBox;
    private ListBox? _uxCommandList;
    private Border? _uxOpeningOverlay;
    private TextBlock? _uxOpeningTitle;
    private TextBlock? _uxOpeningStage;
    private ProgressBar? _uxDoctorProgress;
    private TextBlock? _uxDoctorSeverity;
    private Border? _uxDropOverlay;
    private TextBlock? _uxDropText;
    private TextBlock? _uxStatusDetails;
    private Border? _uxFileDragHandle;
    private Border? _uxLocalFirstCard;
    private Button? _uxMoreRibbonButton;
    private DispatcherTimer? _uxPulseTimer;
    private CancellationTokenSource? _uxPriorityThumbnailCts;
    private bool _uxFocusMode;
    private bool _uxLocalFirstDismissed;
    private Grid? _uxBodyGrid;
    private GridLength _uxBodyNavigationWidth = new(220);
    private GridLength _uxRibbonHeight = new(126);
    private bool _uxPagesWasCollapsedBeforeFocus;
    private bool _uxInspectorWasCollapsedBeforeFocus;
    private int _uxLastUndoCount;
    private int _uxLastRedoCount;
    private string? _uxUndoDocumentPath;
    private ImageSource? _uxOpeningPreviousPreview;
    private bool _uxOpeningWaitingForFirstPage;
    private Point _uxFileDragStart;
    private Button? _uxActiveFitButton;

    static MainWindow()
    {
        EventManager.RegisterClassHandler(
            typeof(MainWindow),
            FrameworkElement.LoadedEvent,
            new RoutedEventHandler(Ux60ClassLoaded),
            true);
        EventManager.RegisterClassHandler(
            typeof(MainWindow),
            Keyboard.PreviewKeyDownEvent,
            new KeyEventHandler(Ux60ClassPreviewKeyDown),
            true);
        EventManager.RegisterClassHandler(
            typeof(MainWindow),
            Mouse.PreviewMouseWheelEvent,
            new MouseWheelEventHandler(Ux60ClassPreviewMouseWheel),
            true);
    }

    private static void Ux60ClassLoaded(object sender, RoutedEventArgs e)
    {
        if (sender is not MainWindow window || !ReferenceEquals(e.OriginalSource, window)) return;
        _ = window.Dispatcher.BeginInvoke(
            DispatcherPriority.ContextIdle,
            new Action(window.InitializeUx60Enhancements));
    }

    private static void Ux60ClassPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (sender is MainWindow window) window.HandleUx60PreviewKeyDown(e);
    }

    private static void Ux60ClassPreviewMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (sender is MainWindow window) window.HandleUx60PreviewMouseWheel(e);
    }

    private void InitializeUx60Enhancements()
    {
        if (_ux60Initialized || !_productShellInitialized) return;
        _ux60Initialized = true;

        if (Content is not Grid root) return;
        _uxBodyGrid = root.Children.OfType<Grid>().FirstOrDefault(child => Grid.GetRow(child) == 1);

        ApplyUxWorkspacePreferences();
        BuildUxActivityChip(root);
        BuildUxToastHost(root);
        BuildUxOpeningOverlay(root);
        BuildUxDropOverlay(root);
        BuildUxCommandPalette(root);
        EnhanceUxDoctorPanel();
        EnhanceUxStatusStrip();
        EnhanceUxLocalFirstCard();
        EnhanceUxSplitters();
        EnhanceUxRibbonResponsiveness();
        EnhanceUxAccessibilityAndTooltips();
        BuildUxCommands();

        _taskCenterService.Changed += UxTaskCenterChanged;
        DocumentTabs.CollectionChanged += UxDocumentTabsCollectionChanged;
        PagesList.SelectionChanged += UxPagesSelectionChanged;
        DocumentTabsList.ItemContainerGenerator.StatusChanged += (_, _) => EnhanceUxDocumentTabMenus();
        SizeChanged += (_, _) => UpdateUxAdaptiveRibbon();
        Closing += (_, _) => PersistUxWorkspacePreferences();
        Closed += (_, _) =>
        {
            _uxPriorityThumbnailCts?.Cancel();
            _uxPriorityThumbnailCts?.Dispose();
            _uxPulseTimer?.Stop();
        };

        AddHandler(ButtonBase.ClickEvent, new RoutedEventHandler(UxAnyButtonClick), true);
        AddHandler(Mouse.PreviewMouseDownEvent, new MouseButtonEventHandler(UxPreviewMouseDown), true);
        AddHandler(DragDrop.PreviewDragEnterEvent, new DragEventHandler(UxPreviewDragEnter), true);
        AddHandler(DragDrop.PreviewDragOverEvent, new DragEventHandler(UxPreviewDragOver), true);
        AddHandler(DragDrop.PreviewDragLeaveEvent, new DragEventHandler(UxPreviewDragLeave), true);
        AddHandler(DragDrop.PreviewDropEvent, new DragEventHandler(UxPreviewDrop), true);

        _uxPulseTimer = new DispatcherTimer(DispatcherPriority.Background)
        {
            Interval = TimeSpan.FromMilliseconds(400)
        };
        _uxPulseTimer.Tick += (_, _) => UxPulse();
        _uxPulseTimer.Start();

        RefreshUxActivityChip();
        RefreshUxWindowTitle();
        UpdateUxAdaptiveRibbon();
        UpdateUxJumpList();
        EnhanceUxDocumentTabMenus();
        App.Log("UX60 shared interaction layer initialized.");
    }

    private void ApplyUxWorkspacePreferences()
    {
        var preferences = AppSettingsService.Current.Preferences;
        _lastPagesSidebarWidth = Math.Clamp(preferences.PagesSidebarWidth, 180d, 460d);
        _lastInspectorWidth = new GridLength(Math.Clamp(preferences.InspectorWidth, 260d, 460d));
        _inspectorUserCollapsed = preferences.InspectorCollapsed;
        _uxLocalFirstDismissed = preferences.LocalFirstCardDismissed;

        SetPagesSidebarCollapsed(preferences.PagesSidebarCollapsed);
        SetInspectorCollapsed(preferences.InspectorCollapsed);
        UpdateResponsiveLayout(ActualWidth);
    }

    private void PersistUxWorkspacePreferences()
    {
        try
        {
            var preferences = AppSettingsService.Current.Preferences;
            var pagesWidth = PagesColumn.ActualWidth > 0
                ? PagesColumn.ActualWidth
                : _lastPagesSidebarWidth;
            var inspectorWidth = InspectorColumn.ActualWidth > 0
                ? InspectorColumn.ActualWidth
                : _lastInspectorWidth.Value;

            AppSettingsService.Current.Save(preferences with
            {
                PagesSidebarWidth = Math.Clamp(pagesWidth, 180d, 460d),
                InspectorWidth = Math.Clamp(inspectorWidth, 260d, 460d),
                PagesSidebarCollapsed = PagesColumn.Width.Value <= 0,
                InspectorCollapsed = _inspectorUserCollapsed,
                LocalFirstCardDismissed = _uxLocalFirstDismissed
            });
        }
        catch (Exception ex)
        {
            App.Log("Could not persist UX workspace preferences: " + ex.Message);
        }
    }

    private void BuildUxActivityChip(Grid root)
    {
        _uxActivityText = new TextBlock
        {
            Text = "Working…",
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxWidth = 300
        };
        _uxActivityText.SetResourceReference(TextBlock.ForegroundProperty, "PrimaryTextBrush");

        _uxActivityProgress = new ProgressBar
        {
            Width = 90,
            Height = 5,
            Margin = new Thickness(10, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center
        };

        var content = new StackPanel { Orientation = Orientation.Horizontal };
        content.Children.Add(new TextBlock
        {
            Text = "",
            FontFamily = new FontFamily("Segoe MDL2 Assets"),
            FontSize = 14,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        });
        content.Children.Add(_uxActivityText);
        content.Children.Add(_uxActivityProgress);

        _uxActivityChip = new Button
        {
            Content = content,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 12, 18, 0),
            Padding = new Thickness(12, 8, 12, 8),
            MinWidth = 180,
            MaxWidth = 440,
            Visibility = Visibility.Collapsed,
            ToolTip = "Open Task Center"
        };
        _uxActivityChip.Style = (Style)FindResource("FlatButtonStyle");
        AutomationProperties.SetName(_uxActivityChip, "Current PDF task. Open Task Center.");
        _uxActivityChip.Click += (_, _) => OpenUxTaskCenter();
        Grid.SetRow(_uxActivityChip, 1);
        Panel.SetZIndex(_uxActivityChip, 105);
        root.Children.Add(_uxActivityChip);
    }

    private void BuildUxToastHost(Grid root)
    {
        _uxToastHost = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            Width = 370,
            Margin = new Thickness(0, 62, 18, 0),
            IsHitTestVisible = true
        };
        Grid.SetRow(_uxToastHost, 1);
        Panel.SetZIndex(_uxToastHost, 110);
        root.Children.Add(_uxToastHost);
    }

    private void BuildUxOpeningOverlay(Grid root)
    {
        _uxOpeningTitle = new TextBlock
        {
            Text = "Opening PDF",
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            TextAlignment = TextAlignment.Center
        };
        _uxOpeningTitle.SetResourceReference(TextBlock.ForegroundProperty, "PrimaryTextBrush");

        _uxOpeningStage = new TextBlock
        {
            Text = "Reading document structure…",
            FontSize = 13,
            Margin = new Thickness(0, 7, 0, 14),
            HorizontalAlignment = HorizontalAlignment.Center
        };
        _uxOpeningStage.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");

        var progress = new ProgressBar
        {
            Width = 320,
            Height = 7,
            IsIndeterminate = true,
            HorizontalAlignment = HorizontalAlignment.Center
        };

        var skeleton = new StackPanel { Width = 520, Margin = new Thickness(0, 24, 0, 0) };
        for (var i = 0; i < 4; i++)
        {
            var line = new Border
            {
                Height = i == 0 ? 18 : 11,
                Width = i == 0 ? 310 : 450 - i * 42,
                CornerRadius = new CornerRadius(5),
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 10),
                Opacity = i == 0 ? 0.62 : 0.36
            };
            line.SetResourceReference(Border.BackgroundProperty, "PanelHoverBrush");
            skeleton.Children.Add(line);
        }

        var panel = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        panel.Children.Add(_uxOpeningTitle);
        panel.Children.Add(_uxOpeningStage);
        panel.Children.Add(progress);
        panel.Children.Add(skeleton);

        _uxOpeningOverlay = new Border
        {
            Visibility = Visibility.Collapsed,
            Child = panel,
            Margin = new Thickness(220, 0, 0, 0),
            IsHitTestVisible = true
        };
        _uxOpeningOverlay.SetResourceReference(Border.BackgroundProperty, "AppBackground");
        Grid.SetRow(_uxOpeningOverlay, 1);
        Panel.SetZIndex(_uxOpeningOverlay, 96);
        root.Children.Add(_uxOpeningOverlay);
    }

    private void BuildUxDropOverlay(Grid root)
    {
        _uxDropText = new TextBlock
        {
            Text = "Drop to open PDF",
            FontSize = 26,
            FontWeight = FontWeights.SemiBold,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        _uxDropText.SetResourceReference(TextBlock.ForegroundProperty, "PrimaryTextBrush");

        var card = new Border
        {
            Width = 520,
            Height = 190,
            CornerRadius = new CornerRadius(18),
            BorderThickness = new Thickness(2),
            Child = _uxDropText,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        card.SetResourceReference(Border.BackgroundProperty, "PanelRaisedBrush");
        card.SetResourceReference(Border.BorderBrushProperty, "AccentBrush");

        _uxDropOverlay = new Border
        {
            Visibility = Visibility.Collapsed,
            Child = card,
            Margin = new Thickness(220, 0, 0, 0),
            Background = new SolidColorBrush(Color.FromArgb(150, 5, 12, 20)),
            IsHitTestVisible = false
        };
        Grid.SetRow(_uxDropOverlay, 1);
        Panel.SetZIndex(_uxDropOverlay, 118);
        root.Children.Add(_uxDropOverlay);
    }

    private void BuildUxCommandPalette(Grid root)
    {
        _uxCommandBox = new TextBox
        {
            Height = 42,
            FontSize = 15,
            Padding = new Thickness(12, 8, 12, 8),
            Margin = new Thickness(0, 10, 0, 10)
        };
        AutomationProperties.SetName(_uxCommandBox, "Command palette search");
        _uxCommandBox.TextChanged += (_, _) => FilterUxCommands();
        _uxCommandBox.KeyDown += UxCommandBoxKeyDown;

        _uxCommandList = new ListBox
        {
            Height = 330,
            BorderThickness = new Thickness(0),
            Background = Brushes.Transparent,
            FontSize = 13
        };
        _uxCommandList.MouseDoubleClick += async (_, _) => await ExecuteSelectedUxCommandAsync();

        var hint = new TextBlock
        {
            Text = "Type a command or destination. Enter runs it. Esc closes.",
            FontSize = 12,
            Margin = new Thickness(0, 0, 0, 2)
        };
        hint.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");

        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = "Commands and places",
            FontSize = 20,
            FontWeight = FontWeights.SemiBold
        });
        stack.Children.Add(hint);
        stack.Children.Add(_uxCommandBox);
        stack.Children.Add(_uxCommandList);

        var card = new Border
        {
            Width = 660,
            Padding = new Thickness(18),
            CornerRadius = new CornerRadius(14),
            BorderThickness = new Thickness(1),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 54, 0, 0),
            Child = stack
        };
        card.SetResourceReference(Border.BackgroundProperty, "PanelRaisedBrush");
        card.SetResourceReference(Border.BorderBrushProperty, "BorderBrushSoft");

        _uxCommandPaletteLayer = new Grid
        {
            Visibility = Visibility.Collapsed,
            Background = new SolidColorBrush(Color.FromArgb(100, 0, 0, 0))
        };
        _uxCommandPaletteLayer.Children.Add(card);
        _uxCommandPaletteLayer.MouseLeftButtonDown += (_, e) =>
        {
            if (ReferenceEquals(e.OriginalSource, _uxCommandPaletteLayer)) HideUxCommandPalette();
        };
        Grid.SetRow(_uxCommandPaletteLayer, 1);
        Panel.SetZIndex(_uxCommandPaletteLayer, 125);
        root.Children.Add(_uxCommandPaletteLayer);
    }

    private void EnhanceUxDoctorPanel()
    {
        if (HealthSummaryText.Parent is not StackPanel panel) return;

        _uxDoctorProgress = new ProgressBar
        {
            Height = 6,
            Margin = new Thickness(0, 2, 0, 8),
            Visibility = Visibility.Collapsed
        };
        _uxDoctorSeverity = new TextBlock
        {
            FontSize = 12,
            Margin = new Thickness(0, 0, 0, 7),
            TextWrapping = TextWrapping.Wrap,
            Visibility = Visibility.Collapsed
        };
        _uxDoctorSeverity.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");

        var index = panel.Children.IndexOf(HealthSummaryText) + 1;
        panel.Children.Insert(index, _uxDoctorProgress);
        panel.Children.Insert(index + 1, _uxDoctorSeverity);
    }

    private void EnhanceUxStatusStrip()
    {
        if (StatusText.Parent is not StackPanel statusStack) return;

        statusStack.Children.Add(new TextBlock
        {
            Text = "  |  ",
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center
        });
        _uxStatusDetails = new TextBlock
        {
            Text = "",
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxWidth = 310
        };
        _uxStatusDetails.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");
        statusStack.Children.Add(_uxStatusDetails);

        statusStack.Children.Add(new TextBlock
        {
            Text = "  |  ",
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center
        });

        var fileLabel = new TextBlock
        {
            Text = "PDF file",
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center
        };
        fileLabel.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");
        _uxFileDragHandle = new Border
        {
            Child = fileLabel,
            Padding = new Thickness(5, 1, 5, 1),
            CornerRadius = new CornerRadius(4),
            Cursor = Cursors.Hand,
            ToolTip = "Drag the current PDF to Explorer or another file target",
            Visibility = Visibility.Collapsed
        };
        _uxFileDragHandle.SetResourceReference(Border.BackgroundProperty, "PanelHoverBrush");
        AutomationProperties.SetName(_uxFileDragHandle, "Drag current PDF file out of AsantePDF");
        _uxFileDragHandle.MouseLeftButtonDown += (_, e) => _uxFileDragStart = e.GetPosition(this);
        _uxFileDragHandle.MouseMove += UxFileDragHandleMouseMove;
        statusStack.Children.Add(_uxFileDragHandle);
    }

    private void EnhanceUxLocalFirstCard()
    {
        var title = FindUxDescendant<TextBlock>(this, item => item.Text == "Local-first processing");
        if (title?.Parent is not StackPanel content || content.Parent is not Border card) return;
        _uxLocalFirstCard = card;

        if (_uxLocalFirstDismissed)
        {
            card.Visibility = Visibility.Collapsed;
            return;
        }

        card.Child = null;
        var grid = new Grid();
        content.Margin = new Thickness(content.Margin.Left, content.Margin.Top, content.Margin.Right + 24, content.Margin.Bottom);
        grid.Children.Add(content);

        var dismiss = new Button
        {
            Content = "×",
            Width = 25,
            Height = 25,
            Padding = new Thickness(0),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            ToolTip = "Dismiss this privacy note"
        };
        dismiss.Style = (Style)FindResource("FlatButtonStyle");
        AutomationProperties.SetName(dismiss, "Dismiss local-first privacy note");
        dismiss.Click += (_, _) =>
        {
            _uxLocalFirstDismissed = true;
            card.Visibility = Visibility.Collapsed;
            PersistUxWorkspacePreferences();
            ShowUxToast("Privacy note hidden", "Local processing still remains in effect. You can review it again in Settings and diagnostics.");
        };
        grid.Children.Add(dismiss);
        card.Child = grid;
    }

    private void EnhanceUxSplitters()
    {
        foreach (var splitter in new[] { PagesSplitter, InspectorSplitter })
        {
            splitter.Cursor = Cursors.SizeWE;
            splitter.ToolTip = "Drag to resize this panel";
            splitter.Opacity = 0.58;
            splitter.MouseEnter += (_, _) => splitter.Opacity = 1;
            splitter.MouseLeave += (_, _) => splitter.Opacity = 0.58;
            AutomationProperties.SetName(splitter, "Resize document side panel");
        }
    }

    private void EnhanceUxRibbonResponsiveness()
    {
        if (RibbonScrollViewer.Content is not StackPanel ribbon) return;
        _uxMoreRibbonButton = new Button
        {
            Visibility = Visibility.Collapsed,
            ToolTip = "More commands (Ctrl+K)",
            Margin = new Thickness(4, 0, 4, 0)
        };
        _uxMoreRibbonButton.Style = (Style)FindResource("RibbonButtonStyle");
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = "",
            FontFamily = new FontFamily("Segoe MDL2 Assets"),
            FontSize = 21,
            HorizontalAlignment = HorizontalAlignment.Center
        });
        stack.Children.Add(new TextBlock { Text = "More", FontSize = 12, Margin = new Thickness(0, 5, 0, 0) });
        _uxMoreRibbonButton.Content = stack;
        _uxMoreRibbonButton.Click += (_, _) => ShowUxCommandPalette();
        ribbon.Children.Add(_uxMoreRibbonButton);
    }

    private void UpdateUxAdaptiveRibbon()
    {
        if (RibbonScrollViewer.Content is not StackPanel ribbon || _uxMoreRibbonButton is null) return;
        var compact = ActualWidth > 0 && ActualWidth < 1120;
        var moreIndex = ribbon.Children.IndexOf(_uxMoreRibbonButton);
        for (var i = 0; i < moreIndex; i++)
        {
            // Keep File, History, Pages and Edit/Annotate directly visible on narrower windows.
            ribbon.Children[i].Visibility = !compact || i < 4 ? Visibility.Visible : Visibility.Collapsed;
        }
        _uxMoreRibbonButton.Visibility = compact ? Visibility.Visible : Visibility.Collapsed;
        RibbonScrollViewer.HorizontalScrollBarVisibility = compact
            ? ScrollBarVisibility.Hidden
            : ScrollBarVisibility.Visible;
    }

    private void EnhanceUxAccessibilityAndTooltips()
    {
        foreach (var button in FindUxDescendants<Button>(this))
        {
            var label = GetUxButtonLabel(button);
            if (string.IsNullOrWhiteSpace(label)) continue;

            if (string.IsNullOrWhiteSpace(AutomationProperties.GetName(button)))
                AutomationProperties.SetName(button, label);

            var shortcut = GetUxShortcut(label);
            if (button.ToolTip is null)
                button.ToolTip = string.IsNullOrWhiteSpace(shortcut) ? label : $"{label}\n{shortcut}";
            else if (!string.IsNullOrWhiteSpace(shortcut) && button.ToolTip is string text && !text.Contains(shortcut, StringComparison.OrdinalIgnoreCase))
                button.ToolTip = $"{text}\n{shortcut}";

            ToolTipService.SetShowDuration(button, 12000);
        }

        foreach (var text in FindUxDescendants<TextBlock>(this))
        {
            if (text.FontFamily?.Source.Contains("Segoe MDL2", StringComparison.OrdinalIgnoreCase) == true) continue;
            if (text.FontSize > 0 && text.FontSize < 11.5) text.FontSize = 12;
        }

        AutomationProperties.SetHelpText(HomeSearchBox, "Search recent files. Press Ctrl+K anywhere to open the command palette.");
        if (TitleSearchContainer is not null)
            TitleSearchContainer.ToolTip = "Search recent files. Ctrl+K opens commands and destinations.";
    }

    private void BuildUxCommands()
    {
        _uxCommands.Clear();
        _uxCommands.AddRange([
            new UxCommand("Open PDFs", "Open one or several PDFs as document tabs", "Ctrl+O", "open files tabs multiple", UxOpenMultiplePdfsFromDialogAsync),
            new UxCommand("Search current PDF", "Find text in the active document", "Ctrl+F", "find search matches", () => { FocusDocumentSearch(); return Task.CompletedTask; }),
            new UxCommand("Save", "Save page-layout changes to the active PDF", "Ctrl+S", "save document", async () => { await SaveInPlaceAsync(showSuccessMessage: false); }),
            new UxCommand("Save As", "Save the current layout under a new name", "Ctrl+Shift+S", "save copy rename", async () => { await SaveAsCurrentDocumentAsync(showSuccessMessage: false); }),
            new UxCommand("Print", "Print the active PDF", "Ctrl+P", "printer pages", () => { Print_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Undo", "Undo the latest page-layout action", "Ctrl+Z", "history revert", () => { Undo_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Redo", "Redo the latest page-layout action", "Ctrl+Y", "history repeat", () => { Redo_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Compress PDF", "Reduce file size non-destructively", "", "compress optimize size", () => { Compress_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("OCR PDF", "Recognize text in scanned pages", "", "ocr searchable text scan", () => { OcrPdf_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("PDF Doctor", "Inspect structure, security and optimization signals", "", "doctor inspect health repair", () => { Doctor_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Convert to Word", "Create a Word result from the active PDF", "", "convert docx word", () => { PdfToWord_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Convert to Excel", "Create an Excel result from the active PDF", "", "convert xlsx spreadsheet", () => { PdfToExcel_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Convert to PowerPoint", "Create a PowerPoint result from the active PDF", "", "convert pptx slides", () => { PdfToPowerPoint_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Fit Width", "Fit the current PDF page to the viewer width", "", "zoom width", () => { FitWidth_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Fit Page", "Fit the whole current page in the viewer", "", "zoom page", () => { FitPageShell_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Recent documents", "Go to recently opened PDFs", "", "recent history files", () => { HomeRecentNav_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Starred documents", "Go to pinned PDFs", "", "starred pinned favorites", () => { HomeStarredNav_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Task Center", "View running, completed and failed work", "", "tasks progress jobs queue", () => { OpenUxTaskCenter(); return Task.CompletedTask; }),
            new UxCommand("Focus mode", "Hide navigation, ribbon and side panels for reading", "Ctrl+Shift+F", "reading focus full screen", () => { ToggleUxFocusMode(); return Task.CompletedTask; }),
            new UxCommand("Appearance settings", "Choose Light, Dark or Follow Windows", "", "dark light theme appearance", () => { Settings_Click(this, new RoutedEventArgs()); return Task.CompletedTask; }),
            new UxCommand("Show current PDF in folder", "Reveal the active PDF in Explorer", "", "folder explorer location", () => { ShowCurrentPdfInExplorer(); return Task.CompletedTask; }),
            new UxCommand("Copy current PDF path", "Copy the active document path", "", "copy path explorer", () => { CopyCurrentPdfPath(); return Task.CompletedTask; })
        ]);
        FilterUxCommands();
    }

    private void HandleUx60PreviewKeyDown(KeyEventArgs e)
    {
        var ctrl = Keyboard.Modifiers.HasFlag(ModifierKeys.Control);
        var shift = Keyboard.Modifiers.HasFlag(ModifierKeys.Shift);

        if (ctrl && e.Key == Key.K)
        {
            e.Handled = true;
            _ = Dispatcher.BeginInvoke(new Action(ShowUxCommandPalette));
            return;
        }

        if (ctrl && e.Key == Key.O)
        {
            e.Handled = true;
            _ = Dispatcher.BeginInvoke(new Action(() => _ = UxOpenMultiplePdfsFromDialogAsync()));
            return;
        }

        if ((ctrl && shift && e.Key == Key.F) || e.Key == Key.F11)
        {
            e.Handled = true;
            _ = Dispatcher.BeginInvoke(new Action(ToggleUxFocusMode));
            return;
        }

        if (e.Key == Key.Escape && _markupMode != MarkupMode.None)
        {
            e.Handled = true;
            EndMarkupMode("Selection mode restored.");
            ShowUxToast("Selection mode", "Annotation mode ended. You can select and navigate normally again.");
        }
    }

    private void HandleUx60PreviewMouseWheel(MouseWheelEventArgs e)
    {
        if (_currentPdf is null || !Keyboard.Modifiers.HasFlag(ModifierKeys.Control)) return;
        e.Handled = true;
        var factor = e.Delta > 0 ? 1.12 : 1d / 1.12;
        _previewWidth = (uint)Math.Clamp(Math.Round(_previewWidth * factor), 320d, 4000d);
        ClearUxFitState();
        PersistWorkspacePosition();
        _ = RerenderSelectedPageAsync();
    }

    private void UxPreviewMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left) return;
        var button = FindUxAncestor<Button>(e.OriginalSource as DependencyObject);
        if (button is null) return;
        _uxPendingButton = button;
        _uxPendingButtonAt = DateTimeOffset.UtcNow;
    }

    private void UxAnyButtonClick(object sender, RoutedEventArgs e)
    {
        if (e.OriginalSource is not DependencyObject source) return;
        var button = FindUxAncestor<Button>(source);
        if (button is null) return;

        _uxPendingButton = button;
        _uxPendingButtonAt = DateTimeOffset.UtcNow;
        var label = GetUxButtonLabel(button);

        if (label.Contains("Fit Width", StringComparison.OrdinalIgnoreCase)) SetUxFitState(button);
        else if (label.Contains("Fit Page", StringComparison.OrdinalIgnoreCase)) SetUxFitState(button);
        else if (label.Contains("Zoom", StringComparison.OrdinalIgnoreCase) || label.Contains("1:1", StringComparison.OrdinalIgnoreCase)) ClearUxFitState();

        if (label.Equals("Delete", StringComparison.OrdinalIgnoreCase) && _undo.Count > 0)
            ShowUxToast("Pages removed", "The change is still reversible. Press Ctrl+Z to restore the deleted page selection.");

        var candidate = _taskCenterService.Items.FirstOrDefault(item =>
            !item.IsFinished &&
            !_uxTaskButtons.ContainsKey(item.Id) &&
            DateTimeOffset.UtcNow - item.CreatedAt < TimeSpan.FromSeconds(2));
        if (candidate is not null) AttachUxBusyButton(candidate, button);
    }

    private void UxTaskCenterChanged(object? sender, EventArgs e)
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(() => UxTaskCenterChanged(sender, e));
            return;
        }

        foreach (var item in _taskCenterService.Items.ToArray())
        {
            if (!_uxTaskStates.TryGetValue(item.Id, out var previous))
            {
                _uxTaskStates[item.Id] = item.State;
                if (!item.IsFinished)
                {
                    if (_uxPendingButton is not null && DateTimeOffset.UtcNow - _uxPendingButtonAt < TimeSpan.FromSeconds(2))
                        AttachUxBusyButton(item, _uxPendingButton);
                    ShowUxToast(item.Title + " started", "You can continue working. View progress in Task Center.", action: OpenUxTaskCenter, actionLabel: "View progress");
                }
                HandleUxTaskInlineState(item);
                continue;
            }

            if (previous == item.State)
            {
                HandleUxTaskInlineState(item);
                continue;
            }

            _uxTaskStates[item.Id] = item.State;
            if (item.IsFinished) RestoreUxBusyButton(item.Id);

            switch (item.State)
            {
                case PdfJobState.Completed:
                    var completionMessage = !string.IsNullOrWhiteSpace(item.OutputPath)
                        ? $"Ready: {Path.GetFileName(item.OutputPath)}"
                        : "Completed successfully.";
                    ShowUxToast(item.Title, completionMessage,
                        action: item.CanOpenOutput ? () => _ = ShowTaskResultWorkflowAsync(item) : null,
                        actionLabel: item.CanOpenOutput ? "Open result" : "Task Center");
                    if (item.Title.Contains("Saving", StringComparison.OrdinalIgnoreCase))
                        StatusText.Text = $"Saved · {DateTime.Now:HH:mm}";
                    break;
                case PdfJobState.Failed:
                    ShowUxToast(item.Title + " failed", item.ErrorMessage ?? "The operation could not be completed.", true, OpenUxTaskCenter, "View details");
                    break;
                case PdfJobState.Cancelled:
                    ShowUxToast(item.Title + " cancelled", "No unfinished output was published.");
                    break;
            }

            HandleUxTaskInlineState(item);
        }

        RefreshUxActivityChip();
    }

    private void HandleUxTaskInlineState(TaskCenterItem item)
    {
        if (item.Title.Contains("Opening PDF", StringComparison.OrdinalIgnoreCase))
        {
            if (!item.IsFinished)
            {
                ShowUxOpeningOverlay(item);
            }
            else if (item.State == PdfJobState.Completed)
            {
                _uxOpeningWaitingForFirstPage = true;
                if (_uxOpeningStage is not null) _uxOpeningStage.Text = "Rendering first page…";
            }
            else
            {
                HideUxOpeningOverlay();
            }
        }

        if (item.Type == PdfJobType.Inspect || item.Title.Contains("Inspect", StringComparison.OrdinalIgnoreCase) || item.Title.Contains("Doctor", StringComparison.OrdinalIgnoreCase))
        {
            if (!item.IsFinished)
            {
                HealthStatusText.Text = "Analysing…";
                HealthSummaryText.Text = string.IsNullOrWhiteSpace(item.Stage) ? "Reading PDF structure…" : item.Stage;
                HealthText.Text = string.Empty;
                if (_uxDoctorProgress is not null)
                {
                    _uxDoctorProgress.Visibility = Visibility.Visible;
                    _uxDoctorProgress.IsIndeterminate = item.IsIndeterminate;
                    _uxDoctorProgress.Minimum = 0;
                    _uxDoctorProgress.Maximum = 1;
                    _uxDoctorProgress.Value = item.Progress;
                }
                if (_uxDoctorSeverity is not null) _uxDoctorSeverity.Visibility = Visibility.Collapsed;
            }
            else
            {
                if (_uxDoctorProgress is not null) _uxDoctorProgress.Visibility = Visibility.Collapsed;
                if (item.State == PdfJobState.Completed) UpdateUxDoctorSeveritySummary();
            }
        }
    }

    private void RefreshUxActivityChip()
    {
        if (_uxActivityChip is null || _uxActivityText is null || _uxActivityProgress is null) return;
        var active = _taskCenterService.Items.FirstOrDefault(item => item.State is PdfJobState.Running or PdfJobState.Paused)
                     ?? _taskCenterService.Items.FirstOrDefault(item => item.State == PdfJobState.Queued);
        if (active is null)
        {
            _uxActivityChip.Visibility = Visibility.Collapsed;
        }
        else
        {
            _uxActivityChip.Visibility = Visibility.Visible;
            _uxActivityText.Text = active.IsIndeterminate
                ? $"{active.Title} · {active.Stage}"
                : $"{active.Title} · {active.ProgressPercent}%";
            _uxActivityProgress.IsIndeterminate = active.IsIndeterminate;
            _uxActivityProgress.Minimum = 0;
            _uxActivityProgress.Maximum = 1;
            _uxActivityProgress.Value = active.Progress;
            _uxActivityChip.ToolTip = $"{active.Stage}\nOpen Task Center";
        }

        var counts = _taskCenterService.GetCounts();
        var activeCount = counts.Running + counts.Queued;
        if (activeCount > 0)
        {
            TaskCenterActiveCountText.Text = activeCount > 99 ? "99+" : activeCount.ToString("N0");
            TaskCenterActiveBadge.Visibility = Visibility.Visible;
            TaskCenterActiveBadge.SetResourceReference(Border.BackgroundProperty, "AccentBrush");
        }
        else if (counts.Failed > 0)
        {
            TaskCenterActiveCountText.Text = counts.Failed > 99 ? "99+" : counts.Failed.ToString("N0");
            TaskCenterActiveBadge.Visibility = Visibility.Visible;
            TaskCenterActiveBadge.SetResourceReference(Border.BackgroundProperty, "CommandDangerBrush");
        }
        else
        {
            TaskCenterActiveBadge.Visibility = Visibility.Collapsed;
        }
    }

    private void AttachUxBusyButton(TaskCenterItem item, Button button)
    {
        if (_uxTaskButtons.ContainsKey(item.Id) || _uxBusyButtons.ContainsKey(button)) return;
        if (!button.IsVisible) return;

        _uxTaskButtons[item.Id] = button;
        _uxBusyButtons[button] = new UxButtonState(button.Content, button.IsHitTestVisible, button.Focusable, button.ToolTip);

        var progress = new ProgressBar
        {
            Width = 30,
            Height = 5,
            IsIndeterminate = true,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 7, 0)
        };
        var text = new TextBlock
        {
            Text = GetUxBusyLabel(item.Title),
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center
        };
        var stack = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
        stack.Children.Add(progress);
        stack.Children.Add(text);
        button.Content = stack;
        button.IsHitTestVisible = false;
        button.Focusable = false;
        button.ToolTip = $"{item.Stage}\nThis command is already running.";
    }

    private void RestoreUxBusyButton(Guid taskId)
    {
        if (!_uxTaskButtons.Remove(taskId, out var button)) return;
        if (!_uxBusyButtons.Remove(button, out var state)) return;
        button.Content = state.Content;
        button.IsHitTestVisible = state.IsHitTestVisible;
        button.Focusable = state.Focusable;
        button.ToolTip = state.ToolTip;
        UpdateCommandStates();
    }

    private static string GetUxBusyLabel(string title)
    {
        if (title.Contains("Word", StringComparison.OrdinalIgnoreCase) || title.Contains("convert", StringComparison.OrdinalIgnoreCase)) return "Converting…";
        if (title.Contains("inspect", StringComparison.OrdinalIgnoreCase) || title.Contains("doctor", StringComparison.OrdinalIgnoreCase)) return "Analysing…";
        if (title.Contains("save", StringComparison.OrdinalIgnoreCase)) return "Saving…";
        if (title.Contains("open", StringComparison.OrdinalIgnoreCase)) return "Opening…";
        if (title.Contains("compress", StringComparison.OrdinalIgnoreCase)) return "Compressing…";
        if (title.Contains("OCR", StringComparison.OrdinalIgnoreCase)) return "Recognising…";
        return "Working…";
    }

    private void ShowUxToast(string title, string message, bool failure = false, Action? action = null, string actionLabel = "View")
    {
        if (_uxToastHost is null) return;
        var titleText = new TextBlock
        {
            Text = title,
            FontWeight = FontWeights.SemiBold,
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap
        };
        titleText.SetResourceReference(TextBlock.ForegroundProperty, failure ? "CommandDangerBrush" : "PrimaryTextBrush");
        var messageText = new TextBlock
        {
            Text = message,
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 4, 0, 0)
        };
        messageText.SetResourceReference(TextBlock.ForegroundProperty, "MutedTextBrush");

        var stack = new StackPanel();
        stack.Children.Add(titleText);
        stack.Children.Add(messageText);
        if (action is not null)
        {
            var actionButton = new Button
            {
                Content = actionLabel,
                HorizontalAlignment = HorizontalAlignment.Left,
                Padding = new Thickness(9, 4, 9, 4),
                Margin = new Thickness(0, 8, 0, 0)
            };
            actionButton.Style = (Style)FindResource("FlatButtonStyle");
            actionButton.Click += (_, _) => action();
            stack.Children.Add(actionButton);
        }

        var card = new Border
        {
            Child = stack,
            CornerRadius = new CornerRadius(9),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(13, 11, 13, 11),
            Margin = new Thickness(0, 0, 0, 8),
            Opacity = 1
        };
        card.SetResourceReference(Border.BackgroundProperty, "PanelRaisedBrush");
        card.SetResourceReference(Border.BorderBrushProperty, failure ? "CommandDangerBrush" : "BorderBrushSoft");
        _uxToastHost.Children.Insert(0, card);
        while (_uxToastHost.Children.Count > 4) _uxToastHost.Children.RemoveAt(_uxToastHost.Children.Count - 1);

        var timer = new DispatcherTimer { Interval = action is null ? TimeSpan.FromSeconds(4) : TimeSpan.FromSeconds(6) };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            var fade = new DoubleAnimation(0, TimeSpan.FromMilliseconds(180));
            fade.Completed += (_, _) => _uxToastHost.Children.Remove(card);
            card.BeginAnimation(OpacityProperty, fade);
        };
        timer.Start();
    }

    private void ShowUxOpeningOverlay(TaskCenterItem item)
    {
        if (_uxOpeningOverlay is null || _uxOpeningTitle is null || _uxOpeningStage is null) return;
        if (_uxOpeningOverlay.Visibility != Visibility.Visible)
            _uxOpeningPreviousPreview = PreviewImage.Source;
        _uxOpeningWaitingForFirstPage = false;
        _uxOpeningOverlay.Visibility = Visibility.Visible;
        _uxOpeningTitle.Text = _currentPdf is null ? "Opening PDF" : $"Opening {Path.GetFileName(_currentPdf)}";
        _uxOpeningStage.Text = item.IsIndeterminate ? "Reading document structure…" : item.Stage;
    }

    private void HideUxOpeningOverlay()
    {
        if (_uxOpeningOverlay is not null) _uxOpeningOverlay.Visibility = Visibility.Collapsed;
        _uxOpeningWaitingForFirstPage = false;
        _uxOpeningPreviousPreview = null;
    }

    private void UpdateUxDoctorSeveritySummary()
    {
        if (_uxDoctorSeverity is null) return;
        var count = FindingsList.Items.Count;
        if (count == 0)
        {
            _uxDoctorSeverity.Text = "No issues found.";
            _uxDoctorSeverity.Visibility = Visibility.Visible;
            return;
        }

        var groups = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var finding in FindingsList.Items)
        {
            var severity = finding?.GetType().GetProperty("Severity")?.GetValue(finding)?.ToString();
            if (string.IsNullOrWhiteSpace(severity)) severity = "advisory";
            groups[severity] = groups.GetValueOrDefault(severity) + 1;
        }
        var detail = string.Join(" · ", groups.Select(group => $"{group.Value:N0} {group.Key.ToLowerInvariant()}"));
        _uxDoctorSeverity.Text = $"{count:N0} issue{(count == 1 ? string.Empty : "s")} found · {detail}";
        _uxDoctorSeverity.Visibility = Visibility.Visible;
    }

    private void OpenUxTaskCenter()
    {
        if (TaskCenterDrawer.Visibility != Visibility.Visible)
            TaskCenterNav_Click(this, new RoutedEventArgs());
    }

    private void ShowUxCommandPalette(string initialQuery = "")
    {
        if (_uxCommandPaletteLayer is null || _uxCommandBox is null) return;
        _uxCommandPaletteLayer.Visibility = Visibility.Visible;
        _uxCommandBox.Text = initialQuery;
        _uxCommandBox.Focus();
        _uxCommandBox.SelectAll();
        FilterUxCommands();
    }

    private void HideUxCommandPalette()
    {
        if (_uxCommandPaletteLayer is not null) _uxCommandPaletteLayer.Visibility = Visibility.Collapsed;
    }

    private void FilterUxCommands()
    {
        if (_uxCommandList is null) return;
        var query = _uxCommandBox?.Text.Trim() ?? string.Empty;
        var filtered = string.IsNullOrWhiteSpace(query)
            ? _uxCommands
            : _uxCommands.Where(command => command.SearchText.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();
        _uxCommandList.ItemsSource = filtered;
        _uxCommandList.SelectedIndex = filtered.Count > 0 ? 0 : -1;
    }

    private async void UxCommandBoxKeyDown(object sender, KeyEventArgs e)
    {
        if (_uxCommandList is null) return;
        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            HideUxCommandPalette();
            return;
        }
        if (e.Key == Key.Down)
        {
            e.Handled = true;
            _uxCommandList.SelectedIndex = Math.Min(_uxCommandList.Items.Count - 1, _uxCommandList.SelectedIndex + 1);
            _uxCommandList.ScrollIntoView(_uxCommandList.SelectedItem);
            return;
        }
        if (e.Key == Key.Up)
        {
            e.Handled = true;
            _uxCommandList.SelectedIndex = Math.Max(0, _uxCommandList.SelectedIndex - 1);
            _uxCommandList.ScrollIntoView(_uxCommandList.SelectedItem);
            return;
        }
        if (e.Key == Key.Enter)
        {
            e.Handled = true;
            await ExecuteSelectedUxCommandAsync();
        }
    }

    private async Task ExecuteSelectedUxCommandAsync()
    {
        if (_uxCommandList?.SelectedItem is not UxCommand command) return;
        HideUxCommandPalette();
        try
        {
            await command.Execute();
        }
        catch (Exception ex)
        {
            App.Log("Command palette action failed: " + ex);
            ShowUxToast(command.Title + " failed", ex.Message, true);
        }
    }

    private async Task UxOpenMultiplePdfsFromDialogAsync()
    {
        if (_busy) return;
        var dialog = new OpenFileDialog
        {
            Title = "Open PDF files",
            Filter = "PDF files (*.pdf)|*.pdf",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true) return;
        await UxOpenPdfSetAsync(dialog.FileNames);
    }

    private async Task UxOpenPdfSetAsync(IEnumerable<string> paths)
    {
        var pdfs = paths
            .Where(File.Exists)
            .Where(path => string.Equals(Path.GetExtension(path), ".pdf", StringComparison.OrdinalIgnoreCase))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (pdfs.Length == 0) return;

        foreach (var pdf in pdfs)
        {
            await OpenPdfAsync(pdf);
            if (_busy) break;
        }
        if (pdfs.Length > 1)
            ShowUxToast("PDFs opened", $"Opened {pdfs.Length:N0} PDFs as document tabs.");
    }

    private void UxPreviewDragEnter(object sender, DragEventArgs e) => UpdateUxDropOverlay(e.Data);
    private void UxPreviewDragOver(object sender, DragEventArgs e) => UpdateUxDropOverlay(e.Data);
    private void UxPreviewDragLeave(object sender, DragEventArgs e)
    {
        if (_uxDropOverlay is not null) _uxDropOverlay.Visibility = Visibility.Collapsed;
    }

    private async void UxPreviewDrop(object sender, DragEventArgs e)
    {
        if (_uxDropOverlay is not null) _uxDropOverlay.Visibility = Visibility.Collapsed;
        var pdfs = GetDroppedPdfs(e.Data);
        if (pdfs.Length <= 1) return;

        e.Handled = true;
        if (_busy)
        {
            ShowUxToast("PDFs not opened", "Finish or cancel the current foreground operation first.");
            return;
        }
        await UxOpenPdfSetAsync(pdfs);
    }

    private void UpdateUxDropOverlay(IDataObject data)
    {
        if (_uxDropOverlay is null || _uxDropText is null) return;
        var pdfs = GetDroppedPdfs(data);
        var images = GetDroppedImages(data);
        if (pdfs.Length == 0 && images.Length == 0)
        {
            _uxDropOverlay.Visibility = Visibility.Collapsed;
            return;
        }
        _uxDropText.Text = pdfs.Length switch
        {
            > 1 => $"Drop to open {pdfs.Length:N0} PDFs as tabs",
            1 => "Drop to open PDF",
            _ => $"Drop to create PDF from {images.Length:N0} image{(images.Length == 1 ? string.Empty : "s")}" 
        };
        _uxDropOverlay.Visibility = Visibility.Visible;
    }

    private async void UxPagesSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_currentPdf is null || PagesList.SelectedItem is not PdfPageItem selected) return;
        _uxPriorityThumbnailCts?.Cancel();
        _uxPriorityThumbnailCts?.Dispose();
        _uxPriorityThumbnailCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _uxPriorityThumbnailCts.Token;
        var generation = _documentGeneration;

        var sourcePages = new[]
        {
            selected.SourcePageNumber,
            selected.SourcePageNumber - 1,
            selected.SourcePageNumber + 1,
            selected.SourcePageNumber - 2,
            selected.SourcePageNumber + 2
        }
        .Where(page => page >= 1 && page <= _renderer.PageCount)
        .Distinct()
        .ToArray();

        try
        {
            foreach (var sourcePage in sourcePages)
            {
                token.ThrowIfCancellationRequested();
                if (generation != _documentGeneration) return;
                if (_thumbnailCache.ContainsKey(sourcePage)) continue;
                var bitmap = await _renderer.RenderAsync(sourcePage, 160, token);
                if (generation != _documentGeneration) return;
                _thumbnailCache[sourcePage] = bitmap;
                foreach (var page in Pages.Where(item => item.SourcePageNumber == sourcePage))
                    page.Thumbnail = bitmap;
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Priority thumbnail render failed: " + ex.Message);
        }
    }

    private void ToggleUxFocusMode()
    {
        if (_currentPdf is null)
        {
            ShowUxToast("Focus mode", "Open a PDF first.");
            return;
        }
        if (_uxBodyGrid is null || _uxBodyGrid.ColumnDefinitions.Count < 2 || DocumentWorkspaceRoot.RowDefinitions.Count < 2) return;

        _uxFocusMode = !_uxFocusMode;
        if (_uxFocusMode)
        {
            _uxBodyNavigationWidth = _uxBodyGrid.ColumnDefinitions[0].Width;
            _uxRibbonHeight = DocumentWorkspaceRoot.RowDefinitions[1].Height;
            _uxPagesWasCollapsedBeforeFocus = PagesColumn.Width.Value <= 0;
            _uxInspectorWasCollapsedBeforeFocus = InspectorColumn.Width.Value <= 0;
            _uxBodyGrid.ColumnDefinitions[0].Width = new GridLength(0);
            DocumentWorkspaceRoot.RowDefinitions[1].Height = new GridLength(0);
            SetPagesSidebarCollapsed(true);
            SetInspectorCollapsed(true);
            CloseTaskCenterDrawer();
            UpdateUxOverlayMargins();
            ShowUxToast("Focus mode on", "Navigation, ribbon, thumbnails and Inspector are hidden. Press F11 or Ctrl+Shift+F to restore them.");
        }
        else
        {
            _uxBodyGrid.ColumnDefinitions[0].Width = _uxBodyNavigationWidth.Value > 0 ? _uxBodyNavigationWidth : new GridLength(220);
            DocumentWorkspaceRoot.RowDefinitions[1].Height = _uxRibbonHeight.Value > 0 ? _uxRibbonHeight : new GridLength(126);
            if (!_uxPagesWasCollapsedBeforeFocus) SetPagesSidebarCollapsed(false);
            if (!_uxInspectorWasCollapsedBeforeFocus) SetInspectorCollapsed(false);
            UpdateUxOverlayMargins();
            UpdateResponsiveLayout(ActualWidth);
            ShowUxToast("Focus mode off", "Your workspace controls are back.");
        }
    }

    private void UpdateUxOverlayMargins()
    {
        var left = _uxFocusMode ? 0 : 220;
        if (_uxOpeningOverlay is not null) _uxOpeningOverlay.Margin = new Thickness(left, 0, 0, 0);
        if (_uxDropOverlay is not null) _uxDropOverlay.Margin = new Thickness(left, 0, 0, 0);
    }

    private void UxDocumentTabsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        RefreshUxWindowTitle();
        UpdateUxJumpList();
        _ = Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(EnhanceUxDocumentTabMenus));

        if (e.OldItems is null) return;
        foreach (var old in e.OldItems.OfType<DocumentTabSession>())
        {
            var continuing = _taskCenterService.Items.Count(item =>
                !item.IsFinished &&
                !string.IsNullOrWhiteSpace(item.SourcePath) &&
                string.Equals(Path.GetFullPath(item.SourcePath), Path.GetFullPath(old.Path), StringComparison.OrdinalIgnoreCase));
            if (continuing > 0)
                ShowUxToast("Background work continues", $"{continuing:N0} task{(continuing == 1 ? string.Empty : "s")} for {old.Name} will continue in Task Center after the tab closes.", action: OpenUxTaskCenter, actionLabel: "Task Center");
        }
    }

    private void EnhanceUxDocumentTabMenus()
    {
        if (DocumentTabsList.ItemContainerGenerator.Status != GeneratorStatus.ContainersGenerated) return;
        for (var i = 0; i < DocumentTabs.Count; i++)
        {
            if (DocumentTabsList.ItemContainerGenerator.ContainerFromIndex(i) is not ListBoxItem container) continue;
            var host = FindUxDescendant<Grid>(container, grid => grid.ContextMenu is not null);
            var menu = host?.ContextMenu;
            if (menu is null || Equals(menu.Tag, "UX60")) continue;
            menu.Tag = "UX60";
            var tab = DocumentTabs[i];

            menu.Items.Add(new Separator());
            var closeAll = new MenuItem { Header = "Close all tabs" };
            closeAll.Click += async (_, _) =>
            {
                foreach (var current in DocumentTabs.ToArray())
                    if (!await CloseDocumentTabAsync(current)) break;
            };
            menu.Items.Add(closeAll);

            var copyPath = new MenuItem { Header = "Copy file path" };
            copyPath.Click += (_, _) =>
            {
                try { Clipboard.SetText(tab.Path); }
                catch (Exception ex) { App.Log("Copy tab path failed: " + ex.Message); }
            };
            menu.Items.Add(copyPath);
        }
    }

    private void RefreshUxWindowTitle()
    {
        var title = _currentPdf is null ? "AsantePDF" : $"{Path.GetFileName(_currentPdf)} · AsantePDF";
        if (!string.Equals(Title, title, StringComparison.Ordinal)) Title = title;
    }

    private void UpdateUxStatusDetails()
    {
        if (_uxStatusDetails is null || _uxFileDragHandle is null) return;
        if (_currentPdf is null || !File.Exists(_currentPdf))
        {
            _uxStatusDetails.Text = string.Empty;
            _uxStatusDetails.Visibility = Visibility.Collapsed;
            _uxFileDragHandle.Visibility = Visibility.Collapsed;
            return;
        }

        _uxFileDragHandle.Visibility = Visibility.Visible;
        _uxStatusDetails.Visibility = ActualWidth >= 1180 ? Visibility.Visible : Visibility.Collapsed;
        if (_uxStatusDetails.Visibility == Visibility.Visible)
        {
            var info = new FileInfo(_currentPdf);
            var version = string.IsNullOrWhiteSpace(InspectorVersion.Text) || InspectorVersion.Text == "Not checked"
                ? "PDF"
                : $"PDF {InspectorVersion.Text}";
            _uxStatusDetails.Text = $"{FormatBytes(info.Length)} | {version}";
        }
    }

    private void UxFileDragHandleMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || _currentPdf is null || !File.Exists(_currentPdf)) return;
        var point = e.GetPosition(this);
        if (Math.Abs(point.X - _uxFileDragStart.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(point.Y - _uxFileDragStart.Y) < SystemParameters.MinimumVerticalDragDistance)
            return;

        var data = new DataObject(DataFormats.FileDrop, new[] { _currentPdf });
        DragDrop.DoDragDrop(_uxFileDragHandle!, data, DragDropEffects.Copy);
    }

    private void UpdateUxJumpList()
    {
        try
        {
            if (Application.Current is null) return;
            var jumpList = new JumpList
            {
                ShowFrequentCategory = false,
                ShowRecentCategory = false
            };
            foreach (var item in _recentDocuments.LoadItems().Where(item => item.Available).Take(10))
            {
                jumpList.JumpItems.Add(new JumpTask
                {
                    Title = item.Name,
                    Description = item.Path,
                    ApplicationPath = Environment.ProcessPath,
                    Arguments = $"\"{item.Path}\"",
                    CustomCategory = "Recent PDFs"
                });
            }
            JumpList.SetJumpList(Application.Current, jumpList);
            jumpList.Apply();
        }
        catch (Exception ex)
        {
            App.Log("Could not update Windows jump list: " + ex.Message);
        }
    }

    private void ShowCurrentPdfInExplorer()
    {
        if (_currentPdf is null || !File.Exists(_currentPdf)) return;
        try
        {
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{_currentPdf}\"") { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            App.Log("Show current PDF in Explorer failed: " + ex.Message);
        }
    }

    private void CopyCurrentPdfPath()
    {
        if (_currentPdf is null) return;
        try
        {
            Clipboard.SetText(_currentPdf);
            ShowUxToast("Path copied", _currentPdf);
        }
        catch (Exception ex)
        {
            App.Log("Copy current PDF path failed: " + ex.Message);
        }
    }

    private void UxPulse()
    {
        RefreshUxWindowTitle();
        UpdateUxStatusDetails();
        RefreshUxUndoHistory();
        RefreshUxActivityChip();

        if (_uxOpeningWaitingForFirstPage && PreviewImage.Source is not null && !ReferenceEquals(PreviewImage.Source, _uxOpeningPreviousPreview))
            HideUxOpeningOverlay();
    }

    private void RefreshUxUndoHistory()
    {
        if (!string.Equals(_uxUndoDocumentPath, _currentPdf, StringComparison.OrdinalIgnoreCase))
        {
            _uxUndoDocumentPath = _currentPdf;
            _uxUndoLabels.Clear();
            _uxRedoLabels.Clear();
            _uxLastUndoCount = _undo.Count;
            _uxLastRedoCount = _redo.Count;
        }

        var status = StatusText.Text?.Trim();
        if (_undo.Count > _uxLastUndoCount && !string.IsNullOrWhiteSpace(status) &&
            !status.StartsWith("Undid", StringComparison.OrdinalIgnoreCase) &&
            !status.StartsWith("Redid", StringComparison.OrdinalIgnoreCase))
        {
            _uxUndoLabels.Add(status);
            while (_uxUndoLabels.Count > 20) _uxUndoLabels.RemoveAt(0);
            _uxRedoLabels.Clear();
        }
        else if (_undo.Count < _uxLastUndoCount && _uxUndoLabels.Count > 0)
        {
            var label = _uxUndoLabels[^1];
            _uxUndoLabels.RemoveAt(_uxUndoLabels.Count - 1);
            _uxRedoLabels.Add(label);
        }

        if (_redo.Count < _uxLastRedoCount && _uxRedoLabels.Count > 0)
        {
            var label = _uxRedoLabels[^1];
            _uxRedoLabels.RemoveAt(_uxRedoLabels.Count - 1);
            if (_undo.Count > 0) _uxUndoLabels.Add(label);
        }
        if (_redo.Count == 0 && _uxLastRedoCount == 0) _uxRedoLabels.Clear();

        _uxLastUndoCount = _undo.Count;
        _uxLastRedoCount = _redo.Count;
        UpdateUxHistoryButton(UndoButton, _undo.Count, _uxUndoLabels, true);
        UpdateUxHistoryButton(RedoButton, _redo.Count, _uxRedoLabels, false);
    }

    private void UpdateUxHistoryButton(Button button, int count, IReadOnlyList<string> labels, bool undo)
    {
        var action = undo ? "Undo" : "Redo";
        var shortcut = undo ? "Ctrl+Z" : "Ctrl+Y";
        button.ToolTip = count == 0
            ? $"{action} · nothing available\n{shortcut}"
            : $"{action} · {count:N0} step{(count == 1 ? string.Empty : "s")} available\n{(labels.Count > 0 ? labels[^1] : "Page-layout history")}\n{shortcut}";

        var menu = new ContextMenu();
        if (labels.Count == 0)
        {
            menu.Items.Add(new MenuItem { Header = "No named history entries yet", IsEnabled = false });
        }
        else
        {
            var recent = labels.Reverse().Take(10).ToArray();
            for (var i = 0; i < recent.Length; i++)
            {
                var steps = i + 1;
                var item = new MenuItem { Header = $"{steps}. {recent[i]}" };
                item.Click += (_, _) =>
                {
                    for (var step = 0; step < steps; step++)
                    {
                        if (undo) Undo_Click(this, new RoutedEventArgs());
                        else Redo_Click(this, new RoutedEventArgs());
                    }
                };
                menu.Items.Add(item);
            }
        }
        button.ContextMenu = menu;
    }

    private void SetUxFitState(Button button)
    {
        if (_uxActiveFitButton is not null && !ReferenceEquals(_uxActiveFitButton, button))
            _uxActiveFitButton.ClearValue(Control.BackgroundProperty);
        _uxActiveFitButton = button;
        button.SetResourceReference(Control.BackgroundProperty, "PanelPressedBrush");
        button.ToolTip = (button.ToolTip?.ToString() ?? GetUxButtonLabel(button)) + "\nActive view fit mode";
    }

    private void ClearUxFitState()
    {
        _uxActiveFitButton?.ClearValue(Control.BackgroundProperty);
        _uxActiveFitButton = null;
    }

    private static string GetUxShortcut(string label)
    {
        var normalized = label.Trim().ToLowerInvariant();
        return normalized switch
        {
            "open" or "open pdf" => "Ctrl+O",
            "save" => "Ctrl+S",
            "save as" => "Ctrl+Shift+S",
            "print" => "Ctrl+P",
            "undo" => "Ctrl+Z",
            "redo" => "Ctrl+Y",
            "close" or "close tab" => "Ctrl+W",
            _ => string.Empty
        };
    }

    private static string GetUxButtonLabel(Button button)
    {
        if (button.Content is string text && !string.IsNullOrWhiteSpace(text)) return text.Trim();
        var labels = FindUxDescendants<TextBlock>(button)
            .Where(item => item.FontFamily?.Source.Contains("Segoe MDL2", StringComparison.OrdinalIgnoreCase) != true)
            .Select(item => item.Text?.Trim())
            .Where(text => !string.IsNullOrWhiteSpace(text) && text!.Any(char.IsLetterOrDigit))
            .ToArray();
        return labels.LastOrDefault() ?? AutomationProperties.GetName(button) ?? string.Empty;
    }

    private static T? FindUxAncestor<T>(DependencyObject? start) where T : DependencyObject
    {
        var current = start;
        while (current is not null)
        {
            if (current is T typed) return typed;
            current = VisualTreeHelper.GetParent(current);
        }
        return null;
    }

    private static T? FindUxDescendant<T>(DependencyObject root, Func<T, bool> predicate) where T : DependencyObject
    {
        foreach (var item in FindUxDescendants<T>(root))
            if (predicate(item)) return item;
        return null;
    }

    private static IEnumerable<T> FindUxDescendants<T>(DependencyObject root) where T : DependencyObject
    {
        var count = VisualTreeHelper.GetChildrenCount(root);
        for (var i = 0; i < count; i++)
        {
            var child = VisualTreeHelper.GetChild(root, i);
            if (child is T typed) yield return typed;
            foreach (var nested in FindUxDescendants<T>(child)) yield return nested;
        }
    }
}