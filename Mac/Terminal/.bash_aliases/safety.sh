alias rm='rm -i'                     # Confirm before deleting files.
alias cp='cp -i'                     # Confirm before overwriting existing files.
alias mv='mv -i'                     # Confirm before overwriting existing files.

# Note: GNU's `--preserve-root` guard for chmod/chown/chgrp does not exist in
# macOS's BSD versions, so those aliases were removed. Use `sudo` deliberately.
