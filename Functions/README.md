# Functions

Standalone Python utilities — not part of machine setup; use them whenever they're handy. They work on Windows, Mac and Linux.

| Script | What it does |
|---|---|
| [generate_password.py](generate_password.py) | Generates strong passwords, random or word-based, with a strength estimate |
| [generate_username.py](generate_username.py) | Generates random usernames, or military-style operation names |
| [convert_to_jpeg.py](convert_to_jpeg.py) | Converts HEIC/HEIF and other images to JPEG |
| [group_downloads.py](group_downloads.py) | Sorts a Downloads folder into category subfolders |
| [group_photos.py](group_photos.py) | Moves photos into Year/Month folders |
| [group_screenshots.py](group_screenshots.py) | Moves screenshots into Year/Month folders |

## Requirements

- Python 3.
- `convert_to_jpeg.py` also needs two packages: `pip install pillow pillow-heif`.

Run scripts with `python3 <script>.py` (Mac/Linux) or `python <script>.py` (Windows). Every script supports `--help`.

---

## generate_password.py — password generator

Run it with no options for an interactive menu, where you can change settings and see new passwords live. It also shows a strength rating and roughly how long the password would take to crack.

Two modes:
- **Memorable** (default): random words with numbers, e.g. `Banjo6-Reprogram5-Clambake2`. Words come from a list of about 1,670.
- **Random**: random letters, numbers and symbols, e.g. `k#9Lp2!xQm@7...`.

```bash
python3 generate_password.py                                              # interactive menu
python3 generate_password.py --non-interactive                            # one memorable password
python3 generate_password.py --non-interactive --mode Random --length 24 --count 5
python3 generate_password.py --non-interactive --word-count 4 --separator Dots --substitutions
```

| Option | What it does | Default |
|---|---|---|
| `--non-interactive` | Print the result(s) and exit, instead of opening the menu. | off |
| `--mode` | `Memorable` or `Random`. | `Memorable` |
| `--count N` | How many passwords to print. | 1 |
| `--word-count N` | Memorable: number of words (1–8). | 5 |
| `--length N` | Random: number of characters (6–64). | 16 |
| `--separator` | Memorable: `Hyphens`, `Underscores`, `Dots`, `Spaces` or `None`. | `Hyphens` |
| `--substitutions` | Memorable: swap letters for lookalikes (`e`→`3`, `a`→`@`...). | off |
| `--no-uppercase` | Random: no capital letters. Memorable: don't capitalize words. | uppercase on |
| `--no-numbers` | No digits. | numbers on |
| `--no-symbols` | Random: no symbols. | symbols on |

---

## generate_username.py — username generator

Builds usernames from random adjectives, nouns, verbs and first names, e.g. `clever-falcon-races`. A **Military** mode makes operation names like `Operation Crimson-Falcon` (or `Operation Crimson Falcon` with `--separator Spaces`). Run with no options for an interactive menu.

```bash
python3 generate_username.py                                              # interactive menu
python3 generate_username.py --non-interactive --count 5
python3 generate_username.py --non-interactive --word-count 3 --separator Underscores --numbers --count 5
python3 generate_username.py --non-interactive --mode Military --word-count 2 --separator Spaces --count 5
python3 generate_username.py --non-interactive --word-types Names Nouns --capitalize
```

| Option | What it does | Default |
|---|---|---|
| `--non-interactive` | Print the result(s) and exit, instead of opening the menu. | off |
| `--mode` | `Standard` or `Military`. | `Standard` |
| `--count N` | How many usernames to print. | 1 |
| `--word-count N` | Number of words (1–5). | 2 |
| `--separator` | `Hyphens`, `Underscores`, `Dots`, `Spaces` or `None`. | `Hyphens` |
| `--numbers` | Add a random number (0–99) at the end. | off |
| `--capitalize` | Capitalize each word (Military names are always capitalized). | off |
| `--leetspeak` | Swap letters for lookalike numbers (`a`→`4`, `e`→`3`...). | off |
| `--word-types` | Standard: which word lists to use — any of `Adjectives`, `Nouns`, `Verbs`, `Names`. Words are taken from them in turn. | Adjectives Nouns Verbs |

---

## convert_to_jpeg.py — convert images to JPEG

Converts images (such as iPhone HEIC photos) to JPEG. The originals are kept; the JPEG is saved next to each one.

```bash
python3 convert_to_jpeg.py IMG_0001.HEIC
python3 convert_to_jpeg.py *.HEIC -r      # IMG_0001.jpg instead of IMG_0001.HEIC.jpg
python3 convert_to_jpeg.py * -f -r        # also fix JPEGs with the wrong extension
```

| Option | What it does |
|---|---|
| `-r`, `--remove-original-extension` | Name the output `photo.jpg` rather than `photo.HEIC.jpg`. |
| `-f`, `--fix-extension-if-jpeg` | If a file is already a JPEG but named something else (e.g. `.png`), rename it to `.jpg` instead of converting. |

Files that aren't images are reported as `[Unsupported]` and skipped.

---

## group_downloads.py — sort Downloads into folders

Moves each file in a `Downloads` folder into a subfolder by type:

| Folder | File types |
|---|---|
| Images | jpg, jpeg, png, gif, bmp |
| Installers | exe, dmg, app |
| Isos | iso |
| Music | mp3, wav, aac, flac, ogg |
| Videos | mp4, avi, mov, mkv, wmv |
| Docs | pdf, txt, doc, docx |
| other | everything else |

Pass the folder that **contains** `Downloads` — usually your home folder:

```bash
python3 group_downloads.py ~           # sorts ~/Downloads
```

Only files directly in `Downloads` are moved; existing subfolders are left alone.

---

## group_photos.py — sort photos by date

Moves every file in a folder into `Year/Month` folders (e.g. `2026/09`), based on each file's last-modified date. That date is used because for synced photos the creation date is just the sync date.

```bash
python3 group_photos.py ~/Pictures/Unsorted ~/Pictures/Sorted
```

The first folder is the source, the second is where the `Year/Month` folders go (they can be the same folder). Only files directly in the source folder are moved.

---

## group_screenshots.py — sort screenshots by date

Moves screenshots (png, jpg, jpeg, bmp) into `Year/Month` folders (e.g. `2026/09`) inside the same folder, based on each file's last-modified date. Unlike `group_photos.py`, it also picks up screenshots in subfolders.

```bash
python3 group_screenshots.py                       # sorts ~/Pictures/Screenshots
python3 group_screenshots.py ~/Desktop/Screens     # or any folder
```
