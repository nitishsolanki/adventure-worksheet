# Adventure Worksheet

This project automatically publishes Adventure Worksheet episodes for Grade 1
(G1) and Kindergarten (K) to GitHub Pages. It reads episode files from a Google
Drive folder and selects the current-date episode for each grade when available
(otherwise that grade's newest available episode). The landing page provides
three links per grade: questions PDF, answers PDF, and episode HTML.

## Google Drive files

Keep the source files together in the configured Google Drive folder. Each
grade's episode uses the same date in all three filenames:

```text
G1_YYYY-MM-DD_answers.pdf
G1_YYYY-MM-DD_episode.html
G1_YYYY-MM-DD.pdf
K_YYYY-MM-DD_answers.pdf
K_YYYY-MM-DD_episode.html
K_YYYY-MM-DD.pdf
```

For example:

```text
G1_2026-10-10_answers.pdf       # Grade 1 answers
G1_2026-10-10_episode.html      # Grade 1 episode
G1_2026-10-10.pdf               # Grade 1 questions
K_2026-10-10_answers.pdf        # Kindergarten answers
K_2026-10-10_episode.html       # Kindergarten episode
K_2026-10-10.pdf                # Kindergarten questions
```

The date in the filename is the episode date; the workflow does not use Drive's
upload or modification time. G1 and K dates are selected independently, so the
grades may show different episode dates when their latest files differ.

The downloader looks in the configured Drive folder for both `G1_` and `K_`
files. For each grade, publishing requires a dated episode HTML, matching
questions PDF (`<grade>_YYYY-MM-DD.pdf`), and matching answers PDF
(`<grade>_YYYY-MM-DD_answers.pdf`). All three are included in that grade's
section on the public landing page.

## What gets published

The GitHub Pages site contains:

- `index.html` — a landing page with separate Grade 1 and Kindergarten
  sections, selected dates, and three links in each section.
- `current-g1-questions.pdf`, `current-g1-answers.pdf`, and
  `current-g1-episode.html` — the selected Grade 1 files.
- `current-k-questions.pdf`, `current-k-answers.pdf`, and
  `current-k-episode.html` — the selected Kindergarten files.

Each link on the landing page points to one of these six grade-specific files.
The filenames are stable, so the links do not change when new episodes are
selected.

## Automation

The workflow is defined in
[`.github/workflows/publish.yml`](.github/workflows/publish.yml). It runs:

- On pushes to `main`.
- Once per day at 4:30 p.m. Central Time. Two UTC cron entries and a schedule
  check handle daylight saving time.
- On demand through **Actions → Publish Adventure Worksheet → Run workflow**.

The workflow checks the Drive configuration, downloads source files, selects
the episode, generates the Pages site, and deploys it to the `github-pages`
environment.

Episode selection and site generation are handled by
[`scripts/select-current-file.ps1`](scripts/select-current-file.ps1):

1. For each grade (`G1` and `K`), look for HTML filenames exactly matching
   `<grade>_YYYY-MM-DD_episode.html`.
2. Prefer a file whose date is today; otherwise select that grade's newest
   dated HTML file.
3. Require a non-empty HTML file and matching non-empty questions and answers
   PDFs for the selected date.
4. Copy the three files for each grade into `site/` under stable grade-specific
   filenames, and generate `site/index.html` with three links per grade.

The build fails rather than deploying a landing page with missing files if
either grade has no valid episode or one of its selected episode files is
missing or empty.

The Drive download is implemented in
[`scripts/download-drive.py`](scripts/download-drive.py). Dependencies are
listed in [`requirements.txt`](requirements.txt).

## GitHub setup

### Google Drive access

1. Create or select a Google Cloud project and enable the Google Drive API.
2. Create a service account and give it **Viewer** access to the Drive folder
   containing the episode files. The downloader uses the read-only Drive API
   scope.
3. Provide the service account credentials to GitHub Actions:
   - Add the Drive folder ID as the Actions repository variable
     `GOOGLE_DRIVE_FOLDER_ID`.
   - Add the complete service-account JSON key contents as the Actions
     repository secret `GOOGLE_SERVICE_ACCOUNT_JSON`.

Do not commit the service-account key or place it in the repository. The
workflow checks that both settings are present before downloading files.

### GitHub Pages

1. Push the project to the `main` branch.
2. In repository **Settings → Pages**, set the source to **GitHub Actions**.
3. Ensure the repository permits the workflow's Pages deployment permissions.
4. Run **Publish Adventure Worksheet** manually once to verify the Drive setup
   and deployment.

The published site is available at:

```text
https://<github-username>.github.io/adventure-worksheet/
```

## Run the site-generation step locally

With Python, the dependencies in `requirements.txt`, and PowerShell 7 (`pwsh`)
installed, put the three source files for each grade in `content/` and run:

```powershell
pwsh -File .\scripts\select-current-file.ps1
```

This generates the `site/` directory from files already in `content/`; both
grades must have a valid matching set. To run the Drive download locally, set
`GOOGLE_DRIVE_FOLDER_ID` and
`GOOGLE_SERVICE_ACCOUNT_JSON` in the environment, then run:

```powershell
python -m pip install -r requirements.txt
python .\scripts\download-drive.py
pwsh -File .\scripts\select-current-file.ps1
```

The local Drive download defaults to `content/`; the generated site defaults to
`site/`. Both directories are ignored by Git.

## Costs and access

The Drive integration makes read-only API requests and downloads source files
for the build. Review current Google Drive API quotas and any applicable Google
Cloud or Google Workspace charges for your account. GitHub Actions and Pages
usage is also subject to the limits and terms of the GitHub account.

Official Drive API references:

- [Drive API usage limits](https://developers.google.com/workspace/drive/api/guides/limits)
- [Google Workspace API quota and billing changes](https://developers.google.com/workspace/tools-safety)