using System.IO;
using System.Windows;

namespace PdfRescue.App.Services;

public static class OutputPathPolicy
{
    public static string? Resolve(Window owner, string path)
    {
        var full = Path.GetFullPath(path);
        if (!File.Exists(full)) return full;

        return AppSettingsService.Current.Preferences.ExistingOutput switch
        {
            ExistingOutputBehavior.CreateUniqueCopy => CreateUniquePath(full),
            _ => MessageBox.Show(
                    owner,
                    $"An output file named '{Path.GetFileName(full)}' already exists. Replace that output file?\n\nThe source document is not affected by this choice.",
                    "Existing output file",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question) == MessageBoxResult.Yes
                ? full
                : null
        };
    }

    private static string CreateUniquePath(string path)
    {
        var directory = Path.GetDirectoryName(path) ?? Environment.CurrentDirectory;
        var name = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);
        for (var index = 2; index < 10000; index++)
        {
            var candidate = Path.Combine(directory, $"{name} ({index}){extension}");
            if (!File.Exists(candidate)) return candidate;
        }
        return Path.Combine(directory, $"{name}-{Guid.NewGuid():N}{extension}");
    }
}