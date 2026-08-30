using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;

namespace PdfRescue.App;

internal static class Ux60PageMenuBootstrap
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
        _ = window.Dispatcher.BeginInvoke(new Action(window.InitializeUx60PageMenuEnhancements));
    }
}

public partial class MainWindow
{
    private bool _ux60PageMenusInitialized;
    private ListBoxItem? _uxPageDragTarget;
    private Brush? _uxPageDragTargetBrush;
    private Thickness _uxPageDragTargetThickness;

    internal void InitializeUx60PageMenuEnhancements()
    {
        if (_ux60PageMenusInitialized) return;
        _ux60PageMenusInitialized = true;

        PagesList.ItemContainerGenerator.StatusChanged += (_, _) => EnhanceUxPageContextMenus();
        PagesList.LayoutUpdated += (_, _) => EnhanceUxPageContextMenus();
        PagesList.AddHandler(DragDrop.DragOverEvent, new DragEventHandler(UxPageDragOver), true);
        PagesList.AddHandler(DragDrop.DragLeaveEvent, new DragEventHandler(UxPageDragLeave), true);
        PagesList.AddHandler(DragDrop.DropEvent, new DragEventHandler(UxPageDropFinished), true);
        EnhanceUxPageContextMenus();
    }

    private void EnhanceUxPageContextMenus()
    {
        if (PagesList.ItemContainerGenerator.Status != GeneratorStatus.ContainersGenerated) return;
        for (var i = 0; i < Pages.Count; i++)
        {
            if (PagesList.ItemContainerGenerator.ContainerFromIndex(i) is not ListBoxItem container) continue;
            var card = FindUxDescendant<Border>(container, border => border.ContextMenu is not null);
            var menu = card?.ContextMenu;
            if (menu is null || Equals(menu.Tag, "UX60-PAGES")) continue;
            menu.Tag = "UX60-PAGES";
            var page = Pages[i];

            menu.Items.Insert(0, BuildUxPageMenuItem("Move up", () =>
            {
                EnsureUxPageSelected(page);
                MoveUp_Click(this, new RoutedEventArgs());
            }));
            menu.Items.Insert(1, BuildUxPageMenuItem("Move down", () =>
            {
                EnsureUxPageSelected(page);
                MoveDown_Click(this, new RoutedEventArgs());
            }));
            menu.Items.Insert(2, new Separator());

            menu.Items.Add(new Separator());
            menu.Items.Add(BuildUxPageMenuItem("Insert page copy before", () => InsertUxPageCopy(page, before: true)));
            menu.Items.Add(BuildUxPageMenuItem("Insert page copy after", () => InsertUxPageCopy(page, before: false)));
            menu.Items.Add(BuildUxPageMenuItem("Copy page into working layout", () =>
            {
                EnsureUxPageSelected(page);
                DuplicatePages_Click(this, new RoutedEventArgs());
            }));
            menu.Items.Add(new Separator());
            menu.Items.Add(BuildUxPageMenuItem("Page properties", () => ShowUxPageProperties(page)));
        }
    }

    private static MenuItem BuildUxPageMenuItem(string header, Action action)
    {
        var item = new MenuItem { Header = header };
        item.Click += (_, _) => action();
        return item;
    }

    private void EnsureUxPageSelected(PdfPageItem page)
    {
        if (PagesList.SelectedItems.Contains(page)) return;
        PagesList.SelectedItems.Clear();
        PagesList.SelectedItems.Add(page);
        PagesList.ScrollIntoView(page);
    }

    private void InsertUxPageCopy(PdfPageItem page, bool before)
    {
        if (_busy || !Pages.Contains(page)) return;
        RecordUndoState();
        var index = Pages.IndexOf(page) + (before ? 0 : 1);
        var copy = new PdfPageItem(page.SourcePageNumber, 0)
        {
            Rotation = page.Rotation,
            Thumbnail = page.Thumbnail ?? GetCachedThumbnail(page.SourcePageNumber)
        };
        Pages.Insert(Math.Clamp(index, 0, Pages.Count), copy);
        AfterLayoutChange([copy], before ? "Inserted a page copy before the selected page." : "Inserted a page copy after the selected page.");
        ShowUxToast("Page inserted", "The inserted copy is part of the working layout and can be undone with Ctrl+Z.");
    }

    private void ShowUxPageProperties(PdfPageItem page)
    {
        var details = $"Position: {page.Position:N0}\nSource page: {page.SourcePageNumber:N0}\nRotation: {page.Rotation % 360}°\nDocument: {_currentPdf ?? "No document"}";
        MessageBox.Show(this, details, "Page properties", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void UxPageDragOver(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(PageDragFormat))
        {
            ClearUxPageDragInsertionCue();
            return;
        }

        var target = FindUxAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (ReferenceEquals(target, _uxPageDragTarget)) return;
        ClearUxPageDragInsertionCue();
        if (target is null) return;

        _uxPageDragTarget = target;
        _uxPageDragTargetBrush = target.BorderBrush;
        _uxPageDragTargetThickness = target.BorderThickness;
        target.SetResourceReference(Control.BorderBrushProperty, "AccentBrush");
        target.BorderThickness = new Thickness(0, 3, 0, 0);
    }

    private void UxPageDragLeave(object sender, DragEventArgs e) => ClearUxPageDragInsertionCue();
    private void UxPageDropFinished(object sender, DragEventArgs e) => ClearUxPageDragInsertionCue();

    private void ClearUxPageDragInsertionCue()
    {
        if (_uxPageDragTarget is null) return;
        _uxPageDragTarget.ClearValue(Control.BorderBrushProperty);
        if (_uxPageDragTargetBrush is not null) _uxPageDragTarget.BorderBrush = _uxPageDragTargetBrush;
        _uxPageDragTarget.BorderThickness = _uxPageDragTargetThickness;
        _uxPageDragTarget = null;
        _uxPageDragTargetBrush = null;
    }
}
