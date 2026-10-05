"""Download episode files from a shared Google Drive folder."""
import os
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]
FOLDER_ID = os.environ["GOOGLE_DRIVE_FOLDER_ID"]
CREDENTIALS = os.environ["GOOGLE_SERVICE_ACCOUNT_JSON"]
DESTINATION = Path(os.environ.get("DOWNLOAD_DIRECTORY", "content"))

credentials = service_account.Credentials.from_service_account_info(
    __import__("json").loads(CREDENTIALS), scopes=SCOPES
)
drive = build("drive", "v3", credentials=credentials, cache_discovery=False)
DESTINATION.mkdir(parents=True, exist_ok=True)

query = (
    f"'{FOLDER_ID}' in parents and trashed = false and "
    "(name contains 'G1_' or name contains '.html' or name contains '.pdf')"
)
files = []
page_token = None
while True:
    response = drive.files().list(
        q=query,
        spaces="drive",
        fields="nextPageToken, files(id,name,mimeType)",
        pageSize=1000,
        pageToken=page_token,
    ).execute()
    files.extend(response.get("files", []))
    page_token = response.get("nextPageToken")
    if not page_token:
        break

for item in files:
    name = item["name"]
    if not (name.startswith("G1_") and (name.endswith("_episode.html") or name.endswith(".pdf"))):
        continue
    request = drive.files().get_media(fileId=item["id"])
    destination = DESTINATION / name
    with destination.open("wb") as output:
        downloader = MediaIoBaseDownload(output, request)
        done = False
        while not done:
            _, done = downloader.next_chunk()

print(f"Downloaded {len(list(DESTINATION.iterdir()))} files to {DESTINATION}")
