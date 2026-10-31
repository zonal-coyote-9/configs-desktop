#!/usr/bin/env python3
"""Convert HEIC/HEIF (and other Pillow-supported) image files to JPEG.

Requires: pip install pillow pillow-heif
"""

import argparse
from pathlib import Path

from PIL import Image, UnidentifiedImageError
from pillow_heif import register_heif_opener

register_heif_opener()


def convert_to_jpeg(files, fix_extension_if_jpeg=False, remove_original_extension=False):
    for file in files:
        path = Path(file)
        print(path.name, end="")

        try:
            image = Image.open(path)
            image.load()
        except (UnidentifiedImageError, OSError):
            print(" [Unsupported]")
            continue

        if image.format == "JPEG":
            if fix_extension_if_jpeg and path.suffix.lower() not in (".jpg", ".jpeg"):
                new_path = path.with_suffix(".jpg")
                path.rename(new_path)
                print(f" => {new_path.name}")
            else:
                print(" [Already JPEG]")
            continue

        # Determine output file name
        if remove_original_extension:
            output_name = path.stem + ".jpg"
        else:
            output_name = path.name + ".jpg"
        output_path = path.parent / output_name

        try:
            image.convert("RGB").save(output_path, "JPEG")
            print(f" -> {output_name}")
        except OSError as e:
            print(f" [Error: {e}]")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", help="Image file(s) to convert to JPEG")
    parser.add_argument(
        "-f", "--fix-extension-if-jpeg",
        action="store_true",
        help="Fix extension of JPEG files without the .jpg extension",
    )
    parser.add_argument(
        "-r", "--remove-original-extension",
        action="store_true",
        help="Remove existing extension of non-JPEG files before adding .jpg",
    )
    args = parser.parse_args()

    convert_to_jpeg(args.files, args.fix_extension_if_jpeg, args.remove_original_extension)
