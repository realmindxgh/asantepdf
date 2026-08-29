param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [ValidateRange(1, 50)]
    [int]$PageCount = 1
)

$ErrorActionPreference = 'Stop'
$encoding = [System.Text.Encoding]::ASCII
$fontObject = 3 + (2 * $PageCount)
$kids = @()
$objects = New-Object System.Collections.Generic.List[string]
$objects.Add('<< /Type /Catalog /Pages 2 0 R >>')
$objects.Add('')
for ($pageIndex = 0; $pageIndex -lt $PageCount; $pageIndex++) {
    $pageObject = 3 + (2 * $pageIndex)
    $contentObject = $pageObject + 1
    $kids += "$pageObject 0 R"
    $objects.Add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 $fontObject 0 R >> >> /Contents $contentObject 0 R >>")
    $content = "BT`n/F1 24 Tf`n72 700 Td`n(AsantePDF runtime page $($pageIndex + 1)) Tj`nET`n"
    $contentLength = $encoding.GetByteCount($content)
    $objects.Add("<< /Length $contentLength >>`nstream`n$content" + 'endstream')
}
$objects[1] = "<< /Type /Pages /Kids [$($kids -join ' ')] /Count $PageCount >>"
$objects.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')

$builder = New-Object System.Text.StringBuilder
[void]$builder.Append("%PDF-1.4`n")
$offsets = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $objects.Count; $i++) {
    $offsets.Add($encoding.GetByteCount($builder.ToString()))
    [void]$builder.Append(($i + 1).ToString()).Append(" 0 obj`n")
    [void]$builder.Append($objects[$i]).Append("`nendobj`n")
}
$xrefOffset = $encoding.GetByteCount($builder.ToString())
$size = $objects.Count + 1
[void]$builder.Append("xref`n0 $size`n")
[void]$builder.Append("0000000000 65535 f `n")
foreach ($offset in $offsets) {
    [void]$builder.Append($offset.ToString('D10')).Append(" 00000 n `n")
}
[void]$builder.Append("trailer`n<< /Size $size /Root 1 0 R >>`n")
[void]$builder.Append("startxref`n").Append($xrefOffset).Append("`n%%EOF`n")

$full = [System.IO.Path]::GetFullPath($OutputPath)
$directory = [System.IO.Path]::GetDirectoryName($full)
if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
[System.IO.File]::WriteAllBytes($full, $encoding.GetBytes($builder.ToString()))
Write-Host "Created $PageCount-page PDF test fixture: $full"