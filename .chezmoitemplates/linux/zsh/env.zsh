# ==============================================================================
# Environment variables
# ==============================================================================
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:/snap/bin:$PATH
export GPG_TTY=$TTY
export EDITOR='nvim'
export BROWSER='google-chrome-stable'
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  export ZSH_TMUX_AUTOSTART=false
else
  export ZSH_TMUX_AUTOSTART=true
fi
export ZSH_TMUX_AUTOCONNECT=true
export LC_ALL=en_US.UTF-8 # needs for tmux by ssh
