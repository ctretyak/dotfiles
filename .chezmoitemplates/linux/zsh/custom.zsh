{{- if stat (joinPath .chezmoi.homeDir ".zshrc_custom.zsh") }}
# ==============================================================================
# Custom ZSH configuration
# ==============================================================================
source ~/.zshrc_custom.zsh
{{- end }}
