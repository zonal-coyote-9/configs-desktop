#!/usr/bin/env python3
"""Move photos into Year/Month folders based on their last-modified date."""

import argparse
import shutil
import sys
from datetime import datetime
from pathlib import Path

def group_photos(source_folder, target_folder):
    source = Path(source_folder)
    target = Path(target_folder)

    if not source.is_dir():
        print(f"Error: Source folder does not exist: {source}", file=sys.stderr)
        return

    # Collect the full file list up front so moving files doesn't affect the scan in progress.
    files = [p for p in source.iterdir() if p.is_file()]

    for path in files:
        try:
            # Uses last-modified time since these are synced files; creation time would be the sync date.
            modified = datetime.fromtimestamp(path.stat().st_mtime)
            dest_folder = target / str(modified.year) / f"{modified.month:02d}"
            dest_folder.mkdir(parents=True, exist_ok=True)

            shutil.move(str(path), str(dest_folder / path.name))
            print(f"Moved: {path.name} -> {modified.year}/{modified.month:02d}")
        except OSError as e:
            print(f"Error moving file: {path} - {e}", file=sys.stderr)

    print("Organization complete!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_folder", help="Folder to sort from")
    parser.add_argument("target_folder", help="Folder to sort into")
    args = parser.parse_args()

    group_photos(args.source_folder, args.target_folder)
