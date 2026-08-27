using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PdfRescue.App.Services;

public enum AppThemeMode
{
    Light,
    Dark,
    FollowWindows
}

public enum DefaultPageViewMode
{
    SinglePage,
    Continuous,
    TwoPage
}

public sealed record AppPreferences
{
    public AppThemeMode Theme { get; init; } = AppThemeMode.Dark;
    public uint DefaultRenderWidth { get; init; } = 1100;
    public DefaultPageViewMode DefaultPageView { get; init; } = DefaultPageViewMode.SinglePage;
    public bool ReopenLastSession { get; init; } = true;
    public bool TrackRecentFiles { get; init; } = true;
    public bool ShowRecentThumbnails { get; init; } = true;
    public string DefaultOcrLanguage { get; init; } = "eng";
    public string DefaultOutputFolder { get; init; } = string.Empty;
    public string OutputNamePattern { get; init; } = "{name}-{operation}";
    public bool RecoveryEnabled { get; init; } = true;
    public bool CheckForUpdates { get; init; } = true;
    public bool FirstLaunchCompleted { get; init; }
}

public sealed class AppSettingsService
{
    private readonly object _sync = new();
    private readonly JsonSerializerOptions _jsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private static readonly Lazy<AppSettingsService> LazyCurrent = new(() => new AppSettingsService());
    public static AppSettingsService Current => LazyCurrent.Value;

    private static string RootDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AsantePDF");
    private static string SettingsPath => Path.Combine(RootDirectory, "settings.json");

    private AppPreferences _preferences;

    private AppSettingsService() => _preferences = LoadCore();

    public AppPreferences Preferences
    {
        get { lock (_sync) return _preferences; }
    }

    public event EventHandler? Changed;

    public void Save(AppPreferences preferences)
    {
        if (preferences is null) throw new ArgumentNullException(nameof(preferences));
        var normalized = preferences with
        {
            DefaultRenderWidth = Math.Clamp(preferences.DefaultRenderWidth, 320u, 4000u),
            DefaultOcrLanguage = string.IsNullOrWhiteSpace(preferences.DefaultOcrLanguage) ? "eng" : preferences.DefaultOcrLanguage.Trim(),
            DefaultOutputFolder = preferences.DefaultOutputFolder?.Trim() ?? string.Empty,
            OutputNamePattern = string.IsNullOrWhiteSpace(preferences.OutputNamePattern) ? "{name}-{operation}" : preferences.OutputNamePattern.Trim()
        };

        lock (_sync)
        {
            _preferences = normalized;
            Directory.CreateDirectory(RootDirectory);
            var staged = SettingsPath + ".tmp";
            File.WriteAllText(staged, JsonSerializer.Serialize(normalized, _jsonOptions), Encoding.UTF8);
            File.Move(staged, SettingsPath, true);
        }
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private AppPreferences LoadCore()
    {
        try
        {
            if (!File.Exists(SettingsPath)) return new AppPreferences();
            return JsonSerializer.Deserialize<AppPreferences>(File.ReadAllText(SettingsPath), _jsonOptions) ?? new AppPreferences();
        }
        catch (Exception ex)
        {
            App.Log("Could not read settings.json: " + ex.Message);
            return new AppPreferences();
        }
    }
}