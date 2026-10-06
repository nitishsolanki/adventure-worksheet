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
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Adventure Worksheet</title>
<style>
    :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px; color: #172033; background: linear-gradient(135deg, #eef6ff 0%, #f7f3ff 52%, #fff8ed 100%); }
    .card { width: min(100%, 680px); padding: clamp(32px, 7vw, 64px); text-align: center; background: rgba(255,255,255,.92); border: 1px solid rgba(255,255,255,.8); border-radius: 28px; box-shadow: 0 24px 70px rgba(53, 63, 99, .16); }
    .mark { display: inline-grid; place-items: center; width: 68px; height: 68px; margin-bottom: 20px; border-radius: 20px; font-size: 32px; background: #e9ddff; }
    h1 { margin: 0; font-size: clamp(2rem, 5vw, 3.2rem); letter-spacing: -.04em; }
    .subtitle { margin: 14px 0 0; color: #667085; font-size: 1.05rem; }
    .episode { display: inline-block; margin: 26px 0 30px; padding: 9px 16px; border-radius: 999px; color: #4b2a87; background: #f0e9ff; font-weight: 700; }
    .actions { display: flex; flex-wrap: wrap; justify-content: center; gap: 14px; }
    .button { display: inline-flex; justify-content: center; align-items: center; min-width: 190px; padding: 14px 22px; border-radius: 12px; color: white; text-decoration: none; font-weight: 700; transition: transform .15s ease, box-shadow .15s ease; }
    .button:hover { transform: translateY(-2px); box-shadow: 0 10px 22px rgba(36, 43, 73, .18); }
    .html-button { background: #4f46e5; }
    .pdf-button { background: #e45756; }
    footer { margin-top: 34px; color: #98a2b3; font-size: .86rem; }
</style>
</head>
<body>
<main class="card">
    <div class="mark" aria-hidden="true">🗺️</div>
    <h1>Adventure Worksheet</h1>
    <p class="subtitle">Explore this episode online or download a printable copy.</p>
    <div class="episode">Episode $($selected.DateText)</div>
    <div class="actions">
        <a class="button html-button" href="./current.html">Open HTML version</a>
        <a class="button pdf-button" href="./current.pdf" download>Download PDF</a>
    </div>
    <footer>Updated automatically from Google Drive</footer>
</main>
</body>
</html>
"@
Set-Content -LiteralPath (Join-Path $site 'index.html') -Value $page -Encoding utf8

Write-Output "Selected HTML: $($selected.File.Name)"
Write-Output "Selected PDF:  $(Split-Path $pdfPath -Leaf)"
Write-Output "Episode date:   $($selected.DateText)"
