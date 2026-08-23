param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$encoding = [System.Text.Encoding]::ASCII
$objects = @(
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    $null,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
)
$content = "BT`n/F1 24 Tf`n72 700 Td`n(AsantePDF release test) Tj`nET`n"
$contentLength = $encoding.GetByteCount($content)
$objects[3] = "<< /Length $contentLength >>`nstream`n$content" + 'endstream'

$builder = New-Object System.Text.StringBuilder
[void]$builder.Append("%PDF-1.4`n")
$offsets = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $objects.Count; $i++) {
    $offsets.Add($encoding.GetByteCount($builder.ToString()))
    [void]$builder.Append(($i + 1).ToString()).Append(" 0 obj`n")
    [void]$builder.Append($objects[$i]).Append("`nendobj`n")
}
$xrefOffset = $encoding.GetByteCount($builder.ToString())
[void]$builder.Append("xref`n0 6`n")
[void]$builder.Append("0000000000 65535 f `n")
foreach ($offset in $offsets) {
    [void]$builder.Append($offset.ToString('D10')).Append(" 00000 n `n")
}
[void]$builder.Append("trailer`n<< /Size 6 /Root 1 0 R >>`n")
[void]$builder.Append("startxref`n").Append($xrefOffset).Append("`n%%EOF`n")

$full = [System.IO.Path]::GetFullPath($OutputPath)
$directory = [System.IO.Path]::GetDirectoryName($full)
if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
[System.IO.File]::WriteAllBytes($full, $encoding.GetBytes($builder.ToString()))
Write-Host "Created PDF test fixture: $full"
