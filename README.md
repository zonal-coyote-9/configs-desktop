# DesktopConfig
Scripts and tools related to new system configuration.

## Overview

This repo holds first-run setup, configuration, security-hardening, and maintenance scripts for three desktop platforms — [Fedora](#fedora), [Mac](#mac), and [Windows](#windows) — plus cross-platform utilities in [Functions/](#functions).

Every platform follows the same general shape:

1. **Setup** — one-time, run right after a fresh OS install. Installs apps and baseline settings.
2. **Configure** — one-time, applies OS preference tweaks.
3. **Secure** — optional, run any time after setup. Reversible hardening in independently-selectable categories, with harden / report / restore-defaults modes.
4. **Update** — recurring, run any time to pull in OS/package updates. Not a first-run step.

Each folder has its own README with full usage for every script: [Fedora](Fedora/README.md), [Mac](Mac/README.md), [Windows](Windows/README.md), [Git](Git/README.md), [Functions](Functions/README.md). The platform READMEs are also included in each platform's release download.

Every Fedora, Mac and Windows script shows its help when run with no options and only makes changes once you pass `--run` / `-Run` (or the script's own options).

All setup/secure/update scripts are written to be idempotent — safe to re-run if interrupted or to pick up where a previous run left off (e.g. after a required reboot).