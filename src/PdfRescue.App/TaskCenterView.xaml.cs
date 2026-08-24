using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Threading;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class TaskCenterView : UserControl
{
    private readonly TaskCenterService _service;
    private readonly ICollectionView _view;
    private readonly DispatcherTimer _elapsedTimer;

    public event Func<TaskCenterItem, Task>? ResultOptionsRequested;

    public TaskCenterView(TaskCenterService service)
    {
        InitializeComponent();
        _service = service;
        TaskList.ItemsSource = service.Items;
        _view = CollectionViewSource.GetDefaultView(service.Items);
        _view.Filter = FilterTask;
        FilterCombo.SelectedIndex = 0;
        _service.Changed += Service_Changed;

        _elapsedTimer = new DispatcherTimer(DispatcherPriority.Background)
        {
            Interval = TimeSpan.FromSeconds(1)
        };
        _elapsedTimer.Tick += (_, _) => _service.RefreshElapsed();
        Loaded += (_, _) =>
        {
            _elapsedTimer.Start();
            RefreshSummary();
        };
        Unloaded += (_, _) => _elapsedTimer.Stop();
        RefreshSummary();
    }

    private bool FilterTask(object item)
    {
        if (item is not TaskCenterItem task) return false;
        return FilterCombo.SelectedIndex switch
        {
            1 => task.State is PdfJobState.Running or PdfJobState.Paused or PdfJobState.Queued,
            2 => task.State == PdfJobState.Completed,
            3 => task.State == PdfJobState.Failed,
            4 => task.State == PdfJobState.Cancelled,
            _ => true
        };
    }

    private void Service_Changed(object? sender, EventArgs e)
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(() => Service_Changed(sender, e));
            return;
        }
        _view.Refresh();
        RefreshSummary();
    }

    private void RefreshSummary()
    {
        var counts = _service.GetCounts();
        RunningCount.Text = counts.Running.ToString("N0");
        QueuedCount.Text = counts.Queued.ToString("N0");
        CompletedCount.Text = counts.Completed.ToString("N0");
        FailedCount.Text = counts.Failed.ToString("N0");
        CancelledCount.Text = counts.Cancelled.ToString("N0");
        EmptyTasks.Visibility = _view.IsEmpty ? Visibility.Visible : Visibility.Collapsed;
        TaskList.Visibility = _view.IsEmpty ? Visibility.Collapsed : Visibility.Visible;
    }

    private void FilterCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _view?.Refresh();
        if (IsLoaded) RefreshSummary();
    }

    private void ClearFinished_Click(object sender, RoutedEventArgs e) => _service.ClearFinished();

    private async void OpenOutput_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: TaskCenterItem item } ||
            !item.CanOpenOutput || string.IsNullOrWhiteSpace(item.OutputPath))
            return;

        var handler = ResultOptionsRequested;
        if (handler is not null) await handler(item);
    }

    private async void RetryTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            await item.RequestRetryAsync();
    }

    private void CancelTask_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: TaskCenterItem item })
            item.RequestCancel();
    }
}
