using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Threading;

namespace PdfRescue.App;

internal static class Ux60AcceptanceFixBootstrap
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
            new Action(window.InitializeUx60AcceptanceFixes));
    }
}

public partial class MainWindow
{
    private bool _ux60AcceptanceFixesInitialized;
    private string? _uxAcceptancePrimaryNavigationState;

    internal void InitializeUx60AcceptanceFixes()
    {
        if (_ux60AcceptanceFixesInitialized || !_productShellInitialized) return;
        _ux60AcceptanceFixesInitialized = true;

        EmptyPanel.IsVisibleChanged += (_, _) => ReconcileUxPrimaryNavigationState();
        DocumentTabs.CollectionChanged += (_, _) =>
            _ = Dispatcher.BeginInvoke(
                DispatcherPriority.Loaded,
                new Action(ReconcileUxPrimaryNavigationState));
        DocumentTabsList.SelectionChanged += (_, _) =>
            _ = Dispatcher.BeginInvoke(
                DispatcherPriority.Loaded,
                new Action(ReconcileUxPrimaryNavigationState));

        if (_uxMoreRibbonButton is not null)
        {
            _uxMoreRibbonButton.ToolTip = "More ribbon commands";
            _uxMoreRibbonButton.Click += UxAcceptanceMoreRibbonButton_Click;
        }

        ReconcileUxPrimaryNavigationState();
        App.Log("UX60 acceptance corrections initialized.");
    }

    private void ReconcileUxPrimaryNavigationState()
    {
        if (!_productShellInitialized) return;

        // Task Center is an intentionally temporary navigation state. Do not steal
        // its selected treatment while the drawer is open.
        if (TaskCenterDrawer is not null && TaskCenterDrawer.Visibility == Visibility.Visible)
            return;

        if (_currentPdf is null)
        {
            if (EmptyPanel.Visibility == Visibility.Visible)
                ApplyUxPrimaryNavigationState(HomeNavButton, "Home");
            return;
        }

        // A document may remain open while the user deliberately visits Home,
        // Recent or Starred. Only claim Active Document when the document workspace
        // itself is the visible primary surface.
        if (EmptyPanel.Visibility != Visibility.Visible)
            ApplyUxPrimaryNavigationState(ActiveDocumentNavButton, "Active Document");
    }

    private void ApplyUxPrimaryNavigationState(Button button, string state)
    {
        if (!Equals(button.Tag, "Active"))
            SetPrimaryNavigationState(button);

        if (string.Equals(_uxAcceptancePrimaryNavigationState, state, StringComparison.Ordinal))
            return;

        _uxAcceptancePrimaryNavigationState = state;
        App.Log($"UX60 primary navigation state: {state}");
    }

    private void UxAcceptanceMoreRibbonButton_Click(object sender, RoutedEventArgs e)
    {
        if (_uxMoreRibbonButton is null || RibbonScrollViewer.Content is not StackPanel ribbon) return;

        // The original UX60 implementation routed More to Ctrl+K. Keep Ctrl+K as a
        // global command palette, but make More a real overflow for commands hidden
        // by the adaptive ribbon.
        if (_uxCommandPaletteLayer is not null)
            _uxCommandPaletteLayer.Visibility = Visibility.Collapsed;

        var menu = new ContextMenu
        {
            PlacementTarget = _uxMoreRibbonButton,
            Placement = PlacementMode.Bottom
        };
        menu.SetResourceReference(Control.BackgroundProperty, "PanelRaisedBrush");
        menu.SetResourceReference(Control.ForegroundProperty, "PrimaryTextBrush");

        var moreIndex = ribbon.Children.IndexOf(_uxMoreRibbonButton);
        var commandCount = 0;
        for (var i = 0; i < moreIndex; i++)
        {
            if (ribbon.Children[i] is not FrameworkElement group || group.Visibility != Visibility.Collapsed)
                continue;

            var buttons = FindUxDescendants<Button>(group)
                .Where(button => !ReferenceEquals(button, _uxMoreRibbonButton))
                .ToArray();
            if (buttons.Length == 0) continue;

            var groupName = FindUxDescendants<TextBlock>(group)
                .Where(text => FindUxAncestor<Button>(text) is null)
                .Select(text => text.Text?.Trim())
                .LastOrDefault(text => !string.IsNullOrWhiteSpace(text)) ?? "Commands";

            if (menu.Items.Count > 0) menu.Items.Add(new Separator());
            menu.Items.Add(new MenuItem
            {
                Header = groupName,
                IsEnabled = false,
                FontWeight = FontWeights.SemiBold
            });

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
                item.Click += (_, _) =>
                    button.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent, button));
                menu.Items.Add(item);
                commandCount++;
            }
        }

        if (commandCount == 0)
            menu.Items.Add(new MenuItem { Header = "No hidden ribbon commands", IsEnabled = false });

        _uxMoreRibbonButton.ContextMenu = menu;
        menu.IsOpen = true;
        App.Log($"UX60 ribbon overflow opened: {commandCount:N0} hidden commands");
    }
}
