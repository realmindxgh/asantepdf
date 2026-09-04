using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;

namespace PdfRescue.App;

internal static class CandidateCRealMachineFixBootstrap
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
        window.QueueCandidateCRealMachineFixInitialization();
    }
}

public partial class MainWindow
{
    private bool _candidateCRealMachineFixesInitialized;
    private bool _candidateCRealMachineFixRetryQueued;

    internal void QueueCandidateCRealMachineFixInitialization()
    {
        if (_candidateCRealMachineFixesInitialized || _candidateCRealMachineFixRetryQueued) return;
        _candidateCRealMachineFixRetryQueued = true;
        _ = Dispatcher.BeginInvoke(
            DispatcherPriority.SystemIdle,
            new Action(() =>
            {
                _candidateCRealMachineFixRetryQueued = false;
                InitializeCandidateCRealMachineFixes();
            }));
    }

    private void InitializeCandidateCRealMachineFixes()
    {
        if (_candidateCRealMachineFixesInitialized) return;

        // The Candidate C failure on the real Windows machine came from a race:
        // the workspace redesign could run before UX60 had created its More control,
        // return from ribbon configuration, and still mark itself initialized.
        // Do not arm the acceptance layer until all of its runtime dependencies exist.
        if (!_productShellInitialized || !_ux60Initialized || _uxMoreRibbonButton is null)
        {
            QueueCandidateCRealMachineFixInitialization();
            return;
        }

        _candidateCRealMachineFixesInitialized = true;

        // Re-apply the complete visual redesign now that every dependency exists.
        CompactWorkspaceChrome();
        RebalanceWorkspaceColumns();
        SimplifyInspectorSurface();

        // Configure is made idempotent here by removing our preview handler first.
        _uxMoreRibbonButton.PreviewMouseLeftButtonDown -= WorkspaceMoreRibbonButton_PreviewMouseLeftButtonDown;
        ConfigureWorkspaceRibbon();
        ApplyWorkspaceRibbonLayout();

        InstallCandidateCScrollbarInvariant();
        InstallCandidateCNavigationInvariant();
        InstallCandidateCPagerInvariant();
        InstallCandidateCQuietToastInvariant();

        // Run once after all existing Loaded/ApplicationIdle callbacks have drained.
        _ = Dispatcher.BeginInvoke(DispatcherPriority.SystemIdle, new Action(() =>
        {
            ApplyCandidateCWorkspaceInvariants();
            App.Log("Candidate C real-machine corrections applied after complete UX60 initialization.");
        }));
    }

    private void InstallCandidateCScrollbarInvariant()
    {
        var descriptor = DependencyPropertyDescriptor.FromProperty(
            ScrollViewer.HorizontalScrollBarVisibilityProperty,
            typeof(ScrollViewer));

        descriptor?.AddValueChanged(RibbonScrollViewer, (_, _) =>
        {
            if (RibbonScrollViewer.HorizontalScrollBarVisibility != ScrollBarVisibility.Hidden)
            {
                RibbonScrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden;
                App.Log("Candidate C invariant corrected ribbon horizontal scrollbar back to Hidden.");
            }
        });

        // Older UX60 SizeChanged code can still run first. Defer our final layout
        // until the complete SizeChanged event has finished so the redesign wins.
        SizeChanged += (_, _) =>
            _ = Dispatcher.BeginInvoke(
                DispatcherPriority.ContextIdle,
                new Action(ApplyCandidateCWorkspaceInvariants));
    }

    private void InstallCandidateCNavigationInvariant()
    {
        foreach (var button in CandidateCPrimaryNavigationButtons())
        {
            var descriptor = DependencyPropertyDescriptor.FromProperty(Button.TagProperty, typeof(Button));
            descriptor?.AddValueChanged(button, (_, _) => ApplyCandidateCNavigationVisuals());
        }
        ApplyCandidateCNavigationVisuals();
    }

    private Button[] CandidateCPrimaryNavigationButtons() =>
    [
        HomeNavButton,
        RecentNavButton,
        StarredNavButton,
        ToolsNavButton,
        DoctorNavButton,
        ActiveDocumentNavButton,
        TaskCenterNavButton
    ];

    private void ApplyCandidateCNavigationVisuals()
    {
        foreach (var button in CandidateCPrimaryNavigationButtons())
        {
            var selected = string.Equals(button.Tag?.ToString(), "Active", StringComparison.OrdinalIgnoreCase);
            if (selected)
            {
                // A four-pixel accent edge is intentionally stronger than the old
                // one-pixel treatment and does not depend on a runtime content wrapper.
                button.BorderThickness = new Thickness(4, 1, 1, 1);
                button.SetResourceReference(Control.BorderBrushProperty, "AccentBrush");
                button.SetResourceReference(Control.BackgroundProperty, "PanelPressedBrush");
                button.FontWeight = FontWeights.Bold;
            }
            else
            {
                button.ClearValue(Control.BorderThicknessProperty);
                button.ClearValue(Control.BorderBrushProperty);
                button.ClearValue(Control.BackgroundProperty);
                button.ClearValue(Control.FontWeightProperty);
            }
        }
    }

    private void InstallCandidateCPagerInvariant()
    {
        Pages.CollectionChanged += (_, _) => QueueCandidateCPagerRefresh();
        PagesList.SelectionChanged += (_, _) => QueueCandidateCPagerRefresh();
        DocumentTabs.CollectionChanged += (_, _) => QueueCandidateCPagerRefresh();
        DocumentTabsList.SelectionChanged += (_, _) => QueueCandidateCPagerRefresh();
        QueueCandidateCPagerRefresh();
    }

    private void QueueCandidateCPagerRefresh()
    {
        _ = Dispatcher.BeginInvoke(
            DispatcherPriority.ContextIdle,
            new Action(() =>
            {
                RefreshWorkspacePager();
                if (_currentPdf is not null && Pages.Count > 0)
                {
                    // The top pager must agree with the same model used by Inspector.
                    PageCountText.Text = $"/ {Pages.Count:N0}";
                    if (!PageNumberBox.IsKeyboardFocusWithin && PagesList.SelectedItem is PdfPageItem selected)
                        PageNumberBox.Text = selected.Position.ToString("N0");
                }
            }));
    }

    private void InstallCandidateCQuietToastInvariant()
    {
        if (_uxToastHost is null) return;
        _uxToastHost.LayoutUpdated += (_, _) =>
        {
            var quietCards = _uxToastHost.Children
                .OfType<Border>()
                .Where(card => FindUxDescendants<TextBlock>(card)
                    .Any(text => string.Equals(text.Text?.Trim(), "Privacy note hidden", StringComparison.OrdinalIgnoreCase)))
                .ToArray();
            foreach (var card in quietCards)
                _uxToastHost.Children.Remove(card);
        };
    }

    private void ApplyCandidateCWorkspaceInvariants()
    {
        if (!_candidateCRealMachineFixesInitialized) return;

        RibbonScrollViewer.HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden;
        RibbonScrollViewer.VerticalScrollBarVisibility = ScrollBarVisibility.Disabled;
        ApplyWorkspaceRibbonLayout();
        RebalanceWorkspaceColumns();
        RefreshWorkspacePager();
        ApplyCandidateCNavigationVisuals();

        if (_currentPdf is not null && Pages.Count > 0)
            PageCountText.Text = $"/ {Pages.Count:N0}";
    }
}
