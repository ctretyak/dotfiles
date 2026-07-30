# ==============================================================================
# Zinit
# ==============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Load powerlevel10k theme
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

zinit light mafredri/zsh-async
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice depth"1" pick"plugins/command-not-found/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh
zinit ice depth"1" pick"plugins/npm/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh

{{ if eq .chezmoi.os "darwin" -}}
# Homebrew-shipped completions (herdr, gh, chezmoi, docker, rg, ...).
# Must precede OMZL::completion.zsh — it runs compinit.
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

{{ end -}}

zinit snippet OMZL::async_prompt.zsh
zinit snippet OMZL::completion.zsh
zinit snippet OMZL::history.zsh
zinit snippet OMZL::key-bindings.zsh

# Initialize the completion system. zinit does not run compinit itself and the
# OMZ snippet above only sets zstyle options, so without this no completions
# load at all. Must come after every fpath change and plugin load.
autoload -Uz compinit
compinit
zinit cdreplay -q
