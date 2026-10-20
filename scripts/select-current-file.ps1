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

function Get-SelectedEpisode {
    param([Parameter(Mandatory)][string]$Grade)

    $htmlFiles = Get-ChildItem -LiteralPath $source -File -Filter "${Grade}_*_episode.html" |
        Where-Object { $_.Name -match "^${Grade}_(\d{4}-\d{2}-\d{2})_episode\.html$" }
    if (-not $htmlFiles) {
        throw "No files matching ${Grade}_YYYY-MM-DD_episode.html were found in $source."
    }

    $candidates = foreach ($file in $htmlFiles) {
        $match = [regex]::Match($file.Name, "^${Grade}_(\d{4}-\d{2}-\d{2})_episode\.html$")
        $dateText = $match.Groups[1].Value
        $date = [datetime]::MinValue
        if (-not [datetime]::TryParseExact(
                $dateText,
                'yyyy-MM-dd',
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None,
                [ref]$date
            )) {
            continue
        }
        [pscustomobject]@{ File = $file; Date = $date; DateText = $dateText }
    }

    $selected = $candidates | Where-Object Date -eq $Today.Date | Select-Object -First 1
    if (-not $selected) {
        $selected = $candidates | Sort-Object Date -Descending | Select-Object -First 1
    }
    if (-not $selected) {
        throw "No valid dated ${Grade} episode HTML files were found in $source."
    }
    if ($selected.File.Length -eq 0) {
        throw "Selected HTML file is empty: $($selected.File.Name)"
    }

    $prefix = "${Grade}_$($selected.DateText)"
    $questionsPath = Join-Path $source "$prefix.pdf"
    $answersPath = Join-Path $source "${prefix}_answers.pdf"
    foreach ($requiredPath in @($questionsPath, $answersPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required file was not found for $Grade episode $($selected.DateText): $(Split-Path $requiredPath -Leaf)"
        }
        if ((Get-Item -LiteralPath $requiredPath).Length -eq 0) {
            throw "Required file is empty: $(Split-Path $requiredPath -Leaf)"
        }
    }

    return [pscustomobject]@{
        Grade = $Grade
        Selected = $selected
        QuestionsPath = $questionsPath
        AnswersPath = $answersPath
    }
}

$gradeNames = Get-ChildItem -LiteralPath $source -File -Filter '*_episode.html' |
    ForEach-Object {
        $match = [regex]::Match($_.Name, '^(K|G\d+)_\d{4}-\d{2}-\d{2}_episode\.html$')
        if ($match.Success) { $match.Groups[1].Value }
    } |
    Sort-Object -Unique -Property @{ Expression = { if ($_ -eq 'K') { 0 } else { [int]$_.Substring(1) + 1 } } }

if (-not $gradeNames) { throw "No worksheet episode files were found in $source." }
$episodes = @($gradeNames | ForEach-Object { Get-SelectedEpisode -Grade $_ })

foreach ($episode in $episodes) {
    $gradeLower = $episode.Grade.ToLowerInvariant()
    Copy-Item -LiteralPath $episode.Selected.File.FullName -Destination (Join-Path $site "current-$gradeLower-episode.html") -Force
    Copy-Item -LiteralPath $episode.QuestionsPath -Destination (Join-Path $site "current-$gradeLower-questions.pdf") -Force
    Copy-Item -LiteralPath $episode.AnswersPath -Destination (Join-Path $site "current-$gradeLower-answers.pdf") -Force
}

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
    .card { width: min(100%, 860px); padding: clamp(32px, 7vw, 64px); text-align: center; background: rgba(255,255,255,.92); border: 1px solid rgba(255,255,255,.8); border-radius: 28px; box-shadow: 0 24px 70px rgba(53, 63, 99, .16); }
    .mark { display: inline-grid; place-items: center; width: 68px; height: 68px; margin-bottom: 20px; border-radius: 20px; font-size: 32px; background: #e9ddff; }
    h1 { margin: 0; font-size: clamp(2rem, 5vw, 3.2rem); letter-spacing: -.04em; }
    .subtitle { margin: 14px 0 28px; color: #667085; font-size: 1.05rem; }
    .grades { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; text-align: left; }
    .grade { padding: 24px; border: 1px solid #eaecf0; border-radius: 18px; background: #fff; }
    .grade h2 { margin: 0; font-size: 1.5rem; }
    .episode { display: inline-block; margin: 12px 0 20px; padding: 7px 12px; border-radius: 999px; color: #4b2a87; background: #f0e9ff; font-size: .9rem; font-weight: 700; }
    .actions { display: grid; gap: 10px; }
    .button { display: inline-flex; justify-content: center; align-items: center; min-height: 46px; padding: 12px 16px; border-radius: 12px; color: white; text-align: center; text-decoration: none; font-weight: 700; transition: transform .15s ease, box-shadow .15s ease; }
    .button:hover { transform: translateY(-2px); box-shadow: 0 10px 22px rgba(36, 43, 73, .18); }
    .html-button { background: #4f46e5; }
    .questions-button { background: #e45756; }
    .answers-button { background: #16836b; }
    footer { margin-top: 34px; color: #98a2b3; font-size: .86rem; }
</style>
</head>
<body>
<main class="card">
    <div class="mark" aria-hidden="true">🗺️</div>
    <h1>Adventure Worksheet</h1>
    <p class="subtitle">Choose a grade and open the episode or download its PDFs.</p>
    <div class="grades">
"@
foreach ($episode in $episodes) {
    $gradeLower = $episode.Grade.ToLowerInvariant()
    $gradeLabel = if ($episode.Grade -eq 'K') { 'Kindergarten' } else { "Grade $($episode.Grade.Substring(1))" }
    $page += @"
        <section class="grade">
            <h2>$($episode.Grade) ($gradeLabel)</h2>
            <div class="episode">Episode $($episode.Selected.DateText)</div>
            <div class="actions">
                <a class="button questions-button" href="./current-$gradeLower-questions.pdf" download>Download questions PDF</a>
                <a class="button answers-button" href="./current-$gradeLower-answers.pdf" download>Download answers PDF</a>
                <a class="button html-button" href="./current-$gradeLower-episode.html">Open episode HTML</a>
            </div>
        </section>
"@
}
$page += @"
    </div>
    <footer>Updated automatically from Google Drive · <a href="./archive/">Browse older worksheets</a></footer>
</main>
</body>
</html>
"@

$archiveManifestPath = Join-Path $source 'archive-manifest.json'
$archiveSiteDirectory = Join-Path $site 'archive'
$archiveFilesDirectory = Join-Path $archiveSiteDirectory 'files'
New-Item -ItemType Directory -Force -Path $archiveFilesDirectory | Out-Null
Get-ChildItem -LiteralPath $archiveFilesDirectory -File | Remove-Item -Force

$archiveEntries = @()
if (Test-Path -LiteralPath $archiveManifestPath -PathType Leaf) {
    $archiveEntries = @(Get-Content -LiteralPath $archiveManifestPath -Raw | ConvertFrom-Json)
}

$archiveGrades = @($archiveEntries | ForEach-Object { $_.grade } | Where-Object { $_ -match '^(K|G\d+)$' } | Sort-Object -Unique -Property @{ Expression = { if ($_ -eq 'K') { 0 } else { [int]$_.Substring(1) + 1 } } })
$archiveRows = foreach ($grade in $archiveGrades) {
    $gradeEntries = @(
        $archiveEntries |
            Where-Object grade -eq $grade |
            Sort-Object -Property @{ Expression = 'date'; Descending = $true }, kind
    )
    if (-not $gradeEntries) { continue }

    $label = if ($grade -eq 'K') { 'Kindergarten' } else { "Grade $($grade.Substring(1))" }
    "<section class=""grade""><h2>$label</h2>"
    foreach ($dateGroup in ($gradeEntries | Group-Object date)) {
        "<h3>$($dateGroup.Name)</h3>"
        foreach ($entry in $dateGroup.Group) {
            $nameMatch = [regex]::Match(
                $entry.name,
                '^(K|G\d+)_(\d{4}-\d{2}-\d{2})(_answers\.pdf|_episode\.html|\.pdf)$'
            )
            $archiveDate = [datetime]::MinValue
            if (
                -not $nameMatch.Success -or
                $nameMatch.Groups[1].Value -ne $grade -or
                $nameMatch.Groups[2].Value -ne $entry.date -or
                -not [datetime]::TryParseExact(
                    $entry.date,
                    'yyyy-MM-dd',
                    [Globalization.CultureInfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::None,
                    [ref]$archiveDate
                ) -or
                $entry.path -ne "archive-downloads/$($entry.output)" -or
                $entry.output -notmatch '^[A-Za-z0-9_-]+_(K|G\d+)_\d{4}-\d{2}-\d{2}(_answers\.pdf|_episode\.html|\.pdf)$'
            ) {
                throw "Invalid archive manifest entry for '$($entry.name)'."
            }
            $sourceFile = Join-Path $source $entry.path
            if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
                throw "Archive file from manifest was not downloaded: $($entry.name)"
            }
            $destination = Join-Path $archiveFilesDirectory $entry.output
            Copy-Item -LiteralPath $sourceFile -Destination $destination -Force
            $href = "./files/$([uri]::EscapeDataString($entry.output))"
            $linkLabel = switch ($entry.kind) {
                'episode' { 'Episode HTML' }
                'questions' { 'Questions PDF' }
                'answers' { 'Answers PDF' }
                default { throw "Unknown archive file type '$($entry.kind)' for $($entry.name)." }
            }
            "<a class=""archive-link"" href=""$href"" download>Download $linkLabel</a>"
        }
    }
    '</section>'
}

$archivePage = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Worksheet Archive | Adventure Worksheet</title>
<style>
    :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; padding: 32px 20px; color: #172033; background: linear-gradient(135deg, #eef6ff 0%, #f7f3ff 52%, #fff8ed 100%); }
    main { width: min(100%, 900px); margin: 0 auto; padding: clamp(24px, 6vw, 52px); background: rgba(255,255,255,.94); border-radius: 24px; box-shadow: 0 24px 70px rgba(53, 63, 99, .16); }
    h1 { margin-top: 0; }
    .back { color: #4f46e5; font-weight: 700; }
    .grades { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 20px; margin-top: 28px; }
    .grade { padding: 22px; border: 1px solid #eaecf0; border-radius: 16px; }
    .grade h2 { margin-top: 0; }
    .archive-link { display: block; padding: 12px 0; border-top: 1px solid #eaecf0; color: #3730a3; text-decoration: none; }
    .archive-link:hover { text-decoration: underline; }
    .empty { color: #667085; }
</style>
</head>
<body>
<main>
    <a class="back" href="../">← Current worksheets</a>
    <h1>Worksheet archive</h1>
    <p>Browse and download older worksheets by grade and episode date.</p>
    <div class="grades">
"@
if ($archiveRows) {
    $archivePage += ($archiveRows -join "`n")
} else {
    $archivePage += '<p class="empty">No archived worksheet files are available yet.</p>'
}
$archivePage += @"
    </div>
</main>
</body>
</html>
"@
Set-Content -LiteralPath (Join-Path $archiveSiteDirectory 'index.html') -Value $archivePage -Encoding utf8

Set-Content -LiteralPath (Join-Path $site 'index.html') -Value $page -Encoding utf8

foreach ($episode in $episodes) {
    Write-Output "Selected $($episode.Grade) episode: $($episode.Selected.DateText)"
    Write-Output "  HTML:     $($episode.Selected.File.Name)"
    Write-Output "  Questions: $(Split-Path $episode.QuestionsPath -Leaf)"
    Write-Output "  Answers:   $(Split-Path $episode.AnswersPath -Leaf)"
}
