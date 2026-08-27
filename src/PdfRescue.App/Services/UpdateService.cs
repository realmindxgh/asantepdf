using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;

namespace PdfRescue.App.Services;

public sealed record UpdateInfo(
    string Version,
    string ReleaseUrl,
    string? InstallerName,
    string? InstallerUrl,
    long? InstallerSizeBytes,
    DateTimeOffset? PublishedUtc,
    string Notes);

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
        if (response.StatusCode == HttpStatusCode.NotFound) return null;
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

        string? installerName = null;
        string? installerUrl = null;
        long? installerSize = null;
        if (root.TryGetProperty("assets", out var assetsNode) && assetsNode.ValueKind == JsonValueKind.Array)
        {
            foreach (var asset in assetsNode.EnumerateArray())
            {
                var name = asset.TryGetProperty("name", out var nameNode) ? nameNode.GetString() : null;
                var download = asset.TryGetProperty("browser_download_url", out var downloadNode) ? downloadNode.GetString() : null;
                if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(download)) continue;
                if (!name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) continue;
                if (!name.Contains("AsantePDF", StringComparison.OrdinalIgnoreCase)) continue;

                installerName = name;
                installerUrl = download;
                if (asset.TryGetProperty("size", out var sizeNode) && sizeNode.TryGetInt64(out var bytes))
                    installerSize = bytes;
                break;
            }
        }

        return new UpdateInfo(tag.TrimStart('v', 'V'), url, installerName, installerUrl, installerSize, published, notes);
    }

    public static bool IsNewer(UpdateInfo update) => CompareReleaseVersions(update.Version, CurrentVersion) > 0;

    public static void OpenRelease(UpdateInfo update) =>
        Process.Start(new ProcessStartInfo(update.ReleaseUrl) { UseShellExecute = true });

    public static async Task<string> DownloadInstallerAsync(
        UpdateInfo update,
        IProgress<double>? progress = null,
        CancellationToken token = default)
    {
        if (string.IsNullOrWhiteSpace(update.InstallerUrl))
            throw new InvalidOperationException("This release does not provide an AsantePDF Windows installer asset.");

        var folder = Path.Combine(Path.GetTempPath(), "AsantePDF", "updates", update.Version);
        Directory.CreateDirectory(folder);
        var fileName = Path.GetFileName(string.IsNullOrWhiteSpace(update.InstallerName) ? "AsantePDF Setup.exe" : update.InstallerName);
        var destination = Path.Combine(folder, fileName);
        var staged = destination + ".part";
        try
        {
            if (File.Exists(staged)) File.Delete(staged);
            using var request = new HttpRequestMessage(HttpMethod.Get, update.InstallerUrl);
            using var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token);
            response.EnsureSuccessStatusCode();
            var length = response.Content.Headers.ContentLength ?? update.InstallerSizeBytes;
            await using var input = await response.Content.ReadAsStreamAsync(token);
            await using var output = new FileStream(staged, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
            var buffer = new byte[81920];
            long total = 0;
            while (true)
            {
                var read = await input.ReadAsync(buffer.AsMemory(0, buffer.Length), token);
                if (read == 0) break;
                await output.WriteAsync(buffer.AsMemory(0, read), token);
                total += read;
                if (length is > 0) progress?.Report(Math.Clamp((double)total / length.Value, 0, 1));
            }
            await output.FlushAsync(token);
            token.ThrowIfCancellationRequested();
            File.Move(staged, destination, true);
            progress?.Report(1);
            return destination;
        }
        catch
        {
            try { if (File.Exists(staged)) File.Delete(staged); } catch { }
            throw;
        }
    }

    public static void LaunchInstaller(string installerPath)
    {
        if (!File.Exists(installerPath)) throw new FileNotFoundException("The downloaded AsantePDF installer could not be found.", installerPath);
        Process.Start(new ProcessStartInfo(installerPath, "/CLOSEAPPLICATIONS /NORESTART")
        {
            UseShellExecute = true,
            Verb = "runas"
        });
    }

    private static int CompareReleaseVersions(string left, string right)
    {
        var core = CompareCoreVersions(left, right);
        if (core != 0) return core;

        var leftPre = ParsePrerelease(left);
        var rightPre = ParsePrerelease(right);
        if (leftPre.IsStable && rightPre.IsStable) return 0;
        if (leftPre.IsStable) return 1;
        if (rightPre.IsStable) return -1;

        var rank = leftPre.Rank.CompareTo(rightPre.Rank);
        if (rank != 0) return rank;
        var number = leftPre.Number.CompareTo(rightPre.Number);
        if (number != 0) return number;
        return string.Compare(leftPre.Label, rightPre.Label, StringComparison.OrdinalIgnoreCase);
    }

    private static (bool IsStable, int Rank, int Number, string Label) ParsePrerelease(string value)
    {
        var normalized = value.Trim().TrimStart('v', 'V');
        var dash = normalized.IndexOf('-');
        if (dash < 0 || dash == normalized.Length - 1)
            return (true, int.MaxValue, int.MaxValue, string.Empty);

        var label = normalized[(dash + 1)..].Split('+', 2)[0].Trim().ToLowerInvariant();
        var rank = label.StartsWith("rc", StringComparison.Ordinal) ? 4
            : label.StartsWith("preview", StringComparison.Ordinal) ? 3
            : label.StartsWith("beta", StringComparison.Ordinal) ? 2
            : label.StartsWith("alpha", StringComparison.Ordinal) ? 1
            : 0;
        var digits = new string(label.SkipWhile(ch => !char.IsDigit(ch)).TakeWhile(char.IsDigit).ToArray());
        var number = int.TryParse(digits, out var parsed) ? parsed : 0;
        return (false, rank, number, label);
    }
    private static int CompareCoreVersions(string left, string right)
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
        var client = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("AsantePDF-Windows/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }
}