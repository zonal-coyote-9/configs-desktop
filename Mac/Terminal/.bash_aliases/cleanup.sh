alias hg='history | grep'                          # Search command history.
alias shreload='source ~/.zshrc'                   # Reload shell configuration on the fly.
alias shconfig='${EDITOR:-nano} ~/.zshrc'          # Quick access to the shell config file.
alias aliasconfig='${EDITOR:-nano} ~/.bash_aliases/'  # Open the aliases directory.
alias aliases='alias | sort'                       # List all aliases alphabetically.
alias today='fc -li 1 | grep "$(date +%F)"'        # Show today's command history (zsh, with timestamps).
