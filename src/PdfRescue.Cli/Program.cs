using PdfRescue.Core.Diagnostics;
using PdfRescue.Infrastructure.Processes;
using PdfRescue.Infrastructure.Qpdf;

var runner = new ExternalProcessRunner();
var inspector = new QpdfInspector(runner);
var operations = new QpdfOperations(runner);
var doctor = new PdfDoctor(inspector);

if (args.Length == 0)
{
    PrintHelp();
    return 1;
}

try
{
    switch (args[0].ToLowerInvariant())
    {
        case "doctor" when args.Length == 2:
        {
            var report = await doctor.DiagnoseAsync(args[1]);
            Console.WriteLine($"AsantePDF Doctor");
            Console.WriteLine($"File: {report.Inspection.FilePath}");
            Console.WriteLine($"Pages: {report.Inspection.PageCount}");
            Console.WriteLine($"PDF version: {report.Inspection.PdfVersion ?? "Unknown"}");
            Console.WriteLine($"Encrypted: {(report.Inspection.IsEncrypted ? "Yes" : "No")}");
            Console.WriteLine($"Health: {report.HealthScore}%");
            foreach (var issue in report.Issues)
                Console.WriteLine($"[{issue.Severity}] {issue.Title}: {issue.Description}");
            return report.Inspection.HasErrors ? 2 : 0;
        }
        case "merge" when args.Length >= 4:
        {
            var output = args[^1];
            var inputs = args[1..^1];
            await operations.MergeAsync(inputs, output);
            Console.WriteLine($"Merged {inputs.Length} PDFs -> {Path.GetFullPath(output)}");
            return 0;
        }
        case "reorder" when args.Length == 4:
        {
            var pages = args[2].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(int.Parse)
                .ToArray();
            await operations.ReorderAsync(args[1], pages, args[3]);
            Console.WriteLine($"Reordered PDF -> {Path.GetFullPath(args[3])}");
            return 0;
        }
        case "extract" when args.Length == 4:
        {
            await operations.ExtractAsync(args[1], args[2], args[3]);
            Console.WriteLine($"Extracted pages {args[2]} -> {Path.GetFullPath(args[3])}");
            return 0;
        }
        default:
            PrintHelp();
            return 1;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"AsantePDF error: {ex.Message}");
    return 2;
}

static void PrintHelp()
{
    Console.WriteLine("AsantePDF foundation CLI");
    Console.WriteLine();
    Console.WriteLine("Commands:");
    Console.WriteLine("  doctor <file.pdf>");
    Console.WriteLine("  merge <a.pdf> <b.pdf> [more.pdf ...] <output.pdf>");
    Console.WriteLine("  reorder <input.pdf> <page-order e.g. 3,1,2> <output.pdf>");
    Console.WriteLine("  extract <input.pdf> <range e.g. 1-5,9> <output.pdf>");
}
