# ==============================================================================
# NVM (Node Version Manager)
# async loading because it's slow
# ==============================================================================
export NVM_DIR="$HOME/.nvm"
# export AUTO_LOAD_NVMRC_FILES=true
export LOAD_NVMRC_ON_INIT=true
function load_nvm() {
    {{ if eq .chezmoi.os "darwin" }}
    # macOS - use Homebrew version
    local HOMEBREW_PREFIX=${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null)}
    [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
    [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
    {{ else }}
    # Linux/other - use standard installation
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    {{ end }}

    load-nvmrc() {
        if [[ -f .nvmrc && -r .nvmrc ]]; then
            nvm use --silent
        elif [[ $(nvm version) != $(nvm version default)  ]]; then
            nvm use default --silent
        fi
    }

    if [ ! -z "$AUTO_LOAD_NVMRC_FILES" ] && [ "$AUTO_LOAD_NVMRC_FILES" = true ]
    then
        autoload -U add-zsh-hook
        add-zsh-hook chpwd load-nvmrc
    fi

    if [ ! -z "$LOAD_NVMRC_ON_INIT" ] && [ "$LOAD_NVMRC_ON_INIT" = true ]
    then
        load-nvmrc
    fi
}

# Initialize a new worker
async_start_worker nvm_worker -n
async_register_callback nvm_worker load_nvm
async_job nvm_worker sleep 0.1
