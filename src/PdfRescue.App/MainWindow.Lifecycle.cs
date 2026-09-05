using System.IO;
using System.Windows;
using System.Windows.Threading;
using PdfRescue.App.Services;

namespace PdfRescue.App;

public partial class MainWindow
{
    private RecoverySnapshot? _pendingRecoverySnapshot;
    private UpdateInfo? _availableUpdate;

    private async Task OfferStartupRecoveryAndOnboardingAsync()
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (preferences.RecoveryEnabled && _pendingRecoverySnapshot is { Documents.Count: > 0 } snapshot)
        {
            var recovery = new RecoveryWindow(snapshot) { Owner = this };
            if (recovery.ShowDialog() == true)
                await RestoreRecoverySnapshotAsync(snapshot);
            else
                RecoverySnapshotService.Current.DiscardSnapshot();
        }

        preferences = AppSettingsService.Current.Preferences;
        if (!preferences.FirstLaunchCompleted && !App.StartedWithPdfArgument)
        {
            var firstLaunch = new FirstLaunchWindow { Owner = this };
            if (firstLaunch.ShowDialog() == true)
                AppSettingsService.Current.Save(AppSettingsService.Current.Preferences with { FirstLaunchCompleted = true });
        }

        if (AppSettingsService.Current.Preferences.CheckForUpdates)
            _ = CheckForUpdatesSilentlyAsync();
    }

    private async Task RestoreRecoverySnapshotAsync(RecoverySnapshot snapshot)
    {
        var available = snapshot.Documents.Where(document => File.Exists(document.Path)).ToArray();
        if (available.Length == 0) return;

        foreach (var state in available)
        {
            if (DocumentTabs.Any(tab => string.Equals(tab.Path, state.Path, StringComparison.OrdinalIgnoreCase))) continue;
            DocumentTabs.Add(new DocumentTabSession(state.Path)
            {
                IsDirty = state.IsDirty,
                SelectedPage = state.SelectedPage,
                PreviewWidth = state.PreviewWidth,
                HorizontalOffset = state.HorizontalOffset,
                VerticalOffset = state.VerticalOffset,
                WorkingLayout = state.WorkingLayout.ToArray(),
                SavedLayout = state.SavedLayout.ToArray(),
                UndoHistory = state.UndoHistory.ToArray(),
                RedoHistory = state.RedoHistory.ToArray()
            });
        }

        var targetIndex = Math.Clamp(snapshot.ActiveDocumentIndex, 0, Math.Max(0, available.Length - 1));
        var targetPath = available[targetIndex].Path;
        var target = DocumentTabs.FirstOrDefault(tab => string.Equals(tab.Path, targetPath, StringComparison.OrdinalIgnoreCase))
                     ?? DocumentTabs.FirstOrDefault(tab => File.Exists(tab.Path));
        if (target is not null)
        {
            await ActivateDocumentTabAsync(target);
            StatusText.Text = available.Any(document => document.IsDirty)
                ? $"Recovered {available.Length:N0} PDF tab(s), including unsaved page-layout state."
                : $"Recovered {available.Length:N0} PDF tab(s) from the interrupted session.";
        }
        PersistWorkspacePosition(immediate: true);
    }

    private async Task CheckForUpdatesSilentlyAsync()
    {
        try
        {
            var update = await UpdateService.CheckAsync(_lifetime.Token);
            if (update is null || !UpdateService.IsNewer(update)) return;
            _availableUpdate = update;
            if (SettingsButton is not null)
                SettingsButton.ToolTip = $"Settings · AsantePDF {update.Version} update available";
            App.Log($"Update available: {update.Version}");
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            App.Log("Silent update check failed: " + ex.Message);
        }
    }

    private void SaveRecoverySnapshot()
    {
        var preferences = AppSettingsService.Current.Preferences;
        if (!preferences.RecoveryEnabled)
        {
            RecoverySnapshotService.Current.DiscardSnapshot();
            return;
        }
        RecoverySnapshotService.Current.SaveSnapshot(DocumentTabs, GetActiveDocumentTabIndex());
    }
}