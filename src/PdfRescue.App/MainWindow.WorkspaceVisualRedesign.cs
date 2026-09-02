using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Threading;

namespace PdfRescue.App;

internal static class WorkspaceVisualRedesignBootstrap
{
    [ModuleInitializer]
    internal static void Install()
    {
        EventManager.RegisterClassHandler(
            typeof(MainWindow),
            FrameworkElement.LoadedEvent,
            new RoutedEventHandler(OnLoaded),
            true);
    }

    private static void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (sender is not MainWindow window || !ReferenceEquals(e.OriginalSource, window)) return;
        _ = window.Dispatcher.BeginInvoke(
            DispatcherPriority.ApplicationIdle,
            new Action(window.InitializeWorkspaceVisualRedesign));
    }
}

public partial class MainWindow
{
    private bool _workspaceVisualRedesignInitialized;

    internal void InitializeWorkspaceVisualRedesign()
    {
        if (_workspaceVisualRedesignInitialized || !_productShellInitialized) return;
        _workspaceVisualRedesignInitialized = true;

        CompactWorkspaceChrome();
        StrengthenPrimaryNavigation();
        RebalanceWorkspaceColumns();
        SimplifyInspectorSurface();
        ConfigureWorkspaceRibbon();
        RefreshWorkspacePager();

        Pages.CollectionChanged += (_, _) => RefreshWorkspacePager();
        PagesList.SelectionChanged += (_, _) => RefreshWorkspacePager();
        SizeChanged += (_, _) =>
        {
            ApplyWorkspaceRibbonLayout();
            RebalanceWorkspaceColumns();
        };

        App.Log("Workspace visual redesign initialized: compact chrome, strong active navigation, no ribbon horizontal scrolling, document-first columns.");
    }

    private void CompactWorkspaceChrome()
    {
        if (DocumentWorkspaceRoot.RowDefinitions.Count >= 4)
        {
            DocumentWorkspaceRoot.RowDefinitions[0].Height = new GridLength(40);
            DocumentWorkspaceRoot.RowDefinitions[1].Height = new GridLength(84);
            DocumentWorkspaceRoot.RowDefinitions[2].Height = new GridLength(42);
            _uxRibbonHeight = new GridLength(84);
        }

        RibbonScrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden;
        RibbonScrollViewer.VerticalScrollBarVisibility = ScrollBarVisibility.Disabled;
        RibbonScrollViewer.PanningMode = PanningMode.None;

        PreviousPageLabel.Visibility = Visibility.Collapsed;
        NextPageLabel.Visibility = Visibility.Collapsed;
        PageNumberBox.Width = 44;
        ZoomPercentBox.Width = 62;
        PageViewModeCombo.Width = 112;
        DocumentSearchBox.Width = 150;
        SearchCountText.Width = 46;
        DocumentSearchContainer.Padding = new Thickness(2);

        AutomationProperties.SetHelpText(RibbonScrollViewer,
            "Primary document commands. Additional commands are available from More. The ribbon never scrolls horizontally.");
    }

    private void StrengthenPrimaryNavigation()
    {
        if (FindResource("NavButtonStyle") is not Style baseStyle) return;

        var style = new Style(typeof(Button), baseStyle);
        var active = new Trigger
        {
            Property = Button.TagProperty,
            Value = "Active"
        };
        active.Setters.Add(new Setter(Control.BackgroundProperty, new DynamicResourceExtension("PanelPressedBrush")));
        active.Setters.Add(new Setter(Control.BorderBrushProperty, new DynamicResourceExtension("AccentBrush")));
        active.Setters.Add(new Setter(Control.BorderThicknessProperty, new Thickness(4, 0, 0, 0)));
        active.Setters.Add(new Setter(Control.FontWeightProperty, FontWeights.Bold));
        style.Triggers.Add(active);

        foreach (var button in new[]
                 {
                     HomeNavButton, RecentNavButton, StarredNavButton, ToolsNavButton,
                     DoctorNavButton, ActiveDocumentNavButton, TaskCenterNavButton
                 })
        {
            button.Style = style;
        }

        ActiveDocumentNavButton.ToolTip = "Current PDF workspace";
        AutomationProperties.SetHelpText(ActiveDocumentNavButton,
            "Returns to the PDF currently open in the document workspace.");
    }

    private void RebalanceWorkspaceColumns()
    {
        if (PagesColumn.Width.Value > 0)
        {
            PagesColumn.MinWidth = 170;
            PagesColumn.MaxWidth = 380;
            if (PagesColumn.Width.Value > 220)
                PagesColumn.Width = new GridLength(220);
        }

        if (InspectorColumn.Width.Value > 0)
        {
            InspectorColumn.MinWidth = 240;
            InspectorColumn.MaxWidth = 380;
            if (InspectorColumn.Width.Value > 275)
                InspectorColumn.Width = new GridLength(275);
        }

        PagesSplitter.Width = 4;
        InspectorSplitter.Width = 4;
        PagesSplitter.Opacity = 0.32;
        InspectorSplitter.Opacity = 0.32;
    }

    private void SimplifyInspectorSurface()
    {
        InspectorBorder.SetResourceReference(Border.BackgroundProperty, "PanelBackground");
        InspectorBorder.BorderThickness = new Thickness(1, 0, 0, 0);
        InspectorContextCard.SetResourceReference(Border.BackgroundProperty, "PanelRaisedBrush");
        InspectorContextCard.SetResourceReference(Border.BorderBrushProperty, "BorderBrushSoft");
        InspectorContextCard.BorderThickness = new Thickness(0);
        InspectorContextCard.CornerRadius = new CornerRadius(7);
        InspectorContextCard.Padding = new Thickness(10);
        InspectorContextCard.Margin = new Thickness(0, 0, 0, 10);

        HealthStatusText.FontSize = 16;
        HealthSummaryText.Margin = new Thickness(0, 0, 0, 6);

        var doctorAction = FindUxDescendants<Button>(InspectorBorder)
            .FirstOrDefault(button => GetUxButtonLabel(button).Contains("Run PDF Doctor", StringComparison.OrdinalIgnoreCase));
        if (doctorAction is not null && FindResource("FlatButtonStyle") is Style flat)
        {
            doctorAction.Style = flat;
            doctorAction.Padding = new Thickness(10, 6, 10, 6);
            doctorAction.Margin = new Thickness(0, 2, 0, 8);
            doctorAction.ToolTip = "Analyse document health";
        }
    }

    private void ConfigureWorkspaceRibbon()
    {
        if (RibbonScrollViewer.Content is not StackPanel ribbon || _uxMoreRibbonButton is null) return;

        _uxMoreRibbonButton.PreviewMouseLeftButtonDown += WorkspaceMoreRibbonButton_PreviewMouseLeftButtonDown;
        _uxMoreRibbonButton.ToolTip = "More document commands";
        _uxMoreRibbonButton.MinWidth = 70;
        _uxMoreRibbonButton.MinHeight = 52;
        _uxMoreRibbonButton.Padding = new Thickness(8, 5, 8, 5);

        var moreContent = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        moreContent.Children.Add(new TextBlock
        {
            Text = "\uE712",
            FontFamily = new FontFamily("Segoe MDL2 Assets"),
            FontSize = 16,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 6, 0)
        });
        moreContent.Children.Add(new TextBlock
        {
            Text = "More",
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center
        });
        _uxMoreRibbonButton.Content = moreContent;

        foreach (var group in ribbon.Children.OfType<Border>())
        {
            group.Background = Brushes.Transparent;
            group.BorderThickness = new Thickness(0, 0, 1, 0);
            group.CornerRadius = new CornerRadius(0);
            group.Margin = new Thickness(0, 5, 0, 5);
            group.Padding = new Thickness(2, 0, 2, 0);

            foreach (var button in FindUxDescendants<Button>(group))
            {
                button.MinWidth = 52;
                button.MinHeight = 54;
                button.Padding = new Thickness(6, 4, 6, 4);
                button.Margin = new Thickness(1);

                if (button.Content is StackPanel content)
                {
                    foreach (var text in content.Children.OfType<TextBlock>())
                    {
                        if (text.FontSize >= 18) text.FontSize = 18;
                        else text.FontSize = 11;
                        if (text.Margin.Top >= 4)
                            text.Margin = new Thickness(text.Margin.Left, 2, text.Margin.Right, text.Margin.Bottom);
                    }
                }
            }
        }

        ApplyWorkspaceRibbonLayout();
    }

    private void ApplyWorkspaceRibbonLayout()
    {
        if (RibbonScrollViewer.Content is not StackPanel ribbon || _uxMoreRibbonButton is null) return;

        RibbonScrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden;
        var groups = ribbon.Children
            .OfType<FrameworkElement>()
            .Where(group => !ReferenceEquals(group, _uxMoreRibbonButton))
            .ToArray();
        if (groups.Length < 6) return;

        var width = ActualWidth <= 0 ? Width : ActualWidth;

        // File is always available. Page commands stay visible whenever practical.
        // Editing is deliberately reduced to the four highest-frequency actions.
        groups[0].Visibility = Visibility.Visible;                         // File
        groups[1].Visibility = width >= 1320 ? Visibility.Visible : Visibility.Collapsed; // History
        groups[2].Visibility = width >= 1020 ? Visibility.Visible : Visibility.Collapsed; // Pages
        groups[3].Visibility = width >= 1200 ? Visibility.Visible : Visibility.Collapsed; // Edit
        groups[4].Visibility = Visibility.Collapsed;                       // Convert -> More
        groups[5].Visibility = Visibility.Collapsed;                       // Optimize -> More

        foreach (var button in FindUxDescendants<Button>(groups[0]))
        {
            var label = GetUxButtonLabel(button);
            button.Visibility = label.Contains("Save Copy", StringComparison.OrdinalIgnoreCase)
                ? Visibility.Collapsed
                : Visibility.Visible;
        }

        foreach (var button in FindUxDescendants<Button>(groups[3]))
        {
            var label = GetUxButtonLabel(button);
            var primary = label.Contains("Edit Text", StringComparison.OrdinalIgnoreCase)
                          || label.Equals("Highlight", StringComparison.OrdinalIgnoreCase)
                          || label.Equals("Note", StringComparison.OrdinalIgnoreCase)
                          || label.Equals("Draw", StringComparison.OrdinalIgnoreCase);
            button.Visibility = primary ? Visibility.Visible : Visibility.Collapsed;
        }

        var hiddenCommands = groups.Sum(group =>
            FindUxDescendants<Button>(group).Count(button =>
                group.Visibility != Visibility.Visible || button.Visibility != Visibility.Visible));
        _uxMoreRibbonButton.Visibility = hiddenCommands > 0 ? Visibility.Visible : Visibility.Collapsed;

        App.Log($"Workspace ribbon layout: width={width:F0}, hidden={hiddenCommands}, horizontal-scroll=Hidden");
    }

    private void WorkspaceMoreRibbonButton_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        e.Handled = true;
        OpenWorkspaceOverflowMenu();
    }

    private void OpenWorkspaceOverflowMenu()
    {
        if (_uxMoreRibbonButton is null || RibbonScrollViewer.Content is not StackPanel ribbon) return;

        var menu = new ContextMenu
        {
            PlacementTarget = _uxMoreRibbonButton,
            Placement = PlacementMode.Bottom
        };
        menu.SetResourceReference(Control.BackgroundProperty, "PanelRaisedBrush");
        menu.SetResourceReference(Control.ForegroundProperty, "PrimaryTextBrush");

        foreach (var group in ribbon.Children.OfType<FrameworkElement>().Where(item => !ReferenceEquals(item, _uxMoreRibbonButton)))
        {
            var buttons = FindUxDescendants<Button>(group)
                .Where(button => group.Visibility != Visibility.Visible || button.Visibility != Visibility.Visible)
                .ToArray();
            if (buttons.Length == 0) continue;

            var groupName = FindUxDescendants<TextBlock>(group)
                .Where(text => FindUxAncestor<Button>(text) is null)
                .Select(text => text.Text?.Trim())
                .LastOrDefault(text => !string.IsNullOrWhiteSpace(text)) ?? "Commands";

            if (menu.Items.Count > 0) menu.Items.Add(new Separator());
            menu.Items.Add(new MenuItem { Header = groupName, IsEnabled = false, FontWeight = FontWeights.SemiBold });

            foreach (var button in buttons)
            {
                var label = GetUxButtonLabel(button);
                if (string.IsNullOrWhiteSpace(label)) continue;
                var item = new MenuItem
                {
                    Header = label,
                    IsEnabled = button.IsEnabled,
                    ToolTip = button.ToolTip,
                    InputGestureText = GetUxShortcut(label)
                };
                item.Click += (_, _) => button.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent, button));
                menu.Items.Add(item);
            }
        }

        if (menu.Items.Count == 0)
            menu.Items.Add(new MenuItem { Header = "All commands are already visible", IsEnabled = false });

        _uxMoreRibbonButton.ContextMenu = menu;
        menu.IsOpen = true;
    }

    private void RefreshWorkspacePager()
    {
        if (PageCountText is null || PageNumberBox is null) return;

        PageCountText.Text = $"/ {Pages.Count:N0}";
        if (!PageNumberBox.IsKeyboardFocusWithin)
        {
            PageNumberBox.Text = PagesList.SelectedItem is PdfPageItem selected
                ? selected.Position.ToString("N0")
                : Pages.Count > 0 ? "1" : string.Empty;
        }
    }
}
