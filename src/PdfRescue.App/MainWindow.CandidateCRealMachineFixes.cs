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

        // Candidate C exposed an ordering race on the real Windows machine. The
        // workspace redesign could run before UX60 created its More control, return
        // from ribbon configuration, and still mark itself initialized. Do not arm
        // this acceptance layer until every runtime dependency really exists.
        if (!_productShellInitialized || !_ux60Initialized || _uxMoreRibbonButton is null)
        {
            QueueCandidateCRealMachineFixInitialization();
            return;
        }

        _candidateCRealMachineFixesInitialized = true;

        // Re-apply the complete visual redesign after the shared UX layer is ready.
        CompactWorkspaceChrome();
        RebalanceWorkspaceColumns();
        SimplifyInspectorSurface();

        // Configure is idempotent for the preview handler here.
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

        // The older UX60 SizeChanged handler may run first. Defer our final layout
        // until the complete SizeChanged event has drained so the redesign always wins.
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
                // one-pixel treatment and does not depend on a timing-sensitive
                // runtime content wrapper.
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
                    // The top pager must agree with the same page model used by Inspector.
                    PageCountText.Text = $"/ {Pages.Count:N0}";
                    if (!PageNumberBox.IsKeyboardFocusWithin && PagesList.SelectedItem is PdfPageItem selected)
                        PageNumberBox.Text = selected.Position.ToString("N0");
                    App.Log($"Candidate C pager invariant: model={Pages.Count:N0} display={PageCountText.Text}");
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
        {
            PageCountText.Text = $"/ {Pages.Count:N0}";
            App.Log($"Candidate C pager invariant: model={Pages.Count:N0} display={PageCountText.Text}");
        }

        var active = CandidateCPrimaryNavigationButtons()
            .FirstOrDefault(button => string.Equals(button.Tag?.ToString(), "Active", StringComparison.OrdinalIgnoreCase));
        var activeLabel = ReferenceEquals(active, ActiveDocumentNavButton) ? "ActiveDocument"
            : ReferenceEquals(active, HomeNavButton) ? "Home"
            : ReferenceEquals(active, RecentNavButton) ? "Recent"
            : ReferenceEquals(active, StarredNavButton) ? "Starred"
            : ReferenceEquals(active, ToolsNavButton) ? "Tools"
            : ReferenceEquals(active, DoctorNavButton) ? "Doctor"
            : ReferenceEquals(active, TaskCenterNavButton) ? "TaskCenter"
            : "None";
        App.Log($"Candidate C navigation invariant: active={activeLabel} left-border={active?.BorderThickness.Left ?? 0:F0}");
    }

    internal void AssertCandidateCRealMachineAcceptanceState()
    {
        if (!_candidateCRealMachineFixesInitialized)
            throw new InvalidOperationException("Candidate C real-machine correction layer did not initialize.");

        if (RibbonScrollViewer.HorizontalScrollBarVisibility != ScrollBarVisibility.Hidden)
            throw new InvalidOperationException($"Ribbon horizontal scrollbar regressed to {RibbonScrollViewer.HorizontalScrollBarVisibility}.");

        if (_uxMoreRibbonButton is null || _uxMoreRibbonButton.Visibility != Visibility.Visible)
            throw new InvalidOperationException("The real ribbon overflow control is not visible.");

        if (_currentPdf is not null && Pages.Count > 0)
        {
            var expected = $"/ {Pages.Count:N0}";
            if (!string.Equals(PageCountText.Text, expected, StringComparison.Ordinal))
                throw new InvalidOperationException($"Pager mismatch: expected '{expected}', got '{PageCountText.Text}'.");

            if (!string.Equals(ActiveDocumentNavButton.Tag?.ToString(), "Active", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Active Document is not the selected primary destination while the PDF workspace is visible.");

            if (ActiveDocumentNavButton.BorderThickness.Left < 4)
                throw new InvalidOperationException($"Active Document accent edge is too weak: {ActiveDocumentNavButton.BorderThickness.Left:F1}px.");
        }

        if (_uxToastHost is not null)
        {
            var privacyToastVisible = _uxToastHost.Children
                .OfType<Border>()
                .Any(card => FindUxDescendants<TextBlock>(card)
                    .Any(text => string.Equals(text.Text?.Trim(), "Privacy note hidden", StringComparison.OrdinalIgnoreCase)));
            if (privacyToastVisible)
                throw new InvalidOperationException("Nonessential privacy-dismiss toast is still covering the document workspace.");
        }

        App.Log("Candidate C real-machine acceptance assertions passed.");
    }
}
