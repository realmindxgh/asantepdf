using PdfRescue.Core.Diagnostics;
using PdfRescue.Core.Jobs;
using PdfRescue.Core.Models;
using PdfRescue.Core.Services;
using PdfRescue.Infrastructure.Qpdf;
using PdfRescue.Infrastructure.Processes;

if (args.Length == 1 && args[0] == "--cancellation-child")
{
    await Task.Delay(TimeSpan.FromSeconds(30));
    return 0;
}

var failures = new List<string>();
Run("Job happy path", TestJobHappyPath);
Run("Job rejects invalid transition", TestJobRejectsInvalidTransition);
Run("Progress clamps", TestProgressClamps);
await RunAsync("Queue executes one job", TestQueueAsync);
await RunAsync("Qpdf inspector maps warnings", TestInspectorAsync);
await RunAsync("Doctor scores structural warning", TestDoctorAsync);
await RunAsync("Page layout preserves order and rotations", TestPageLayoutAsync);
await RunAsync("Transactional write preserves destination on failure", TestTransactionalWriteSafetyAsync);
await RunAsync("Compression profile uses expected qpdf options", TestCompressionAsync);
await RunAsync("Sensitive passwords stay out of process arguments", TestSensitiveArgumentsAsync);
await RunAsync("Split stages and publishes multiple files", TestSplitAsync);
await RunAsync("External process cancellation terminates promptly", TestExternalProcessCancellationAsync);

if (failures.Count == 0)
{
    Console.WriteLine("All AsantePDF smoke tests passed.");
    return 0;
}

Console.Error.WriteLine($"{failures.Count} smoke test(s) failed:");
foreach (var failure in failures)
    Console.Error.WriteLine($" - {failure}");
return 1;

void Run(string name, Action test)
{
    try { test(); Console.WriteLine($"PASS  {name}"); }
    catch (Exception ex) { failures.Add($"{name}: {ex.Message}"); Console.WriteLine($"FAIL  {name}"); }
}

async Task RunAsync(string name, Func<Task> test)
{
    try { await test(); Console.WriteLine($"PASS  {name}"); }
    catch (Exception ex) { failures.Add($"{name}: {ex.Message}"); Console.WriteLine($"FAIL  {name}"); }
}

void TestJobHappyPath()
{
    var job = new PdfJob(PdfJobType.Inspect, "Inspect");
    job.TransitionTo(PdfJobState.Queued);
    job.TransitionTo(PdfJobState.Running);
    job.ReportProgress(0.5);
    job.TransitionTo(PdfJobState.Completed);
    Assert(job.State == PdfJobState.Completed, "Job should complete.");
    Assert(Math.Abs(job.Progress - 1) < 0.0001, "Completed job should report 100%.");
}

void TestJobRejectsInvalidTransition()
{
    var job = new PdfJob(PdfJobType.Merge, "Merge");
    var threw = false;
    try { job.TransitionTo(PdfJobState.Completed); }
    catch (InvalidOperationException) { threw = true; }
    Assert(threw, "Created -> Completed must be rejected.");
}

void TestProgressClamps()
{
    var job = new PdfJob(PdfJobType.Ocr, "OCR");
    job.TransitionTo(PdfJobState.Queued);
    job.TransitionTo(PdfJobState.Running);
    job.ReportProgress(9);
    Assert(Math.Abs(job.Progress - 1) < 0.0001, "Progress should clamp to 1.");
}

async Task TestQueueAsync()
{
    await using var queue = new PdfJobQueue();
    var job = new PdfJob(PdfJobType.Inspect, "Queue test");
    var result = await queue.RunAsync(job, async (runningJob, ct) =>
    {
        runningJob.ReportProgress(0.25, "Working");
        await Task.Delay(5, ct);
        return 42;
    });
    Assert(result == 42, "Queue should return operation result.");
    Assert(job.State == PdfJobState.Completed, "Queue should complete the job.");
}

async Task TestInspectorAsync()
{
    var path = Path.Combine(Path.GetTempPath(), $"asantepdf-test-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(path, new byte[2048]);
    try
    {
        var inspector = new QpdfInspector(new FakeQpdfRunner());
        var result = await inspector.InspectAsync(path);
        Assert(result.PageCount == 7, "Inspector should parse page count.");
        Assert(result.PdfVersion == "1.7", "Inspector should parse PDF version.");
        Assert(result.HasWarnings, "Exit code 3 should map to warnings.");
        Assert(!result.HasErrors, "Warnings must not become hard errors.");
        Assert(!result.IsEncrypted, "Exit code 2 from --is-encrypted means not encrypted.");
    }
    finally
    {
        File.Delete(path);
    }
}

async Task TestDoctorAsync()
{
    var path = Path.Combine(Path.GetTempPath(), $"asantepdf-test-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(path, new byte[2048]);
    try
    {
        var doctor = new PdfDoctor(new QpdfInspector(new FakeQpdfRunner()));
        var report = await doctor.DiagnoseAsync(path);
        Assert(report.HealthScore == 85, "A structural warning should currently cost 15 health points.");
        Assert(report.Issues.Any(i => i.Code == "STRUCTURE_WARNING"), "Doctor should surface the structural warning.");
    }
    finally
    {
        File.Delete(path);
    }
}

async Task TestTransactionalWriteSafetyAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-safe-in-{Guid.NewGuid():N}.pdf");
    var output = Path.Combine(Path.GetTempPath(), $"asantepdf-safe-out-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(input, new byte[] { 1, 2, 3 });
    await File.WriteAllBytesAsync(output, new byte[] { 4, 5, 6 });

    try
    {
        var operations = new QpdfOperations(new FailingWriteRunner());
        var threw = false;
        try
        {
            await operations.LinearizeAsync(input, output);
        }
        catch (InvalidDataException)
        {
            threw = true;
        }

        Assert(threw, "A qpdf write failure should be surfaced.");
        Assert((await File.ReadAllBytesAsync(output)).SequenceEqual(new byte[] { 4, 5, 6 }),
            "A failed qpdf write must leave the pre-existing destination untouched.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
        if (File.Exists(output)) File.Delete(output);
    }
}

async Task TestPageLayoutAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-layout-{Guid.NewGuid():N}.pdf");
    var output = Path.Combine(Path.GetTempPath(), $"asantepdf-layout-out-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(input, new byte[] { 1, 2, 3 });
    try
    {
        var runner = new RecordingQpdfRunner();
        var operations = new QpdfOperations(runner);
        await operations.ApplyPageLayoutAsync(
            input,
            [
                new PdfPageTransform(3, 90),
                new PdfPageTransform(1, 180),
                new PdfPageTransform(2, 90)
            ],
            output);

        Assert(File.Exists(output), "Layout operation should create the requested output.");
        Assert(runner.Calls.Count == 2, "Layout with rotations should stage reorder then rotate.");
        Assert(runner.Calls[0].Contains("3,1,2"), "First qpdf pass should preserve requested source page order.");
        Assert(runner.Calls[1].Contains("--rotate=+90:1,3"), "Second qpdf pass should group 90-degree output page rotations.");
        Assert(runner.Calls[1].Contains("--rotate=+180:2"), "Second qpdf pass should apply the 180-degree output page rotation.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
        if (File.Exists(output)) File.Delete(output);
    }
}

async Task TestCompressionAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-compress-{Guid.NewGuid():N}.pdf");
    var output = Path.Combine(Path.GetTempPath(), $"asantepdf-compress-out-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(input, new byte[] { 1, 2, 3 });
    try
    {
        var runner = new RecordingQpdfRunner();
        var operations = new QpdfOperations(runner);
        await operations.CompressAsync(input, PdfCompressionProfile.Strong, output);
        Assert(File.Exists(output), "Compression should create the output file.");
        Assert(runner.Calls.Count == 1, "Compression should use one qpdf pass.");
        Assert(runner.Calls[0].Contains("--object-streams=generate"), "Compression should generate object streams.");
        Assert(runner.Calls[0].Contains("--recompress-flate"), "Compression should recompress flate streams.");
        Assert(runner.Calls[0].Contains("--optimize-images"), "Strong compression should optimize suitable images.");
        Assert(runner.Calls[0].Contains("--jpeg-quality=55"), "Strong compression should use the strong JPEG quality setting.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
        if (File.Exists(output)) File.Delete(output);
    }
}

async Task TestSensitiveArgumentsAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-protect-{Guid.NewGuid():N}.pdf");
    var output = Path.Combine(Path.GetTempPath(), $"asantepdf-protect-out-{Guid.NewGuid():N}.pdf");
    await File.WriteAllBytesAsync(input, new byte[] { 1, 2, 3 });
    try
    {
        var runner = new SensitiveQpdfRunner();
        var operations = new QpdfOperations(runner);
        await operations.ProtectAsync(input, "very secret", "owner secret", output);
        Assert(File.Exists(output), "Protection should create an output file.");
        Assert(runner.ProcessArguments.Count == 1 && runner.ProcessArguments[0].StartsWith('@'),
            "Passwords should be supplied through qpdf's argument-file mechanism rather than directly in process arguments.");
        Assert(runner.SensitiveArguments.Any(line => line == "--user-password=very secret"),
            "The temporary qpdf argument file should contain the opening password.");
        Assert(runner.SensitiveArguments.Any(line => line == "--owner-password=owner secret"),
            "The temporary qpdf argument file should contain the owner password.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
        if (File.Exists(output)) File.Delete(output);
    }
}

async Task TestSplitAsync()
{
    var input = Path.Combine(Path.GetTempPath(), $"asantepdf-split-{Guid.NewGuid():N}.pdf");
    var outputDirectory = Path.Combine(Path.GetTempPath(), $"asantepdf-split-out-{Guid.NewGuid():N}");
    Directory.CreateDirectory(outputDirectory);
    var outputBase = Path.Combine(outputDirectory, "document-split.pdf");
    await File.WriteAllBytesAsync(input, new byte[] { 1, 2, 3 });
    try
    {
        var runner = new SplitQpdfRunner();
        var operations = new QpdfOperations(runner);
        var outputs = await operations.SplitAsync(input, 2, outputBase);
        Assert(outputs.Count == 2, "Split should publish all staged output files.");
        Assert(outputs.All(File.Exists), "All split outputs should exist in the chosen destination folder.");
        Assert(runner.Arguments.Contains("--split-pages=2"), "Split should pass the requested group size to qpdf.");
    }
    finally
    {
        if (File.Exists(input)) File.Delete(input);
        if (Directory.Exists(outputDirectory)) Directory.Delete(outputDirectory, recursive: true);
    }
}


async Task TestExternalProcessCancellationAsync()
{
    var executable = Environment.ProcessPath
        ?? throw new InvalidOperationException("Could not resolve the smoke-test executable path.");
    var childArguments = new List<string>();
    if (string.Equals(
        Path.GetFileNameWithoutExtension(executable),
        "dotnet",
        StringComparison.OrdinalIgnoreCase))
    {
        var entryAssembly = System.Reflection.Assembly.GetEntryAssembly()?.Location;
        if (string.IsNullOrWhiteSpace(entryAssembly))
            throw new InvalidOperationException("Could not resolve the smoke-test entry assembly.");
        childArguments.Add(entryAssembly);
    }
    childArguments.Add("--cancellation-child");

    using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(250));
    var runner = new ExternalProcessRunner();
    var stopwatch = System.Diagnostics.Stopwatch.StartNew();
    var cancelled = false;
    try
    {
        await runner.RunAsync(executable, childArguments, cts.Token);
    }
    catch (OperationCanceledException)
    {
        cancelled = true;
    }
    stopwatch.Stop();

    Assert(cancelled, "ExternalProcessRunner should surface cancellation.");
    Assert(stopwatch.Elapsed < TimeSpan.FromSeconds(5),
        "Cancellation should terminate and drain the child process promptly.");
}

static void Assert(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

sealed class FakeQpdfRunner : IExternalProcessRunner
{
    public Task<ProcessResult> RunAsync(string executable, IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
        if (arguments.Contains("--check"))
            return Task.FromResult(new ProcessResult(3, "checking file\n", "WARNING: recovered damaged xref\n", TimeSpan.FromMilliseconds(1)));
        if (arguments.Contains("--show-npages"))
            return Task.FromResult(new ProcessResult(0, "7\n", "", TimeSpan.FromMilliseconds(1)));
        if (arguments.Contains("--json"))
            return Task.FromResult(new ProcessResult(0, "{\"qpdf\":[{\"jsonversion\":2,\"pdfversion\":\"1.7\"},{}]}", "", TimeSpan.FromMilliseconds(1)));
        if (arguments.Contains("--is-encrypted"))
            return Task.FromResult(new ProcessResult(2, "", "", TimeSpan.FromMilliseconds(1)));

        throw new InvalidOperationException("Unexpected fake qpdf call: " + string.Join(' ', arguments));
    }
}


sealed class RecordingQpdfRunner : IExternalProcessRunner
{
    public List<string[]> Calls { get; } = [];

    public Task<ProcessResult> RunAsync(string executable, IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
        var args = arguments.ToArray();
        Calls.Add(args);

        string? output = null;
        if (args.Contains("--empty"))
            output = args[^1];
        else if (args.Any(argument => argument.StartsWith("--rotate=", StringComparison.Ordinal)))
            output = args.Length > 1 ? args[1] : null;
        output ??= args.FirstOrDefault(argument => argument.EndsWith(".write.pdf", StringComparison.OrdinalIgnoreCase));

        if (!string.IsNullOrWhiteSpace(output))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
            File.WriteAllBytes(output, new byte[] { 9, 8, 7 });
        }

        return Task.FromResult(new ProcessResult(0, string.Empty, string.Empty, TimeSpan.FromMilliseconds(1)));
    }
}


sealed class SensitiveQpdfRunner : IExternalProcessRunner
{
    public IReadOnlyList<string> ProcessArguments { get; private set; } = [];
    public IReadOnlyList<string> SensitiveArguments { get; private set; } = [];

    public Task<ProcessResult> RunAsync(string executable, IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
        ProcessArguments = arguments.ToArray();
        if (arguments.Count != 1 || !arguments[0].StartsWith('@'))
            throw new InvalidOperationException("Expected qpdf argument file.");

        var argumentFile = arguments[0][1..];
        SensitiveArguments = File.ReadAllLines(argumentFile);
        var output = SensitiveArguments.FirstOrDefault(argument => argument.EndsWith(".write.pdf", StringComparison.OrdinalIgnoreCase));
        if (output is null)
            throw new InvalidOperationException("Sensitive qpdf call did not contain a staged output.");

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
        File.WriteAllBytes(output, new byte[] { 7, 7, 7 });
        return Task.FromResult(new ProcessResult(0, string.Empty, string.Empty, TimeSpan.FromMilliseconds(1)));
    }
}

sealed class SplitQpdfRunner : IExternalProcessRunner
{
    public IReadOnlyList<string> Arguments { get; private set; } = [];

    public Task<ProcessResult> RunAsync(string executable, IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
        Arguments = arguments.ToArray();
        var outputBase = arguments[^1];
        var directory = Path.GetDirectoryName(outputBase)!;
        var stem = Path.GetFileNameWithoutExtension(outputBase);
        Directory.CreateDirectory(directory);
        File.WriteAllBytes(Path.Combine(directory, $"{stem}-01-02.pdf"), new byte[] { 1 });
        File.WriteAllBytes(Path.Combine(directory, $"{stem}-03-04.pdf"), new byte[] { 2 });
        return Task.FromResult(new ProcessResult(0, string.Empty, string.Empty, TimeSpan.FromMilliseconds(1)));
    }
}

sealed class FailingWriteRunner : IExternalProcessRunner
{
    public Task<ProcessResult> RunAsync(string executable, IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
        var stagedOutput = arguments.FirstOrDefault(argument =>
            !argument.StartsWith("--", StringComparison.Ordinal) &&
            argument.Contains(".write.pdf", StringComparison.OrdinalIgnoreCase));

        if (!string.IsNullOrWhiteSpace(stagedOutput))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(stagedOutput))!);
            File.WriteAllBytes(stagedOutput, new byte[] { 9, 9, 9 });
        }

        return Task.FromResult(new ProcessResult(2, string.Empty, "simulated qpdf failure", TimeSpan.FromMilliseconds(1)));
    }
}
