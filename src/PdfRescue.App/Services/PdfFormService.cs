using System.IO;
using PdfSharp.Pdf;
using PdfSharp.Pdf.AcroForms;
using PdfSharp.Pdf.IO;

namespace PdfRescue.App.Services;

public sealed record PdfFormFieldInfo(string Name, string Kind, string Value, bool Writable);

public sealed class PdfFormService
{
    public IReadOnlyList<PdfFormFieldInfo> ReadFields(string inputPath)
    {
        var input = Path.GetFullPath(inputPath);
        if (!File.Exists(input)) throw new FileNotFoundException("PDF was not found.", input);

        using var document = PdfReader.Open(input, PdfDocumentOpenMode.Import);
        try
        {
            var fields = document.AcroForm.Fields;
            var names = fields.DescendantNames ?? Array.Empty<string>();
            var result = new List<PdfFormFieldInfo>(names.Length);
            foreach (var name in names.Distinct(StringComparer.Ordinal))
            {
                var field = fields[name];
                if (field is null) continue;
                result.Add(ToInfo(name, field));
            }
            return result;
        }
        catch (Exception ex) when (ex is InvalidOperationException or NullReferenceException)
        {
            return Array.Empty<PdfFormFieldInfo>();
        }
    }

    public Task FillAsync(
        string inputPath,
        string outputPath,
        IReadOnlyDictionary<string, string> values,
        CancellationToken token = default)
    {
        return Task.Run(() =>
        {
            var input = Path.GetFullPath(inputPath);
            var output = Path.GetFullPath(outputPath);
            if (!File.Exists(input)) throw new FileNotFoundException("PDF was not found.", input);
            if (string.Equals(input, output, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Choose a different output file. AsantePDF never overwrites the source PDF.");
            Directory.CreateDirectory(Path.GetDirectoryName(output)!);

            var staged = output + "." + Guid.NewGuid().ToString("N") + ".staged.pdf";
            try
            {
                using var document = PdfReader.Open(input, PdfDocumentOpenMode.Modify);
                var form = document.AcroForm;
                form.Elements["/NeedAppearances"] = new PdfBoolean(true);
                var fields = form.Fields;

                foreach (var entry in values)
                {
                    token.ThrowIfCancellationRequested();
                    var field = fields[entry.Key];
                    if (field is null || field.ReadOnly) continue;
                    SetValue(field, entry.Value ?? string.Empty);
                }

                token.ThrowIfCancellationRequested();
                document.Save(staged);
                token.ThrowIfCancellationRequested();
                CommitTransactional(staged, output);
            }
            finally
            {
                TryDelete(staged);
            }
        }, token);
    }


    private static void CommitTransactional(string staged, string output)
    {
        if (File.Exists(output))
            File.Replace(staged, output, null, true);
        else
            File.Move(staged, output);
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path)) File.Delete(path);
        }
        catch
        {
            // Best-effort cleanup must never hide the actual form operation result.
        }
    }

    private static PdfFormFieldInfo ToInfo(string name, PdfAcroField field) => field switch
    {
        PdfTextField text => new(name, "Text", text.Text ?? string.Empty, !field.ReadOnly),
        PdfCheckBoxField check => new(name, "Checkbox", check.Checked ? "true" : "false", !field.ReadOnly),
        PdfRadioButtonField radio => new(name, "Radio", radio.SelectedIndex.ToString(), !field.ReadOnly),
        PdfComboBoxField combo => new(name, "Combo", combo.SelectedIndex.ToString(), !field.ReadOnly),
        PdfListBoxField list => new(name, "List", list.SelectedIndex.ToString(), !field.ReadOnly),
        PdfSignatureField => new(name, "Signature", "", false),
        _ => new(name, "Other", field.Value?.ToString() ?? string.Empty, !field.ReadOnly)
    };

    private static void SetValue(PdfAcroField field, string value)
    {
        switch (field)
        {
            case PdfTextField text:
                text.Text = value;
                break;
            case PdfCheckBoxField check:
                check.Checked = value.Equals("true", StringComparison.OrdinalIgnoreCase) ||
                                value.Equals("yes", StringComparison.OrdinalIgnoreCase) ||
                                value == "1";
                break;
            case PdfRadioButtonField radio:
                radio.SelectedIndex = ParseIndex(value);
                break;
            case PdfComboBoxField combo:
                combo.SelectedIndex = ParseIndex(value);
                break;
            case PdfListBoxField list:
                list.SelectedIndex = ParseIndex(value);
                break;
            case PdfSignatureField:
                break;
            default:
                field.Value = new PdfString(value);
                break;
        }
    }

    private static int ParseIndex(string value) =>
        int.TryParse(value, out var index) && index >= 0 ? index : 0;
}
