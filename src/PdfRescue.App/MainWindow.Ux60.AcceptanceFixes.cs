using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
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
}
