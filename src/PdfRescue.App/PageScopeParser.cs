namespace PdfRescue.App;

internal static class PageScopeParser
{
    public static bool TryParse(string? text, int pageCount, out int[] positions, out string error)
    {
        positions = [];
        error = string.Empty;
        if (pageCount < 1)
        {
            error = "This PDF has no pages.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(text) || string.Equals(text.Trim(), "all", StringComparison.OrdinalIgnoreCase))
        {
            positions = Enumerable.Range(1, pageCount).ToArray();
            return true;
        }

        var result = new List<int>();
        var seen = new HashSet<int>();
        foreach (var token in text.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            var dash = token.IndexOf('-');
            if (dash < 0)
            {
                if (!int.TryParse(token, out var page) || page < 1 || page > pageCount)
                {
                    error = $"'{token}' is not a valid page number from 1 to {pageCount:N0}.";
                    return false;
                }
                if (seen.Add(page)) result.Add(page);
                continue;
            }

            if (token.IndexOf('-', dash + 1) >= 0 ||
                !int.TryParse(token[..dash].Trim(), out var start) ||
                !int.TryParse(token[(dash + 1)..].Trim(), out var end) ||
                start < 1 || end < start || end > pageCount)
            {
                error = $"'{token}' is not a valid ascending page range within 1 to {pageCount:N0}.";
                return false;
            }

            for (var page = start; page <= end; page++)
                if (seen.Add(page)) result.Add(page);
        }

        if (result.Count == 0)
        {
            error = "Enter at least one page number or range, for example 1-3,5,8-10.";
            return false;
        }

        positions = result.ToArray();
        return true;
    }
}