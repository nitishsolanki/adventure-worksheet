[CmdletBinding()]
param(
    [string]$SourceDirectory,
    [string]$SiteDirectory,
    [datetime]$Today = (Get-Date)
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $SourceDirectory) { $SourceDirectory = Join-Path $scriptRoot '..\content' }
if (-not $SiteDirectory) { $SiteDirectory = Join-Path $scriptRoot '..\site' }
$source = (Resolve-Path $SourceDirectory).Path
$site = [IO.Path]::GetFullPath($SiteDirectory)
New-Item -ItemType Directory -Force -Path $site | Out-Null

$htmlFiles = Get-ChildItem -LiteralPath $source -File -Filter 'G1_*_episode.html' |
    Where-Object { $_.Name -match '^G1_(\d{4}-\d{2}-\d{2})_episode\.html$' }

if (-not $htmlFiles) { throw "No files matching G1_YYYY-MM-DD_episode.html were found in $source." }

$candidates = foreach ($file in $htmlFiles) {
    $date = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
    [pscustomobject]@{ File = $file; Date = $date; DateText = $Matches[1] }
}

$selected = $candidates | Where-Object Date -eq $Today.Date | Select-Object -First 1
if (-not $selected) { $selected = $candidates | Sort-Object Date -Descending | Select-Object -First 1 }

$pdfPath = Join-Path $source "G1_$($selected.DateText).pdf"
if (-not (Test-Path -LiteralPath $pdfPath -PathType Leaf)) {
    throw "Matching PDF was not found: G1_$($selected.DateText).pdf"
}
if ($selected.File.Length -eq 0) { throw "Selected HTML file is empty: $($selected.File.Name)" }

Copy-Item -LiteralPath $selected.File.FullName -Destination (Join-Path $site 'current.html') -Force
Copy-Item -LiteralPath $pdfPath -Destination (Join-Path $site 'current.pdf') -Force

$page = @"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Adventure Worksheet</title></head>
<body>
<main>
<h1>Adventure Worksheet</h1>
<p>Episode: $($selected.DateText)</p>
<p><a href="./current.html">Open HTML version</a></p>
<p><a href="./current.pdf">Download PDF</a></p>
</main>
</body>
</html>
"@
Set-Content -LiteralPath (Join-Path $site 'index.html') -Value $page -Encoding utf8

Write-Output "Selected HTML: $($selected.File.Name)"
Write-Output "Selected PDF:  $(Split-Path $pdfPath -Leaf)"
Write-Output "Episode date:   $($selected.DateText)"
