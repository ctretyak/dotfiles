#!/bin/bash

BASE_DIR=~/git
LOCAL_INCLUDE_FILE=~/.gitconfig.local

# Prompt for identity name
read -p "Enter identity name (e.g. github, gitlab, work): " identity

if [[ -z "$identity" ]]; then
  echo "No identity name provided. Exiting."
  exit 1
fi

ID_DIR="$BASE_DIR/$identity"
CONFIG_PATH="$ID_DIR/.gitconfig"

mkdir -p "$ID_DIR"

if [[ -f "$CONFIG_PATH" ]]; then
  echo "$CONFIG_PATH already exists — skipping"
else
  echo "Setting up identity for '$identity':"
  read -p "  Email: " email
  read -p "  Name: " name
  read -p "  Use GPG signing for this identity? [y/N]: " use_gpg
  use_gpg=${use_gpg,,} # lowercase

  if [[ "$use_gpg" == "y" ]]; then
    read -s -p "  GPG Passphrase (input hidden): " passphrase
    echo

    # Create temporary GPG home and batch file
    GNUPGHOME=$(mktemp -d)
    KEYFILE=$(mktemp)

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

    echo "Generating GPG key..."
    gpg --batch --homedir "$GNUPGHOME" --generate-key "$KEYFILE"

    KEY_ID=$(gpg --homedir "$GNUPGHOME" --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')
    if [[ -z "$KEY_ID" ]]; then
      echo "Failed to generate or retrieve key ID. Exiting."
      rm -rf "$GNUPGHOME" "$KEYFILE"
      exit 1
    fi

    echo "Exporting key to default keyring..."
    gpg --homedir "$GNUPGHOME" --export-secret-keys --armor "$KEY_ID" | gpg --import
    gpg --homedir "$GNUPGHOME" --export --armor "$KEY_ID" | gpg --import

    rm -rf "$GNUPGHOME" "$KEYFILE"
    echo "GPG key created with ID: $KEY_ID"

    cat >"$CONFIG_PATH" <<EOF
[user]
    email = $email
    name = $name
    signingkey = $KEY_ID
[commit]
    gpgsign = true
EOF

  else
    echo "Skipping GPG key generation"

    cat >"$CONFIG_PATH" <<EOF
[user]
    email = $email
    name = $name
EOF

  fi

  echo "Created $CONFIG_PATH"
fi

# Add includeIf block to ~/.gitconfig.local if missing
ID_DIR_TILDE="${ID_DIR/#$HOME/~}"
INCLUDE_IF_LINE="[includeIf \"gitdir:$ID_DIR_TILDE/\"]"
PATH_LINE="    path = $ID_DIR_TILDE/.gitconfig"

if grep -Fq "$INCLUDE_IF_LINE" "$LOCAL_INCLUDE_FILE" 2>/dev/null; then
  echo "Include for $identity already exists in $LOCAL_INCLUDE_FILE — skipping"
else
  {
    echo
    echo "$INCLUDE_IF_LINE"
    echo "$PATH_LINE"
  } >>"$LOCAL_INCLUDE_FILE"

  echo "Added includeIf for $identity to $LOCAL_INCLUDE_FILE"
fi

# Export public key if GPG was used
if [[ "$use_gpg" == "y" && -n "$KEY_ID" ]]; then
  echo
  echo "🔑 Public GPG key for $identity:"
  echo
  gpg --armor --export "$KEY_ID"
fi
