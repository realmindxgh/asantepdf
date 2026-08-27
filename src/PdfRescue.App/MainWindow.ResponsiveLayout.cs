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
        Dispatcher.BeginInvoke(new Action(() => UpdateResponsiveInspector(ActualWidth)));
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

    private void MainWindow_ResponsiveSizeChanged(object sender, SizeChangedEventArgs e) =>
        UpdateResponsiveInspector(e.NewSize.Width);

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
            if (InspectorColumn.Width.Value > 0)
                _lastInspectorWidth = InspectorColumn.Width;
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