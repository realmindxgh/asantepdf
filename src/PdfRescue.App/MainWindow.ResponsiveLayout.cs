using System.Windows;

namespace PdfRescue.App;

public partial class MainWindow
{
    private GridLength _lastInspectorWidth = new(310);
    private bool _inspectorUserCollapsed;
    private bool _inspectorAutoCollapsed;
    private bool _responsiveLayoutInitialized;

    private void InitializeResponsiveLayout()
    {
        if (_responsiveLayoutInitialized) return;
        _responsiveLayoutInitialized = true;
        SizeChanged += MainWindow_ResponsiveSizeChanged;
        Dispatcher.BeginInvoke(new Action(() => UpdateResponsiveLayout(ActualWidth)));
    }

    private void CollapseInspector_Click(object sender, RoutedEventArgs e)
    {
        _inspectorUserCollapsed = true;
        _inspectorAutoCollapsed = false;
        SetInspectorCollapsed(true);
    }

    private void ExpandInspector_Click(object sender, RoutedEventArgs e)
    {
        _inspectorUserCollapsed = false;
        _inspectorAutoCollapsed = false;
        SetInspectorCollapsed(false);
    }

    private void MainWindow_ResponsiveSizeChanged(object sender, SizeChangedEventArgs e) => UpdateResponsiveLayout(e.NewSize.Width);

    private void UpdateResponsiveLayout(double width)
    {
        UpdateResponsiveInspector(width);
        UpdateResponsiveShell(width);
    }

    private void UpdateResponsiveShell(double width)
    {
        if (width <= 0) return;

        if (TitleSearchContainer is not null)
        {
            TitleSearchContainer.Visibility = width < 980 ? Visibility.Collapsed : Visibility.Visible;
            TitleSearchContainer.Width = width < 1200 ? 300 : width < 1450 ? 400 : 520;
        }

        var usable = Math.Max(420, width - 300);
        if (QuickToolsGrid is not null)
            QuickToolsGrid.Columns = usable >= 1220 ? 7 : usable >= 980 ? 5 : usable >= 760 ? 4 : 3;
        if (MoreToolsGrid is not null)
            MoreToolsGrid.Columns = usable >= 1080 ? 5 : usable >= 820 ? 4 : usable >= 620 ? 3 : 2;

        var showHeroArt = width >= 1180;
        if (HomeHeroArt is not null) HomeHeroArt.Visibility = showHeroArt ? Visibility.Visible : Visibility.Collapsed;
        if (HomeHeroArtColumn is not null)
            HomeHeroArtColumn.Width = showHeroArt ? new GridLength(0.95, GridUnitType.Star) : new GridLength(0);

        if (TaskCenterDrawer is not null)
        {
            var productWidth = Math.Max(520, width - 220);
            TaskCenterDrawer.Width = Math.Clamp(productWidth * 0.68, 520, 720);
        }
    }

    private void UpdateResponsiveInspector(double width)
    {
        if (InspectorColumn is null || InspectorBorder is null || InspectorSplitter is null || ExpandInspectorButton is null) return;

        if (width > 0 && width < 1180 && InspectorColumn.Width.Value > 0 && !_inspectorUserCollapsed)
        {
            _inspectorAutoCollapsed = true;
            SetInspectorCollapsed(true);
            return;
        }

        if (width >= 1320 && _inspectorAutoCollapsed && !_inspectorUserCollapsed)
        {
            _inspectorAutoCollapsed = false;
            SetInspectorCollapsed(false);
        }
    }

    private void SetInspectorCollapsed(bool collapsed)
    {
        if (collapsed)
        {
            if (InspectorColumn.Width.Value > 0) _lastInspectorWidth = InspectorColumn.Width;
            InspectorColumn.Width = new GridLength(0);
            InspectorBorder.Visibility = Visibility.Collapsed;
            InspectorSplitter.Visibility = Visibility.Collapsed;
            ExpandInspectorButton.Visibility = Visibility.Visible;
        }
        else
        {
            var width = _lastInspectorWidth.IsAbsolute ? _lastInspectorWidth.Value : 310;
            InspectorColumn.Width = new GridLength(Math.Clamp(width, 260, 460));
            InspectorBorder.Visibility = Visibility.Visible;
            InspectorSplitter.Visibility = Visibility.Visible;
            ExpandInspectorButton.Visibility = Visibility.Collapsed;
        }
    }
}