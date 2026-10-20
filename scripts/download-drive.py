"""Download episode files from a shared Google Drive folder."""
import os
import json
import re
from datetime import date
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]
FOLDER_ID = os.environ["GOOGLE_DRIVE_FOLDER_ID"]
CREDENTIALS = os.environ["GOOGLE_SERVICE_ACCOUNT_JSON"]
DESTINATION = Path(os.environ.get("DOWNLOAD_DIRECTORY", "content"))
ARCHIVE_DIRECTORY = DESTINATION / "archive-downloads"
ARCHIVE_MANIFEST = DESTINATION / "archive-manifest.json"

if not FOLDER_ID.strip():
    raise RuntimeError("GOOGLE_DRIVE_FOLDER_ID is empty. Add it as a GitHub Actions repository variable.")
if not CREDENTIALS.strip():
    raise RuntimeError("GOOGLE_SERVICE_ACCOUNT_JSON is empty. Add the complete service-account JSON as a GitHub Actions repository secret.")

try:
    credentials_info = json.loads(CREDENTIALS)
except json.JSONDecodeError as error:
    raise RuntimeError(
        "GOOGLE_SERVICE_ACCOUNT_JSON is not valid JSON. Paste the complete contents of the downloaded .json key file, not its filename or file path."
    ) from error

credentials = service_account.Credentials.from_service_account_info(
    credentials_info, scopes=SCOPES
)
drive = build("drive", "v3", credentials=credentials, cache_discovery=False)
DESTINATION.mkdir(parents=True, exist_ok=True)

def list_drive_files(query):
    results = []
    page_token = None
    while True:
        response = drive.files().list(
            q=query,
            spaces="drive",
            fields="nextPageToken, files(id,name,mimeType)",
            pageSize=1000,
            pageToken=page_token,
        ).execute()
        results.extend(response.get("files", []))
        page_token = response.get("nextPageToken")
        if not page_token:
            return results


def download_file(item, destination):
    request = drive.files().get_media(fileId=item["id"])
    with destination.open("wb") as output:
        downloader = MediaIoBaseDownload(output, request)
        done = False
        while not done:
            _, done = downloader.next_chunk()


root_query = f"'{FOLDER_ID}' in parents and trashed = false"
files = list_drive_files(root_query)
worksheet_pattern = re.compile(r"^(K|G\d+)_\d{4}-\d{2}-\d{2}(_answers\.pdf|_episode\.html|\.pdf)$")
for item in files:
    name = item["name"]
    if not worksheet_pattern.fullmatch(name):
        continue
    destination = DESTINATION / name
    download_file(item, destination)

archive_folders = list_drive_files(
    f"'{FOLDER_ID}' in parents and trashed = false and "
    "mimeType = 'application/vnd.google-apps.folder' and name = 'Backup'"
)
ARCHIVE_DIRECTORY.mkdir(parents=True, exist_ok=True)
for existing_file in ARCHIVE_DIRECTORY.iterdir():
    if existing_file.is_file():
        existing_file.unlink()

archive_files = []
archive_pattern = re.compile(
    r"^(K|G\d+)_(\d{4}-\d{2}-\d{2})(_answers\.pdf|_episode\.html|\.pdf)$"
)
for backup_folder in archive_folders:
    query = f"'{backup_folder['id']}' in parents and trashed = false"
    for item in list_drive_files(query):
        match = archive_pattern.fullmatch(item["name"])
        if not match:
            continue
        try:
            date.fromisoformat(match.group(2))
        except ValueError:
            continue

        grade, episode_date, suffix = match.groups()
        if suffix == "_episode.html":
            kind = "episode"
        elif suffix == "_answers.pdf":
            kind = "answers"
        else:
            kind = "questions"
        local_name = f"{item['id']}_{item['name']}"
        download_file(item, ARCHIVE_DIRECTORY / local_name)
        archive_files.append(
            {
                "grade": grade,
                "date": episode_date,
                "kind": kind,
                "name": item["name"],
                "path": f"archive-downloads/{local_name}",
                "output": local_name,
            }
        )

ARCHIVE_MANIFEST.write_text(
    json.dumps(archive_files, indent=2),
    encoding="utf-8",
)
print(
    f"Downloaded {len(files)} current-folder files and "
    f"{len(archive_files)} archived worksheet files."
)
