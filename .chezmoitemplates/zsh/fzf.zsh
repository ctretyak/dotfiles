# Load fzf key bindings and completion
{{ if eq .chezmoi.os "darwin" -}}
source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" 2>/dev/null
source "$(brew --prefix)/opt/fzf/shell/completion.zsh" 2>/dev/null
{{ else -}}
if [[ -f /usr/share/fzf/shell/key-bindings.zsh ]]; then
  source /usr/share/fzf/shell/key-bindings.zsh
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

if [[ -f /usr/share/fzf/shell/completion.zsh ]]; then
  source /usr/share/fzf/shell/completion.zsh
elif [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then
  source /usr/share/doc/fzf/examples/completion.zsh
fi
{{ end -}}
