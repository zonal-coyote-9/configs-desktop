#!/usr/bin/env python3
"""Move screenshots into Year/Month folders based on their last-modified date."""

import argparse
import shutil
import sys
from datetime import datetime
from pathlib import Path

DEFAULT_SOURCE_FOLDER = Path.home() / "Pictures" / "Screenshots"
IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".bmp")


def group_screenshots(source_folder=DEFAULT_SOURCE_FOLDER, image_extensions=IMAGE_EXTENSIONS):
    source = Path(source_folder)

    if not source.is_dir():
        print(f"Error: Source folder does not exist: {source}", file=sys.stderr)
        return

    # Collect the full file list up front so moving files doesn't affect the scan in progress.
    files = [p for p in source.rglob("*") if p.is_file() and p.suffix.lower() in image_extensions]

    for path in files:
        try:
            modified = datetime.fromtimestamp(path.stat().st_mtime)
            dest_folder = source / str(modified.year) / f"{modified.month:02d}"
            dest_folder.mkdir(parents=True, exist_ok=True)

            shutil.move(str(path), str(dest_folder / path.name))
            print(f"Moved: {path.name} -> {modified.year}/{modified.month:02d}")
        except OSError as e:
            print(f"Error moving file: {path} - {e}", file=sys.stderr)

    print("Organization complete!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source_folder",
        nargs="?",
        default=DEFAULT_SOURCE_FOLDER,
        help=f"Folder to organize (default: {DEFAULT_SOURCE_FOLDER})",
    )
    args = parser.parse_args()

    group_screenshots(args.source_folder)
