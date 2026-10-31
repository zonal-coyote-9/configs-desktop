#!/usr/bin/env python3
"""Sort files in a Downloads folder into category subfolders by extension."""

import argparse
import shutil
import sys
from pathlib import Path

CATEGORY_EXTENSIONS = {
    "Images": (".jpg", ".jpeg", ".png", ".gif", ".bmp"),
    "Installers": (".exe", ".dmg", ".app"),
    "Isos": (".iso",),
    "Music": (".mp3", ".wav", ".aac", ".flac", ".ogg"),
    "Videos": (".mp4", ".avi", ".mov", ".mkv", ".wmv"),
    "Docs": (".pdf", ".txt", ".doc", ".docx"),
}
OTHER_CATEGORY = "other"


def group_downloads(folder_path):
    downloads = Path(folder_path) / "Downloads"

    if not downloads.is_dir():
        print(f"Error: Downloads folder does not exist: {downloads}", file=sys.stderr)
        return

    for category in (*CATEGORY_EXTENSIONS, OTHER_CATEGORY):
        (downloads / category).mkdir(parents=True, exist_ok=True)

    files = [p for p in downloads.iterdir() if p.is_file()]

    for path in files:
        extension = path.suffix.lower()
        category = OTHER_CATEGORY
        for name, extensions in CATEGORY_EXTENSIONS.items():
            if extension in extensions:
                category = name
                break

        try:
            shutil.move(str(path), str(downloads / category / path.name))
            print(f"Moved: {path.name} -> {category}")
        except OSError as e:
            print(f"Error moving file: {path} - {e}", file=sys.stderr)

    print("Sorting completed!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder_path", help="Folder containing the Downloads directory to sort")
    args = parser.parse_args()

    group_downloads(args.folder_path)
