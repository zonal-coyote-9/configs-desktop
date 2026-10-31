# Modern CLI replacements. Each alias is only defined when its tool is installed,
# so a machine without them still has working core commands.
#   brew install eza bat btop fd dust procs gping git-delta

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'      # Modern ls with icons and grouping.
  alias ll='eza -lah --icons --group-directories-first' # Detailed listing with human-readable sizes.
  alias tree='eza --tree --icons'                       # Directory tree with icons.
fi

command -v bat  >/dev/null 2>&1 && alias cat='bat'      # Syntax-highlighted file viewer.
command -v btop >/dev/null 2>&1 && alias top='btop'     # Rich interactive system monitor.

# These tools take different arguments than the classic command they resemble,
# so they get their own names rather than shadowing find/du/ps/ping/diff.
command -v fd    >/dev/null 2>&1 && alias f='fd'        # Faster, friendlier file finder.
command -v dust  >/dev/null 2>&1 && alias duh='dust'    # Visual disk-usage viewer.
command -v procs >/dev/null 2>&1 && alias pp='procs'    # Modern process viewer.
command -v gping >/dev/null 2>&1 && alias png='gping'   # Ping with a live latency chart.
command -v delta >/dev/null 2>&1 && alias dlt='delta'   # Pretty diff pager.
