# ==============================================================================
# Zinit
# ==============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# # Load powerlevel10k theme
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

# Load pure theme
# zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
# zinit light sindresorhus/pure

zinit light mafredri/zsh-async
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice depth"1" pick"plugins/command-not-found/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh
zinit ice depth"1" pick"plugins/git/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh
zinit ice depth"1" pick"plugins/npm/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh
zinit ice depth"1" pick"plugins/tmux/*.plugin.zsh"
zinit light ohmyzsh/ohmyzsh

zinit snippet OMZL::async_prompt.zsh
zinit snippet OMZL::completion.zsh
zinit snippet OMZL::history.zsh
zinit snippet OMZL::key-bindings.zsh
