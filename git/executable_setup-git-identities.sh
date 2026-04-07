#!/bin/bash
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

BASE_DIR=~/git
LOCAL_INCLUDE_FILE=~/.gitconfig.local

# --- Helpers ---
info()    { echo -e "${BLUE}$*${RESET}"; }
success() { echo -e "${GREEN}$*${RESET}"; }
error()   { echo -e "${RED}$*${RESET}" >&2; }
warn()    { echo -e "${YELLOW}$*${RESET}"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; echo -e "${DIM}$(printf '%.0s─' {1..40})${RESET}"; }

cleanup() {
  [[ -n "${GNUPGHOME_TMP:-}" ]] && rm -rf "$GNUPGHOME_TMP"
  [[ -n "${KEYFILE:-}" ]] && rm -f "$KEYFILE"
}
trap cleanup EXIT

# --- List identities ---
list_identities() {
  header "Git Identities"
  local found=0
  for cfg in "$BASE_DIR"/*/.gitconfig; do
    [[ -f "$cfg" ]] || continue
    found=1
    local dir=$(dirname "$cfg")
    local id=$(basename "$dir")
    local name=$(git config -f "$cfg" user.name 2>/dev/null || echo "?")
    local email=$(git config -f "$cfg" user.email 2>/dev/null || echo "?")
    local key=$(git config -f "$cfg" user.signingkey 2>/dev/null || echo "")
    local gpg_badge=""
    [[ -n "$key" ]] && gpg_badge=" ${YELLOW}GPG${RESET}"
    printf "  ${BOLD}%-12s${RESET} %s ${DIM}<%s>${RESET}%b\n" "$id" "$name" "$email" "$gpg_badge"
  done
  [[ $found -eq 0 ]] && echo -e "  ${DIM}No identities configured${RESET}"
  echo
}

# --- Create identity ---
create_identity() {
  header "Create Identity"

  read -p "  Identity name (e.g. github, work): " identity
  if [[ -z "$identity" ]]; then
    error "No identity name provided."
    return
  fi
  if [[ "$identity" =~ [^a-zA-Z0-9_-] ]]; then
    error "Identity name must contain only letters, numbers, hyphens, underscores."
    return
  fi

  local id_dir="$BASE_DIR/$identity"
  local config_path="$id_dir/.gitconfig"

  if [[ -f "$config_path" ]]; then
    warn "  Identity '$identity' already exists."
    return
  fi

  mkdir -p "$id_dir"

  local email name
  while true; do
    read -p "  Email: " email
    [[ "$email" == *@* ]] && break
    error "  Invalid email format."
  done

  while true; do
    read -p "  Name: " name
    [[ -n "$name" ]] && break
    error "  Name cannot be empty."
  done

  read -p "  Use GPG signing? [y/N]: " use_gpg
  use_gpg="${use_gpg,,}"

  local key_id=""
  if [[ "$use_gpg" == "y" ]]; then
    if ! command -v gpg &>/dev/null; then
      error "  gpg not found. Install GnuPG first."
      return
    fi

    read -s -p "  GPG Passphrase (hidden): " passphrase
    echo

    GNUPGHOME_TMP=$(mktemp -d)
    KEYFILE=$(mktemp -m 600)

    cat >"$KEYFILE" <<EOF
%echo Generating GPG key for $name <$email>
Key-Type: RSA
Key-Length: 4096
Name-Real: $name
Name-Email: $email
Passphrase: $passphrase
%commit
%echo done
EOF

    info "  Generating GPG key..."
    gpg --batch --homedir "$GNUPGHOME_TMP" --generate-key "$KEYFILE" 2>/dev/null

    key_id=$(gpg --homedir "$GNUPGHOME_TMP" --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/ {print $5; exit}')
    if [[ -z "$key_id" ]]; then
      error "  Failed to generate GPG key."
      cleanup
      return
    fi

    gpg --homedir "$GNUPGHOME_TMP" --export-secret-keys --armor "$key_id" 2>/dev/null | gpg --import 2>/dev/null
    gpg --homedir "$GNUPGHOME_TMP" --export --armor "$key_id" 2>/dev/null | gpg --import 2>/dev/null

    cleanup
    GNUPGHOME_TMP="" KEYFILE=""
  fi

  # Preview
  header "Preview: $config_path"
  echo -e "  ${DIM}[user]${RESET}"
  echo -e "  ${DIM}    email = ${RESET}$email"
  echo -e "  ${DIM}    name = ${RESET}$name"
  if [[ -n "$key_id" ]]; then
    echo -e "  ${DIM}    signingkey = ${RESET}$key_id"
    echo -e "  ${DIM}[commit]${RESET}"
    echo -e "  ${DIM}    gpgsign = true${RESET}"
  fi
  echo

  read -p "  Save? [Y/n]: " confirm
  if [[ "${confirm,,}" == "n" ]]; then
    warn "  Cancelled."
    return
  fi

  # Write config
  if [[ -n "$key_id" ]]; then
    cat >"$config_path" <<EOF
[user]
    email = $email
    name = $name
    signingkey = $key_id
[commit]
    gpgsign = true
EOF
  else
    cat >"$config_path" <<EOF
[user]
    email = $email
    name = $name
EOF
  fi

  # Add includeIf
  local id_dir_tilde="${id_dir/#$HOME/~}"
  local include_if_line="[includeIf \"gitdir:$id_dir_tilde/\"]"

  if ! grep -Fq "$include_if_line" "$LOCAL_INCLUDE_FILE" 2>/dev/null; then
    { echo; echo "$include_if_line"; echo "    path = $id_dir_tilde/.gitconfig"; } >>"$LOCAL_INCLUDE_FILE"
  fi

  success "  Identity '$identity' created."

  if [[ -n "$key_id" ]]; then
    echo
    info "  Public GPG key (add to Git hosting):"
    echo
    gpg --armor --export "$key_id"
  fi
}

# --- Delete identity ---
delete_identity() {
  header "Delete Identity"

  local identities=()
  for cfg in "$BASE_DIR"/*/.gitconfig; do
    [[ -f "$cfg" ]] || continue
    identities+=($(basename "$(dirname "$cfg")"))
  done

  if [[ ${#identities[@]} -eq 0 ]]; then
    echo -e "  ${DIM}No identities to delete.${RESET}"
    return
  fi

  echo "  Available identities:"
  for i in "${!identities[@]}"; do
    echo -e "    ${BOLD}$((i+1)))${RESET} ${identities[$i]}"
  done
  echo

  read -p "  Select number to delete (or q to cancel): " choice
  [[ "$choice" == "q" || -z "$choice" ]] && return

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#identities[@]} )); then
    error "  Invalid selection."
    return
  fi

  local identity="${identities[$((choice-1))]}"
  local id_dir="$BASE_DIR/$identity"
  local config_path="$id_dir/.gitconfig"

  warn "  This will delete $config_path and remove includeIf from $LOCAL_INCLUDE_FILE"
  read -p "  Are you sure? [y/N]: " confirm
  [[ "${confirm,,}" != "y" ]] && return

  rm -f "$config_path"

  # Remove includeIf block from .gitconfig.local
  local id_dir_tilde="${id_dir/#$HOME/~}"
  if [[ -f "$LOCAL_INCLUDE_FILE" ]]; then
    local tmp=$(mktemp)
    awk -v pattern="gitdir:$id_dir_tilde/" '
      $0 ~ "\\[includeIf.*" pattern ".*\\]" { skip=1; next }
      skip && /^[[:space:]]+(path|email|name)/ { next }
      skip && /^\[/ { skip=0 }
      skip && /^$/ { next }
      !skip { print }
    ' "$LOCAL_INCLUDE_FILE" > "$tmp"
    mv "$tmp" "$LOCAL_INCLUDE_FILE"
  fi

  success "  Identity '$identity' deleted."
}

# --- Main menu ---
echo -e "\n${BOLD}Git Identity Manager${RESET}"

while true; do
  echo -e "${DIM}$(printf '%.0s─' {1..40})${RESET}"
  echo -e "  ${BOLD}1)${RESET} Create new identity"
  echo -e "  ${BOLD}2)${RESET} List identities"
  echo -e "  ${BOLD}3)${RESET} Delete identity"
  echo -e "  ${BOLD}4)${RESET} Exit"
  echo

  read -p "  Choose [1-4]: " action
  case "$action" in
    1) create_identity ;;
    2) list_identities ;;
    3) delete_identity ;;
    4|q|"") break ;;
    *) error "  Invalid option." ;;
  esac
done
