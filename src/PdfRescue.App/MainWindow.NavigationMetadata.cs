using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private readonly DocumentAnnotationService _documentAnnotations = new();
    private readonly DocumentAttachmentService _documentAttachments = new();
    private CancellationTokenSource? _annotationNavigationCts;
    private CancellationTokenSource? _attachmentNavigationCts;
    private string? _annotationsLoadedForPath;
    private string? _attachmentsLoadedForPath;

    private void InitializeDocumentNavigationMetadata()
    {
        Closed += (_, _) =>
        {
            _annotationNavigationCts?.Cancel();
            _annotationNavigationCts?.Dispose();
            _attachmentNavigationCts?.Cancel();
            _attachmentNavigationCts?.Dispose();
            _annotationNavigationCts = null;
            _attachmentNavigationCts = null;
        };
    }

    private async void PageModeAnnotations_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        ShowAnnotationsSidebar();
        await LoadDocumentAnnotationsAsync();
    }

    private async void PageModeAttachments_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || Pages.Count == 0) return;
        ShowAttachmentsSidebar();
        await LoadDocumentAttachmentsAsync();
    }

    private void ShowAnnotationsSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Visible;
    }

    private void ShowAttachmentsSidebar()
    {
        PagesList.Visibility = Visibility.Collapsed;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Visible;
    }

    private async Task LoadDocumentAnnotationsAsync()
    {
        if (_currentPdf is null) return;
        var path = _currentPdf;
        if (string.Equals(_annotationsLoadedForPath, path, StringComparison.OrdinalIgnoreCase))
        {
            UpdateAnnotationsEmptyState();
            return;
        }

        _annotationNavigationCts?.Cancel();
        _annotationNavigationCts?.Dispose();
        _annotationNavigationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _annotationNavigationCts.Token;
        var generation = _documentGeneration;
        AnnotationsList.ItemsSource = null;
        AnnotationsEmptyText.Text = "Loading comments and annotations…";
        AnnotationsEmptyText.Visibility = Visibility.Visible;

        try
        {
            var annotations = await _documentAnnotations.LoadAsync(path, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase)) return;
            _annotationsLoadedForPath = path;
            AnnotationsList.ItemsSource = annotations;
            UpdateAnnotationsEmptyState();
            StatusText.Text = annotations.Count == 0
                ? "This PDF does not contain comment-style annotations."
                : $"Loaded {annotations.Count:N0} comment/annotation item(s).";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF annotation navigation load failed: " + ex);
            if (generation != _documentGeneration) return;
            AnnotationsList.ItemsSource = null;
            AnnotationsEmptyText.Text = "Could not read this PDF's comments and annotations.";
            AnnotationsEmptyText.Visibility = Visibility.Visible;
            StatusText.Text = "PDF annotation navigation could not be loaded.";
        }
    }

    private async Task LoadDocumentAttachmentsAsync()
    {
        if (_currentPdf is null) return;
        var path = _currentPdf;
        if (string.Equals(_attachmentsLoadedForPath, path, StringComparison.OrdinalIgnoreCase))
        {
            UpdateAttachmentsEmptyState();
            return;
        }

        _attachmentNavigationCts?.Cancel();
        _attachmentNavigationCts?.Dispose();
        _attachmentNavigationCts = CancellationTokenSource.CreateLinkedTokenSource(_lifetime.Token);
        var token = _attachmentNavigationCts.Token;
        var generation = _documentGeneration;
        AttachmentsList.ItemsSource = null;
        AttachmentsEmptyText.Text = "Loading embedded files…";
        AttachmentsEmptyText.Visibility = Visibility.Visible;

        try
        {
            var attachments = await _documentAttachments.LoadAsync(path, token);
            if (token.IsCancellationRequested || generation != _documentGeneration ||
                _currentPdf is null || !string.Equals(path, _currentPdf, StringComparison.OrdinalIgnoreCase)) return;
            _attachmentsLoadedForPath = path;
            AttachmentsList.ItemsSource = attachments;
            UpdateAttachmentsEmptyState();
            StatusText.Text = attachments.Count == 0
                ? "This PDF does not contain embedded file attachments."
                : $"Loaded {attachments.Count:N0} embedded file attachment(s).";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF attachment navigation load failed: " + ex);
            if (generation != _documentGeneration) return;
            AttachmentsList.ItemsSource = null;
            AttachmentsEmptyText.Text = "Could not read this PDF's embedded attachments.";
            AttachmentsEmptyText.Visibility = Visibility.Visible;
            StatusText.Text = "PDF attachment navigation could not be loaded.";
        }
    }

    private void UpdateAnnotationsEmptyState()
    {
        var hasItems = AnnotationsList.Items.Count > 0;
        AnnotationsList.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        AnnotationsEmptyText.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;
        if (!hasItems) AnnotationsEmptyText.Text = "This PDF does not contain comment-style annotations.";
    }

    private void UpdateAttachmentsEmptyState()
    {
        var hasItems = AttachmentsList.Items.Count > 0;
        AttachmentsList.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        SaveAttachmentButton.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        AttachmentsEmptyText.Visibility = hasItems ? Visibility.Collapsed : Visibility.Visible;
        if (!hasItems) AttachmentsEmptyText.Text = "This PDF does not contain embedded file attachments.";
    }

    private void AnnotationsList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selectedPdfAnnotation = AnnotationsList.SelectedItem as PdfAnnotationItem;
        if (_selectedPdfAnnotation is not PdfAnnotationItem annotation)
        {
            UpdateInspectorContext();
            return;
        }
        var target = Pages.FirstOrDefault(page => page.SourcePageNumber == annotation.SourcePageNumber);
        if (target is null)
        {
            StatusText.Text = $"This annotation belongs to source page {annotation.SourcePageNumber:N0}, which is not in the working layout.";
            return;
        }
        PagesList.SelectedItem = target;
        PagesList.ScrollIntoView(target);
        StatusText.Text = $"Opened {annotation.TypeLabel.ToLowerInvariant()} on page {target.Position:N0}.";
        UpdateInspectorContext();
    }

    private async void SaveAttachment_Click(object sender, RoutedEventArgs e)
    {
        if (_currentPdf is null || AttachmentsList.SelectedItem is not PdfAttachmentItem attachment) return;
        var suggestedName = Path.GetFileName(attachment.DisplayName);
        if (string.IsNullOrWhiteSpace(suggestedName)) suggestedName = $"attachment-{attachment.Index + 1:N0}.bin";
        var dialog = new SaveFileDialog
        {
            Title = "Save embedded PDF attachment",
            FileName = suggestedName,
            Filter = "All files (*.*)|*.*",
            AddExtension = false,
            OverwritePrompt = true
        };
        if (dialog.ShowDialog(this) != true) return;

        var sourcePath = _currentPdf;
        try
        {
            StatusText.Text = $"Extracting {attachment.DisplayName}…";
            var bytes = await _documentAttachments.ReadFileAsync(sourcePath, attachment.Index, _lifetime.Token);
            await File.WriteAllBytesAsync(dialog.FileName, bytes, _lifetime.Token);
            StatusText.Text = $"Saved embedded attachment: {Path.GetFileName(dialog.FileName)}";
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("PDF attachment extraction failed: " + ex);
            MessageBox.Show(this, "The embedded attachment could not be saved.\n\n" + ex.Message,
                "AsantePDF", MessageBoxButton.OK, MessageBoxImage.Warning);
            StatusText.Text = "Embedded attachment extraction failed.";
        }
    }

    private void ResetDocumentNavigationMetadataForDocumentChange()
    {
        _annotationNavigationCts?.Cancel();
        _annotationNavigationCts?.Dispose();
        _annotationNavigationCts = null;
        _attachmentNavigationCts?.Cancel();
        _attachmentNavigationCts?.Dispose();
        _attachmentNavigationCts = null;
        _annotationsLoadedForPath = null;
        _attachmentsLoadedForPath = null;
        _selectedPdfAnnotation = null;

        if (!_productShellInitialized || AnnotationsList is null || AttachmentsList is null) return;
        AnnotationsList.ItemsSource = null;
        AttachmentsList.ItemsSource = null;
        PagesList.Visibility = Visibility.Visible;
        BookmarksPanel.Visibility = Visibility.Collapsed;
        SearchResultsPanel.Visibility = Visibility.Collapsed;
        AnnotationsPanel.Visibility = Visibility.Collapsed;
        AttachmentsPanel.Visibility = Visibility.Collapsed;
        SaveAttachmentButton.Visibility = Visibility.Collapsed;
    }
}