PROMPT="%n@%m|%*|%W %d %# "

# Load all alias files
if [ -d "$HOME/.bash_aliases" ]; then
  for file in "$HOME"/.bash_aliases/*.sh; do
    [ -f "$file" ] && source "$file"
  done
fi
