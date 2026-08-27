using System.IO;
using System.Printing;
using System.Windows;
using System.Windows.Controls;
using PdfRescue.App.Services;
using PdfRescue.Core.Models;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly PdfPrintService _printService = new();

    private async void Print_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0 || _busy) return;
        var selected = SelectedPages().Select(page => page.Position).ToArray();
        var current = PagesList.SelectedItem is PdfPageItem item ? item.Position : 1;
        var optionsWindow = new PrintOptionsWindow(Pages.Count, current, selected) { Owner = this };
        if (optionsWindow.ShowDialog() != true || optionsWindow.Options is null) return;

        var printDialog = new PrintDialog();
        if (printDialog.ShowDialog() != true) return;
        if (optionsWindow.Options.Landscape)
            printDialog.PrintTicket.PageOrientation = PageOrientation.Landscape;

        var working = _currentPdf;
        string? snapshot = null;
        try
        {
            if (HasLayoutChanges())
            {
                var directory = Path.Combine(Path.GetTempPath(), "AsantePDF", "print");
                Directory.CreateDirectory(directory);
                snapshot = Path.Combine(directory, Guid.NewGuid().ToString("N") + ".pdf");
                var transforms = Pages.Select(page => new PdfPageTransform(page.SourcePageNumber, page.Rotation)).ToArray();
                await _operations.ApplyPageLayoutAsync(_currentPdf, transforms, snapshot, _lifetime.Token);
                working = snapshot;
            }

            var printed = await RunBusyAsync("Preparing print job...", async token =>
            {
                var document = await _printService.BuildAsync(
                    working,
                    optionsWindow.Options.Pages,
                    printDialog.PrintableAreaWidth,
                    printDialog.PrintableAreaHeight,
                    optionsWindow.Options.Landscape,
                    optionsWindow.Options.FitToPrintableArea,
                    token);
                token.ThrowIfCancellationRequested();
                printDialog.PrintDocument(document.DocumentPaginator, Path.GetFileName(_currentPdf));
            });
            if (printed) StatusText.Text = "Print job sent to the selected printer.";
        }
        finally
        {
            try { if (snapshot is not null && File.Exists(snapshot)) File.Delete(snapshot); } catch { }
        }
    }
}