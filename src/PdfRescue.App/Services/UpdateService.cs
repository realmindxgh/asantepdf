using System.Diagnostics;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace PdfRescue.App.Services;

public sealed record UpdateInfo(string Version, string ReleaseUrl, DateTimeOffset? PublishedUtc, string Notes);

public static class UpdateService
{
    private const string LatestReleaseApi = "https://api.github.com/repos/realmindxgh/asantepdf/releases/latest";
    private static readonly HttpClient Client = CreateClient();

    public static string CurrentVersion => typeof(UpdateService).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
        .InformationalVersion?
        .Split('+', 2)[0] ?? "1.0.0";

    public static async Task<UpdateInfo?> CheckAsync(CancellationToken token = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, LatestReleaseApi);
        using var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(token);
        using var json = await JsonDocument.ParseAsync(stream, cancellationToken: token);
        var root = json.RootElement;
        var tag = root.TryGetProperty("tag_name", out var tagNode) ? tagNode.GetString() : null;
        var url = root.TryGetProperty("html_url", out var urlNode) ? urlNode.GetString() : null;
        var notes = root.TryGetProperty("body", out var bodyNode) ? bodyNode.GetString() ?? string.Empty : string.Empty;
        DateTimeOffset? published = null;
        if (root.TryGetProperty("published_at", out var dateNode) && DateTimeOffset.TryParse(dateNode.GetString(), out var parsed))
            published = parsed;
        if (string.IsNullOrWhiteSpace(tag) || string.IsNullOrWhiteSpace(url)) return null;
        return new UpdateInfo(tag.TrimStart('v', 'V'), url, published, notes);
    }

    public static bool IsNewer(UpdateInfo update) => CompareVersions(update.Version, CurrentVersion) > 0;

    public static void OpenRelease(UpdateInfo update) =>
        Process.Start(new ProcessStartInfo(update.ReleaseUrl) { UseShellExecute = true });

    private static int CompareVersions(string left, string right)
    {
        static Version Parse(string value)
        {
            var core = value.Trim().TrimStart('v', 'V').Split('-', 2)[0];
            return Version.TryParse(core, out var parsed) ? parsed : new Version(0, 0);
        }
        return Parse(left).CompareTo(Parse(right));
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AsantePDF-Windows/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }
}