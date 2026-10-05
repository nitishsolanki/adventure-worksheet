# Plan: Publish Adventure Worksheet with GitHub Actions

## Current project status

The current project contains only `workspace.code-workspace`. The implementation can therefore be added with a clean repository structure.

## Goal

Publish the latest Adventure Worksheet to GitHub Pages. The public page must:

- Display the selected HTML episode.
- Link to the matching PDF.
- Prefer the file for the current date.
- Fall back to the most recent available dated file.

Source files are stored in Google Drive and use these exact naming patterns:

```text
G1_YYYY-MM-DD_episode.html
G1_YYYY-MM-DD.pdf
```

For example:

```text
G1_2026-10-05_episode.html
G1_2026-10-05.pdf
```

## Proposed repository structure

```text
adventure-worksheet/
├── .github/
│   └── workflows/
│       └── publish.yml
├── site/
│   ├── index.html
│   ├── current.html
│   └── current.pdf
├── scripts/
│   └── select-current-file.ps1
├── plan.md
└── workspace.code-workspace
```

`site/` is the GitHub Pages publishing directory. `current.html` and `current.pdf` are stable URLs that are replaced by each successful workflow run.

## Automated workflow

The GitHub Actions workflow should:

1. Run on pushes to `main`.
2. Run once per day using a scheduled trigger.
3. Support manual execution with `workflow_dispatch`.
4. Download matching HTML and PDF files from Google Drive.
5. Search for a file named `G1_<today>_episode.html`.
6. If today's file is unavailable, identify every filename matching `G1_YYYY-MM-DD_episode.html` and select the greatest date.
7. Extract the selected date from the HTML filename.
8. Require the matching `G1_<selected-date>.pdf` file.
9. Copy the selected HTML to `site/current.html`.
10. Copy the matching PDF to `site/current.pdf`.
11. Generate `site/index.html` with the selected date and links to both files.
12. Fail the workflow if no valid HTML file or matching PDF is found.
13. Publish `site/` with GitHub Pages.

The date must be parsed from the filename, not from file upload time. Because the date format is ISO `YYYY-MM-DD`, lexicographic sorting is also chronological sorting.

## Google Drive access design

Use a Google Cloud service account with read-only access to the specific Drive folder.

Required setup:

1. Create or select a Google Cloud project.
2. Enable the Google Drive API.
3. Create a service account.
4. Share the Drive folder with the service-account email as a Viewer.
5. Create a JSON key only if the selected download tool requires it.
6. Store the credential JSON in a GitHub Actions secret, such as `GOOGLE_SERVICE_ACCOUNT_JSON`.
7. Store the Drive folder ID in a repository variable, such as `GOOGLE_DRIVE_FOLDER_ID`.
8. Download only the required `.html` and `.pdf` files.

The service account should not receive write access to the Drive folder.

## Cost answer

For this use case, a Google Cloud service account itself does not normally cost money. The standard Google Drive API is available at no additional cost within its quotas. A daily workflow downloading one HTML file and one PDF should be far below normal quota limits.

Google’s current Drive API documentation says standard use is available at no additional cost, while quota overages or future quota-increase billing can incur charges. This workflow should therefore be designed to make only a small number of API requests and download only the necessary files.

Possible costs to monitor:

- Google Drive or Google Workspace storage, if the account exceeds its included storage.
- Google Cloud services added beyond the Drive API.
- Future Drive API quota overage or paid quota increases.
- GitHub Actions or GitHub Pages limits, depending on the GitHub account and usage.

Recommended safeguards:

- Use a dedicated Google Cloud project for this automation.
- Grant the service account read-only access to one folder.
- Add a Google Cloud budget alert, if billing is enabled.
- Avoid downloading the entire Drive repeatedly.
- List filenames first, then download only the selected HTML and matching PDF.
- Keep the scheduled workflow to once per day.

Official references:

- [Google Drive API usage limits and pricing](https://developers.google.com/workspace/drive/api/guides/limits)
- [Google Workspace API quota and billing changes](https://developers.google.com/workspace/tools-safety)

## `index.html` behavior

The generated landing page should include:

```html
<h1>Adventure Worksheet</h1>
<p>Episode: YYYY-MM-DD</p>
<p><a href="./current.html">Open HTML version</a></p>
<p><a href="./current.pdf">Download PDF</a></p>
```

The selected episode HTML will be available at:

```text
/current.html
```

The matching PDF will be available at:

```text
/current.pdf
```

## GitHub Pages setup

1. Create a GitHub repository named `adventure-worksheet`.
2. Push this project to the `main` branch.
3. In repository Settings, open Pages.
4. Set the publishing source to GitHub Actions.
5. Add the workflow under `.github/workflows/publish.yml`.
6. Confirm that the workflow has permission to write Pages artifacts and deploy Pages.
7. Open the resulting URL:

```text
https://<github-username>.github.io/adventure-worksheet/
```

## Validation requirements

The workflow must stop before deployment when:

- No valid `G1_YYYY-MM-DD_episode.html` file exists.
- The selected HTML file is empty.
- The matching PDF does not exist.
- The HTML and PDF dates differ.
- More than one file has the same date and the selection is ambiguous.

The workflow log should report the selected date and filenames without printing credentials.

## Implementation order

1. Add the repository structure.
2. Add the file-selection script.
3. Add the Google Drive download step.
4. Add validation and matching-date logic.
5. Add generated `index.html` logic.
6. Add the GitHub Pages deployment workflow.
7. Configure Google Cloud and GitHub secrets.
8. Run the workflow manually.
9. Verify the current-date case.
10. Temporarily test with no current-date file and verify that the newest older file is selected.
11. Verify both the HTML link and PDF link from the published page.
12. Enable the daily schedule.

## Recommended first implementation choice

Use a single GitHub Actions workflow with a small PowerShell or Python selection script. Use Google Drive API access through a read-only service account, download only candidate filenames, select the current or newest date, and deploy the generated `site/` directory to GitHub Pages.

