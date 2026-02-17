# ==============================================================================
# Environment variables
# ==============================================================================
{{ if eq .chezmoi.os "linux" -}}
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:/snap/bin:$PATH
export GPG_TTY=$TTY
{{ else -}}
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
{{ end -}}
export EDITOR='nvim'
{{ if eq .chezmoi.os "linux" -}}
export BROWSER='google-chrome-stable'
{{ end -}}
